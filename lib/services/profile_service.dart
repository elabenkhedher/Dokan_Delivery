import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/driver_profile.dart';

/// Service gérant la lecture en temps réel et la mise à jour du profil livreur
/// dans la collection Firestore `users/{uid}`.
class ProfileService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  ProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _customFirestore = firestore,
        _customAuth = auth;

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    if (_customAuth != null) return _customAuth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  String? get currentUid => _auth?.currentUser?.uid;

  /// Écoute en temps réel des changements du profil livreur.
  Stream<DriverProfile?> streamProfile({String? uid}) {
    final targetUid = uid ?? currentUid;
    final firestore = _firestore;
    if (firestore == null || targetUid == null || targetUid.isEmpty) {
      return Stream.value(null);
    }

    return firestore
        .collection('users')
        .doc(targetUid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return DriverProfile.fromMap(snapshot.data()!, uid: snapshot.id);
    }).handleError((error) {
      debugPrint('[ProfileService] Erreur streamProfile: $error');
      return null;
    });
  }

  /// Récupère ponctuellement le document du profil livreur.
  Future<DriverProfile?> getProfile({String? uid}) async {
    final targetUid = uid ?? currentUid;
    final firestore = _firestore;
    if (firestore == null || targetUid == null || targetUid.isEmpty) {
      return null;
    }

    try {
      final doc = await firestore.collection('users').doc(targetUid).get();
      if (!doc.exists || doc.data() == null) return null;
      return DriverProfile.fromMap(doc.data()!, uid: doc.id);
    } catch (e) {
      debugPrint('[ProfileService] Erreur getProfile: $e');
      return null;
    }
  }

  /// Met à jour les informations modifiables du livreur :
  /// - Nom complet (name)
  /// - Numéro de téléphone (phone)
  /// - Zone d'affectation (assignedRegionId & assignedRegionName)
  ///
  /// Note de sécurité : les champs du véhicule (assignedVehicle*) ne sont PAS
  /// modifiés par cette méthode afin de garantir la règle d'attribution exclusive
  /// par l'administration.
  Future<void> updateDriverProfile({
    required String uid,
    required String name,
    required String phone,
    required String regionId,
    required String regionName,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      throw StateError('Firestore n\'est pas disponible.');
    }

    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();

    // 1. Mise à jour propre avec fusion dans `users/{uid}`
    await firestore.collection('users').doc(uid).set({
      'name': trimmedName,
      'nom': trimmedName,
      'phone': trimmedPhone,
      'telephone': trimmedPhone,
      'assignedRegionId': regionId,
      'assignedRegionName': regionName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Synchronisation du displayName de FirebaseAuth si possible
    try {
      final user = _auth?.currentUser;
      if (user != null && user.uid == uid) {
        await user.updateDisplayName(trimmedName);
      }
    } catch (e) {
      debugPrint('[ProfileService] Note: impossible de synchroniser displayName auth: $e');
    }
  }
}
