import 'delivery_order.dart';

/// Statistiques de réputation, notation et compliments pour le livreur Dokan.
class DriverStats {
  final int totalDelivered;
  final int ratedOrdersCount;
  final double averageRating;
  final Map<String, int> compliments;

  const DriverStats({
    required this.totalDelivered,
    required this.ratedOrdersCount,
    required this.averageRating,
    required this.compliments,
  });

  /// Tags de compliments officiels Dokan
  static const String tagPonctuel = 'Ponctuel ⏱️';
  static const String tagCourtois = 'Courtois & Souriant 😊';
  static const String tagColisSoigne = 'Colis soigné 📦';
  static const String tagProfessionnel = 'Professionnel ⭐';

  static const List<String> officialTags = [
    tagPonctuel,
    tagCourtois,
    tagColisSoigne,
    tagProfessionnel,
  ];

  /// Calcule les statistiques à partir d'une liste de commandes en mémoire
  factory DriverStats.fromOrders(List<DeliveryOrder> orders) {
    final deliveredOrders = orders.where((o) => o.isDelivered).toList();
    final totalDelivered = deliveredOrders.length;

    int ratedOrdersCount = 0;
    double sumRatings = 0;
    final complimentCounts = <String, int>{
      tagPonctuel: 0,
      tagCourtois: 0,
      tagColisSoigne: 0,
      tagProfessionnel: 0,
    };

    for (final order in deliveredOrders) {
      if (order.driverRating != null && order.driverRating! > 0) {
        ratedOrdersCount++;
        sumRatings += order.driverRating!;
      }

      final feedback = order.driverFeedback;
      if (feedback != null && feedback.trim().isNotEmpty) {
        final lower = feedback.toLowerCase();
        if (lower.contains('ponctuel')) {
          complimentCounts[tagPonctuel] =
              (complimentCounts[tagPonctuel] ?? 0) + 1;
        }
        if (lower.contains('courtois') || lower.contains('souriant')) {
          complimentCounts[tagCourtois] =
              (complimentCounts[tagCourtois] ?? 0) + 1;
        }
        if (lower.contains('soigné') || lower.contains('soigne') || lower.contains('colis')) {
          complimentCounts[tagColisSoigne] =
              (complimentCounts[tagColisSoigne] ?? 0) + 1;
        }
        if (lower.contains('professionnel') || lower.contains('pro')) {
          complimentCounts[tagProfessionnel] =
              (complimentCounts[tagProfessionnel] ?? 0) + 1;
        }
      }
    }

    final average =
        ratedOrdersCount > 0 ? (sumRatings / ratedOrdersCount) : 5.0;

    return DriverStats(
      totalDelivered: totalDelivered,
      ratedOrdersCount: ratedOrdersCount,
      averageRating: average,
      compliments: complimentCounts,
    );
  }

  /// Statistiques par défaut pour un nouveau livreur
  factory DriverStats.initial() {
    return const DriverStats(
      totalDelivered: 0,
      ratedOrdersCount: 0,
      averageRating: 5.0,
      compliments: {
        tagPonctuel: 0,
        tagCourtois: 0,
        tagColisSoigne: 0,
        tagProfessionnel: 0,
      },
    );
  }

  String get formattedAverage => averageRating.toStringAsFixed(1);
}
