import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/delivery_order.dart';
import '../services/deliverer_location_service.dart';
import '../services/order_service.dart';
import 'navigation_screen.dart';
import '../services/working_hours_service.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/delivery_qr_dialog.dart';
import '../widgets/order_status_badge.dart';

class OrderDetailsScreen extends StatefulWidget {
  final DeliveryOrder order;
  final OrderService orderService;
  final WorkingHoursService workingHoursService;

  const OrderDetailsScreen({
    super.key,
    required this.order,
    required this.orderService,
    required this.workingHoursService,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: AppDurations.normal,
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: AppCurves.smooth);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _advanceStatus() async {
    HapticFeedback.lightImpact();

    if (!widget.order.isPickedUp) {
      AppSnackBar.showError(
        context,
        'Impossible de livrer : ce colis n\'a pas encore été enlevé au stock. Veuillez d\'abord scanner le bon d\'enlèvement.',
      );
      return;
    }

    // Confirmation de livraison par scan QR client
    final success = await DeliveryQrDialog.show(
      context: context,
      order: widget.order,
      orderService: widget.orderService,
    );

    if (success == true && mounted) {
      // Synchronisation du suivi GPS temps réel
      DelivererLocationService().updateCurrentOrder(null);

      setState(() {});
      AppSnackBar.showSuccess(
        context,
        'Commande #${widget.order.displayNumber.isNotEmpty ? widget.order.displayNumber : widget.order.id} livrée avec succès !',
      );
    }
  }

  Future<void> _openNavigation(String address) async {
    final cleanAddress = address.trim();
    if (cleanAddress.isEmpty || cleanAddress == 'Adresse non spécifiée') {
      AppSnackBar.showError(
        context,
        'Adresse de livraison non spécifiée pour la navigation.',
      );
      return;
    }

    // Lance directement l'écran de guidage GPS intégré à l'application
    final delivered = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NavigationScreen(
          order: widget.order,
          destination: widget.order.destinationLatLng,
          vehicleInfo: DelivererLocationService().vehicleInfo,
        ),
      ),
    );

    if (delivered == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _openExternalMaps(String address) async {
    final cleanAddress = address.trim();
    final encoded = Uri.encodeComponent(cleanAddress);
    final googleMapsUrl =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');

    try {
      final launched =
          await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(googleMapsUrl);
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: cleanAddress));
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Adresse copiée dans le presse-papier : $cleanAddress',
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      AppSnackBar.showError(context, 'Numéro de téléphone non renseigné ou invalide.');
      return;
    }
    final Uri uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Impossible d\'ouvrir l\'application d\'appel. Numéro copié : $phone',
        );
      }
    }
  }

  Future<void> _sendSms(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      AppSnackBar.showError(context, 'Numéro de téléphone non renseigné ou invalide.');
      return;
    }
    final Uri uri = Uri(scheme: 'sms', path: cleanPhone);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: phone));
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Impossible d\'ouvrir les SMS. Numéro copié : $phone',
        );
      }
    }
  }

  void _showContactOptions(String phone, String customerName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Contacter $customerName',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                phone,
                style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.successSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.phone_rounded, color: AppColors.success, size: 22),
                ),
                title: const Text('Appeler le client', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Lancer un appel téléphonique direct'),
                onTap: () {
                  Navigator.pop(ctx);
                  _makePhoneCall(phone);
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.sms_rounded, color: AppColors.primary, size: 22),
                ),
                title: const Text('Envoyer un SMS', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Ouvrir l\'application de messagerie'),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendSms(phone);
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.copy_rounded, color: AppColors.mutedText, size: 20),
                ),
                title: const Text('Copier le numéro', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Copier dans le presse-papier'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: phone));
                  AppSnackBar.showSuccess(context, 'Numéro copié');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _declareDeliveryFailure() async {
    final reasons = [
      'Client injoignable (ne répond pas)',
      'Adresse introuvable ou incorrecte',
      'Client absent du domicile / lieu convenu',
      'Colis refusé par le client',
      'Autre motif...',
    ];
    String selectedReason = reasons[0];
    final customController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.report_problem_rounded,
                    color: Theme.of(context).colorScheme.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Échec de livraison',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Indiquez le motif de non-livraison :',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  ...reasons.map((r) => RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(r, style: const TextStyle(fontSize: 14)),
                        value: r,
                        // ignore: deprecated_member_use
                        groupValue: selectedReason,
                        activeColor: Theme.of(context).colorScheme.error,
                        // ignore: deprecated_member_use
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedReason = val);
                          }
                        },
                      )),
                  if (selectedReason == 'Autre motif...') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Précisez la raison...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Annuler'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () {
                  final reason = selectedReason == 'Autre motif...' &&
                          customController.text.trim().isNotEmpty
                      ? customController.text.trim()
                      : selectedReason;
                  Navigator.pop(ctx, reason);
                },
                child: const Text('Confirmer l\'échec'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && mounted) {
      try {
        await widget.orderService.marquerEchecCommande(widget.order, result);
        DelivererLocationService().updateCurrentOrder(null);
        if (!mounted) return;
        setState(() {});
        AppSnackBar.showError(
          context,
          'Échec de livraison enregistré : $result',
        );
      } catch (e) {
        if (!mounted) return;
        AppSnackBar.showError(context, 'Erreur : $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final order = widget.order;
    final isDelivered = order.isDelivered;
    final isRefused = order.isFailedOrRefused;

    final statusStep = order.isDelivered
        ? 2
        : order.isInProgress
            ? 1
            : order.isAssigned
                ? 0
                : -1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Commande #${order.displayNumber.isNotEmpty ? order.displayNumber : order.id}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // ── Bannière statut ──────────────────────────────
            _StatusBanner(order: order),
            const SizedBox(height: 16),

            // ── Raccourci Navigation GPS en cours ─────────────
            if (order.isInProgress) ...[
              Card(
                elevation: 0,
                color: AppColors.primarySoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Navigation GPS en direct',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Position temps réel partagée',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _openNavigation(order.address),
                        icon: const Icon(Icons.turn_right_rounded, size: 16),
                        label: const Text('Naviguer'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 6),
            ],

            if (order.driverRating != null && order.driverRating! > 0) ...[
              const _SectionTitle(title: '⭐ Évaluation & Compliments client'),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: const BorderSide(color: Color(0xFFFCD34D), width: 1.2),
                ),
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < order.driverRating!
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: const Color(0xFFF59E0B),
                                size: 24,
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${order.driverRating} / 5 étoiles',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                      if (order.feedbackTags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: order.feedbackTags.map((tag) {
                            return Chip(
                              backgroundColor: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFFEF3C7),
                              side: const BorderSide(color: Color(0xFFFCD34D)),
                              label: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF92400E),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Infos client ────────────────────────────────
            const _SectionTitle(title: 'Informations client'),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Client',
                    value: order.customerName,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Adresse de livraison (Appuyez pour naviguer)',
                    value: order.address,
                    isAddress: true,
                    onNavigate: () => _openNavigation(order.address),
                    onExternalMaps: () => _openExternalMaps(order.address),
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: order.address));
                      AppSnackBar.showSuccess(context, 'Adresse copiée');
                    },
                    onTap: () => _openNavigation(order.address),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Téléphone (Appuyez pour contacter)',
                    value: order.phone,
                    isPhone: true,
                    onCall: () => _makePhoneCall(order.phone),
                    onSms: () => _sendSms(order.phone),
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: order.phone));
                      AppSnackBar.showSuccess(context, 'Numéro copié');
                    },
                    onTap: () => _showContactOptions(order.phone, order.customerName),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Montant à encaisser',
                    value: '${order.total.toStringAsFixed(3)} TND',
                    isAmount: true,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _InfoRow(
                    icon: Icons.scale_rounded,
                    label: 'Poids du colis (charge)',
                    value: '${order.totalPoids % 1 == 0 ? order.totalPoids.toInt() : order.totalPoids.toStringAsFixed(1)} kg',
                  ),
                ],
              ),
            ),
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 22),
              _SectionTitle(title: 'Articles commandés (${order.items.length})'),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: order.items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, idx) {
                    final item = order.items[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Center(
                          child: Text(
                            '${item.quantity}x',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: item.poids > 0
                          ? Text(
                              'Poids : ${item.poids % 1 == 0 ? item.poids.toInt() : item.poids.toStringAsFixed(1)} kg/u (Total : ${item.totalPoidsLigne.toStringAsFixed(1)} kg)',
                              style: const TextStyle(fontSize: 12),
                            )
                          : null,
                      trailing: item.price > 0
                          ? Text(
                              '${(item.price * item.quantity).toStringAsFixed(3)} DT',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 22),

            // ── Rapport d'échec / refus ───────────────────────
            if (isRefused) ...[
              const _SectionTitle(title: 'Rapport d\'incident'),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.report_problem_rounded,
                            color: Theme.of(context).colorScheme.error,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Échec de livraison (Retour stock)',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (order.motifEchec != null && order.motifEchec!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Motif enregistré :',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.motifEchec!,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (order.failedAt != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: AppColors.mutedText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Enregistré le ${order.failedAt!.day.toString().padLeft(2, '0')}/${order.failedAt!.month.toString().padLeft(2, '0')}/${order.failedAt!.year} à ${order.failedAt!.hour.toString().padLeft(2, '0')}:${order.failedAt!.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mutedText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ],

            // ── Progression de la livraison ──────────────────
            if (!isRefused) ...[
              const _SectionTitle(title: 'Progression de la livraison'),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 22,
                  ),
                  child: _DeliveryTimeline(currentStep: statusStep),
                ),
              ),
              const SizedBox(height: 22),
            ],

          ],
        ),
      ),
      bottomNavigationBar: _BottomActions(
        order: order,
        isDelivered: isDelivered,
        isRefused: isRefused,
        onAdvance: _advanceStatus,
        onDeclareFailure: _declareDeliveryFailure,
      ),
    );
  }
}

// ── Bannière statut ────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final DeliveryOrder order;
  const _StatusBanner({required this.order});

  @override
  Widget build(BuildContext context) {
    final color = order.statusColor(context);

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(order.statusIcon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Commande #${order.displayNumber.isNotEmpty ? order.displayNumber : order.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                ),
                const SizedBox(height: 6),
                OrderStatusBadge(
                  status: order.status,
                  fontSize: 12,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline de livraison ─────────────────────────────────────
class _DeliveryTimeline extends StatelessWidget {
  final int currentStep;
  const _DeliveryTimeline({required this.currentStep});

  static const _steps = [
    ('Affectée', Icons.assignment_outlined),
    ('En cours', Icons.directions_car_rounded),
    ('Livrée', Icons.check_circle_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (int i = 0; i < _steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ligne de liaison
                    if (i < _steps.length - 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          height: 2.5,
                          margin: const EdgeInsets.only(left: 30),
                          color: i < currentStep
                              ? AppColors.primary
                              : colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                    // Cercle d'étape
                    AnimatedContainer(
                      duration: AppDurations.medium,
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= currentStep
                            ? (i == currentStep
                                ? AppColors.primary
                                : AppColors.success)
                            : colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: i <= currentStep
                              ? Colors.transparent
                              : colorScheme.outline.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: i == currentStep
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        i < currentStep
                            ? Icons.check_rounded
                            : _steps[i].$2,
                        color: i <= currentStep
                            ? Colors.white
                            : colorScheme.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _steps[i].$1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: i == currentStep
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i <= currentStep
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Ligne info ─────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isPhone;
  final bool isAddress;
  final bool isAmount;
  final VoidCallback? onCall;
  final VoidCallback? onSms;
  final VoidCallback? onCopy;
  final VoidCallback? onNavigate;
  final VoidCallback? onExternalMaps;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isPhone = false,
    this.isAddress = false,
    this.isAmount = false,
    this.onCall,
    this.onSms,
    this.onCopy,
    this.onNavigate,
    this.onExternalMaps,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 12,
            ),
      ),
      subtitle: Text(
        value,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: isAmount ? FontWeight.w800 : FontWeight.w600,
              color: isAmount ? AppColors.primary : null,
              fontSize: isAmount ? 16 : 14,
            ),
      ),
      trailing: isPhone
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onCall != null)
                  IconButton(
                    tooltip: 'Appeler',
                    icon: const Icon(Icons.phone_rounded, color: AppColors.success, size: 20),
                    onPressed: onCall,
                  ),
                if (onSms != null)
                  IconButton(
                    tooltip: 'Envoyer SMS',
                    icon: const Icon(Icons.sms_rounded, color: AppColors.primary, size: 20),
                    onPressed: onSms,
                  ),
                IconButton(
                  tooltip: 'Copier le numéro',
                  onPressed: onCopy ??
                      () {
                        Clipboard.setData(ClipboardData(text: value));
                        AppSnackBar.showSuccess(context, 'Numéro copié');
                      },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                ),
              ],
            )
          : (isAddress
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onNavigate != null)
                      IconButton.filledTonal(
                        tooltip: 'Guidage GPS dans l\'app',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primarySoft,
                          foregroundColor: AppColors.primary,
                        ),
                        icon: const Icon(Icons.navigation_rounded, size: 20),
                        onPressed: onNavigate,
                      ),
                    if (onExternalMaps != null)
                      IconButton(
                        tooltip: 'Google Maps externe',
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        onPressed: onExternalMaps,
                      ),
                    IconButton(
                      tooltip: 'Copier l\'adresse',
                      onPressed: onCopy ??
                          () {
                            Clipboard.setData(ClipboardData(text: value));
                            AppSnackBar.showSuccess(context, 'Adresse copiée');
                          },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                )
              : null),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// ── Section title ──────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
    );
  }
}

// ── Actions bas de page ───────────────────────────────────────
class _BottomActions extends StatelessWidget {
  final DeliveryOrder order;
  final bool isDelivered;
  final bool isRefused;
  final VoidCallback onAdvance;
  final VoidCallback onDeclareFailure;

  const _BottomActions({
    required this.order,
    required this.isDelivered,
    required this.isRefused,
    required this.onAdvance,
    required this.onDeclareFailure,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content;
    if (isDelivered || isRefused) {
      content = Card(
        color: isDelivered
            ? AppColors.primarySoft
            : colorScheme.errorContainer.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: ListTile(
          leading: Icon(
            isDelivered
                ? Icons.check_circle_rounded
                : Icons.assignment_return_rounded,
            color: isDelivered ? AppColors.primary : colorScheme.error,
          ),
          title: Text(
            isDelivered
                ? 'Commande livrée avec succès'
                : 'Échec de livraison (Retour dépôt)',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDelivered ? AppColors.primary : colorScheme.error,
            ),
          ),
          subtitle: Text(
            isDelivered
                ? 'Cette livraison est définitivement terminée.'
                : (order.motifEchec != null && order.motifEchec!.isNotEmpty
                    ? 'Motif : ${order.motifEchec}'
                    : 'Cette commande est déclarée en échec de livraison (retour au dépôt central).'),
          ),
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            key: const ValueKey('advance-order-status'),
            onPressed: onAdvance,
            icon: const Icon(Icons.task_alt_rounded),
            label: const Text('Marquer comme livrée'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('declare-failure-btn'),
            onPressed: onDeclareFailure,
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Déclarer un échec de livraison'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error, width: 1.5),
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ],
      );
    }

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? AppColors.darkBorder
                  : AppColors.border.withValues(alpha: 0.5),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: content,
      ),
    );
  }
}
