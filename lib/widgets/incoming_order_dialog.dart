import 'package:flutter/material.dart';

import '../models/delivery_order.dart';
import '../theme/app_theme.dart';
import 'vehicle_payload_card.dart';

/// Dialogue modal ergonomique pour présenter une nouvelle offre de commande au livreur.
/// Affiche le poids total de la commande en kg et la nouvelle charge projetée du véhicule si acceptée.
class IncomingOrderDialog extends StatelessWidget {
  final DeliveryOrder order;
  final double currentLoadedWeight;
  final double maxCapacityKg;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  const IncomingOrderDialog({
    super.key,
    required this.order,
    required this.currentLoadedWeight,
    required this.maxCapacityKg,
    required this.onAccept,
    required this.onRefuse,
  });

  /// Méthode statique utilitaire pour afficher ce dialogue
  static Future<bool?> show({
    required BuildContext context,
    required DeliveryOrder order,
    required double currentLoadedWeight,
    required double maxCapacityKg,
    required VoidCallback onAccept,
    required VoidCallback onRefuse,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IncomingOrderDialog(
        order: order,
        currentLoadedWeight: currentLoadedWeight,
        maxCapacityKg: maxCapacityKg,
        onAccept: () {
          Navigator.pop(ctx, true);
          onAccept();
        },
        onRefuse: () {
          Navigator.pop(ctx, false);
          onRefuse();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final safeMax = maxCapacityKg > 0 ? maxCapacityKg : 100.0;
    final projectedWeight = currentLoadedWeight + order.totalPoids;
    final projectedPercentage = (projectedWeight / safeMax) * 100.0;
    final currentPercentage = (currentLoadedWeight / safeMax) * 100.0;

    final isOverCapacity = projectedWeight > safeMax;
    final projectedGaugeColor = VehiclePayloadCard.getStatusColor(projectedPercentage);

    final currentRatio = (currentLoadedWeight / safeMax).clamp(0.0, 1.0);
    final projectedRatio = (projectedWeight / safeMax).clamp(0.0, 1.0);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── En-tête : Badge offre & Numéro commande ───────
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: const Text(
                                'NOUVELLE OFFRE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Commande #${order.displayNumber.isNotEmpty ? order.displayNumber : order.id}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${order.total.toStringAsFixed(3)} DT',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── Poids de la commande (Mise en valeur) ─────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.scale_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Poids total du colis',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${VehiclePayloadCard.formatWeight(order.totalPoids)} kg',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (order.items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '${order.items.length} article${order.items.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Section Charge Projetée du Véhicule ──────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: projectedGaugeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: projectedGaugeColor.withValues(alpha: isOverCapacity ? 0.6 : 0.3),
                    width: isOverCapacity ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.speed_rounded,
                          size: 18,
                          color: projectedGaugeColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Charge projetée du véhicule',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: projectedGaugeColor,
                            ),
                          ),
                        ),
                        Text(
                          '${projectedPercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: projectedGaugeColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Actuelle : ${VehiclePayloadCard.formatWeight(currentLoadedWeight)} kg (${currentPercentage.toStringAsFixed(0)}%)  ➔  Projetée : ${VehiclePayloadCard.formatWeight(projectedWeight)} / ${VehiclePayloadCard.formatWeight(safeMax)} kg',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                    ),
                    const SizedBox(height: 10),

                    // Double jauge superposée (Actuelle vs Ajout commande)
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceAlt
                                : Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Portion projetée totale
                        FractionallySizedBox(
                          widthFactor: projectedRatio,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: projectedGaugeColor.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        // Portion actuelle déjà chargée
                        FractionallySizedBox(
                          widthFactor: currentRatio,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: projectedGaugeColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (isOverCapacity) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Attention : Dépasse la capacité max (${VehiclePayloadCard.formatWeight(projectedWeight - safeMax)} kg excédentaire) !',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Destination & Client ──────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.mutedText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${order.customerName} • ${order.address}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Liste succincte des articles si disponibles
              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Text(
                  'Articles inclus :',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 4),
                ...order.items.take(3).map((it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${it.quantity}x ${it.name}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (it.poids > 0)
                            Text(
                              '${VehiclePayloadCard.formatWeight(it.totalPoidsLigne)} kg',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mutedText,
                              ),
                            ),
                        ],
                      ),
                    )),
                if (order.items.length > 3)
                  Text(
                    '+ ${order.items.length - 3} autre(s) article(s)...',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.mutedText),
                  ),
              ],

              const SizedBox(height: 22),

              // ── Boutons d'Action ─────────────────────────────
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: OutlinedButton(
                      key: const ValueKey('dialog-refuse-btn'),
                      onPressed: onRefuse,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(
                          color: colorScheme.error.withValues(alpha: 0.6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text(
                        'Refuser',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: FilledButton.icon(
                      key: const ValueKey('dialog-accept-btn'),
                      onPressed: onAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: isOverCapacity ? AppColors.accent : AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Accepter',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
