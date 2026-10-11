import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Badge d'en-tête transparent avec bordure, réutilisé sur les écrans d'authentification.
class AuthHeaderBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final double borderRadius;

  const AuthHeaderBadge({
    super.key,
    required this.icon,
    this.size = 72,
    this.iconSize = 36,
    this.borderRadius = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: Colors.white,
      ),
    );
  }
}

/// Structure de base (Scaffold + fond dégradé + carte blanche courbée)
/// partagée entre LoginScreen et PasswordScreen.
class AuthScaffold extends StatelessWidget {
  final Widget header;
  final Widget body;
  final double heroHeightFactor;
  final Animation<double>? fadeInAnimation;
  final Animation<Offset>? slideInAnimation;
  final EdgeInsetsGeometry formPadding;

  const AuthScaffold({
    super.key,
    required this.header,
    required this.body,
    this.heroHeightFactor = 0.38,
    this.fadeInAnimation,
    this.slideInAnimation,
    this.formPadding = const EdgeInsets.fromLTRB(28, 32, 28, 32),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget content = CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              // En-tête
              header,

              // Carte formulaire
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? colorScheme.surface : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: formPadding,
                    child: body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (slideInAnimation != null) {
      content = SlideTransition(position: slideInAnimation!, child: content);
    }
    if (fadeInAnimation != null) {
      content = FadeTransition(opacity: fadeInAnimation!, child: content);
    }

    return Scaffold(
      body: Stack(
        children: [
          // Fond dégradé supérieur
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * heroHeightFactor,
            child: const DecoratedBox(
              decoration: BoxDecoration(gradient: AppTheme.heroGradient),
            ),
          ),

          SafeArea(child: content),
        ],
      ),
    );
  }
}
