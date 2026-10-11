import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/page_transitions.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/auth_layout.dart';
import '../widgets/password_field.dart';
import '../widgets/primary_button.dart';
import 'dashboard_screen.dart';

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

  int _strength = 0;
  String _passwordText = '';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
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
      AppSnackBar.showError(
        context,
        'Les mots de passe ne correspondent pas.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isLoading = false);
    HapticFeedback.lightImpact();

    await Navigator.pushReplacement(
      context,
      SlideFadePageRoute(page: const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      heroHeightFactor: 0.32,
      fadeInAnimation: _fadeIn,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          children: [
            // Stepper
            const _StepIndicator(currentStep: 1),
            const SizedBox(height: 24),
            const AuthHeaderBadge(
              icon: Icons.lock_reset_rounded,
              size: 68,
              iconSize: 34,
              borderRadius: 20,
            ),
            const SizedBox(height: 12),
            const Text(
              'Modifier le mot de passe',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choisissez un nouveau mot de passe',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nouveau mot de passe (widget réutilisable)
          PasswordField(
            controller: _newPasswordController,
            labelText: 'Nouveau mot de passe',
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
          ),
          const SizedBox(height: 10),

          // Barre de force
          _StrengthBar(
            strength: _strength,
            passwordText: _passwordText,
          ),
          const SizedBox(height: 18),

          // Confirmation (widget réutilisable)
          PasswordField(
            controller: _confirmPasswordController,
            focusNode: _confirmFocus,
            labelText: 'Confirmer le mot de passe',
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _changePassword(),
          ),
          const SizedBox(height: 28),

          // Bouton confirmer réutilisable
          PrimaryButton(
            label: 'Confirmer et continuer',
            icon: Icons.check_rounded,
            isLoading: _isLoading,
            onPressed: _changePassword,
          ),
          const SizedBox(height: 20),

          // Exigences
          _RequirementsList(password: _passwordText),
        ],
      ),
    );
  }
}

// ── Stepper 2 étapes ─────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(0),
        _line(0),
        _dot(1),
      ],
    );
  }

  Widget _dot(int index) {
    final done = index < currentStep;
    final active = index == currentStep;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 34 : 30,
      height: active ? 34 : 30,
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
            ? const Icon(Icons.check_rounded,
                color: Color(0xFF1F7A7A), size: 15)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: active
                      ? const Color(0xFF1F7A7A)
                      : Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
      ),
    );
  }

  Widget _line(int index) {
    return Container(
      width: 44,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: index < currentStep
            ? Colors.white
            : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ── Barre de force ────────────────────────────────────────────
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
    if (strength <= 1) return const Color(0xFFD64545);
    if (strength == 2) return const Color(0xFFF2A65A);
    if (strength == 3) return const Color(0xFF1F7A7A);
    return const Color(0xFF2E9E6B);
  }

  @override
  Widget build(BuildContext context) {
    if (passwordText.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) => Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: i < strength
                    ? _color
                    : Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          )),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            'Force : $_label',
            key: ValueKey(_label),
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Exigences ─────────────────────────────────────────────────
class _RequirementsList extends StatelessWidget {
  final String password;
  const _RequirementsList({required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final requirements = [
      ('8 caractères minimum', password.length >= 8),
      ('Une lettre majuscule', password.contains(RegExp(r'[A-Z]'))),
      ('Un chiffre', password.contains(RegExp(r'[0-9]'))),
      ('Un caractère spécial (!@#...)', password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))),
    ];

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exigences du mot de passe',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...requirements.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        r.$2
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        key: ValueKey('${r.$1}-${r.$2}'),
                        color: r.$2
                            ? const Color(0xFF2E9E6B)
                            : Theme.of(context).colorScheme.outline,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.$1,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: r.$2
                                ? const Color(0xFF2E9E6B)
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight:
                                r.$2 ? FontWeight.w600 : FontWeight.normal,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
