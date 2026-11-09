import 'package:flutter/material.dart';

import '../models/delivery_order.dart';
import '../models/driver_profile.dart';
import '../theme/app_theme.dart';

/// Carte de jauge de charge utile du véhicule (Payload Gauge)
/// Visualise la charge cumulée des commandes actives (affectées et en cours)
/// par rapport à la capacité maximale du véhicule du livreur.
class VehiclePayloadCard extends StatelessWidget {
  final List<DeliveryOrder> orders;
  final double maxCapacityKg;
  final String? vehicleType;
  final VoidCallback? onTap;

  const VehiclePayloadCard({
    super.key,
    required this.orders,
    required this.maxCapacityKg,
    this.vehicleType,
    this.onTap,
  });

  /// Calcule le poids actuellement chargé dans le véhicule :
  /// Somme des totalPoids de toutes les commandes actives (affectées, en cours).
  static double calculateCurrentLoadedWeight(List<DeliveryOrder> orders) {
    return orders
        .where((o) => o.isAssigned || o.isInProgress)
        .fold<double>(0.0, (sum, o) => sum + o.totalPoids);
  }

  /// Calcule la capacité restante : maxCapacityKg - currentLoadedWeight
  static double calculateRemainingCapacity(double maxCapacityKg, double currentLoadedWeight) {
    return maxCapacityKg - currentLoadedWeight;
  }

  /// Détermine la couleur selon le pourcentage de charge :
  /// - Vert (< 70%)
  /// - Orange (70% - 90%)
  /// - Rouge (> 90%)
  static Color getStatusColor(double percentage) {
    if (percentage < 70.0) {
      return AppColors.success;
    } else if (percentage <= 90.0) {
      return const Color(0xFFF59E0B); // Orange ambré
    } else {
      return AppColors.error;
    }
  }

  static String formatWeight(double weight) {
    if (weight % 1 == 0) {
      return weight.toInt().toString();
    }
    return weight.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeOrders = orders.where((o) => o.isAssigned || o.isInProgress).toList();
    final currentLoadedWeight = calculateCurrentLoadedWeight(orders);
    final remainingCapacity = calculateRemainingCapacity(maxCapacityKg, currentLoadedWeight);

    final safeMax = maxCapacityKg > 0 ? maxCapacityKg : 100.0;
    final percentage = (currentLoadedWeight / safeMax) * 100.0;
    final ratio = (currentLoadedWeight / safeMax).clamp(0.0, 1.0);
    final gaugeColor = getStatusColor(percentage);

    final typeEnum = VehicleType.fromString(vehicleType);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: percentage > 90.0
              ? AppColors.error.withValues(alpha: 0.5)
              : (isDark
                  ? AppColors.darkBorder
                  : AppColors.border.withValues(alpha: 0.65)),
          width: percentage > 90.0 ? 1.5 : 1.0,
        ),
        boxShadow: AppShadows.soft(),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête : Titre & Badge pourcentage
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: gaugeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: gaugeColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        typeEnum.icon,
                        color: gaugeColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Charge du véhicule',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14.5,
                                      letterSpacing: -0.2,
                                    ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  typeEnum.displayName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Charge du véhicule : ${formatWeight(currentLoadedWeight)} / ${formatWeight(safeMax)} kg (${percentage.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: gaugeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Badge état
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: gaugeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: gaugeColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: gaugeColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Barre de progression (Jauge linéaire stylisée)
                Stack(
                  children: [
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceAlt
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              gaugeColor.withValues(alpha: 0.8),
                              gaugeColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: gaugeColor.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Pied de carte : Capacité restante & Nombre de commandes en tournée
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${activeOrders.length} commande${activeOrders.length > 1 ? 's' : ''} en tournée',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          remainingCapacity < 0
                              ? Icons.warning_amber_rounded
                              : Icons.speed_rounded,
                          size: 14,
                          color: remainingCapacity < 0
                              ? AppColors.error
                              : (isDark ? AppColors.darkMuted : AppColors.mutedText),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          remainingCapacity < 0
                              ? 'Surcharge : ${formatWeight(-remainingCapacity)} kg'
                              : 'Reste : ${formatWeight(remainingCapacity)} kg libre',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: remainingCapacity < 0
                                ? AppColors.error
                                : (isDark ? AppColors.darkMuted : AppColors.mutedText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
