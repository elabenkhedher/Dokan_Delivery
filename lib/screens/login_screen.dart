import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/page_transitions.dart';
import '../widgets/auth_layout.dart';
import '../widgets/password_field.dart';
import '../widgets/primary_button.dart';
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

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
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

    // Simule un court délai de traitement
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() => _isLoading = false);

    HapticFeedback.lightImpact();

    await Navigator.pushReplacement(
      context,
      SlideFadePageRoute(page: const PasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      heroHeightFactor: 0.42,
      fadeInAnimation: _fadeIn,
      slideInAnimation: _slideIn,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 36),
        child: Column(
          children: [
            const AuthHeaderBadge(
              icon: Icons.directions_car_rounded,
              size: 80,
              iconSize: 40,
              borderRadius: 24,
            ),
            const SizedBox(height: 20),
            const Text(
              'Dokan Delivery',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Espace livreur',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bienvenue',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Connectez-vous à votre compte',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),

          // Formulaire
          Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                children: [
                  // Email
                  TextFormField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
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
                    decoration: const InputDecoration(
                      labelText: 'Adresse e-mail',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mot de passe (widget réutilisable)
                  PasswordField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    onFieldSubmitted: (_) => _login(),
                    validator: (value) => (value ?? '').isEmpty
                        ? 'Saisissez votre mot de passe.'
                        : null,
                  ),
                  const SizedBox(height: 28),

                  // Bouton principal réutilisable
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

          const SizedBox(height: 32),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Connexion sécurisée',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
