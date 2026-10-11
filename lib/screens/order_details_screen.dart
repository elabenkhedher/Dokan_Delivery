import 'package:flutter/material.dart';

import '../models/delivery_order.dart';
import '../services/order_service.dart';
import '../services/working_hours_service.dart';
import '../utils/snackbar_helper.dart';
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
      duration: const Duration(milliseconds: 450),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _advanceStatus() {
    late final String status;
    try {
      status = widget.orderService.advanceStatus(widget.order);
    } on StateError catch (error) {
      AppSnackBar.showError(context, error.message);
      return;
    }
    setState(() {});
    AppSnackBar.showSuccess(context, 'Nouveau statut : $status');
  }

  Future<void> _refuseOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser cette commande ?'),
        content: const Text(
          'Cette décision est définitive et la commande sera '
          'ajoutée à votre historique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer le refus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      widget.orderService.refuseOrder(widget.order);
    } on StateError catch (error) {
      AppSnackBar.showError(context, error.message);
      return;
    }
    setState(() {});
    AppSnackBar.showSuccess(context, 'Commande refusée.');
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isDelivered = order.status == DeliveryOrder.delivered;
    final isRefused = order.status == DeliveryOrder.refused;

    final statusStep = switch (order.status) {
      DeliveryOrder.awaitingPickup => 0,
      DeliveryOrder.inProgress => 1,
      DeliveryOrder.delivered => 2,
      _ => -1,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text('Commande #${order.id}'),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // ── Bannière statut ──────────────────────────────
            _StatusBanner(order: order),
            const SizedBox(height: 20),

            // ── Infos client ────────────────────────────────
            const _SectionTitle(title: 'Informations client'),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Client',
                    value: order.customerName,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Adresse',
                    value: order.address,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _InfoRow(
                    icon: Icons.phone_outlined,
                    label: 'Téléphone',
                    value: order.phone,
                    isPhone: true,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Montant',
                    value: '${order.total.toStringAsFixed(3)} TND',
                    isAmount: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Progression ──────────────────────────────────
            if (!isRefused) ...[
              const _SectionTitle(title: 'Progression de la livraison'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _DeliveryTimeline(currentStep: statusStep),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Suggestion horaires ──────────────────────────
            if (order.status == DeliveryOrder.awaitingPickup) ...[
              _WorkingHoursSuggestion(
                workingHoursService: widget.workingHoursService,
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _BottomActions(
        order: order,
        isDelivered: isDelivered,
        isRefused: isRefused,
        onAdvance: _advanceStatus,
        onRefuse: _refuseOrder,
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
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
                  'Commande #${order.id}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                OrderStatusBadge(
                  status: order.status,
                  fontSize: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    ('À récupérer', Icons.store_outlined),
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
                // Cercle + ligne
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ligne
                    if (i < _steps.length - 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(left: 24),
                          color: i < currentStep
                              ? colorScheme.primary
                              : colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                    // Cercle
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= currentStep
                            ? (i == currentStep
                                ? colorScheme.primary
                                : const Color(0xFF2E9E6B))
                            : colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: i <= currentStep
                              ? Colors.transparent
                              : colorScheme.outline.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: i == currentStep
                            ? [
                                BoxShadow(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
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
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _steps[i].$1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == currentStep
                        ? FontWeight.w700
                        : FontWeight.normal,
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
  final bool isAmount;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isPhone = false,
    this.isAmount = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colorScheme.primary, size: 22),
      title: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
      subtitle: Text(
        value,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: isAmount ? FontWeight.w700 : FontWeight.normal,
              color: isAmount ? colorScheme.primary : null,
            ),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }
}

// ── Suggestion horaires ────────────────────────────────────────
class _WorkingHoursSuggestion extends StatelessWidget {
  final WorkingHoursService workingHoursService;
  const _WorkingHoursSuggestion({required this.workingHoursService});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoaded = workingHoursService.isLoaded;
    final isWorking =
        isLoaded && workingHoursService.isWorkingAt(DateTime.now());

    final color = !isLoaded
        ? colorScheme.onSurfaceVariant
        : isWorking
            ? colorScheme.primary
            : colorScheme.error;

    return Card(
      color: !isLoaded
          ? colorScheme.surfaceContainerHighest
          : isWorking
              ? colorScheme.primaryContainer
              : colorScheme.errorContainer,
      child: ListTile(
        leading: Icon(
          !isLoaded
              ? Icons.schedule_outlined
              : isWorking
                  ? Icons.schedule_rounded
                  : Icons.event_busy_rounded,
          color: color,
        ),
        title: Text(
          !isLoaded
              ? 'Suggestion indisponible'
              : isWorking
                  ? '💡 Suggestion : accepter'
                  : '⚠ Suggestion : refuser',
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
        subtitle: Text(
          !isLoaded
              ? 'Les horaires ne sont pas disponibles.'
              : isWorking
                  ? 'Vous êtes dans vos horaires. Vous restez libre de votre décision.'
                  : 'Vous êtes hors de vos horaires. Vous restez libre de votre décision.',
        ),
      ),
    );
  }
}

// ── Section title ──────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

// ── Actions bas de page ───────────────────────────────────────
class _BottomActions extends StatelessWidget {
  final DeliveryOrder order;
  final bool isDelivered;
  final bool isRefused;
  final VoidCallback onAdvance;
  final VoidCallback onRefuse;

  const _BottomActions({
    required this.order,
    required this.isDelivered,
    required this.isRefused,
    required this.onAdvance,
    required this.onRefuse,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget content;
    if (isDelivered || isRefused) {
      content = Card(
        color: isDelivered
            ? colorScheme.primaryContainer
            : colorScheme.errorContainer,
        child: ListTile(
          leading: Icon(
            isDelivered ? Icons.check_circle_rounded : Icons.block_rounded,
            color: isDelivered ? colorScheme.primary : colorScheme.error,
          ),
          title: Text(
            isDelivered ? 'Commande terminée' : 'Commande refusée',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDelivered ? colorScheme.primary : colorScheme.error,
            ),
          ),
          subtitle: Text(
            isDelivered
                ? 'Cette livraison est définitivement terminée.'
                : 'Cette commande a été refusée définitivement.',
          ),
        ),
      );
    } else if (order.status == DeliveryOrder.inProgress) {
      content = SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          key: const ValueKey('advance-order-status'),
          onPressed: onAdvance,
          icon: const Icon(Icons.task_alt_rounded),
          label: const Text('Marquer comme livrée'),
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            key: const ValueKey('accept-order'),
            onPressed: onAdvance,
            icon: const Icon(Icons.handshake_outlined),
            label: const Text('Accepter la commande'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('refuse-order'),
            onPressed: onRefuse,
            icon: const Icon(Icons.block_outlined),
            label: const Text('Refuser la commande'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error),
            ),
          ),
        ],
      );
    }

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
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
