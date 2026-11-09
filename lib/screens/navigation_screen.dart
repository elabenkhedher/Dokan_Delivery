import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/navigation_controller.dart';
import '../models/delivery_order.dart';
import '../services/navigation/location_service.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/delivery_qr_dialog.dart';

/// Écran complet de navigation GPS temps réel basé sur OpenStreetMap (100% gratuit, sans clé payante).
class NavigationScreen extends StatelessWidget {
  final DeliveryOrder? order;
  final LatLng? destination;
  final List<DeliveryOrder>? tourOrders;
  final Map<String, dynamic>? vehicleInfo;

  const NavigationScreen({
    super.key,
    this.order,
    this.destination,
    this.tourOrders,
    this.vehicleInfo,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NavigationController()
        ..initialize(
          deliveryOrder: order,
          clientDestination: destination,
          tourOrders: tourOrders,
          assignedVehicle: vehicleInfo,
        ),
      child: const _NavigationScreenBody(),
    );
  }
}

class _NavigationScreenBody extends StatelessWidget {
  const _NavigationScreenBody();

  Future<void> _callCustomer(BuildContext context, String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      AppSnackBar.showError(context, 'Numéro de téléphone client non renseigné.');
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      Clipboard.setData(ClipboardData(text: phone));
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Numéro copié : $phone');
      }
    }
  }

  Future<void> _openExternalMaps(BuildContext context, LatLng dest, String address) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}&travelmode=driving',
    );
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) await launchUrl(url);
    } catch (_) {
      Clipboard.setData(ClipboardData(text: address));
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Adresse copiée dans le presse-papier.');
      }
    }
  }

  Future<void> _openDeliveryQr(
    BuildContext context,
    NavigationController controller,
  ) async {
    HapticFeedback.heavyImpact();
    final success = await DeliveryQrDialog.show(
      context: context,
      order: controller.order,
      orderService: controller.orderService,
    );
    if (success == true) {
      await controller.completeDelivery();
      if (context.mounted) {
        if (controller.remainingTourOrdersCount == 0) {
          AppSnackBar.showSuccess(
              context, 'Toutes les commandes de la tournée ont été livrées !');
        } else {
          AppSnackBar.showSuccess(context, 'Livraison terminée avec succès !');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NavigationController>();

    // ── 1. Écran de refus de permission avec redirection ────────────
    if (controller.permissionStatus == DelivererLocationPermissionStatus.permissionDeniedForever ||
        controller.permissionStatus == DelivererLocationPermissionStatus.serviceDisabled) {
      return Scaffold(
        appBar: AppBar(title: const Text('GPS requis')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off_rounded, size: 72, color: AppColors.accent),
                const SizedBox(height: 16),
                const Text(
                  'Localisation indisponible',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.permissionStatus == DelivererLocationPermissionStatus.serviceDisabled
                      ? 'Veuillez activer le capteur GPS dans vos paramètres.'
                      : 'La permission GPS permanente est requise pour le guidage en direct.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => LocationService().openAppSettings(),
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Ouvrir les paramètres'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── 2. Écran principal de Navigation OpenStreetMap ───────────────
    final initialCenter = controller.currentLocation?.latLng ?? controller.destination;

    return Scaffold(
      body: Stack(
        children: [
          // A. Carte OpenStreetMap plein écran (Gratuite, sans clé d'API)
          FlutterMap(
            mapController: controller.mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 16.5,
              initialRotation: controller.currentLocation?.heading ?? 0.0,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  controller.onUserPanMap();
                }
              },
            ),
            children: [
              // Tuiles OpenStreetMap (100% gratuites, nettes avec rues, routes et noms)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                fallbackUrl: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.livreur_app',
                maxZoom: 19,
                panBuffer: 1,
                keepBuffer: 2,
              ),

              // Tracé de l'itinéraire OSRM (Ligne bleue) vers la commande sélectionnée
              if (controller.routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: controller.routePoints,
                      strokeWidth: 6.0,
                      color: const Color(0xFF2563EB),
                    ),
                  ],
                ),

              // Marqueurs : Commandes de la tournée & Véhicule Livreur
              MarkerLayer(
                markers: [
                  // 1. Tous les marqueurs des commandes de la tournée
                  if (controller.tourOrders.isNotEmpty)
                    ...controller.tourOrders.asMap().entries.map((entry) {
                      final index = entry.key;
                      final o = entry.value;
                      final isSelected = o.id == controller.order.id;
                      return Marker(
                        point: o.destinationLatLng,
                        width: isSelected ? 52 : 38,
                        height: isSelected ? 52 : 38,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.selectOrder(o);
                          },
                          child: _OrderStopMarker(
                            stopNumber: index + 1,
                            isSelected: isSelected,
                            isDelivered: o.isDelivered,
                            displayNumber: o.displayNumber.isNotEmpty
                                ? o.displayNumber
                                : o.id,
                          ),
                        ),
                      );
                    })
                  else
                    // Marqueur unique Client classique
                    Marker(
                      point: controller.destination,
                      width: 44,
                      height: 44,
                      child: const _ClientDestinationMarker(),
                    ),

                  // 2. Marqueur du véhicule (avec rotation selon le cap)
                  if (controller.currentLocation != null)
                    Marker(
                      point: controller.currentLocation!.latLng,
                      width: 52,
                      height: 52,
                      child: Transform.rotate(
                        angle: (controller.currentLocation!.heading * math.pi) / 180,
                        child: const _VehicleMarker(),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // B. Bandeau supérieur : Prochaine instruction de guidage
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _TopManeuverBanner(controller: controller),
              ),
            ),
          ),

          // C. Bouton Retour (Quitter la navigation)
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 20,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // D1. Bouton "Vue d'ensemble de la tournée"
          if (controller.tourOrders.length > 1)
            Positioned(
              right: 16,
              bottom: controller.isArrived ? 260 : 255,
              child: FloatingActionButton.extended(
                heroTag: 'fab_tour_overview',
                backgroundColor: Colors.white,
                foregroundColor: AppColors.text,
                elevation: 4,
                onPressed: controller.fitAllStops,
                icon: const Icon(Icons.map_rounded, size: 20, color: AppColors.primary),
                label: Text(
                  'Tournée (${controller.remainingTourOrdersCount}/${controller.tourOrders.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),

          // D2. Bouton "Recentrer" si le suivi de caméra a été déplacé manuellement
          if (!controller.isTrackingCamera)
            Positioned(
              right: 16,
              bottom: controller.tourOrders.length > 1
                  ? (controller.isArrived ? 315 : 310)
                  : (controller.isArrived ? 260 : 200),
              child: FloatingActionButton.extended(
                heroTag: 'fab_recenter_driver',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                onPressed: controller.recenterCamera,
                icon: const Icon(Icons.navigation_rounded, size: 20),
                label: const Text(
                  'Recentrer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // E. Tournée complétée à 100%
          if (controller.isDelivered &&
              controller.tourOrders.isNotEmpty &&
              controller.remainingTourOrdersCount == 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                child: _TourCompletedCard(
                  totalOrders: controller.tourOrders.length,
                  onClose: () => Navigator.pop(context, true),
                ),
              ),
            )
          // F. Panneau d'arrivée ou télémétrie classique
          else ...[
            // Sélecteur horizontal d'arrêts de la tournée
            if (controller.tourOrders.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: controller.isArrived ? 240 : 210,
                child: SafeArea(
                  child: _TourStopsCarousel(controller: controller),
                ),
              ),

            if (controller.isArrived)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: SafeArea(
                  child: _ArrivalCard(
                    order: controller.order,
                    onCall: () => _callCustomer(context, controller.order.phone),
                    onExternalMaps: () => _openExternalMaps(
                      context,
                      controller.destination,
                      controller.order.address,
                    ),
                    onDelivered: () => _openDeliveryQr(context, controller),
                  ),
                ),
              )
            else
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: _BottomTelemetryPanel(
                    controller: controller,
                    onCallCustomer: () => _callCustomer(context, controller.order.phone),
                    onExternalMaps: () => _openExternalMaps(
                      context,
                      controller.destination,
                      controller.order.address,
                    ),
                    onOpenQr: () => _openDeliveryQr(context, controller),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Widget Marqueur Client (Destination) ─────────────────────────
class _ClientDestinationMarker extends StatelessWidget {
  const _ClientDestinationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
    );
  }
}

// ── Widget Marqueur Véhicule (Livreur orienté) ───────────────────
class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.navigation_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Widget Bandeau Haut (Instruction OSRM) ──────────────────────
class _TopManeuverBanner extends StatelessWidget {
  final NavigationController controller;
  const _TopManeuverBanner({required this.controller});

  @override
  Widget build(BuildContext context) {
    final step = controller.currentStep;
    final isRecalc = controller.isRecalculating;

    return Card(
      elevation: 6,
      color: const Color(0xFF1E293B), // Fond sombre style GPS pro
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRecalc ? AppColors.accent : const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isRecalc
                    ? Icons.sync_rounded
                    : (step?.icon ?? Icons.straight_rounded),
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRecalc) ...[
                    const Text(
                      'Recalcul de l\'itinéraire...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Sortie de route détectée',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ] else ...[
                    Text(
                      step != null ? step.formatDistance() : 'Itinéraire en cours',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step?.instruction ?? 'Suivez le tracé bleu',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget Panneau Bas (Télémétrie & Options) ─────────────────────
class _BottomTelemetryPanel extends StatelessWidget {
  final NavigationController controller;
  final VoidCallback onCallCustomer;
  final VoidCallback onExternalMaps;
  final VoidCallback onOpenQr;

  const _BottomTelemetryPanel({
    required this.controller,
    required this.onCallCustomer,
    required this.onExternalMaps,
    required this.onOpenQr,
  });

  @override
  Widget build(BuildContext context) {
    final route = controller.routeInfo;

    return Card(
      elevation: 8,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Durée restante
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route?.formattedDuration ?? '-- min',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ETA : ${route?.etaFormatted ?? '--:--'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),

                // Distance restante
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      route?.formattedDistance ?? '-- km',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Distance',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),

                // Actions rapides (Appel client + Maps externe)
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Appeler le client',
                      onPressed: onCallCustomer,
                      icon: const Icon(Icons.phone_rounded, color: AppColors.success),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: 'Ouvrir dans Google Maps',
                      onPressed: onExternalMaps,
                      icon: const Icon(Icons.map_rounded, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                const Icon(Icons.person_pin_circle_rounded, size: 18, color: Colors.black45),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${controller.order.customerName} • ${controller.order.address}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onOpenQr,
                icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                label: const Text(
                  'Valider la livraison (QR Client)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget Marqueur d'arrêt de tournée ─────────────────────────────
class _OrderStopMarker extends StatelessWidget {
  final int stopNumber;
  final bool isSelected;
  final bool isDelivered;
  final String displayNumber;

  const _OrderStopMarker({
    required this.stopNumber,
    required this.isSelected,
    required this.isDelivered,
    required this.displayNumber,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDelivered
        ? AppColors.success
        : (isSelected ? const Color(0xFF2563EB) : const Color(0xFFF59E0B));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isSelected ? 50 : 38,
      height: isSelected ? 50 : 38,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: isSelected ? 3.5 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: isSelected ? 0.55 : 0.35),
            blurRadius: isSelected ? 12 : 6,
            spreadRadius: isSelected ? 2 : 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: isDelivered
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : Text(
                '$stopNumber',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSelected ? 17 : 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

// ── Carrousel horizontal des arrêts de la tournée ─────────────────
class _TourStopsCarousel extends StatelessWidget {
  final NavigationController controller;

  const _TourStopsCarousel({required this.controller});

  @override
  Widget build(BuildContext context) {
    final orders = controller.tourOrders;
    if (orders.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final o = orders[index];
          final isSelected = o.id == controller.order.id;
          final isDelivered = o.isDelivered;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: () {
                HapticFeedback.selectionClick();
                controller.selectOrder(o);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isDelivered
                          ? AppColors.success.withValues(alpha: 0.15)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDelivered ? AppColors.success : AppColors.border),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : (isDelivered
                                ? AppColors.success
                                : const Color(0xFFF59E0B)),
                      ),
                      alignment: Alignment.center,
                      child: isDelivered
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 14)
                          : Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      o.customerName.isNotEmpty
                          ? o.customerName
                          : 'Arrêt #${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDelivered
                                ? AppColors.success
                                : Colors.black87),
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.navigation_rounded,
                          color: Colors.white, size: 14),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Carte de célébration fin de tournée ───────────────────────────
class _TourCompletedCard extends StatelessWidget {
  final int totalOrders;
  final VoidCallback onClose;

  const _TourCompletedCard({
    required this.totalOrders,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 14,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: AppColors.success,
                size: 46,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Tournée 100% Terminée !',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Les $totalOrders commandes de votre tournée ont toutes été validées et livrées avec succès.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.mutedText),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.dashboard_rounded),
              label: const Text(
                'Retourner au tableau de bord',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget Alerte d'Arrivée (<= 50m) ─────────────────────────────
class _ArrivalCard extends StatelessWidget {
  final DeliveryOrder order;
  final VoidCallback onCall;
  final VoidCallback onExternalMaps;
  final VoidCallback onDelivered;

  const _ArrivalCard({
    required this.order,
    required this.onCall,
    required this.onExternalMaps,
    required this.onDelivered,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 12,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vous êtes arrivé !',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Destination : ${order.customerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('Appeler'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: const BorderSide(color: AppColors.success),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onExternalMaps,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Maps'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: onDelivered,
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text(
                'Livraison terminée',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
