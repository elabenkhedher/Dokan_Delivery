import 'package:flutter/material.dart';

import '../models/delivery_order.dart';

/// Fonctions d'aide pour obtenir la couleur et l'icône associées
/// à chaque statut de commande.
class OrderStatusHelper {
  static Color color(BuildContext context, String status) {
    switch (status) {
      case DeliveryOrder.delivered:
        return const Color(0xFF2E9E6B);
      case DeliveryOrder.inProgress:
        return const Color(0xFF9A5B14);
      case DeliveryOrder.refused:
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  static IconData icon(String status) {
    switch (status) {
      case DeliveryOrder.delivered:
        return Icons.check_circle_rounded;
      case DeliveryOrder.inProgress:
        return Icons.directions_car_rounded;
      case DeliveryOrder.refused:
        return Icons.block_rounded;
      default:
        return Icons.local_shipping_outlined;
    }
  }
}

/// Extension pratique sur [DeliveryOrder] pour accéder directement
/// à sa couleur et son icône de statut.
extension DeliveryOrderStatusX on DeliveryOrder {
  Color statusColor(BuildContext context) => OrderStatusHelper.color(context, status);
  IconData get statusIcon => OrderStatusHelper.icon(status);
}

/// Badge d'affichage du statut d'une commande (pilule colorée réutilisable).
class OrderStatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const OrderStatusBadge({
    super.key,
    required this.status,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = OrderStatusHelper.color(context, status);
    final statusBg = statusColor.withValues(alpha: 0.1);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: statusColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
