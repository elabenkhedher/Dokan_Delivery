import 'package:flutter/material.dart';

import '../models/delivery_order.dart';
import '../services/order_service.dart';
import '../services/working_hours_service.dart';
import '../utils/page_transitions.dart';
import '../widgets/empty_state.dart';
import '../widgets/order_card.dart';
import 'order_details_screen.dart';

typedef HistoriqueScreen = HistoryScreen;

class HistoryScreen extends StatefulWidget {
  final OrderService? orderService;
  final WorkingHoursService? workingHoursService;
  final List<DeliveryOrder>? historyOrders;
  final void Function(DeliveryOrder)? onOrderTap;
  final Future<void> Function()? onRefresh;
  final bool isEmbedded;

  const HistoryScreen({
    super.key,
    this.orderService,
    this.workingHoursService,
    this.historyOrders,
    this.onOrderTap,
    this.onRefresh,
    this.isEmbedded = false,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final OrderService _orderService;
  late final WorkingHoursService _workingHoursService;

  @override
  void initState() {
    super.initState();
    _orderService = widget.orderService ?? OrderService();
    _workingHoursService = widget.workingHoursService ?? WorkingHoursService();
  }

  void _openOrder(DeliveryOrder order) async {
    if (widget.onOrderTap != null) {
      widget.onOrderTap!(order);
      return;
    }
    await Navigator.push(
      context,
      SlideFadePageRoute(
        page: OrderDetailsScreen(
          order: order,
          orderService: _orderService,
          workingHoursService: _workingHoursService,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _handleRefresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.historyOrders ??
        _orderService
            .getOrders()
            .where(
              (o) =>
                  o.status == DeliveryOrder.delivered ||
                  o.status == DeliveryOrder.refused,
            )
            .toList();

    final content = RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Theme.of(context).colorScheme.primary,
      child: ListView(
        key: const ValueKey('history-page'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Commandes terminées',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Commandes livrées et refusées.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 18),
          if (list.isEmpty)
            const EmptyState(message: 'Aucune commande dans votre historique.')
          else
            ...list.map(
              (o) => OrderCard(
                order: o,
                onTap: () => _openOrder(o),
              ),
            ),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
      ),
      body: content,
    );
  }
}
