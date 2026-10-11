import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bouton d'action principal avec dégradé, état de chargement animé
/// et retour visuel tactile.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;
  final VoidCallback? onPressed;
  final double height;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.onPressed,
    this.height = 54,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    Widget buttonContent;
    if (isLoading) {
      buttonContent = const SizedBox(
        key: ValueKey('loading'),
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
        ),
      );
    } else {
      buttonContent = Row(
        key: ValueKey('label-$label'),
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      );
    }

    final container = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      decoration: BoxDecoration(
        gradient: enabled ? AppTheme.primaryGradient : null,
        color: !enabled
            ? colorScheme.primary.withValues(alpha: 0.65)
            : null,
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: const Color(0xFF1F7A7A).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withValues(alpha: 0.15),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: buttonContent,
            ),
          ),
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: container);
    }
    return container;
  }
}
