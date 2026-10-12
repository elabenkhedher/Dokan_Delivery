import 'package:flutter/material.dart';

import '../models/delivery_order.dart';
import '../services/order_service.dart';
import '../services/working_hours_service.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../widgets/empty_state.dart';
import '../widgets/order_card.dart';
import '../widgets/stat_card.dart';
import 'order_details_screen.dart';

class HomeScreen extends StatefulWidget {
  final OrderService? orderService;
  final WorkingHoursService? workingHoursService;
  final void Function(DeliveryOrder)? onOrderTap;
  final VoidCallback? onViewAllOrders;
  final Future<void> Function()? onRefresh;
  final bool isEmbedded;

  const HomeScreen({
    super.key,
    this.orderService,
    this.workingHoursService,
    this.onOrderTap,
    this.onViewAllOrders,
    this.onRefresh,
    this.isEmbedded = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    final colorScheme = Theme.of(context).colorScheme;
    final orders = _orderService.getOrders();
    final now = DateTime.now();
    final isWorking = _workingHoursService.isLoaded &&
        _workingHoursService.isWorkingAt(now);

    final content = RefreshIndicator(
      onRefresh: _handleRefresh,
      color: colorScheme.primary,
      child: ListView(
        key: const ValueKey('home-page'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // ── Carte hero ──────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.waving_hand_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bonjour, Livreur !',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isWorking
                            ? '✅ Vous êtes en service'
                            : '⏸ Hors de vos horaires',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          // ── Stats ────────────────────────────────────────
          Text(
            'Votre activité',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 4 : 2;
              const spacing = 12.0;
              final cardWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      title: 'Total commandes',
                      value: '${_orderService.totalOrders}',
                      icon: Icons.inventory_2_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      title: 'Livrées',
                      value: '${_orderService.deliveredOrders}',
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF2E9E6B),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: StatCard(
                      title: 'En cours',
                      value: '${_orderService.activeOrders}',
                      icon: Icons.directions_car_rounded,
                      color: const Color(0xFF9A5B14),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: const StatCard(
                      title: 'Espace',
                      value: 'Livreur',
                      icon: Icons.person_outline,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // ── Commandes récentes ───────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  'Commandes récentes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (widget.onViewAllOrders != null)
                TextButton.icon(
                  onPressed: widget.onViewAllOrders,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Tout voir'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (orders.isEmpty)
            const EmptyState(message: 'Aucune commande disponible.')
          else
            ...orders.take(3).map(
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
        title: const Text('Dashboard Livreur'),
      ),
      body: content,
    );
  }
}
