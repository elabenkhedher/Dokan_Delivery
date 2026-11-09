import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/stock_pickup.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_helper.dart';
import 'bouncy_button.dart';

/// Dialogue animé affiché après le scan réussi d'un bon d'enlèvement en entrepôt.
class StockPickupSuccessDialog extends StatefulWidget {
  final StockPickup pickup;
  final VoidCallback onStartTour;

  const StockPickupSuccessDialog({
    super.key,
    required this.pickup,
    required this.onStartTour,
  });

  static Future<bool?> show({
    required BuildContext context,
    required StockPickup pickup,
    required VoidCallback onStartTour,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'StockPickupSuccess',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: AppCurves.spring);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim, secondaryAnim) {
        return StockPickupSuccessDialog(
          pickup: pickup,
          onStartTour: onStartTour,
        );
      },
    );
  }

  @override
  State<StockPickupSuccessDialog> createState() =>
      _StockPickupSuccessDialogState();
}

class _StockPickupSuccessDialogState extends State<StockPickupSuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();
    _pulseScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.pickup;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder
                  : AppColors.border.withValues(alpha: 0.8),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // ── En-tête avec badge animé ─────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.success.withValues(alpha: 0.15),
                        AppColors.primary.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: _pulseScale,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tournée validée !',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.text,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${p.effectiveOrderCount} colis enlevés au stock',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkMuted
                              : AppColors.mutedText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // ── Détails du Bon d'Enlèvement ──────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    children: [
                      // Badge Code Série cliquable
                      InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: p.serialCode));
                          HapticFeedback.selectionClick();
                          AppSnackBar.showSuccess(
                            context,
                            'Code série copié : ${p.serialCode}',
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceAlt
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.qr_code_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CODE SÉRIE STOCK',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: isDark
                                            ? AppColors.darkMuted
                                            : AppColors.mutedText,
                                      ),
                                    ),
                                    Text(
                                      p.serialCode,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                        fontFamily: 'monospace',
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.copy_rounded,
                                size: 16,
                                color: isDark
                                    ? AppColors.darkMuted
                                    : AppColors.hintText,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Grille récapitulative : Dépôt, Colis, Poids, Véhicule
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceAlt.withValues(alpha: 0.5)
                              : AppColors.surfaceAlt.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.border.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              icon: Icons.warehouse_rounded,
                              label: 'Entrepôt',
                              value: p.warehouseLocation,
                              color: AppColors.primary,
                              isDark: isDark,
                            ),
                            const Divider(height: 16, thickness: 0.6),
                            _buildInfoRow(
                              icon: Icons.inventory_2_rounded,
                              label: 'Commandes / Colis',
                              value: '${p.effectiveOrderCount} colis assignés',
                              color: AppColors.accent,
                              isDark: isDark,
                            ),
                            const Divider(height: 16, thickness: 0.6),
                            _buildInfoRow(
                              icon: Icons.scale_rounded,
                              label: 'Poids total chargé',
                              value: '${p.totalWeightKg.toStringAsFixed(1)} kg',
                              color: const Color(0xFF10B981),
                              isDark: isDark,
                            ),
                            if (p.vehiclePlate.isNotEmpty) ...[
                              const Divider(height: 16, thickness: 0.6),
                              _buildInfoRow(
                                icon: Icons.local_shipping_rounded,
                                label: 'Véhicule',
                                value:
                                    '${p.vehiclePlate} (${p.vehicleType.toUpperCase()})',
                                color: AppColors.primary,
                                isDark: isDark,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Bouton principal d'action : "Démarrer la tournée"
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: BouncyButton(
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            Navigator.of(context).pop(true);
                            widget.onStartTour();
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.navigation_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Démarrer la tournée',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(
                          'Fermer',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkMuted
                                : AppColors.mutedText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkMuted : AppColors.mutedText,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.text,
          ),
        ),
      ],
    );
  }
}
