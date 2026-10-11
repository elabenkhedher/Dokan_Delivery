import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/delivery_order.dart';
import '../services/order_service.dart';
import '../services/working_hours_service.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/empty_state.dart';
import '../widgets/order_card.dart';
import '../widgets/stat_card.dart';
import 'login_screen.dart';
import 'order_details_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final OrderService _orderService = OrderService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  int _selectedIndex = 0;
  bool _hoursLoading = true;
  String? _hoursLoadError;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadWorkingHours();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  static const _destinations = [
    _NavItem('Accueil', Icons.home_outlined, Icons.home_rounded),
    _NavItem('Commandes', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
    _NavItem('Historique', Icons.history_rounded, Icons.history_rounded),
    _NavItem('Horaires', Icons.schedule_outlined, Icons.schedule_rounded),
    _NavItem('Profil', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  static const _titles = [
    'Dashboard Livreur',
    'Mes commandes',
    'Historique',
    'Mes horaires',
    'Mon profil',
  ];

  void _openOrder(DeliveryOrder order) async {
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

  Future<void> _logout() async {
    HapticFeedback.lightImpact();
    Navigator.pushAndRemoveUntil(
      context,
      SlideFadePageRoute(page: const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _loadWorkingHours() async {
    setState(() {
      _hoursLoading = true;
      _hoursLoadError = null;
    });
    try {
      await _workingHoursService.load();
      if (mounted) setState(() => _hoursLoading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _hoursLoading = false;
          _hoursLoadError = error.toString();
        });
      }
    }
  }

  Future<void> _updateWorkingHours(int day, DailyWorkingHours updatedHours) async {
    try {
      await _workingHoursService.updateDay(day, updatedHours);
      if (mounted) {
        setState(() {});
        AppSnackBar.showSuccess(
          context,
          '${WorkingHoursService.weekdays[day - 1]} enregistré.',
        );
      }
    } catch (error) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Impossible d\'enregistrer les horaires : $error',
        );
      }
    }
  }

  Future<void> _selectWorkingTime(int day, {required bool isStart}) async {
    final current = _workingHoursService.hours[day]!;
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? current.start : current.end,
      helpText: isStart ? 'Début du service' : 'Fin du service',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: TimePickerThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;

    final updated = current.copyWith(
      start: isStart ? selected : null,
      end: isStart ? null : selected,
    );
    final startMinute = updated.start.hour * 60 + updated.start.minute;
    final endMinute = updated.end.hour * 60 + updated.end.minute;
    if (updated.enabled && endMinute <= startMinute) {
      AppSnackBar.showWarning(
        context,
        'L\'heure de fin doit être après l\'heure de début.',
      );
      return;
    }
    await _updateWorkingHours(day, updated);
  }

  // ── Pages ─────────────────────────────────────────────────

  Widget _buildHome(
    BuildContext context,
    List<DeliveryOrder> orders,
    ColorScheme colorScheme,
  ) {
    final now = DateTime.now();
    final isWorking =
        _workingHoursService.isLoaded && _workingHoursService.isWorkingAt(now);

    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) setState(() {});
      },
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
          Text('Votre activité',
              style: Theme.of(context).textTheme.titleLarge),
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
                child: Text('Commandes récentes',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _selectedIndex = 1),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Tout voir'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (orders.isEmpty)
            const EmptyState(message: 'Aucune commande disponible.')
          else
            ...orders.take(3).map((o) => OrderCard(
                  order: o,
                  onTap: () => _openOrder(o),
                )),
        ],
      ),
    );
  }

  Widget _buildOrders(BuildContext context, List<DeliveryOrder> orders) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) setState(() {});
      },
      color: Theme.of(context).colorScheme.primary,
      child: ListView(
        key: const ValueKey('orders-page'),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Toutes vos commandes',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${orders.length} commande${orders.length == 1 ? '' : 's'} au total',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 18),
          if (orders.isEmpty)
            const EmptyState(message: 'Aucune commande disponible.')
          else
            ...orders.map((o) => OrderCard(
                  order: o,
                  onTap: () => _openOrder(o),
                )),
        ],
      ),
    );
  }

  Widget _buildHistory(
      BuildContext context, List<DeliveryOrder> historyOrders) {
    return ListView(
      key: const ValueKey('history-page'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Commandes terminées',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Commandes livrées et refusées.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 18),
        if (historyOrders.isEmpty)
          const EmptyState(message: 'Aucune commande dans votre historique.')
        else
          ...historyOrders.map((o) => OrderCard(
                order: o,
                onTap: () => _openOrder(o),
              )),
      ],
    );
  }

  Widget _buildWorkingHours(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_hoursLoading) {
      return const Center(
        key: ValueKey('working-hours-loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Chargement des horaires…'),
          ],
        ),
      );
    }

    if (_hoursLoadError != null) {
      return Center(
        key: const ValueKey('working-hours-error'),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 56, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Impossible de charger vos horaires.',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_hoursLoadError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadWorkingHours,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    final isWorking = _workingHoursService.isWorkingAt(now);
    final todaysHours = _workingHoursService.hours[now.weekday]!;
    final todayRange = todaysHours.enabled
        ? '${todaysHours.start.format(context)} – ${todaysHours.end.format(context)}'
        : 'Jour de repos';

    return ListView(
      key: const ValueKey('working-hours-page'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Organisez votre semaine',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Ces horaires vous aident à décider d\'accepter une commande.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),

        // Statut du jour
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: isWorking
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isWorking
                  ? colorScheme.primary.withValues(alpha: 0.3)
                  : colorScheme.outline,
            ),
          ),
          child: ListTile(
            leading: Icon(
              isWorking
                  ? Icons.work_history_rounded
                  : Icons.event_busy_rounded,
              color: isWorking
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            title: Text(
              isWorking ? 'En service' : 'Hors de vos horaires',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isWorking
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
            ),
            subtitle: Text('Aujourd\'hui : $todayRange'),
          ),
        ),
        const SizedBox(height: 16),

        for (var day = 1; day <= 7; day++) _buildDaySchedule(context, day),

        const SizedBox(height: 12),
        Text(
          'Défaut : lundi–vendredi 9 h–17 h. Enregistré sur cet appareil. '
          'Suggère uniquement – vous gardez le choix.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDaySchedule(BuildContext context, int day) {
    final hours = _workingHoursService.hours[day]!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  WorkingHoursService.weekdays[day - 1],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  hours.enabled ? 'Jour travaillé' : 'Jour de repos',
                  style: TextStyle(
                    color: hours.enabled
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                value: hours.enabled,
                onChanged: (enabled) =>
                    _updateWorkingHours(day, hours.copyWith(enabled: enabled)),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: hours.enabled
                    ? Column(
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: ValueKey('start-time-$day'),
                                  onPressed: () =>
                                      _selectWorkingTime(day, isStart: true),
                                  icon: const Icon(Icons.login_rounded,
                                      size: 16),
                                  label: Text(
                                      'Début  ${hours.start.format(context)}'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: ValueKey('end-time-$day'),
                                  onPressed: () =>
                                      _selectWorkingTime(day, isStart: false),
                                  icon: const Icon(Icons.logout_rounded,
                                      size: 16),
                                  label: Text(
                                      'Fin  ${hours.end.format(context)}'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfile(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      key: const ValueKey('profile-page'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        // Avatar
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Espace livreur',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  'Votre profil de livraison',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Infos
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.badge_outlined),
                title: Text('Rôle'),
                subtitle: Text('Livreur'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Commandes attribuées'),
                trailing: Chip(
                  label: Text('${_orderService.totalOrders}'),
                  backgroundColor: colorScheme.primaryContainer,
                  side: BorderSide.none,
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Commandes livrées'),
                trailing: Chip(
                  label: Text('${_orderService.deliveredOrders}'),
                  backgroundColor:
                      const Color(0xFF2E9E6B).withValues(alpha: 0.1),
                  side: BorderSide.none,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Déconnexion
        OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Se déconnecter'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.error,
            side: BorderSide(color: colorScheme.error.withValues(alpha: 0.6)),
            minimumSize: const Size(0, 48),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orderService.getOrders();
    final historyOrders = orders
        .where((o) =>
            o.status == DeliveryOrder.delivered ||
            o.status == DeliveryOrder.refused)
        .toList();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pages = [
      _buildHome(context, orders, colorScheme),
      _buildOrders(context, orders),
      _buildHistory(context, historyOrders),
      _buildWorkingHours(context),
      _buildProfile(context),
    ];

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _titles[_selectedIndex],
            key: ValueKey(_titles[_selectedIndex]),
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          if (_selectedIndex != 4)
            IconButton(
              tooltip: 'Déconnexion',
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.02, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surface : Colors.white,
          border: Border(
            top: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          backgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            HapticFeedback.selectionClick();
            setState(() => _selectedIndex = index);
          },
          destinations: [
            for (var i = 0; i < _destinations.length; i++)
              NavigationDestination(
                key: ValueKey('nav-$i'),
                icon: Icon(_destinations[i].icon),
                selectedIcon: Icon(_destinations[i].selectedIcon),
                label: _destinations[i].label,
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _NavItem(this.label, this.icon, this.selectedIcon);
}
