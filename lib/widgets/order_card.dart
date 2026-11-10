import 'package:flutter/material.dart';

import '../models/delivery_order.dart';
import '../theme/app_theme.dart';
import 'bouncy_button.dart';
import 'order_status_badge.dart';

/// Carte de commande moderne, ergonomique avec micro-interaction tactile.
class OrderCard extends StatelessWidget {
  final DeliveryOrder order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = order.statusColor(context);
    final statusBg = statusColor.withValues(alpha: 0.12);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.surface;

    final card = Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.border.withValues(alpha: 0.65),
        ),
        boxShadow: AppShadows.soft(),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar statut avec halo doux
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: statusColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Icon(order.statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 14),

          // Informations de la commande
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Commande #${order.displayNumber.isNotEmpty ? order.displayNumber : order.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OrderStatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  order.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.address,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.darkMuted
                                  : AppColors.mutedText,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (order.totalPoids > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceAlt
                              : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                          ),
                        ),
                        child: Text(
                          '${order.totalPoids % 1 == 0 ? order.totalPoids.toInt() : order.totalPoids.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkMuted
                                : AppColors.mutedText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        '${order.total.toStringAsFixed(3)} TND',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (order.driverRating != null && order.driverRating! > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF78350F).withValues(alpha: 0.35)
                          : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: const Color(0xFFFCD34D),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${order.driverRating}/5',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFF92400E),
                          ),
                        ),
                        if (order.driverFeedback != null &&
                            order.driverFeedback!.trim().isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '• ${order.driverFeedback!}',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFF92400E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? AppColors.darkMuted : AppColors.mutedText,
            size: 22,
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BouncyButton(
        key: ValueKey('order-card-${order.id}'),
        onTap: onTap,
        scaleFactor: 0.98,
        child: card,
      ),
    );
  }
}
