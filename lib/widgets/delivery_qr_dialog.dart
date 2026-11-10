import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/delivery_order.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../utils/snackbar_helper.dart';

/// Dialogue modal affichant le QR Code Dokan sécurisé pour confirmation
/// de livraison par le client, avec écoute Firestore temps réel et code PIN de secours.
class DeliveryQrDialog extends StatefulWidget {
  final DeliveryOrder order;
  final OrderService orderService;
  final bool enableSimulation;

  const DeliveryQrDialog({
    super.key,
    required this.order,
    required this.orderService,
    this.enableSimulation = false,
  });

  /// Affiche le dialogue modal de confirmation QR.
  /// Renvoie `true` si la livraison a été confirmée avec succès par le client.
  static Future<bool?> show({
    required BuildContext context,
    required DeliveryOrder order,
    required OrderService orderService,
    bool enableSimulation = false,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'DeliveryQrDialog',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: AppCurves.spring);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
      pageBuilder: (context, anim, secondaryAnim) {
        return DeliveryQrDialog(
          order: order,
          orderService: orderService,
          enableSimulation: enableSimulation,
        );
      },
    );
  }

  @override
  State<DeliveryQrDialog> createState() => _DeliveryQrDialogState();
}

class _DeliveryQrDialogState extends State<DeliveryQrDialog>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  late final AnimationController _successController;
  late final Animation<double> _successScale;

  StreamSubscription<DocumentSnapshot>? _ordersSub;
  StreamSubscription<DocumentSnapshot>? _commandesSub;

  bool _isSuccess = false;
  bool _isManualValidating = false;
  int? _receivedRating;
  String? _receivedFeedback;

  @override
  void initState() {
    super.initState();

    // Animation de pulsation du statut d'attente (radar)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animation du checkmark de succès
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _successScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _startFirestoreListeners();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _commandesSub?.cancel();
    _pulseController.dispose();
    _successController.dispose();
    super.dispose();
  }

  /// Démarre l'écoute en temps réel des documents Firestore dans `orders` et `commandes`
  void _startFirestoreListeners() {
    try {
      final firestore = FirebaseFirestore.instance;

      _ordersSub = firestore
          .collection('orders')
          .doc(widget.order.id)
          .snapshots()
          .listen(
            _processSnapshot,
            onError: (err) =>
                debugPrint('[DeliveryQrDialog] orders stream error: $err'),
          );

      _commandesSub = firestore
          .collection('commandes')
          .doc(widget.order.id)
          .snapshots()
          .listen(
            _processSnapshot,
            onError: (err) =>
                debugPrint('[DeliveryQrDialog] commandes stream error: $err'),
          );
    } catch (e) {
      debugPrint('[DeliveryQrDialog] Firestore listen init error: $e');
    }
  }

  /// Analyse les mises à jour Firestore pour détecter la validation client et les notes
  void _processSnapshot(DocumentSnapshot snapshot) {
    if (!mounted || _isSuccess) return;
    if (!snapshot.exists) return;

    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) return;

    final rawStatus = (data['status'] ?? data['statut'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    final isDelivered = data['isDelivered'] == true ||
        rawStatus == 'livre' ||
        rawStatus == 'livré' ||
        rawStatus == 'completed' ||
        rawStatus == 'delivered';

    final rawRating = data['driverRating'] ?? data['rating'] ?? data['noteLivreur'] ?? data['note'];
    final int? rating = (rawRating is num)
        ? rawRating.toInt()
        : int.tryParse(rawRating?.toString() ?? '');
    final String? feedback =
        (data['driverFeedback'] ?? data['feedback'] ?? data['avisLivreur'] ?? data['compliments'])?.toString();

    if (isDelivered || rating != null) {
      _triggerSuccess(
        clientScanned: true,
        rating: rating,
        feedback: feedback,
      );
    }
  }

  /// Déclenche l'état de validation avec animation de succès et célébration des notes
  void _triggerSuccess({
    required bool clientScanned,
    int? rating,
    String? feedback,
  }) {
    if (_isSuccess) return;
    _isSuccess = true;

    _receivedRating = rating ?? widget.order.driverRating;
    _receivedFeedback = feedback ?? widget.order.driverFeedback;

    // Mise à jour de l'instance locale si nécessaire
    if (!widget.order.isDelivered) {
      widget.order.markAsDelivered();
    }
    if (_receivedRating != null) widget.order.driverRating = _receivedRating;
    if (_receivedFeedback != null) widget.order.driverFeedback = _receivedFeedback;

    HapticFeedback.heavyImpact();

    if (mounted) {
      setState(() {});
      _successController.forward();

      // Arrêt des écouteurs Firestore
      _ordersSub?.cancel();
      _commandesSub?.cancel();
    }
  }

  /// Simulation ou validation manuelle de secours
  Future<void> _handleManualValidation() async {
    if (_isManualValidating || _isSuccess) return;

    setState(() => _isManualValidating = true);
    HapticFeedback.mediumImpact();

    try {
      await widget.orderService.marquerLivree(widget.order);
      const simulatedRating = 5;
      const simulatedFeedback = 'Ponctuel ⏱️, Courtois & Souriant 😊, Colis soigné 📦';
      widget.order.driverRating = simulatedRating;
      widget.order.driverFeedback = simulatedFeedback;
      _triggerSuccess(
        clientScanned: false,
        rating: simulatedRating,
        feedback: simulatedFeedback,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _isManualValidating = false);
        AppSnackBar.showError(context, 'Erreur lors de la validation : $error');
      }
    }
  }

  /// Génère un code de secours PIN à 6 chiffres déterministe
  String get _fallbackPin {
    final numbers = widget.order.id.replaceAll(RegExp(r'[^0-9]'), '');
    if (numbers.length >= 6) {
      return numbers.substring(numbers.length - 6);
    }
    final hash = widget.order.id.hashCode.abs();
    final pinNum = 100000 + (hash % 900000);
    return pinNum.toString();
  }

  /// Détermine si la commande nécessite un encaissement à la livraison (Cash on delivery)
  bool get _isCashOnDelivery {
    final status = widget.order.paymentStatus.toLowerCase();
    if (status == 'paid' || status == 'payé' || status == 'payee') {
      return false;
    }
    final method = widget.order.paymentMethod.toLowerCase();
    return method.contains('cash') ||
        method.contains('espece') ||
        method.contains('espèces') ||
        method.contains('livraison') ||
        method.contains('porte') ||
        method.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;
    final order = widget.order;
    final displayNumber =
        order.displayNumber.isNotEmpty ? order.displayNumber : order.id;

    // Payload de QR Code conforme au cahier des charges
    final qrPayload =
        'DOKAN-CONFIRM:${order.id}:${order.displayNumber}:${order.total}';

    return PopScope(
      canPop: !_isManualValidating && !_isSuccess,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.border.withValues(alpha: 0.6),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _isSuccess
                    ? _buildSuccessView(isDark, displayNumber)
                    : _buildQrView(isDark, primaryColor, displayNumber, qrPayload),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Vue principale affichant le QR Code et les informations de confirmation
  Widget _buildQrView(
    bool isDark,
    Color primaryColor,
    String displayNumber,
    String qrPayload,
  ) {
    final order = widget.order;
    final pin = _fallbackPin;
    final formattedPin =
        pin.length >= 6 ? '${pin.substring(0, 3)} ${pin.substring(3)}' : pin;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── En-tête : Titre, badge et bouton fermer ───────────────────────
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.qr_code_2_rounded,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Validation par le client',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkText : AppColors.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: const Text(
                            'Scan QR Dokan',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        Text(
                          '#$displayNumber',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkMuted
                                : AppColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => Navigator.of(context).pop(false),
                icon: Icon(
                  Icons.close_rounded,
                  color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                  size: 22,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Carte Résumé Commande & Client ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceAlt
                  : AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.customerName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkText : AppColors.text,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Encaissement ou badge payé
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isCashOnDelivery
                        ? AppColors.accentSoft
                        : AppColors.successSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: _isCashOnDelivery
                          ? AppColors.accent.withValues(alpha: 0.4)
                          : AppColors.success.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isCashOnDelivery
                            ? Icons.payments_outlined
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: _isCashOnDelivery
                            ? AppColors.warning
                            : AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _isCashOnDelivery
                              ? 'Montant à encaisser :'
                              : 'Payé en ligne :',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isCashOnDelivery
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${order.total.toStringAsFixed(3)} ${order.currency.isNotEmpty ? order.currency : 'TND'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _isCashOnDelivery
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── QR Code en haute netteté / contraste ──────────────────────────
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
              ),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0F172A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F172A),
                ),
                gapless: true,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Code PIN de secours (confirmation orale) ──────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceAlt
                  : AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.pin_rounded,
                  size: 16,
                  color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Code de secours (oral) :',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkMuted
                          : AppColors.mutedText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    formattedPin,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: isDark ? AppColors.primarySoft : AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Texte d'explication ───────────────────────────────────────────
          Text(
            'Présentez ce QR Code au client. Dès que le client le scanne, la livraison sera validée.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark ? AppColors.darkMuted : AppColors.mutedText,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 10),

          // ── Indicateur Pulse : En attente du scan client ───────────────────
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: primaryColor
                        .withValues(alpha: 0.06 + (_pulseAnimation.value * 0.08)),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: primaryColor
                          .withValues(alpha: 0.15 + (_pulseAnimation.value * 0.3)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(
                                  alpha: 0.6 * _pulseAnimation.value),
                              blurRadius: 6 * _pulseAnimation.value,
                              spreadRadius: 2 * _pulseAnimation.value,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'En attente du scan client...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Bouton d'action : Simuler scan client (Test) / Validation (activable uniquement en mode test) ──
          if (widget.enableSimulation) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              key: const ValueKey('delivery-qr-simulate-btn'),
              onPressed: _isManualValidating ? null : _handleManualValidation,
              icon: _isManualValidating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bolt_rounded, size: 20),
              label: Text(
                _isManualValidating
                    ? 'Validation en cours...'
                    : 'Simuler scan client (Test)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                elevation: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Vue de célébration festive avec étoiles et compliments lors de la confirmation
  Widget _buildSuccessView(bool isDark, String displayNumber) {
    final rating = _receivedRating ?? widget.order.driverRating ?? 5;
    final feedback = _receivedFeedback ?? widget.order.driverFeedback;
    final tags = (feedback != null && feedback.trim().isNotEmpty)
        ? feedback
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList()
        : <String>[];

    return SingleChildScrollView(
      key: const ValueKey('qr-validation-success-view'),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _successScale,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 46,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '🎉 Livraison réussie et validée !',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.darkText : AppColors.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Colis remis au client • Commande #$displayNumber',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkMuted : AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 16),

          // ── Notation par étoiles du client ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFFFFBEB), // Amber 50
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: const Color(0xFFFCD34D), // Amber 300
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Note attribuée par le client :',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final isFilled = index < rating;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Icon(
                        isFilled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFF59E0B),
                        size: 30,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(
                  '$rating / 5 étoiles',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD97706),
                  ),
                ),
              ],
            ),
          ),

          // ── Puces des compliments reçus ──
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: tags.map((tag) {
                return Chip(
                  backgroundColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFFEF3C7),
                  side: const BorderSide(color: Color(0xFFFCD34D)),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  label: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF92400E),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 20),

          // ── Bouton Continuer ma tournée ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              key: const ValueKey('continue-tour-btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E), // Vert Dokan
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                elevation: 2,
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.rocket_launch_rounded, size: 20),
              label: const Text(
                'Continuer ma tournée 🚀',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
