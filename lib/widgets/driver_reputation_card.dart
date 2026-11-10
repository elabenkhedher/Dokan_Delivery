import 'package:flutter/material.dart';
import '../models/driver_stats.dart';
import '../theme/app_theme.dart';

/// Carte de réputation officielle Dokan affichant la note moyenne
/// et la grille des compliments reçus par le livreur.
class DriverReputationCard extends StatelessWidget {
  final DriverStats stats;

  const DriverReputationCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avg = stats.averageRating;
    final formattedAvg = stats.formattedAverage;
    final ratedCount = stats.ratedOrdersCount;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isDark
              ? const Color(0xFFB45309).withValues(alpha: 0.5)
              : const Color(0xFFFCD34D),
          width: 1.3,
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB), // Amber 50
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête : Titre & Badge note moyenne ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RÉPUTATION & AVIS CLIENTS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ratedCount > 0
                            ? '$ratedCount livraison${ratedCount > 1 ? 's' : ''} notée${ratedCount > 1 ? 's' : ''}'
                            : 'Nouveau livreur Dokan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge Note ⭐ 4.9 / 5
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$formattedAvg / 5',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Étoiles visuelles
            Row(
              children: List.generate(5, (index) {
                final isFull = (index + 1) <= avg.floor();
                final isHalf = !isFull && (index < avg);
                return Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Icon(
                    isFull
                        ? Icons.star_rounded
                        : (isHalf ? Icons.star_half_rounded : Icons.star_outline_rounded),
                    color: const Color(0xFFF59E0B),
                    size: 20,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            const Divider(height: 1, color: Color(0xFFFDE68A)),
            const SizedBox(height: 14),

            // ── Grille des badges / compliments reçus ──
            const Text(
              'Compliments reçus :',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E),
              ),
            ),
            const SizedBox(height: 10),

            _buildComplimentsGrid(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildComplimentsGrid(bool isDark) {
    final compliments = stats.compliments;

    final items = [
      _ComplimentItem(
        icon: '⏱️',
        label: 'Ponctuel',
        count: compliments[DriverStats.tagPonctuel] ?? 0,
      ),
      _ComplimentItem(
        icon: '😊',
        label: 'Courtois & Souriant',
        count: compliments[DriverStats.tagCourtois] ?? 0,
      ),
      _ComplimentItem(
        icon: '📦',
        label: 'Colis soigné',
        count: compliments[DriverStats.tagColisSoigne] ?? 0,
      ),
      _ComplimentItem(
        icon: '⭐',
        label: 'Professionnel',
        count: compliments[DriverStats.tagProfessionnel] ?? 0,
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFFCD34D),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                item.icon,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${item.count}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF92400E),
                      ),
                    ),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkMuted : AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ComplimentItem {
  final String icon;
  final String label;
  final int count;

  const _ComplimentItem({
    required this.icon,
    required this.label,
    required this.count,
  });
}
