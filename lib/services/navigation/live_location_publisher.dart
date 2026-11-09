import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../../models/navigation/deliverer_location.dart';
import '../deliverer_location_service.dart';

/// Service responsable de la diffusion de la position en temps réel vers Firebase Realtime Database.
/// Publie chaque mise à jour vers :
/// `https://ee-comeerce-default-rtdb.firebaseio.com/deliverers_live/{delivererId}`
class LiveLocationPublisher {
  static const String defaultDatabaseUrl =
      'https://ee-comeerce-default-rtdb.firebaseio.com';

  final FirebaseAuth? _customAuth;
  final FirebaseDatabase? _customDatabase;

  DateTime? _lastWriteTime;
  bool _isInitialized = false;

  LiveLocationPublisher({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
  })  : _customAuth = auth,
        _customDatabase = database;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

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

  /// Initialise la configuration onDisconnect() pour basculer isOnline à false en cas de déconnexion inattendue
  Future<void> initializeDisconnectHandler() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final ref = _database.ref('deliverers_live/${user.uid}');
      await ref.onDisconnect().update({
        'isOnline': false,
        'timestamp': ServerValue.timestamp,
      });
      _isInitialized = true;
    } catch (e) {
      debugPrint('[LiveLocationPublisher] Note onDisconnect non critique: $e');
    }
  }

  /// Publie la position courante avec limitation stricte à 1 écriture / 3 secondes.
  /// Résilience réseau : les erreurs d'écriture ne bloquent JAMAIS la navigation locale.
  Future<void> publishLocation({
    required DelivererLocation location,
    required String? currentOrderId,
    Map<String, dynamic>? vehicleInfo,
  }) async {
    final user = _currentUser;
    if (user == null) return;

    final now = DateTime.now();
    if (_lastWriteTime != null &&
        now.difference(_lastWriteTime!) < const Duration(seconds: 3)) {
      return; // Throttling actif
    }
    _lastWriteTime = now;

    if (!_isInitialized) {
      await initializeDisconnectHandler();
    }

    final vehicle = vehicleInfo ?? DelivererLocationService().vehicleInfo;

    final data = DelivererLocationService.buildLivePayload(
      latitude: location.latitude,
      longitude: location.longitude,
      rawHeading: location.heading,
      rawSpeed: location.speed,
      isOnline: true,
      currentOrderId: currentOrderId,
      vehicleInfo: vehicle,
      delivererId: user.uid,
      delivererName: (user.displayName != null && user.displayName!.isNotEmpty)
          ? user.displayName
          : 'Livreur',
    );

    try {
      await _database.ref('deliverers_live/${user.uid}').update(data);
    } catch (e) {
      // Échec silencieux pour ne pas impacter l'interface ni le guidage
      debugPrint('[LiveLocationPublisher] Échec publication (hors-ligne temporaire) : $e');
    }
  }

  /// Marque le livreur comme hors ligne et libère la commande
  Future<void> markOffline() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final ref = _database.ref('deliverers_live/${user.uid}');
      await ref.onDisconnect().cancel();
      await ref.update({
        'isOnline': false,
        'currentOrderId': null,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[LiveLocationPublisher] Erreur markOffline: $e');
    }
  }
}
