import 'package:flutter/material.dart';

import '../models/delivery_order.dart';
import 'order_status_badge.dart';

class OrderCard extends StatelessWidget {
  final DeliveryOrder order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusColor = order.statusColor(context);
    final statusBg = statusColor.withValues(alpha: 0.08);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('order-card-${order.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: statusColor.withValues(alpha: 0.06),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outline.withValues(alpha: 0.6)),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar statut
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(order.statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 14),

                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Commande #${order.id}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          // Badge statut réutilisable
                          OrderStatusBadge(status: order.status),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        order.customerName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.address,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${order.total.toStringAsFixed(3)} TND',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
