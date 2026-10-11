import 'package:flutter/material.dart';

/// Transition de page fluide combinant un fondu (fade) et un léger glissement horizontal (slide).
class SlideFadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideFadePageRoute({
    required this.page,
    Duration duration = const Duration(milliseconds: 350),
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
                child: child,
              ),
            );
          },
        );
}
