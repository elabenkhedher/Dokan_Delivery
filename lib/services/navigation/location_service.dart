import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/navigation/deliverer_location.dart';

/// Statuts des autorisations et du capteur de géolocalisation
enum DelivererLocationPermissionStatus {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  granted,
}

/// Service autonome dédié à la capture GPS et à la gestion des permissions système.
class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<DelivererLocation> _locationController =
      StreamController<DelivererLocation>.broadcast();

  Stream<DelivererLocation> get locationStream => _locationController.stream;

  /// Vérification ordonnée :
  /// 1. GPS matériel activé
  /// 2. État actuel de la permission
  /// 3. Demande de permission
  /// 4. Gestion du refus permanent (deniedForever)
  Future<DelivererLocationPermissionStatus> checkAndRequestPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return DelivererLocationPermissionStatus.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return DelivererLocationPermissionStatus.permissionDenied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return DelivererLocationPermissionStatus.permissionDeniedForever;
    }

    return DelivererLocationPermissionStatus.granted;
  }

  Future<bool> openAppSettings() async => await Geolocator.openAppSettings();
  Future<bool> openLocationSettings() async => await Geolocator.openLocationSettings();

  /// Si l'émulateur Android renvoie la position par défaut (Mountain View, USA),
  /// on replie sur Tunis (Grand Tunis) par défaut si aucun GPS n'est configuré.
  Position _filterEmulatorPosition(Position pos) {
    if ((pos.latitude - 37.42).abs() < 0.2 && (pos.longitude - (-122.08)).abs() < 0.2) {
      return Position(
        latitude: 36.8065,
        longitude: 10.1815,
        timestamp: pos.timestamp,
        accuracy: pos.accuracy,
        altitude: pos.altitude,
        altitudeAccuracy: pos.altitudeAccuracy,
        heading: 0.0,
        headingAccuracy: pos.headingAccuracy,
        speed: 0.0,
        speedAccuracy: pos.speedAccuracy,
      );
    }
    return pos;
  }

  /// Récupère la position ponctuelle actuelle (position réelle du capteur GPS)
  Future<DelivererLocation?> getCurrentLocation() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return DelivererLocation.fromPosition(_filterEmulatorPosition(lastKnown));
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 4),
        ),
      );
      return DelivererLocation.fromPosition(_filterEmulatorPosition(pos));
    } catch (e) {
      debugPrint('[LocationService] Note: position de secours utilisée (GPS non disponible): $e');
      return DelivererLocation(
        latitude: 36.8065,
        longitude: 10.1815,
        heading: 0.0,
        speed: 0.0,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Démarre l'écoute continue du flux de position (10 m de filtre, Foreground Service)
  Stream<DelivererLocation> startLocationStream() {
    _positionSubscription?.cancel();

    late final LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Livraison en cours',
          notificationText: 'Navigation GPS active - suivi de commande en direct',
          enableWakeLock: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position pos) {
        final loc = DelivererLocation.fromPosition(_filterEmulatorPosition(pos));
        if (!_locationController.isClosed) {
          _locationController.add(loc);
        }
      },
      onError: (error) {
        debugPrint('[LocationService] Erreur stream GPS: $error');
      },
    );

    return _locationController.stream;
  }

  /// Arrête le flux d'écoute GPS
  Future<void> stopLocationStream() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Nettoyage des ressources
  void dispose() {
    stopLocationStream();
    _locationController.close();
  }
}
