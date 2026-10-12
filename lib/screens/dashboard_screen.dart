import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/delivery_order.dart';
import '../services/order_service.dart';
import '../services/working_hours_service.dart';
import '../utils/page_transitions.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'order_details_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'working_hours_screen.dart';

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

  Future<void> _loadWorkingHours() async {
    try {
      await _workingHoursService.load();
      if (mounted) setState(() {});
    } catch (_) {
      // Les erreurs et chargements sont également gérés par WorkingHoursScreen
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pages = [
      HomeScreen(
        orderService: _orderService,
        workingHoursService: _workingHoursService,
        onOrderTap: _openOrder,
        onViewAllOrders: () => setState(() => _selectedIndex = 1),
        isEmbedded: true,
      ),
      OrdersScreen(
        orderService: _orderService,
        workingHoursService: _workingHoursService,
        onOrderTap: _openOrder,
        isEmbedded: true,
      ),
      HistoryScreen(
        orderService: _orderService,
        workingHoursService: _workingHoursService,
        onOrderTap: _openOrder,
        isEmbedded: true,
      ),
      WorkingHoursScreen(
        workingHoursService: _workingHoursService,
        onHoursChanged: () {
          if (mounted) setState(() {});
        },
        isEmbedded: true,
      ),
      ProfileScreen(
        orderService: _orderService,
        onLogout: _logout,
        isEmbedded: true,
      ),
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
