import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth/firebase_role_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/hero_delivery_car.dart';
import '../widgets/password_field.dart';
import '../widgets/primary_button.dart';
import 'auth_gate.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen>
    with SingleTickerProviderStateMixin {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _confirmFocus = FocusNode();

  bool _isLoading = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  int _strength = 0;
  String _passwordText = '';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: AppDurations.hero);
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: AppCurves.smooth);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: AppCurves.smooth));
    _animCtrl.forward();

    _newPasswordController.addListener(_evalStrength);
  }

  void _evalStrength() {
    final pw = _newPasswordController.text;
    int score = 0;
    if (pw.length >= 8) score++;
    if (pw.contains(RegExp(r'[A-Z]'))) score++;
    if (pw.contains(RegExp(r'[0-9]'))) score++;
    if (pw.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) score++;
    setState(() {
      _strength = score;
      _passwordText = pw;
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _newPasswordController.removeListener(_evalStrength);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final password = _newPasswordController.text;
    final confirmation = _confirmPasswordController.text;

    if (password.length < 8) {
      AppSnackBar.showError(
        context,
        'Le mot de passe doit contenir au moins 8 caractères.',
      );
      return;
    }
    if (password != confirmation) {
      AppSnackBar.showError(context, 'Les mots de passe ne correspondent pas.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final currentUser = AuthService().currentUser;
      if (currentUser == null) {
        throw StateError('Aucun utilisateur connecté.');
      }
      await currentUser.updatePassword(password);
      await FirebaseRoleService().markPasswordChanged(currentUser);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      String errorMessage = 'Impossible de modifier le mot de passe.';
      if (e.code == 'weak-password') {
        errorMessage = 'Le mot de passe est trop faible.';
      } else if (e.code == 'requires-recent-login') {
        errorMessage =
            'Veuillez vous reconnecter avant de modifier le mot de passe.';
      } else if (e.message != null && e.message!.isNotEmpty) {
        errorMessage = e.message!;
      }
      AppSnackBar.showError(context, errorMessage);
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.showError(
        context,
        'Le mot de passe a peut-être été modifié, mais la validation du compte a échoué. Réessayez : ${e.toString()}',
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    HapticFeedback.lightImpact();

    await Navigator.pushAndRemoveUntil(
      context,
      SlideFadePageRoute(page: const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideIn,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // ── BANDEAU HERO RÉCEPTEUR (Voiture de Livraison Dokan) ──
                  Container(
                    height: 146,
                    decoration: BoxDecoration(
                      gradient: AppTheme.heroGradient,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Décorations subtiles d'arrière-plan
                        Positioned(
                          right: -25,
                          top: -25,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        // Contenu textuel & Stepper
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22.0,
                            vertical: 16.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Stepper 2 étapes
                              const _StepIndicator(currentStep: 1),
                              const SizedBox(height: 10),
                              const Text(
                                'Dokan Delivery',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                ),
                                child: const Text(
                                  'Sécurité du compte • Livreur',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Camionnette d'expédition réceptrice du Hero
                        const Positioned(
                          right: 10,
                          top: 10,
                          bottom: 10,
                          child: HeroDeliveryCar(
                            size: 132,
                            heroTag: 'delivery_vehicle_hero_tag',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Titre & Sous-titre
                  Text(
                    'Modifier le mot de passe',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pour votre première connexion, choisissez un nouveau mot de passe sécurisé.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                    ),
                  ),

                  const SizedBox(height: 26),

                  // Champs de mot de passe
                  PasswordField(
                    controller: _newPasswordController,
                    labelText: 'Nouveau mot de passe',
                    hintText: 'Au moins 8 caractères',
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                  ),
                  const SizedBox(height: 10),

                  // Barre de force interactive avec score en temps réel
                  _StrengthBar(
                    strength: _strength,
                    passwordText: _passwordText,
                  ),
                  const SizedBox(height: 18),

                  // Confirmation du mot de passe
                  PasswordField(
                    controller: _confirmPasswordController,
                    focusNode: _confirmFocus,
                    labelText: 'Confirmer le mot de passe',
                    hintText: 'Retapez votre mot de passe',
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _changePassword(),
                  ),
                  const SizedBox(height: 24),

                  // Bouton principal avec micro-interaction physique (rebond 60 FPS)
                  PrimaryButton(
                    label: 'Confirmer et continuer',
                    icon: Icons.check_circle_outline_rounded,
                    isLoading: _isLoading,
                    onPressed: _changePassword,
                  ),
                  const SizedBox(height: 22),

                  // Checklist dynamique des exigences de sécurité
                  _RequirementsList(password: _passwordText),

                  const SizedBox(height: 20),

                  // Footer de sécurité
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 15,
                        color: isDark
                            ? AppColors.darkMuted
                            : AppColors.mutedText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Vos identifiants sont chiffrés et sécurisés',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkMuted
                              : AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        await AuthService().signOut();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            SlideFadePageRoute(page: const AuthGate()),
                            (route) => false,
                          );
                        }
                      },
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 16,
                        color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                      ),
                      label: Text(
                        'Se déconnecter',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Stepper 2 étapes (Capsules 100px) ─────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_dot(0, '1'), _line(0), _dot(1, '2')],
    );
  }

  Widget _dot(int index, String label) {
    final done = index < currentStep;
    final active = index == currentStep;
    return AnimatedContainer(
      duration: AppDurations.medium,
      width: active ? 28 : 24,
      height: active ? 28 : 24,
      decoration: BoxDecoration(
        color: (done || active)
            ? Colors.white
            : Colors.white.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Center(
        child: done
            ? const Icon(
                Icons.check_rounded,
                color: AppColors.primary,
                size: 14,
              )
            : Text(
                label,
                style: TextStyle(
                  color: active
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }

  Widget _line(int index) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: index < currentStep
            ? Colors.white
            : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}

// ── Barre de force avec dégradé et libellé interactif ────────
class _StrengthBar extends StatelessWidget {
  final int strength;
  final String passwordText;
  const _StrengthBar({required this.strength, required this.passwordText});

  String get _label {
    if (strength <= 1) return 'Faible';
    if (strength == 2) return 'Moyen';
    if (strength == 3) return 'Fort';
    return 'Très fort ✓';
  }

  Color get _color {
    if (strength <= 1) return AppColors.error;
    if (strength == 2) return AppColors.accent;
    if (strength == 3) return AppColors.primary;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    if (passwordText.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
            4,
            (i) => Expanded(
              child: AnimatedContainer(
                duration: AppDurations.quick,
                margin: EdgeInsets.only(right: i < 3 ? 5 : 0),
                height: 4.5,
                decoration: BoxDecoration(
                  color: i < strength
                      ? _color
                      : Theme.of(context).colorScheme.outline
                            .withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AnimatedSwitcher(
              duration: AppDurations.quick,
              child: Text(
                'Niveau de sécurité : $_label',
                key: ValueKey(_label),
                style: TextStyle(
                  color: _color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${(strength * 25)}%',
              style: TextStyle(
                color: _color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Checklist des exigences de sécurité ───────────────────────
class _RequirementsList extends StatelessWidget {
  final String password;
  const _RequirementsList({required this.password});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final requirements = [
      ('8 caractères minimum', password.length >= 8),
      ('Une lettre majuscule', password.contains(RegExp(r'[A-Z]'))),
      ('Un chiffre', password.contains(RegExp(r'[0-9]'))),
      (
        'Un caractère spécial (!@#...\$)',
        password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]')),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : AppColors.border.withValues(alpha: 0.6),
        ),
        boxShadow: AppShadows.soft(),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_box_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Critères du mot de passe',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkText : AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...requirements.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  AnimatedSwitcher(
                    duration: AppDurations.quick,
                    child: Container(
                      key: ValueKey('${r.$1}-${r.$2}'),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: r.$2
                            ? AppColors.success.withValues(alpha: 0.15)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: r.$2
                              ? AppColors.success
                              : (isDark
                                    ? AppColors.darkBorder
                                    : AppColors.border),
                          width: 1.5,
                        ),
                      ),
                      child: r.$2
                          ? const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: AppColors.success,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    r.$1,
                    style: TextStyle(
                      fontSize: 13,
                      color: r.$2
                          ? AppColors.success
                          : (isDark
                                ? AppColors.darkMuted
                                : AppColors.mutedText),
                      fontWeight: r.$2 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
