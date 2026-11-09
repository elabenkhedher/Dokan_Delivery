import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
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

  /// Normalise les coordonnées de l'émulateur Android par défaut (Mountain View, USA) vers la ville du client
  Position _filterEmulatorPosition(Position pos, [LatLng? referenceDestination]) {
    if ((pos.latitude - 37.42).abs() < 0.2 && (pos.longitude - (-122.08)).abs() < 0.2) {
      final lat = referenceDestination != null ? referenceDestination.latitude - 0.007 : 36.8120;
      final lon = referenceDestination != null ? referenceDestination.longitude - 0.005 : 10.1800;
      return Position(
        latitude: lat,
        longitude: lon,
        timestamp: pos.timestamp,
        accuracy: pos.accuracy,
        altitude: pos.altitude,
        altitudeAccuracy: pos.altitudeAccuracy,
        heading: 45.0,
        headingAccuracy: pos.headingAccuracy,
        speed: 8.5,
        speedAccuracy: pos.speedAccuracy,
      );
    }
    return pos;
  }

  /// Récupère la position ponctuelle actuelle (avec secours réactif pour émulateur)
  Future<DelivererLocation?> getCurrentLocation({LatLng? referenceDestination}) async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return DelivererLocation.fromPosition(_filterEmulatorPosition(lastKnown, referenceDestination));
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 4),
        ),
      );
      return DelivererLocation.fromPosition(_filterEmulatorPosition(pos, referenceDestination));
    } catch (e) {
      debugPrint('[LocationService] Note: position de secours utilisée (émulateur sans GPS fixé): $e');
      if (referenceDestination != null) {
        return DelivererLocation(
          latitude: referenceDestination.latitude - 0.007,
          longitude: referenceDestination.longitude - 0.005,
          heading: 45.0,
          speed: 8.5,
          timestamp: DateTime.now(),
        );
      }
      return DelivererLocation(
        latitude: 36.8120,
        longitude: 10.1800,
        heading: 45.0,
        speed: 8.5,
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
