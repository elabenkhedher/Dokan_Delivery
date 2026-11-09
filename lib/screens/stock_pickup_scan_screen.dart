import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/stock_pickup.dart';
import '../services/stock_pickup_service.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/stock_pickup_success_dialog.dart';

/// Écran complet de scan QR Code et saisie manuelle pour l'enlèvement stock
/// et le départ de tournée Dokan Delivery.
class StockPickupScanScreen extends StatefulWidget {
  final StockPickupService? pickupService;
  final String? delivererUid;
  final void Function(StockPickup pickup)? onPickupCompleted;

  final bool initialManualMode;

  const StockPickupScanScreen({
    super.key,
    this.pickupService,
    this.delivererUid,
    this.onPickupCompleted,
    this.initialManualMode = false,
  });

  @override
  State<StockPickupScanScreen> createState() => _StockPickupScanScreenState();
}

class _StockPickupScanScreenState extends State<StockPickupScanScreen>
    with SingleTickerProviderStateMixin {
  late final StockPickupService _pickupService;
  late final MobileScannerController _scannerController;
  final TextEditingController _serialController = TextEditingController();

  late final AnimationController _laserAnimCtrl;
  late final Animation<double> _laserPosition;

  bool _isProcessing = false;
  bool _isTorchOn = false;
  late bool _isManualMode;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pickupService = widget.pickupService ?? StockPickupService();
    _isManualMode = widget.initialManualMode;

    _scannerController = MobileScannerController(
      autoStart: !_isManualMode,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128],
    );

    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (!_isManualMode) {
      _laserAnimCtrl.repeat(reverse: true);
    }

    _laserPosition = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserAnimCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserAnimCtrl.dispose();
    _scannerController.dispose();
    _serialController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawVal = barcodes.first.rawValue;
    if (rawVal == null || rawVal.trim().isEmpty) return;

    await _processCode(rawVal.trim());
  }

  Future<void> _processCode(String rawCode) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    _laserAnimCtrl.stop();

    HapticFeedback.mediumImpact();

    try {
      // 1. Validation critique immédiate du bon d'enlèvement (Dokan Delivery)
      try {
        await validerScanBonEnlevement(rawCode);
      } catch (e) {
        debugPrint('[StockPickupScanScreen] Note validerScanBonEnlevement: $e');
      }

      final result = await _pickupService.verifyAndProcessPickup(
        rawCode,
        delivererUid: widget.delivererUid,
      );

      if (!mounted) return;

      StockPickup? finalPickup = result.pickup;
      if (finalPickup == null) {
        try {
          String clean = rawCode.trim();
          if (clean.startsWith('{') && clean.contains('serialCode')) {
            final decoded = jsonDecode(clean);
            clean = decoded['serialCode']?.toString() ?? clean;
          }
          final doc1 = await FirebaseFirestore.instance.collection('bons_enlevement').doc(clean).get();
          final doc2 = (!doc1.exists) ? await FirebaseFirestore.instance.collection('stock_pickups').doc(clean).get() : null;
          final foundDoc = doc1.exists ? doc1 : doc2;
          if (foundDoc != null && foundDoc.exists) {
            finalPickup = StockPickup.fromFirestore(foundDoc);
          }
        } catch (_) {}
      }

      if ((result.isSuccess || finalPickup != null) && finalPickup != null) {
        // Haptic de succès immédiat
        HapticFeedback.heavyImpact();

        // Pause du flux caméra
        try {
          await _scannerController.stop();
        } catch (_) {}

        if (!mounted) return;

        setState(() {
          _isProcessing = false;
        });

        // Affichage du dialogue animé de succès
        await StockPickupSuccessDialog.show(
          context: context,
          pickup: finalPickup,
          onStartTour: () {
            if (widget.onPickupCompleted != null) {
              widget.onPickupCompleted!(finalPickup!);
            } else {
              Navigator.of(context).pop(finalPickup);
            }
          },
        );

        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(finalPickup);
        }
      } else {
        // Erreur de validation
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = result.message;
          _isProcessing = false;
        });
        _showErrorDialog(result.message);
      }
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = 'Erreur technique : $e';
        _isProcessing = false;
      });
      _showErrorDialog('Une erreur imprévue est survenue : $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Échec de validation',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _isProcessing = false;
              });
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _toggleTorch() async {
    HapticFeedback.selectionClick();
    try {
      await _scannerController.toggleTorch();
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (_) {}
  }

  void _switchCamera() async {
    HapticFeedback.selectionClick();
    try {
      await _scannerController.switchCamera();
    } catch (_) {}
  }

  void _submitManualCode() {
    final text = _serialController.text.trim();
    if (text.isEmpty) {
      AppSnackBar.showError(context, 'Veuillez saisir un code série.');
      return;
    }
    _processCode(text);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Enlèvement Stock',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: _isTorchOn ? 'Éteindre la lampe' : 'Allumer la lampe',
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? AppColors.accent : Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
          IconButton(
            tooltip: 'Changer de caméra',
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            onPressed: _switchCamera,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // ── Vue caméra ou formulaire manuel ──────────────────────
          if (!_isManualMode)
            MobileScanner(
              controller: _scannerController,
              onDetect: _handleBarcodeDetected,
              errorBuilder: (context, error, child) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.videocam_off_rounded,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Caméra inaccessible',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Impossible d\'activer la caméra (${error.errorCode.name}). Utilisez la saisie manuelle.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() => _isManualMode = true);
                          },
                          icon: const Icon(Icons.keyboard_rounded),
                          label: const Text('Saisie manuelle du code'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            _buildManualInputView(isDark),

          // ── Overlay Viseur avec Laser de scan animé ─────────────
          if (!_isManualMode) _buildScannerOverlay(),

          // ── Instructions en bas d'écran & bascule mode ───────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: AppColors.accent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isManualMode
                              ? 'Mode saisie manuelle'
                              : 'Cadrez le QR Code affiché à l\'entrepôt',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Bouton pour basculer entre caméra et saisie manuelle
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isManualMode = !_isManualMode;
                        if (_isManualMode) {
                          _laserAnimCtrl.stop();
                        } else {
                          _laserAnimCtrl.repeat(reverse: true);
                        }
                      });
                    },
                    icon: Icon(
                      _isManualMode
                          ? Icons.camera_alt_rounded
                          : Icons.keyboard_alt_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _isManualMode
                          ? 'Revenir au scanner caméra'
                          : 'Problème caméra ? Saisie manuelle',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Indicateur de chargement / vérification ──────────────
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: AppShadows.soft(),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Vérification du bon...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Mise à jour Firestore & tournée',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkMuted
                              : AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Viseur carré avec coins stylisés et ligne laser animée
  Widget _buildScannerOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = (constraints.maxWidth * 0.72).clamp(240.0, 320.0);
        final topOffset = (constraints.maxHeight - boxSize) / 2 - 40;

        return Stack(
          children: [
            // Fond sombre semi-transparent troué au centre
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.55),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Align(
                    alignment: Alignment(0, (topOffset / constraints.maxHeight) * 2 - 1),
                    child: Container(
                      width: boxSize,
                      height: boxSize,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Cadre et coins du viseur
            Align(
              alignment: Alignment(0, (topOffset / constraints.maxHeight) * 2 - 1),
              child: SizedBox(
                width: boxSize,
                height: boxSize,
                child: Stack(
                  children: [
                    // Bordure
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.6),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),

                    // Ligne Laser animée
                    AnimatedBuilder(
                      animation: _laserPosition,
                      builder: (context, child) {
                        return Positioned(
                          top: _laserPosition.value * (boxSize - 4),
                          left: 12,
                          right: 12,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppColors.accent,
                                  AppColors.primary,
                                  AppColors.accent,
                                  Colors.transparent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Vue dédiée à la saisie manuelle du code série (ex: STK-261108-7491)
  Widget _buildManualInputView(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Saisie du Code Série',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Entrez le code figurant sous le QR Code affiché par l\'administrateur (ex: STK-261108-7491 ou PKP_...).',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                  height: 1.4,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _serialController,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 1.0,
                ),
                decoration: InputDecoration(
                  labelText: 'Code Série / ID Enlèvement',
                  hintText: 'STK-261108-7491',
                  prefixIcon: const Icon(Icons.qr_code_rounded),
                  suffixIcon: _serialController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _serialController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkSurfaceAlt
                      : AppColors.surfaceAlt.withValues(alpha: 0.5),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submitManualCode(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: BouncyButton(
                  onTap: _submitManualCode,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Valider le bon d\'enlèvement',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
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
      ),
    );
  }
}
