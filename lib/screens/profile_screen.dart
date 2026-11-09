import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/delivery_order.dart';
import '../models/driver_profile.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../widgets/assigned_vehicle_card.dart';
import 'auth_gate.dart';
import 'edit_profile_screen.dart';

typedef ProfilScreen = ProfileScreen;

class ProfileScreen extends StatefulWidget {
  final OrderService? orderService;
  final ProfileService? profileService;
  final AuthService? authService;
  final DriverProfile? initialProfile;
  final List<DeliveryOrder>? orders;
  final VoidCallback? onLogout;
  final bool isEmbedded;

  const ProfileScreen({
    super.key,
    this.orderService,
    this.profileService,
    this.authService,
    this.initialProfile,
    this.orders,
    this.onLogout,
    this.isEmbedded = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileService _profileService;
  late final AuthService _authService;
  late final OrderService _orderService;

  DriverProfile? _localProfile;

  @override
  void initState() {
    super.initState();
    _profileService = widget.profileService ?? ProfileService();
    _authService = widget.authService ?? AuthService();
    _orderService = widget.orderService ?? OrderService();
    _localProfile = widget.initialProfile;
  }

  Future<void> _handleLogout(BuildContext context) async {
    HapticFeedback.lightImpact();
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }
    await _authService.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      SlideFadePageRoute(page: const AuthGate()),
      (route) => false,
    );
  }

  void _openEditProfile(DriverProfile currentProfile) async {
    HapticFeedback.selectionClick();
    final updatedProfile = await Navigator.push<DriverProfile>(
      context,
      SlideFadePageRoute(
        page: EditProfileScreen(
          initialProfile: currentProfile,
          profileService: _profileService,
          authService: _authService,
        ),
      ),
    );

    if (updatedProfile != null && mounted) {
      setState(() {
        _localProfile = updatedProfile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = _authService.currentUser;

    final orderList = widget.orders ?? _orderService.getOrders();
    final totalAssigned = orderList.length;
    final totalDelivered = orderList.where((o) => o.isDelivered).length;

    return StreamBuilder<DriverProfile?>(
      stream: _profileService.streamProfile(uid: currentUser?.uid),
      initialData: _localProfile,
      builder: (context, snapshot) {
        // Profil fusionné : stream en direct prioritaire, sinon local, sinon fallback
        final profile = snapshot.data ??
            _localProfile ??
            DriverProfile(
              uid: currentUser?.uid ?? '',
              name: currentUser?.displayName ?? '',
              email: currentUser?.email ?? '',
            );

        final displayName = profile.name.trim().isNotEmpty
            ? profile.name.trim()
            : (currentUser?.displayName?.trim().isNotEmpty == true
                ? currentUser!.displayName!.trim()
                : 'Espace livreur');

        final displayEmail = profile.email.isNotEmpty
            ? profile.email
            : (currentUser?.email ?? 'Compte vérifié');

        final currentRegion = profile.region ??
            DeliveryRegion.findById(profile.assignedRegionId);

        final content = SingleChildScrollView(
          key: const ValueKey('profile-page'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // ── 1. Carte Profil & Avatar avec bouton Édition rapide ──
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkSurface
                                  : Colors.white,
                              width: 2.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      displayName,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayEmail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkMuted
                                : AppColors.mutedText,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Bouton Modifier mon profil
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openEditProfile(profile),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Modifier mes informations'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.4,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── 2. Zone d'affectation / Région d'activité ────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.explore_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ZONE D\'AFFECTATION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: AppColors.mutedText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentRegion != null
                                ? currentRegion.fullLabel
                                : (profile.assignedRegionName != null &&
                                        profile.assignedRegionName!.isNotEmpty
                                    ? profile.assignedRegionName!
                                    : 'Non assignée (Sélectionner une région)'),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: AppColors.mutedText,
                      onPressed: () => _openEditProfile(profile),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── 3. Section Véhicule de Flotte (LECTURE SEULE) ────────
            AssignedVehicleCard(
              vehiclePlate: profile.assignedVehiclePlate,
              vehicleModel: profile.assignedVehicleModel,
              vehicleType: profile.assignedVehicleType,
              showHeader: true,
            ),
            const SizedBox(height: 14),

            // ── 4. Détails du compte & Statistiques ──────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                children: [
                  if (profile.phone.isNotEmpty) ...[
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: const Text('Numéro de téléphone'),
                      subtitle: Text(profile.phone),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _openEditProfile(profile),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                  if (currentUser?.email != null) ...[
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Adresse e-mail'),
                      subtitle: Text(currentUser!.email!),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                  if (currentUser?.uid != null) ...[
                    ListTile(
                      leading: const Icon(Icons.fingerprint_rounded),
                      title: const Text('Mon UID Livreur (Firebase)'),
                      subtitle: Text(
                        currentUser!.uid,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Copier mon UID',
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: currentUser.uid),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('UID copié dans le presse-papier !'),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                  const ListTile(
                    leading: Icon(Icons.badge_outlined),
                    title: Text('Rôle'),
                    subtitle: Text('Livreur officiel'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('Commandes attribuées'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$totalAssigned',
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: const Text('Commandes livrées'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successSoft,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$totalDelivered',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 5. Bouton de déconnexion ──────────────────────────────
            OutlinedButton.icon(
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Se déconnecter'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colorScheme.error,
                side: BorderSide(
                  color: colorScheme.error.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
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
            title: const Text('Mon profil'),
          ),
          body: content,
        );
      },
    );
  }
}
