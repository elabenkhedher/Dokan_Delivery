import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/delivery_order.dart';
import '../theme/app_theme.dart';
import 'bouncy_button.dart';

/// Carte de répartition dynamique des statuts avec jauge segmentée et filtres interactifs.
class StatusBreakdownCard extends StatelessWidget {
  final int deliveredCount;
  final int inProgressCount;
  final int awaitingCount;
  final int refusedCount;
  final String activeFilter;
  final ValueChanged<String> onFilterChanged;

  const StatusBreakdownCard({
    super.key,
    required this.deliveredCount,
    required this.inProgressCount,
    required this.awaitingCount,
    required this.refusedCount,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;

    final total = deliveredCount + inProgressCount + refusedCount;

    // Calcul des pourcentages
    final pDelivered = total > 0 ? deliveredCount / total : 0.0;
    final pInProgress = total > 0 ? inProgressCount / total : 0.0;
    final pRefused = total > 0 ? refusedCount / total : 0.0;

    final statuses = [
      _StatusItem(
        label: DeliveryOrder.delivered,
        filterKey: 'Livrées',
        count: deliveredCount,
        percent: (pDelivered * 100).round(),
        color: AppColors.success,
        icon: Icons.check_circle_outline_rounded,
      ),
      _StatusItem(
        label: DeliveryOrder.inProgress,
        filterKey: 'En cours',
        count: inProgressCount,
        percent: (pInProgress * 100).round(),
        color: AppColors.accent,
        icon: Icons.directions_car_rounded,
      ),
      if (refusedCount > 0)
        _StatusItem(
          label: 'Échec / Retour',
          filterKey: 'Échecs',
          count: refusedCount,
          percent: (pRefused * 100).round(),
          color: AppColors.error,
          icon: Icons.assignment_return_rounded,
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.border.withValues(alpha: 0.65),
        ),
        boxShadow: AppShadows.soft(),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.donut_large_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Répartition des commandes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                  ),
                ],
              ),
              if (activeFilter != 'Toutes')
                BouncyButton(
                  scaleFactor: 0.95,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onFilterChanged('Toutes');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceAlt
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.restart_alt_rounded,
                          size: 12,
                          color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Réinitialiser',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkMuted
                                : AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Jauge segmentée animée ──────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 12,
              child: total == 0
                  ? Container(
                      color: isDark
                          ? AppColors.darkSurfaceAlt
                          : AppColors.surfaceAlt,
                    )
                  : Row(
                      children: [
                        if (pDelivered > 0)
                          Expanded(
                            flex: (pDelivered * 1000).toInt(),
                            child: Container(color: AppColors.success),
                          ),
                        if (pInProgress > 0)
                          Expanded(
                            flex: (pInProgress * 1000).toInt(),
                            child: Container(color: AppColors.accent),
                          ),
                        if (pRefused > 0)
                          Expanded(
                            flex: (pRefused * 1000).toInt(),
                            child: Container(color: AppColors.error),
                          ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Puces interactives cliquables pour filtrer ───────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: statuses.map((st) {
              final isSelected = activeFilter == st.filterKey;

              return BouncyButton(
                scaleFactor: 0.95,
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (isSelected) {
                    onFilterChanged('Toutes');
                  } else {
                    onFilterChanged(st.filterKey);
                  }
                },
                child: AnimatedContainer(
                  duration: AppDurations.quick,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? st.color.withValues(alpha: 0.15)
                        : (isDark
                            ? AppColors.darkSurfaceAlt
                            : AppColors.surfaceAlt),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isSelected
                          ? st.color
                          : (isDark
                              ? AppColors.darkBorder
                              : AppColors.border.withValues(alpha: 0.6)),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: st.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        st.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? st.color
                              : (isDark
                                  ? AppColors.darkText
                                  : AppColors.text),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: st.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '${st.count}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: st.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatusItem {
  final String label;
  final String filterKey;
  final int count;
  final int percent;
  final Color color;
  final IconData icon;

  const _StatusItem({
    required this.label,
    required this.filterKey,
    required this.count,
    required this.percent,
    required this.color,
    required this.icon,
  });
}
