import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Modèle immuable représentant la position et la télémétrie GPS du livreur.
class DelivererLocation {
  final double latitude;
  final double longitude;
  final double heading; // Orientation normalisée en degrés (0.0 à 360.0)
  final double speed; // Vitesse en m/s (>= 0.0)
  final double accuracy; // Précision en mètres
  final DateTime timestamp;

  const DelivererLocation({
    required this.latitude,
    required this.longitude,
    required this.heading,
    required this.speed,
    this.accuracy = 0.0,
    required this.timestamp,
  });

  /// Conversion sécurisée depuis l'objet Position de Geolocator
  factory DelivererLocation.fromPosition(Position pos) {
    final rawHeading = pos.heading;
    final heading = (rawHeading.isNaN || rawHeading.isInfinite)
        ? 0.0
        : ((rawHeading % 360.0) + 360.0) % 360.0;

    final rawSpeed = pos.speed;
    final speed = (rawSpeed.isNaN || rawSpeed.isInfinite || rawSpeed < 0.0)
        ? 0.0
        : rawSpeed;

    return DelivererLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      heading: heading,
      speed: speed,
      accuracy: pos.accuracy,
      timestamp: pos.timestamp,
    );
  }

  /// Coordonnée OpenStreetMap / latlong2 LatLng
  LatLng get latLng => LatLng(latitude, longitude);

  /// Calcule la distance géodésique en mètres jusqu'à une autre coordonnée
  double distanceTo(LatLng target) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      target.latitude,
      target.longitude,
    );
  }

  /// Vitesse en kilomètres par heure (km/h)
  double get speedKmh => speed * 3.6;

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'accuracy': accuracy,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
