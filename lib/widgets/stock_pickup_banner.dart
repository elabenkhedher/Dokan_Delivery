import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/stock_pickup.dart';
import '../screens/stock_pickup_scan_screen.dart';
import '../services/stock_pickup_service.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import 'bouncy_button.dart';

/// Bannière ergonomique pour initier l'enlèvement stock au dépôt et le départ de tournée.
class StockPickupBanner extends StatelessWidget {
  final int pendingOrdersCount;
  final int activeTourOrdersCount;
  final StockPickupService? pickupService;
  final String? delivererUid;
  final void Function(StockPickup pickup)? onPickupCompleted;
  final VoidCallback? onStartTour;

  const StockPickupBanner({
    super.key,
    this.pendingOrdersCount = 0,
    this.activeTourOrdersCount = 0,
    this.pickupService,
    this.delivererUid,
    this.onPickupCompleted,
    this.onStartTour,
  });

  void _openScanner(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push<StockPickup?>(
      context,
      SlideFadePageRoute(
        page: StockPickupScanScreen(
          pickupService: pickupService,
          delivererUid: delivererUid,
        ),
      ),
    );

    if (result != null && onPickupCompleted != null) {
      onPickupCompleted!(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasActiveTour = activeTourOrdersCount > 0 && onStartTour != null;
    final isTourReadyOnly = hasActiveTour && pendingOrdersCount == 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : (hasActiveTour
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border.withValues(alpha: 0.8)),
          width: hasActiveTour ? 1.5 : 1.0,
        ),
        boxShadow: AppShadows.card(),
      ),
      child: Stack(
        children: [
          // Accents décoratifs discrets en arrière-plan
          Positioned(
            right: -15,
            top: -15,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (hasActiveTour ? const Color(0xFF2563EB) : AppColors.primary)
                    .withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isTourReadyOnly
                              ? [const Color(0xFF2563EB), const Color(0xFF1D4ED8)]
                              : [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(
                            color: (isTourReadyOnly ? const Color(0xFF2563EB) : AppColors.primary)
                                .withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isTourReadyOnly
                            ? Icons.navigation_rounded
                            : Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isTourReadyOnly
                                    ? 'Tournée prête'
                                    : 'Enlèvement Stock',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppColors.text,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (activeTourOrdersCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (isTourReadyOnly
                                            ? const Color(0xFF2563EB)
                                            : AppColors.accent)
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    '$activeTourOrdersCount en tournée',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isTourReadyOnly
                                          ? const Color(0xFF2563EB)
                                          : AppColors.accent,
                                    ),
                                  ),
                                ),
                              ] else if (pendingOrdersCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.accent.withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    '$pendingOrdersCount prêt${pendingOrdersCount > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isTourReadyOnly
                                ? 'Vos colis sont chargés. Démarrez la tournée pour afficher tous vos arrêts sur la carte interactive.'
                                : 'Scannez le QR Code de l\'entrepôt pour charger vos colis et démarrer votre tournée.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkMuted
                                  : AppColors.mutedText,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Bouton(s) d'action ──
                if (hasActiveTour) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: BouncyButton(
                      onTap: onStartTour,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.navigation_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Démarrer la tournée ($activeTourOrdersCount)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (pendingOrdersCount > 0) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: TextButton.icon(
                        onPressed: () => _openScanner(context),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
                        label: Text('Scanner d\'autres colis au stock ($pendingOrdersCount)'),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : AppColors.text,
                        ),
                      ),
                    ),
                  ],
                ] else
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: BouncyButton(
                      onTap: () => _openScanner(context),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Scanner Bon de Stock',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
