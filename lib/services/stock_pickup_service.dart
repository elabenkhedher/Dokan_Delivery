import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/stock_pickup.dart';
import 'deliverer_location_service.dart';
import 'order_service.dart'
    show
        validerScanBonEnlevement,
        consumeRecentlyValidatedPickupCode;

export 'order_service.dart' show validerScanBonEnlevement;

/// Résultat de la validation d'un scan ou saisie de code d'enlèvement
class StockPickupResult {
  final bool isSuccess;
  final String message;
  final StockPickup? pickup;
  final int updatedOrdersCount;
  final String? errorCode;

  const StockPickupResult({
    required this.isSuccess,
    required this.message,
    this.pickup,
    this.updatedOrdersCount = 0,
    this.errorCode,
  });

  factory StockPickupResult.success({
    required String message,
    required StockPickup pickup,
    int updatedOrdersCount = 0,
  }) {
    return StockPickupResult(
      isSuccess: true,
      message: message,
      pickup: pickup,
      updatedOrdersCount: updatedOrdersCount,
    );
  }

  factory StockPickupResult.failure({
    required String message,
    StockPickup? pickup,
    String? errorCode,
  }) {
    return StockPickupResult(
      isSuccess: false,
      message: message,
      pickup: pickup,
      errorCode: errorCode,
    );
  }
}

/// Service complet de gestion de l'enlèvement stock et départ de tournée.
class StockPickupService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseDatabase? _customDatabase;
  final FirebaseAuth? _customAuth;
  final DelivererLocationService? _customLocationService;

  // Cache mémoire / test pour les tests unitaires sans Firebase
  final Map<String, StockPickup> _testPickups = {};
  final Map<String, Map<String, dynamic>> _testOrders = {};
  final Map<String, Map<String, dynamic>> _testUsers = {};

  StockPickupService({
    FirebaseFirestore? firestore,
    FirebaseDatabase? database,
    FirebaseAuth? auth,
    DelivererLocationService? locationService,
    List<StockPickup>? initialPickups,
  })  : _customFirestore = firestore,
        _customDatabase = database,
        _customAuth = auth,
        _customLocationService = locationService {
    if (initialPickups != null) {
      for (final p in initialPickups) {
        _testPickups[p.id] = p;
        if (p.serialCode.isNotEmpty) {
          _testPickups[p.serialCode] = p;
        }
      }
    }
  }

  @visibleForTesting
  Map<String, Map<String, dynamic>> get testOrders => _testOrders;

  @visibleForTesting
  Map<String, Map<String, dynamic>> get testUsers => _testUsers;

  @visibleForTesting
  void addTestPickup(StockPickup pickup) {
    _testPickups[pickup.id] = pickup;
    if (pickup.serialCode.isNotEmpty) {
      _testPickups[pickup.serialCode] = pickup;
    }
  }

  @visibleForTesting
  StockPickup? getTestPickup(String idOrSerial) => _testPickups[idOrSerial];

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

  FirebaseDatabase? get _database {
    if (_customDatabase != null) return _customDatabase;
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: DelivererLocationService.defaultDatabaseUrl,
      );
    } catch (_) {
      try {
        return FirebaseDatabase.instance;
      } catch (_) {
        return null;
      }
    }
  }

  String? get currentUid => _auth?.currentUser?.uid;

  /// Recherche un document de bon d'enlèvement (`stock_pickups` ou `bons_enlevement`)
  /// selon la stratégie définie par la logique métier :
  /// 1. Recherche par serialCode direct dans Firestore `stock_pickups/{serialCode}` ou `bons_enlevement/{serialCode}`.
  /// 2. Si un docId / pickupId est spécifié, recherche par docId dans `stock_pickups` ou `bons_enlevement`.
  /// 3. Fallback requête Firestore : `stock_pickups.where('serialCode', == serialCode).where('status', == 'pending')`.
  /// 4. Fallback RTDB : lecture du nœud `deliverers_live/{livreurUid}/pendingPickup`.
  /// 5. Repli cache mémoire de tests.
  Future<StockPickup?> findPickup(
    StockPickupQrData qrData, {
    String? delivererUid,
  }) async {
    final firestore = _firestore;
    final effectiveDelivererUid =
        delivererUid ?? qrData.delivererId ?? currentUid;
    final serial = (qrData.serialCode ?? qrData.primaryCode)?.trim() ?? '';
    final pickupId = qrData.pickupId?.trim() ?? '';

    // 1. Recherche directe Firestore dans stock_pickups/{serialCode} ou bons_enlevement/{serialCode}
    if (firestore != null && serial.isNotEmpty) {
      try {
        final docStock =
            await firestore.collection('stock_pickups').doc(serial).get();
        if (docStock.exists && docStock.data() != null) {
          return StockPickup.fromFirestore(docStock);
        }
      } catch (e) {
        debugPrint('[StockPickupService] Erreur findPickup stock_pickups/$serial : $e');
      }

      try {
        final docBons =
            await firestore.collection('bons_enlevement').doc(serial).get();
        if (docBons.exists && docBons.data() != null) {
          return StockPickup.fromFirestore(docBons);
        }
      } catch (e) {
        debugPrint('[StockPickupService] Erreur findPickup bons_enlevement/$serial : $e');
      }
    }

    // 1.B. Recherche directe par pickupId si différent du code série
    if (firestore != null && pickupId.isNotEmpty && pickupId != serial) {
      try {
        final doc =
            await firestore.collection('stock_pickups').doc(pickupId).get();
        if (doc.exists && doc.data() != null) {
          return StockPickup.fromFirestore(doc);
        }
      } catch (_) {}

      try {
        final doc =
            await firestore.collection('bons_enlevement').doc(pickupId).get();
        if (doc.exists && doc.data() != null) {
          return StockPickup.fromFirestore(doc);
        }
      } catch (_) {}
    }

    // 1.C. Recherche directe par texte brut scanné (ID de document Firestore)
    final rawText = qrData.rawInput.trim();
    if (firestore != null &&
        rawText.isNotEmpty &&
        rawText != serial &&
        rawText != pickupId) {
      try {
        final doc =
            await firestore.collection('bons_enlevement').doc(rawText).get();
        if (doc.exists && doc.data() != null) {
          return StockPickup.fromFirestore(doc);
        }
      } catch (_) {}

      try {
        final doc =
            await firestore.collection('stock_pickups').doc(rawText).get();
        if (doc.exists && doc.data() != null) {
          return StockPickup.fromFirestore(doc);
        }
      } catch (_) {}
    }

    // 2. Fallback sur Firestore query :
    // firestore.collection('stock_pickups').where('serialCode', isEqualTo: serialCode.trim()).where('status', isEqualTo: 'pending')
    if (firestore != null && serial.isNotEmpty) {
      try {
        final queryPending = await firestore
            .collection('stock_pickups')
            .where('serialCode', isEqualTo: serial)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();
        if (queryPending.docs.isNotEmpty) {
          return StockPickup.fromFirestore(queryPending.docs.first);
        }
      } catch (e) {
        debugPrint('[StockPickupService] Erreur query stock_pickups pending: $e');
      }

      // Query sans filtre 'pending' dans stock_pickups (ex: pour détecter statut déjà scanné)
      try {
        final queryAny = await firestore
            .collection('stock_pickups')
            .where('serialCode', isEqualTo: serial)
            .limit(1)
            .get();
        if (queryAny.docs.isNotEmpty) {
          return StockPickup.fromFirestore(queryAny.docs.first);
        }
      } catch (_) {}

      // Query dans bons_enlevement
      try {
        final queryBons = await firestore
            .collection('bons_enlevement')
            .where('serialCode', isEqualTo: serial)
            .limit(1)
            .get();
        if (queryBons.docs.isNotEmpty) {
          return StockPickup.fromFirestore(queryBons.docs.first);
        }
      } catch (_) {}
    }

    // 3. Fallback RTDB : lire deliverers_live/{livreurUid}/pendingPickup
    if (effectiveDelivererUid != null && effectiveDelivererUid.isNotEmpty) {
      final db = _database;
      if (db != null) {
        try {
          final snap = await db
              .ref('deliverers_live/$effectiveDelivererUid/pendingPickup')
              .get();
          if (snap.exists && snap.value != null) {
            final val = snap.value;
            if (val is Map) {
              final map = Map<String, dynamic>.from(val);
              final rtdbSerial =
                  (map['serialCode'] ?? map['serial'] ?? '').toString();
              if (serial.isEmpty || rtdbSerial.isEmpty || rtdbSerial == serial) {
                final rtdbId = (map['id'] ?? map['pickupId'] ?? serial).toString();
                return StockPickup.fromMap(map, id: rtdbId);
              }
            }
          }
        } catch (e) {
          debugPrint('[StockPickupService] Erreur fallback RTDB pendingPickup: $e');
        }
      }
    }

    // 4. Cache mémoire de tests (unit tests sans Firebase)
    if (serial.isNotEmpty && _testPickups.containsKey(serial)) {
      return _testPickups[serial];
    }
    if (pickupId.isNotEmpty && _testPickups.containsKey(pickupId)) {
      return _testPickups[pickupId];
    }

    return null;
  }

  /// Traitement complet de validation d'un enlèvement de stock :
  /// 1. Parse le code QR (JSON ou chaîne code série "STK-YYMMDD-XXXX").
  /// 2. Recherche la session d'enlèvement (Firestore stock_pickups, bons_enlevement, RTDB).
  /// 3. Met à jour le statut du bon : `status: 'scanned'`, `scannedAt`, `scannedBy`.
  /// 4. Met à jour le statut de TOUTES les commandes (orderIds) à `'enleve'` dans `orders` et `commandes`.
  /// 5. Met à jour la télémétrie RTDB du livreur (`status: 'in_progress'`, `isOnline: true`, `updatedAt`, `last_serial_code`)
  ///    et supprime le nœud `pendingPickup`.
  Future<StockPickupResult> verifyAndProcessPickup(
    String rawCodeOrSerial, {
    String? delivererUid,
  }) async {
    final qrData = StockPickupQrData.parse(rawCodeOrSerial);
    final primaryCode = qrData.primaryCode;

    if (primaryCode == null || primaryCode.isEmpty) {
      return StockPickupResult.failure(
        message: 'Code QR ou numéro de série vide ou invalide.',
        errorCode: 'INVALID_CODE_FORMAT',
      );
    }

    final effectiveDelivererUid =
        delivererUid ?? qrData.delivererId ?? currentUid;

    // 1. Recherche du bon d'enlèvement (Firestore direct, query pending, fallback RTDB)
    final pickup = await findPickup(
      qrData,
      delivererUid: effectiveDelivererUid,
    );
    if (pickup == null) {
      return StockPickupResult.failure(
        message:
            'Aucun bon d\'enlèvement trouvé pour le code "$primaryCode". Veuillez vérifier avec l\'administrateur ou le responsable entrepôt.',
        errorCode: 'PICKUP_NOT_FOUND',
      );
    }

    // 2. Vérification de l'affectation du livreur
    if (pickup.delivererId.isNotEmpty &&
        effectiveDelivererUid != null &&
        effectiveDelivererUid.isNotEmpty &&
        pickup.delivererId != effectiveDelivererUid) {
      final livreurInfo = pickup.delivererName.isNotEmpty
          ? pickup.delivererName
          : pickup.delivererId;
      return StockPickupResult.failure(
        message:
            'Ce bon d\'enlèvement est attribué à un autre livreur ($livreurInfo). Vous ne pouvez pas le scanner.',
        pickup: pickup,
        errorCode: 'UNAUTHORIZED_DELIVERER',
      );
    }

    // 3. Vérification du statut
    if (pickup.isScanned) {
      final wasJustValidated =
          consumeRecentlyValidatedPickupCode(pickup.serialCode) ||
          consumeRecentlyValidatedPickupCode(pickup.id) ||
          consumeRecentlyValidatedPickupCode(primaryCode) ||
          consumeRecentlyValidatedPickupCode(rawCodeOrSerial);

      if (!wasJustValidated) {
        final dateStr = pickup.scannedAt != null
            ? ' le ${pickup.scannedAt!.day}/${pickup.scannedAt!.month} à ${pickup.scannedAt!.hour}h${pickup.scannedAt!.minute.toString().padLeft(2, '0')}'
            : '';
        return StockPickupResult.failure(
          message:
              'Cet enlèvement (${pickup.serialCode}) a déjà été scanné et validé$dateStr.',
          pickup: pickup,
          errorCode: 'ALREADY_SCANNED',
        );
      }
    }

    if (!pickup.isPending && !pickup.isScanned) {
      return StockPickupResult.failure(
        message:
            'Le bon d\'enlèvement présente un statut inattendu : "${pickup.status}".',
        pickup: pickup,
        errorCode: 'INVALID_STATUS',
      );
    }

    final firestore = _firestore;
    final now = DateTime.now();

    // 4. Mises à jour Firestore
    if (firestore != null) {
      try {
        // Exécution de la fonction critique validerScanBonEnlevement (Dokan Delivery)
        try {
          await validerScanBonEnlevement(rawCodeOrSerial);
        } catch (e) {
          debugPrint('[StockPickupService] Note validerScanBonEnlevement: $e');
        }

        // B. Mettre à jour le statut du bon :
        // status: 'scanned', scannedAt: FieldValue.serverTimestamp(), scannedBy: currentUser.uid
        final bonUpdate = {
          'status': StockPickup.statusScanned,
          'scannedAt': FieldValue.serverTimestamp(),
          'scannedBy': effectiveDelivererUid ?? 'inconnu',
        };

        // Mise à jour collection 'stock_pickups'
        final pickupDocId =
            pickup.id.isNotEmpty ? pickup.id : pickup.serialCode;
        await firestore
            .collection('stock_pickups')
            .doc(pickupDocId)
            .set(bonUpdate, SetOptions(merge: true));

        if (pickup.serialCode.isNotEmpty && pickup.serialCode != pickupDocId) {
          await firestore
              .collection('stock_pickups')
              .doc(pickup.serialCode)
              .set(bonUpdate, SetOptions(merge: true));
        }

        // Mise à jour collection 'bons_enlevement'
        if (pickup.serialCode.isNotEmpty) {
          await firestore
              .collection('bons_enlevement')
              .doc(pickup.serialCode)
              .set(bonUpdate, SetOptions(merge: true));
        }
        if (pickup.id.isNotEmpty && pickup.id != pickup.serialCode) {
          await firestore
              .collection('bons_enlevement')
              .doc(pickup.id)
              .set(bonUpdate, SetOptions(merge: true));
        }

        // C. Mettre à jour le statut de TOUTES les commandes (orderIds) à 'enleve' :
        // Pour chaque orderId dans orderIds, mettre à jour les collections orders et commandes
        final comment =
            'Colis enlevé au stock par le livreur (Scan ${pickup.serialCode})';

        for (final orderId in pickup.orderIds) {
          try {
            await firestore.collection('orders').doc(orderId).update({
              'status': 'enleve',
              'isPickedUp': true,
              'pickedUpAt': FieldValue.serverTimestamp(),
              'statusHistory': FieldValue.arrayUnion([
                {
                  'at': Timestamp.now(),
                  'status': 'enleve',
                  'comment': comment,
                }
              ]),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            debugPrint('[StockPickupService] Note update orders/$orderId : $e');
            // Fallback set avec merge si le document n'existait pas encore
            try {
              await firestore.collection('orders').doc(orderId).set({
                'status': 'enleve',
                'isPickedUp': true,
                'pickedUpAt': FieldValue.serverTimestamp(),
                'statusHistory': FieldValue.arrayUnion([
                  {
                    'at': Timestamp.now(),
                    'status': 'enleve',
                    'comment': comment,
                  }
                ]),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            } catch (_) {}
          }

          // Si l'application utilise la collection commandes, mettre à jour également le document
          try {
            await firestore.collection('commandes').doc(orderId).set({
              'status': 'enleve',
              'isPickedUp': true,
              'pickedUpAt': FieldValue.serverTimestamp(),
              'statusHistory': FieldValue.arrayUnion([
                {
                  'at': Timestamp.now(),
                  'status': 'enleve',
                  'comment': comment,
                }
              ]),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('[StockPickupService] Note update commandes/$orderId : $e');
          }
        }

        // Mise à jour du profil livreur Firestore users/{uid}
        if (effectiveDelivererUid != null && effectiveDelivererUid.isNotEmpty) {
          final userRef =
              firestore.collection('users').doc(effectiveDelivererUid);
          await userRef.set(
            {
              'status': 'in_progress',
              'isOnline': true,
              'currentTourStartedAt': FieldValue.serverTimestamp(),
              'lastStockPickupId': pickup.id,
              'lastStockPickupSerial': pickup.serialCode,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      } catch (e) {
        debugPrint('[StockPickupService] Erreur Firestore : $e');
        return StockPickupResult.failure(
          message: 'Erreur lors de l\'enregistrement Firestore : $e',
          pickup: pickup,
          errorCode: 'FIRESTORE_ERROR',
        );
      }
    }

    // D. Mettre à jour la télémétrie RTDB du livreur :
    // - Mettre à jour deliverers_live/{livreurUid} :
    //   status: 'in_progress'
    //   isOnline: true
    //   updatedAt: DateTime.now().toIso8601String()
    // - Supprimer ou vider le noeud deliverers_live/{livreurUid}/pendingPickup.
    if (effectiveDelivererUid != null && effectiveDelivererUid.isNotEmpty) {
      final db = _database;
      if (db != null) {
        try {
          final rtdbRef = db.ref('deliverers_live/$effectiveDelivererUid');
          await rtdbRef.update({
            'status': 'in_progress',
            'isOnline': true,
            'updatedAt': DateTime.now().toIso8601String(),
            'last_serial_code': pickup.serialCode,
            'timestamp': ServerValue.timestamp,
            if (pickup.orderIds.isNotEmpty)
              'currentOrderId': pickup.orderIds.first,
          });

          // Supprimer le nœud pendingPickup
          await rtdbRef.child('pendingPickup').remove();
        } catch (e) {
          debugPrint('[StockPickupService] Note RTDB update: $e');
        }
      }

      // Activation immédiate du suivi GPS temps réel
      try {
        final locService = _customLocationService ?? DelivererLocationService();
        await locService.goOnline(
          currentOrderId:
              pickup.orderIds.isNotEmpty ? pickup.orderIds.first : null,
          vehicleInfo: DelivererLocationService.formatVehicleInfo(
            plate: pickup.vehiclePlate,
            type: pickup.vehicleType,
          ),
        );
      } catch (e) {
        debugPrint('[StockPickupService] Note start GPS live: $e');
      }
    }

    // Mise à jour de l'instance locale
    final updatedPickup = pickup.copyWith(
      status: StockPickup.statusScanned,
      scannedAt: now,
      scannedBy: effectiveDelivererUid,
    );

    // Si on est en mode test mémoire
    for (final orderId in pickup.orderIds) {
      _testOrders[orderId] = {
        'status': 'enleve',
        'isPickedUp': true,
        'pickedUpAt': now,
        'comment':
            'Colis enlevé au stock par le livreur (Scan ${pickup.serialCode})',
        'by': effectiveDelivererUid,
      };
    }
    if (effectiveDelivererUid != null) {
      _testUsers[effectiveDelivererUid] = {
        'status': 'in_progress',
        'isOnline': true,
        'lastStockPickupId': pickup.id,
        'lastStockPickupSerial': pickup.serialCode,
      };
    }

    _testPickups[updatedPickup.id] = updatedPickup;
    if (updatedPickup.serialCode.isNotEmpty) {
      _testPickups[updatedPickup.serialCode] = updatedPickup;
    }

    return StockPickupResult.success(
      message:
          'Tournée validée ! ${pickup.effectiveOrderCount} colis enlevés au stock.',
      pickup: updatedPickup,
      updatedOrdersCount: pickup.effectiveOrderCount,
    );
  }
}
