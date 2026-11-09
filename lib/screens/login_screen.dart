import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/auth/firebase_role_service.dart';
import '../core/auth/role_denied_exception.dart';
import '../core/auth/user_role.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/hero_delivery_car.dart';
import '../widgets/password_field.dart';
import '../widgets/primary_button.dart';
import 'auth_gate.dart';
import 'password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _keepSignedIn = true;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

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
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // Masquer le clavier
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    try {
      final emailInput = _emailController.text.trim();
      final passwordInput = _passwordController.text.trim();

      // Connexion Firebase + vérification du rôle livreur dans Firestore :
      final credential = await FirebaseRoleService().signInWithRole(
        email: emailInput,
        password: passwordInput,
        requiredRole: UserRole.deliverer,
      );

      if (!mounted) return;
      HapticFeedback.lightImpact();

      final user = credential.user ?? FirebaseAuth.instance.currentUser;
      final roleService = FirebaseRoleService();
      final mustChange =
          user != null && await roleService.requiresPasswordChange(user);

      if (!mounted) return;

      if (mustChange) {
        // Première connexion -> Écran de changement de mot de passe
        await Navigator.pushAndRemoveUntil(
          context,
          SlideFadePageRoute(page: const PasswordScreen()),
          (route) => false,
        );
      } else {
        // Redirection vers AuthGate / Dashboard
        await Navigator.pushAndRemoveUntil(
          context,
          SlideFadePageRoute(page: const AuthGate()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = 'Une erreur est survenue lors de la connexion.';
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Aucun utilisateur trouvé avec cet e-mail.';
          break;
        case 'wrong-password':
          errorMessage = 'Mot de passe incorrect.';
          break;
        case 'invalid-email':
          errorMessage = 'Adresse e-mail invalide.';
          break;
        case 'user-disabled':
          errorMessage = 'Ce compte a été désactivé.';
          break;
        case 'too-many-requests':
          errorMessage = 'Trop de tentatives. Veuillez réessayer plus tard.';
          break;
        case 'invalid-credential':
          errorMessage = 'E-mail ou mot de passe incorrect. Veuillez vérifier vos identifiants.';
          break;
        default:
          if (e.message != null && e.message!.isNotEmpty) {
            errorMessage = e.message!;
          }
      }
      AppSnackBar.showError(context, errorMessage);
    } on RoleDeniedException catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, e.toString());
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Erreur de connexion : ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppSnackBar.showError(
        context,
        'Veuillez saisir votre adresse e-mail pour réinitialiser votre mot de passe.',
      );
      _emailFocus.requestFocus();
      return;
    }

    try {
      await AuthService().sendPasswordResetEmail(email);
      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        'Un e-mail de réinitialisation a été envoyé à $email.',
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(
        context,
        e.message ?? 'Impossible d\'envoyer l\'e-mail de réinitialisation.',
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Erreur : ${e.toString()}');
    }
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

                  // ── BANDEAU HERO RÉCEPTEUR (Hero Scooter Animation) ──
                  Container(
                    height: 144,
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
                          right: -20,
                          top: -20,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        // Textes de marque
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22.0,
                            vertical: 18.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Dokan Delivery',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
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
                                  'Espace livreur',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Vos courses, en toute sérénité.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
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

                  const SizedBox(height: 32),

                  // Titre et sous-titre
                  Text(
                    'Bienvenue',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Connectez-vous à votre compte',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Formulaire de connexion
                  Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // E-mail ou téléphone
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            onFieldSubmitted: (_) =>
                                _passwordFocus.requestFocus(),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              final atIndex = email.indexOf('@');
                              if (email.isEmpty) {
                                return 'Saisissez votre adresse e-mail.';
                              }
                              if (atIndex < 1 ||
                                  !email.substring(atIndex + 1).contains('.')) {
                                return 'Adresse e-mail invalide.';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'Adresse e-mail',
                              prefixIcon: const Icon(Icons.email_outlined),
                              hintText: 'exemple@dokan.tn',
                              filled: true,
                              fillColor: isDark
                                  ? AppColors.darkSurfaceAlt
                                  : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Mot de passe
                          PasswordField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            onFieldSubmitted: (_) => _login(),
                            validator: (value) => (value ?? '').isEmpty
                                ? 'Saisissez votre mot de passe.'
                                : null,
                          ),
                          const SizedBox(height: 10),

                          // Mémorisation & Mot de passe oublié
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _keepSignedIn,
                                      activeColor: AppColors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (v) => setState(
                                        () => _keepSignedIn = v ?? false,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Rester connecté',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.darkMuted
                                          : AppColors.mutedText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: _forgotPassword,
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text(
                                  'Mot de passe oublié ?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Bouton de connexion avec micro-interaction physique (rebond 60 FPS)
                          PrimaryButton(
                            label: 'Se connecter',
                            icon: Icons.login_rounded,
                            isLoading: _isLoading,
                            onPressed: _login,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Footer sécurisé
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.darkMuted
                            : AppColors.mutedText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Connexion sécurisée • Dokan Livreur',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.darkMuted
                              : AppColors.mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
