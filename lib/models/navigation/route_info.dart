import 'package:latlong2/latlong.dart';
import 'nav_step.dart';

/// Données complètes d'un itinéraire calculé par le moteur de routage.
class RouteInfo {
  final List<LatLng> points;
  final List<NavStep> steps;
  final double totalDistanceMeters;
  final double totalDurationSeconds;
  final double remainingDistanceMeters;
  final double remainingDurationSeconds;

  const RouteInfo({
    required this.points,
    required this.steps,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
  });

  /// Formatage convivial de la distance restante
  String get formattedDistance {
    if (remainingDistanceMeters < 1000) {
      return '${(remainingDistanceMeters / 10).round() * 10} m';
    }
    return '${(remainingDistanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Formatage de la durée restante (ex: "12 min" ou "1 h 05")
  String get formattedDuration {
    final minutes = (remainingDurationSeconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    return '${hours}h ${remainingMins.toString().padLeft(2, '0')}';
  }

  /// Heure d'arrivée estimée (ETA) au format HH:mm
  String get etaFormatted {
    final arrivalTime = DateTime.now().add(
      Duration(seconds: remainingDurationSeconds.round()),
    );
    final hour = arrivalTime.hour.toString().padLeft(2, '0');
    final minute = arrivalTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  RouteInfo copyWith({
    List<LatLng>? points,
    List<NavStep>? steps,
    double? totalDistanceMeters,
    double? totalDurationSeconds,
    double? remainingDistanceMeters,
    double? remainingDurationSeconds,
  }) {
    return RouteInfo(
      points: points ?? this.points,
      steps: steps ?? this.steps,
      totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      remainingDistanceMeters:
          remainingDistanceMeters ?? this.remainingDistanceMeters,
      remainingDurationSeconds:
          remainingDurationSeconds ?? this.remainingDurationSeconds,
    );
  }
}
