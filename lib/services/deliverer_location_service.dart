import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'profile_service.dart';
import 'navigation/location_service.dart' show DelivererLocationPermissionStatus;
export 'navigation/location_service.dart' show DelivererLocationPermissionStatus;

/// Service de suivi GPS temps réel du livreur vers Firebase Realtime Database.
/// Publie chaque mise à jour vers :
/// `https://ee-comeerce-default-rtdb.firebaseio.com/deliverers_live/{delivererId}`
class DelivererLocationService {
  static const String defaultDatabaseUrl =
      'https://ee-comeerce-default-rtdb.firebaseio.com';

  static final DelivererLocationService _instance =
      DelivererLocationService._internal();

  factory DelivererLocationService() => _instance;

  DelivererLocationService._internal({
    FirebaseDatabase? database,
    FirebaseAuth? auth,
    ProfileService? profileService,
  })  : _customDatabase = database,
        _customAuth = auth,
        _customProfileService = profileService;

  @visibleForTesting
  factory DelivererLocationService.withDependencies({
    FirebaseDatabase? database,
    FirebaseAuth? auth,
    ProfileService? profileService,
  }) {
    return DelivererLocationService._internal(
      database: database,
      auth: auth,
      profileService: profileService,
    );
  }

  final FirebaseDatabase? _customDatabase;
  final FirebaseAuth? _customAuth;
  final ProfileService? _customProfileService;

  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastWriteTime;

  String? _currentOrderId;
  Map<String, dynamic>? _vehicleInfo;
  bool _isOnline = false;

  bool get isOnline => _isOnline;
  String? get currentOrderId => _currentOrderId;
  Map<String, dynamic>? get vehicleInfo => _vehicleInfo;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;
  ProfileService get _profileService => _customProfileService ?? ProfileService();

  FirebaseDatabase get _database {
    if (_customDatabase != null) return _customDatabase;
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: defaultDatabaseUrl,
      );
    } catch (_) {
      return FirebaseDatabase.instance;
    }
  }

  User? get _currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Formate et valide les informations du véhicule selon la spécification Dokan :
  /// { "plate": "...", "type": "voiture" | "camion" }
  static Map<String, dynamic>? formatVehicleInfo({
    String? plate,
    String? type,
  }) {
    final cleanPlate = plate?.trim();
    if (cleanPlate == null || cleanPlate.isEmpty) return null;

    final lowerType = type?.toLowerCase().trim() ?? '';
    final normalizedType = (lowerType == 'camion' || lowerType == 'truck')
        ? 'camion'
        : 'voiture';

    return {
      'plate': cleanPlate,
      'type': normalizedType,
    };
  }

  /// Construit le dictionnaire de publication conforme aux exigences temps réel :
  /// - latitude (double), longitude (double)
  /// - heading (double 0-360)
  /// - speed (double en m/s >= 0)
  /// - timestamp: ServerValue.timestamp (long ms)
  /// - isOnline: true/false
  /// - currentOrderId: string ou null
  /// - vehicle (optionnel) : { "plate": "...", "type": "voiture" | "camion" }
  static Map<String, dynamic> buildLivePayload({
    required double latitude,
    required double longitude,
    required double rawHeading,
    required double rawSpeed,
    required bool isOnline,
    required String? currentOrderId,
    Map<String, dynamic>? vehicleInfo,
    String? delivererId,
    String? delivererName,
  }) {
    // Normalisation heading entre 0.0 et 360.0 degrés
    final double heading = (rawHeading.isNaN || rawHeading.isInfinite)
        ? 0.0
        : ((rawHeading % 360.0) + 360.0) % 360.0;

    // Vitesse en m/s (valeur positive)
    final double speed = (rawSpeed.isNaN || rawSpeed.isInfinite || rawSpeed < 0.0)
        ? 0.0
        : rawSpeed;

    final formattedVehicle = vehicleInfo != null
        ? formatVehicleInfo(
            plate: vehicleInfo['plate']?.toString(),
            type: vehicleInfo['type']?.toString(),
          )
        : null;

    return <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed': speed,
      'timestamp': ServerValue.timestamp,
      'isOnline': isOnline,
      'currentOrderId': currentOrderId,
      'vehicle': ?formattedVehicle,
      if (delivererId != null && delivererId.isNotEmpty) 'delivererId': delivererId,
      if (delivererName != null && delivererName.isNotEmpty)
        'delivererName': delivererName,
    };
  }

  /// 1. Vérification ordonnée des permissions et activation du GPS
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

  /// Ouvre l'écran des paramètres de l'application
  Future<bool> openAppSettings() async => await Geolocator.openAppSettings();

  /// Ouvre l'écran des paramètres de localisation de l'appareil
  Future<bool> openLocationSettings() async => await Geolocator.openLocationSettings();

  /// 2. Passer en ligne, configurer onDisconnect() et démarrer le tracking
  Future<void> goOnline({
    String? currentOrderId,
    Map<String, dynamic>? vehicleInfo,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Impossible de démarrer le tracking : livreur non connecté.');
    }

    _currentOrderId = currentOrderId;

    if (vehicleInfo != null) {
      _vehicleInfo = formatVehicleInfo(
        plate: vehicleInfo['plate']?.toString(),
        type: vehicleInfo['type']?.toString(),
      );
    } else if (_vehicleInfo == null) {
      // Résolution automatique du véhicule via le profil livreur
      try {
        final profile = await _profileService.getProfile(uid: user.uid);
        if (profile != null && profile.hasAssignedVehicle) {
          _vehicleInfo = formatVehicleInfo(
            plate: profile.assignedVehiclePlate,
            type: profile.assignedVehicleType,
          );
        }
      } catch (e) {
        debugPrint('[DelivererLocationService] Note fetch profile vehicle: $e');
      }
    }

    final delivererRef = _database.ref('deliverers_live/${user.uid}');

    // Configuration onDisconnect() : si l'application plante ou perd la connexion,
    // le statut isOnline bascule immédiatement sur false côté client Dokan
    try {
      await delivererRef.onDisconnect().update({
        'isOnline': false,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[DelivererLocationService] onDisconnect warning: $e');
    }

    // Configuration du suivi GPS avec service d'avant-plan
    late final LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Livraison en cours',
          notificationText: 'Partage de position GPS actif en temps réel',
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

    // Stopper tout flux existant avant de relancer
    await _positionSubscription?.cancel();
    _isOnline = true;
    _lastWriteTime = null;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) => _onPositionUpdate(position, delivererRef, user),
      onError: (error) {
        debugPrint('[DelivererLocationService] Erreur stream GPS : $error');
      },
    );
  }

  /// Callback exécuté à chaque émission GPS avec limitation (1 écriture / 3s max)
  Future<void> _onPositionUpdate(
    Position pos,
    DatabaseReference delivererRef,
    User user,
  ) async {
    final now = DateTime.now();

    // Limitation stricte à 1 écriture toutes les 3 secondes pour préserver la batterie et le quota
    if (_lastWriteTime != null &&
        now.difference(_lastWriteTime!) < const Duration(seconds: 3)) {
      return;
    }
    _lastWriteTime = now;

    final data = buildLivePayload(
      latitude: pos.latitude,
      longitude: pos.longitude,
      rawHeading: pos.heading,
      rawSpeed: pos.speed,
      isOnline: true,
      currentOrderId: _currentOrderId,
      vehicleInfo: _vehicleInfo,
      delivererId: user.uid,
      delivererName: user.displayName?.isNotEmpty == true
          ? user.displayName
          : 'Livreur',
    );

    try {
      await delivererRef.update(data);
    } catch (e) {
      debugPrint('[DelivererLocationService] Erreur maj position RTDB: $e');
    }
  }

  /// 3. Mettre à jour la commande en cours sans relancer le flux GPS
  Future<void> updateCurrentOrder(String? orderId) async {
    _currentOrderId = orderId;
    final user = _currentUser;
    if (user != null && _isOnline) {
      try {
        await _database.ref('deliverers_live/${user.uid}').update({
          'currentOrderId': orderId,
          'timestamp': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint('[DelivererLocationService] Erreur updateCurrentOrder: $e');
      }
    }
  }

  /// Mettre à jour les informations du véhicule utilisé
  void setVehicleInfo(Map<String, dynamic>? info) {
    if (info == null) {
      _vehicleInfo = null;
    } else {
      _vehicleInfo = formatVehicleInfo(
        plate: info['plate']?.toString(),
        type: info['type']?.toString(),
      );
    }
  }

  /// 4. Passer hors ligne et couper le tracking
  Future<void> goOffline() async {
    _isOnline = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    final user = _currentUser;
    if (user != null) {
      try {
        final delivererRef = _database.ref('deliverers_live/${user.uid}');
        await delivererRef.onDisconnect().cancel();
        await delivererRef.update({
          'isOnline': false,
          'timestamp': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint('[DelivererLocationService] Erreur goOffline: $e');
      }
    }
  }

  /// 5. Libérer les ressources
  void dispose() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isOnline = false;
  }
}
