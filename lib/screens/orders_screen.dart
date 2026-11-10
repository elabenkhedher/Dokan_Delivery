import 'package:flutter/material.dart';

import '../models/delivery_order.dart';
import '../models/driver_profile.dart';
import '../models/stock_pickup.dart';
import '../services/order_service.dart';
import '../services/stock_pickup_service.dart';
import '../services/working_hours_service.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/empty_state.dart';
import '../widgets/order_card.dart';
import '../widgets/stock_pickup_banner.dart';
import 'order_details_screen.dart';

typedef CommandesScreen = OrdersScreen;

class OrdersScreen extends StatefulWidget {
  final OrderService? orderService;
  final WorkingHoursService? workingHoursService;
  final StockPickupService? stockPickupService;
  final List<DeliveryOrder>? orders;
  final DriverProfile? driverProfile;
  final String? initialFilter;
  final void Function(DeliveryOrder)? onOrderTap;
  final void Function(StockPickup)? onPickupCompleted;
  final VoidCallback? onStartTour;
  final Future<void> Function()? onRefresh;
  final bool isEmbedded;

  const OrdersScreen({
    super.key,
    this.orderService,
    this.workingHoursService,
    this.stockPickupService,
    this.orders,
    this.driverProfile,
    this.initialFilter,
    this.onOrderTap,
    this.onPickupCompleted,
    this.onStartTour,
    this.onRefresh,
    this.isEmbedded = false,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final OrderService _orderService;
  late final WorkingHoursService _workingHoursService;
  late String _activeFilter;

  @override
  void initState() {
    super.initState();
    _orderService = widget.orderService ?? OrderService();
    _workingHoursService = widget.workingHoursService ?? WorkingHoursService();
    _activeFilter = widget.initialFilter ?? 'Toutes';
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
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allOrders = widget.orders ?? _orderService.getOrders();
    final pickedUpOrders = allOrders
        .where((o) => o.isPickedUp && !o.isDelivered && !o.isFailedOrRefused)
        .toList();
    final activeOrders =
        allOrders.where((o) => !o.isDelivered && !o.isFailedOrRefused).toList();

    final filteredOrders = switch (_activeFilter) {
      'Tournée active' || 'Tournée en cours' || 'En cours' || 'Actives' =>
        pickedUpOrders.isNotEmpty ? pickedUpOrders : activeOrders,
      'Terminées' || 'Livrées' => allOrders
          .where((o) => o.isDelivered || o.isFailedOrRefused)
          .toList(),
      _ => allOrders,
    };

    final content = RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primary,
      child: ListView(
        key: const ValueKey('orders-page'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        children: [
          Text(
            'Toutes vos commandes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${allOrders.length} commande${allOrders.length == 1 ? '' : 's'} au total',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                ),
          ),
          const SizedBox(height: 14),

          // Pilules de filtrage interactif (Capsules 100px)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ['Toutes', 'Tournée active', 'Terminées'].map((f) {
                final isSelected = _activeFilter == f ||
                    (_activeFilter == 'En cours' && f == 'Tournée active');
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: BouncyButton(
                    onTap: () => setState(() => _activeFilter = f),
                    scaleFactor: 0.95,
                    child: AnimatedContainer(
                      duration: AppDurations.quick,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkSurfaceAlt
                                : AppColors.surfaceAlt),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.border),
                        ),
                      ),
                      child: Text(
                        f,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? AppColors.darkText
                                  : AppColors.text),
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // ── Bannière Enlèvement Stock & Tournée active ──
          Builder(
            builder: (context) {
              final pendingStockCount = allOrders
                  .where((o) => !o.isPickedUp && !o.isDelivered && !o.isFailedOrRefused)
                  .length;
              final activeTourOrdersCount = allOrders
                  .where((o) => o.isPickedUp && !o.isDelivered && !o.isFailedOrRefused)
                  .length;

              if (pendingStockCount > 0 || activeTourOrdersCount > 0 || _activeFilter == 'Tournée active') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StockPickupBanner(
                    pendingOrdersCount: pendingStockCount,
                    activeTourOrdersCount: activeTourOrdersCount,
                    pickupService: widget.stockPickupService,
                    delivererUid: widget.driverProfile?.uid,
                    onPickupCompleted: (pickup) {
                      setState(() => _activeFilter = 'Tournée active');
                      if (widget.onPickupCompleted != null) {
                        widget.onPickupCompleted!(pickup);
                      }
                    },
                    onStartTour: widget.onStartTour,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          if (filteredOrders.isEmpty)
            const EmptyState(message: 'Aucune commande disponible.')
          else
            ...filteredOrders.map(
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
        title: const Text('Mes commandes'),
      ),
      body: content,
    );
  }
}
