import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import 'login_screen.dart';

typedef ProfilScreen = ProfileScreen;

class ProfileScreen extends StatelessWidget {
  final OrderService? orderService;
  final VoidCallback? onLogout;
  final bool isEmbedded;

  const ProfileScreen({
    super.key,
    this.orderService,
    this.onLogout,
    this.isEmbedded = false,
  });

  Future<void> _handleLogout(BuildContext context) async {
    HapticFeedback.lightImpact();
    if (onLogout != null) {
      onLogout!();
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      SlideFadePageRoute(page: const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final service = orderService ?? OrderService();

    final content = ListView(
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
                  label: Text('${service.totalOrders}'),
                  backgroundColor: colorScheme.primaryContainer,
                  side: BorderSide.none,
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Commandes livrées'),
                trailing: Chip(
                  label: Text('${service.deliveredOrders}'),
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
          onPressed: () => _handleLogout(context),
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

    if (isEmbedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
      ),
      body: content,
    );
  }
}
