import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Badge réaliste et élégant représentant une plaque d'immatriculation tunisienne officielle.
/// Format typique : "218 TN 6450" ou "218 تونس 6450".
class TunisianPlateBadge extends StatelessWidget {
  final String plate;
  final double fontSize;
  final bool isCompact;

  const TunisianPlateBadge({
    super.key,
    required this.plate,
    this.fontSize = 15,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cleaned = plate.trim();
    if (cleaned.isEmpty) {
      return const SizedBox.shrink();
    }

    // Découpage intelligent du matricule si format 'XXX TN YYYY' ou 'XXX تونس YYYY'
    final parts = cleaned.split(RegExp(r'\s+'));
    Widget plateContent;

    if (parts.length >= 3 &&
        (parts[1].toUpperCase() == 'TN' || parts[1] == 'تونس')) {
      plateContent = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Série (ex: 218)
          Text(
            parts[0],
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontFamily: 'monospace',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFC8102E), // Rouge drapeau tunisien
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'تونس',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize * 0.75,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
          ),
          // Numéro séquentiel (ex: 6450)
          Text(
            parts.sublist(2).join(' '),
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontFamily: 'monospace',
            ),
          ),
        ],
      );
    } else {
      // Affichage standard formaté si format personnalisé
      plateContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFC8102E),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'TN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            cleaned,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              fontFamily: 'monospace',
            ),
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 14,
        vertical: isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF14171A), // Noir plaque officiel
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Vis de fixation gauche
          Positioned(
            left: 0,
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF718096),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Contenu de la plaque
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: plateContent,
          ),
          // Vis de fixation droite
          Positioned(
            right: 0,
            child: Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF718096),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
