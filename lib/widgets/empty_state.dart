import 'package:flutter/material.dart';

/// Widget réutilisable pour afficher un état vide (liste vide, aucun résultat, etc.).
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.padding = const EdgeInsets.symmetric(vertical: 24),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 48,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
