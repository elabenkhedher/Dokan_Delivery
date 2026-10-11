import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import 'login_screen.dart';

/// Écran de démarrage (Splash Screen) animé avec le nom et logo de l'application.
class SplashScreen extends StatefulWidget {
  final Duration duration;
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    this.duration = const Duration(milliseconds: 2500),
    this.nextScreen = const LoginScreen(),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<Offset> _slideAnim;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    _scaleAnim = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _animCtrl.forward();

    // Redirection automatique après le délai spécifié
    Future.delayed(widget.duration, () {
      if (mounted) _goToNextScreen();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _goToNextScreen() {
    if (_navigated || !mounted) return;
    _navigated = true;

    Navigator.pushReplacement(
      context,
      SlideFadePageRoute(page: widget.nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _goToNextScreen,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppTheme.heroGradient,
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Cercles décoratifs d'arrière-plan
                Positioned(
                  top: -60,
                  right: -60,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 80,
                  left: -80,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),

                // Contenu central
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo avec halo lumineux
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.directions_car_rounded,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Nom de l'application
                            const Text(
                              'Soukna Delivery',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Sous-titre
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Espace Livreur',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bas de page (indicateur et version)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 32,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Rapidité • Fiabilité • Sécurité',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
