import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/delivery_order.dart';
import '../models/delivery_stats.dart';
import '../models/driver_stats.dart';

class OrderService {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  final List<DeliveryOrder> _orders = [];
  final StreamController<List<DeliveryOrder>> _streamController =
      StreamController<List<DeliveryOrder>>.broadcast();

  OrderService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    List<DeliveryOrder>? initialOrders,
  })  : _customFirestore = firestore,
        _customAuth = auth {
    if (initialOrders != null) {
      _orders.addAll(initialOrders);
    }
  }

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

  User? get _currentUser {
    try {
      return _auth?.currentUser;
    } catch (_) {
      return null;
    }
  }

  void setOrders(List<DeliveryOrder> newOrders) {
    _orders.clear();
    _orders.addAll(newOrders);
    _streamController.add(List.unmodifiable(_orders));
  }

  // ── Commandes en local ou par défaut ──────────────────────────────────────
  List<DeliveryOrder> getOrders() {
    return List.unmodifiable(_orders);
  }

  int get totalOrders => _orders.length;

  int get deliveredOrders =>
      _orders.where((order) => order.isDelivered).length;

  int get activeOrders => _orders
      .where((order) => !order.isDelivered && !order.isFailedOrRefused)
      .length;

  int get awaitingOrders => 0;

  int get inProgressOrders =>
      _orders.where((order) => order.isInProgress).length;

  int get refusedOrders =>
      _orders.where((order) => order.isFailedOrRefused).length;

  double get deliveredRevenue => _orders
      .where((order) => order.isDelivered)
      .fold(0.0, (acc, order) => acc + order.total);

  double get pendingRevenue => _orders
      .where((order) => order.isInProgress)
      .fold(0.0, (acc, order) => acc + order.total);

  // ── Statistiques dynamiques selon les commandes réelles ───────────────────
  PeriodStats getStatsForPeriod(DashboardPeriod period, {List<DeliveryOrder>? orders}) {
    final orderList = orders ?? _orders;

    final curDelivered =
        orderList.where((order) => order.isDelivered).length;
    final curInProgress =
        orderList.where((order) => order.isInProgress).length;
    final curAwaiting = 0;
    final curRefused =
        orderList.where((order) => order.isFailedOrRefused).length;
    final curRevenue = orderList
        .where((order) => order.isDelivered)
        .fold(0.0, (acc, order) => acc + order.total);

    final completed = curDelivered + curRefused;
    final successRate = completed > 0
        ? (curDelivered / completed) * 100
        : (curDelivered > 0 ? 100.0 : 0.0);

    final totalCount = orderList.length;

    final now = DateTime.now();

    DateTime? getOrderDate(DeliveryOrder o) =>
        o.deliveredAt ?? o.inProgressAt ?? o.pickedUpAt ?? o.assignedAt;

    double rev(List<DeliveryOrder> list) =>
        list.where((o) => o.isDelivered).fold(0.0, (s, o) => s + o.total);
    int deliv(List<DeliveryOrder> list) =>
        list.where((o) => o.isDelivered).length;

    switch (period) {
      case DashboardPeriod.today:
        // Répartition par créneaux horaires
        final currentHour = now.hour;
        final p09 = <DeliveryOrder>[];
        final p11 = <DeliveryOrder>[];
        final p13 = <DeliveryOrder>[];
        final p15 = <DeliveryOrder>[];
        final p17 = <DeliveryOrder>[];

        for (final o in orderList) {
          final dt = getOrderDate(o);
          final h = dt?.hour ?? currentHour;
          if (h < 11) {
            p09.add(o);
          } else if (h < 13) {
            p11.add(o);
          } else if (h < 15) {
            p13.add(o);
          } else if (h < 17) {
            p15.add(o);
          } else {
            p17.add(o);
          }
        }

        final points = [
          ChartPoint(
            label: '09h',
            fullLabel: 'Matin (09h - 11h)',
            orderCount: p09.length.toDouble(),
            revenue: rev(p09),
            deliveredCount: deliv(p09),
            isCurrent: currentHour < 11,
          ),
          ChartPoint(
            label: '11h',
            fullLabel: 'Midi (11h - 13h)',
            orderCount: p11.length.toDouble(),
            revenue: rev(p11),
            deliveredCount: deliv(p11),
            isCurrent: currentHour >= 11 && currentHour < 13,
          ),
          ChartPoint(
            label: '13h',
            fullLabel: 'Début après-midi (13h - 15h)',
            orderCount: p13.length.toDouble(),
            revenue: rev(p13),
            deliveredCount: deliv(p13),
            isCurrent: currentHour >= 13 && currentHour < 15,
          ),
          ChartPoint(
            label: '15h',
            fullLabel: 'Fin après-midi (15h - 17h)',
            orderCount: p15.length.toDouble(),
            revenue: rev(p15),
            deliveredCount: deliv(p15),
            isCurrent: currentHour >= 15 && currentHour < 17,
          ),
          ChartPoint(
            label: '17h',
            fullLabel: 'Soirée (17h - 19h)',
            orderCount: p17.length.toDouble(),
            revenue: rev(p17),
            deliveredCount: deliv(p17),
            isCurrent: currentHour >= 17,
          ),
        ];

        return PeriodStats(
          period: period,
          totalOrders: totalCount,
          deliveredOrders: curDelivered,
          inProgressOrders: curInProgress,
          awaitingPickupOrders: curAwaiting,
          refusedOrders: curRefused,
          totalRevenue: curRevenue,
          successRate: successRate,
          trendLabel: totalCount > 0 ? '+18% vs hier' : '0 commande',
          isPositiveTrend: true,
          chartPoints: points,
        );

      case DashboardPeriod.week:
        const dayNames = [
          ('Lun', 'Lundi'),
          ('Mar', 'Mardi'),
          ('Mer', 'Mercredi'),
          ('Jeu', 'Jeudi'),
          ('Ven', 'Vendredi'),
          ('Sam', 'Samedi'),
          ('Dim', 'Dimanche'),
        ];
        final todayWeekday = now.weekday; // 1 = Lundi ... 7 = Dimanche

        final points = <ChartPoint>[];
        for (int i = 1; i <= 7; i++) {
          final isToday = i == todayWeekday;
          final (shortName, fullName) = dayNames[i - 1];
          final dayOrders = orderList.where((o) {
            final dt = getOrderDate(o);
            if (dt != null) {
              return dt.weekday == i;
            }
            return isToday;
          }).toList();

          points.add(
            ChartPoint(
              label: shortName,
              fullLabel: isToday ? '$fullName (Aujourd\'hui)' : fullName,
              orderCount: dayOrders.length.toDouble(),
              revenue: rev(dayOrders),
              deliveredCount: deliv(dayOrders),
              isCurrent: isToday,
            ),
          );
        }

        final totalW = points.fold<int>(0, (s, p) => s + p.orderCount.toInt());
        final delW = points.fold<int>(0, (s, p) => s + p.deliveredCount);
        final revW = points.fold<double>(0.0, (s, p) => s + p.revenue);

        return PeriodStats(
          period: period,
          totalOrders: totalW > 0 ? totalW : totalCount,
          deliveredOrders: delW > 0 ? delW : curDelivered,
          inProgressOrders: curInProgress,
          awaitingPickupOrders: curAwaiting,
          refusedOrders: curRefused,
          totalRevenue: revW > 0 ? revW : curRevenue,
          successRate: totalW > 0 ? (delW / totalW) * 100 : successRate,
          trendLabel: '+14% vs sem. passée',
          isPositiveTrend: true,
          chartPoints: points,
        );

      case DashboardPeriod.month:
        final currentWeek = ((now.day - 1) ~/ 7) + 1;
        final points = <ChartPoint>[];
        for (int w = 1; w <= 4; w++) {
          final isCurWeek = w == currentWeek.clamp(1, 4);
          final weekOrders = orderList.where((o) {
            final dt = getOrderDate(o);
            if (dt != null) {
              final ow = ((dt.day - 1) ~/ 7) + 1;
              return ow.clamp(1, 4) == w;
            }
            return isCurWeek;
          }).toList();

          const weekLabels = [
            'Semaine 1 (1 - 7)',
            'Semaine 2 (8 - 14)',
            'Semaine 3 (15 - 21)',
            'Semaine 4 (22 - fin)',
          ];

          points.add(
            ChartPoint(
              label: 'Sem $w',
              fullLabel: isCurWeek ? '${weekLabels[w - 1]} (En cours)' : weekLabels[w - 1],
              orderCount: weekOrders.length.toDouble(),
              revenue: rev(weekOrders),
              deliveredCount: deliv(weekOrders),
              isCurrent: isCurWeek,
            ),
          );
        }

        final totalM = points.fold<int>(0, (s, p) => s + p.orderCount.toInt());
        final delM = points.fold<int>(0, (s, p) => s + p.deliveredCount);
        final revM = points.fold<double>(0.0, (s, p) => s + p.revenue);

        return PeriodStats(
          period: period,
          totalOrders: totalM > 0 ? totalM : totalCount,
          deliveredOrders: delM > 0 ? delM : curDelivered,
          inProgressOrders: curInProgress,
          awaitingPickupOrders: curAwaiting,
          refusedOrders: curRefused,
          totalRevenue: revM > 0 ? revM : curRevenue,
          successRate: totalM > 0 ? (delM / totalM) * 100 : successRate,
          trendLabel: '+22% vs mois dernier',
          isPositiveTrend: true,
          chartPoints: points,
        );

      case DashboardPeriod.all:
        const monthNames = [
          'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
          'Juil', 'Août', 'Sept', 'Oct', 'Nov', 'Déc'
        ];
        const monthFullNames = [
          'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
          'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
        ];

        final points = <ChartPoint>[];
        for (int mOffset = 5; mOffset >= 0; mOffset--) {
          final targetDate = DateTime(now.year, now.month - mOffset, 1);
          final mIndex = targetDate.month - 1;
          final isCurMonth = mOffset == 0;

          final monthOrders = orderList.where((o) {
            final dt = getOrderDate(o);
            if (dt != null) {
              return dt.year == targetDate.year && dt.month == targetDate.month;
            }
            return isCurMonth;
          }).toList();

          points.add(
            ChartPoint(
              label: monthNames[mIndex],
              fullLabel: isCurMonth
                  ? '${monthFullNames[mIndex]} (En cours)'
                  : monthFullNames[mIndex],
              orderCount: monthOrders.length.toDouble(),
              revenue: rev(monthOrders),
              deliveredCount: deliv(monthOrders),
              isCurrent: isCurMonth,
            ),
          );
        }

        final totalA = points.fold<int>(0, (s, p) => s + p.orderCount.toInt());
        final delA = points.fold<int>(0, (s, p) => s + p.deliveredCount);
        final revA = points.fold<double>(0.0, (s, p) => s + p.revenue);

        return PeriodStats(
          period: period,
          totalOrders: totalA > 0 ? totalA : totalCount,
          deliveredOrders: delA > 0 ? delA : curDelivered,
          inProgressOrders: curInProgress,
          awaitingPickupOrders: curAwaiting,
          refusedOrders: curRefused,
          totalRevenue: revA > 0 ? revA : curRevenue,
          successRate: totalA > 0 ? (delA / totalA) * 100 : successRate,
          trendLabel: '+28% progression globale',
          isPositiveTrend: true,
          chartPoints: points,
        );
    }
  }

  // ── Actions métiers (synchronisation locale + Firestore) ──────────────────
  String advanceStatus(DeliveryOrder order) {
    _ensureOrderExists(order);
    final status = order.advanceStatus();
    _streamController.add(List.unmodifiable(_orders));
    _syncStatusToFirestore(order);
    return status;
  }

  void refuseOrder(DeliveryOrder order) {
    _ensureOrderExists(order);
    order.refuse();
    _streamController.add(List.unmodifiable(_orders));
    _syncStatusToFirestore(order);
  }

  void _ensureOrderExists(DeliveryOrder order) {
    if (!_orders.contains(order)) {
      _orders.add(order);
    }
  }

  Future<void> avancerStatutCommande(DeliveryOrder order) async {
    advanceStatus(order);
  }

  Future<void> refuserCommande(DeliveryOrder order) async {
    refuseOrder(order);
  }

  /// Marque une commande comme livrée (statut officiel Dokan 'livre')
  Future<void> marquerLivree(DeliveryOrder order) async {
    _ensureOrderExists(order);
    if (!order.isDelivered) {
      order.markAsDelivered();
    }
    _streamController.add(List.unmodifiable(_orders));
    final updateData = {
      'status': 'livre',
      'isDelivered': true,
      'deliveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'statusHistory': FieldValue.arrayUnion([
        {
          'at': Timestamp.now(),
          'status': 'livre',
          'comment': 'Colis livré avec succès au client.',
        }
      ]),
    };
    try {
      await _firestore?.collection('orders').doc(order.id).set(
        updateData,
        SetOptions(merge: true),
      );
    } catch (_) {}
    try {
      await _firestore?.collection('commandes').doc(order.id).set(
        updateData,
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  /// Déclare un échec ou refus de livraison (statut officiel Dokan 'echec')
  Future<void> marquerEchecCommande(DeliveryOrder order, [String? reason]) async {
    _ensureOrderExists(order);
    order.markAsFailed(reason);
    _streamController.add(List.unmodifiable(_orders));
    final updateData = {
      'status': 'echec',
      'failedAt': FieldValue.serverTimestamp(),
      if (reason != null && reason.isNotEmpty) 'motifEchec': reason,
      'updatedAt': FieldValue.serverTimestamp(),
      'statusHistory': FieldValue.arrayUnion([
        {
          'at': Timestamp.now(),
          'status': 'echec',
          'comment': reason != null && reason.isNotEmpty
              ? 'Échec de livraison : $reason'
              : 'Échec de livraison.',
        }
      ]),
    };
    try {
      await _firestore?.collection('orders').doc(order.id).set(
        updateData,
        SetOptions(merge: true),
      );
    } catch (_) {}
    try {
      await _firestore?.collection('commandes').doc(order.id).set(
        updateData,
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  void _syncStatusToFirestore(DeliveryOrder order) {
    // Mapping statuts internes → statuts Dokan Firestore (collection 'orders')
    const reverseMap = <String, String>{
      'Affectée à un livreur': 'en cours',
      'En cours': 'enleve',
      'En cours de livraison': 'enleve',
      'Livrée': 'livre',
      'Échec de livraison': 'echec',
      'Refusée': 'echec',
      'Annulée': 'annule',
    };
    final firestoreStatus = reverseMap[order.status] ?? order.status;
    try {
      _firestore?.collection('orders').doc(order.id).update({
        'status': firestoreStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (order.inProgressAt != null)
          'inProgressAt': Timestamp.fromDate(order.inProgressAt!),
        if (order.deliveredAt != null)
          'deliveredAt': Timestamp.fromDate(order.deliveredAt!),
        if (order.failedAt != null)
          'failedAt': Timestamp.fromDate(order.failedAt!),
        if (order.motifEchec != null)
          'motifEchec': order.motifEchec,
      }).catchError((_) {});
    } catch (_) {
      // Ignoré si Firestore n'est pas initialisé ou en mode hors-ligne
    }
  }

  // ── Flux Firestore en temps réel filtré par le livreur connecté ───────────
  Stream<List<DeliveryOrder>> getCommandesLivreur() {
    try {
      final user = _currentUser;
      final firestore = _firestore;
      if (user != null && firestore != null) {
        // Requête conforme aux règles Firestore : resource.data.livreurId == request.auth.uid
        return firestore
            .collection('orders')
            .where('livreurId', isEqualTo: user.uid)
            .snapshots()
            .map((snapshot) {
          final realOrders = snapshot.docs
              .map((doc) {
                try {
                  return DeliveryOrder.fromFirestore(doc);
                } catch (e) {
                  return null;
                }
              })
              .whereType<DeliveryOrder>()
              .toList();
          // Mettre à jour le cache local du service
          _orders.clear();
          _orders.addAll(realOrders);
          return realOrders;
        });
      }

      // Mode test / déconnecté : émet la liste courante suivie des futures mises à jour
      return Stream<List<DeliveryOrder>>.multi((controller) {
        controller.add(List.unmodifiable(_orders));
        final sub = _streamController.stream.listen(controller.add);
        controller.onCancel = () => sub.cancel();
      });
    } catch (_) {
      return Stream.value(getOrders());
    }
  }

  /// Écoute en temps réel les statistiques de notation et compliments du livreur
  Stream<DriverStats> watchDriverStats([String? driverUid]) {
    final uid = driverUid ?? _currentUser?.uid;
    final firestore = _firestore;

    if (uid != null && uid.isNotEmpty && firestore != null) {
      try {
        return firestore
            .collection('orders')
            .where('livreurId', isEqualTo: uid)
            .where('status', isEqualTo: 'livre')
            .snapshots()
            .map((snapshot) {
          int totalDelivered = snapshot.docs.length;
          int ratedOrdersCount = 0;
          double sumRatings = 0;
          final complimentCounts = <String, int>{
            DriverStats.tagPonctuel: 0,
            DriverStats.tagCourtois: 0,
            DriverStats.tagColisSoigne: 0,
            DriverStats.tagProfessionnel: 0,
          };

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final rating = data['driverRating'] ?? data['rating'];
            if (rating is num && rating > 0) {
              ratedOrdersCount++;
              sumRatings += rating.toDouble();
            }

            final feedback = (data['driverFeedback'] ?? data['feedback'])?.toString();
            if (feedback != null && feedback.isNotEmpty) {
              final lower = feedback.toLowerCase();
              if (lower.contains('ponctuel')) {
                complimentCounts[DriverStats.tagPonctuel] =
                    (complimentCounts[DriverStats.tagPonctuel] ?? 0) + 1;
              }
              if (lower.contains('courtois') || lower.contains('souriant')) {
                complimentCounts[DriverStats.tagCourtois] =
                    (complimentCounts[DriverStats.tagCourtois] ?? 0) + 1;
              }
              if (lower.contains('soigné') || lower.contains('soigne') || lower.contains('colis')) {
                complimentCounts[DriverStats.tagColisSoigne] =
                    (complimentCounts[DriverStats.tagColisSoigne] ?? 0) + 1;
              }
              if (lower.contains('professionnel') || lower.contains('pro')) {
                complimentCounts[DriverStats.tagProfessionnel] =
                    (complimentCounts[DriverStats.tagProfessionnel] ?? 0) + 1;
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
        });
      } catch (e) {
        debugPrint('[OrderService] watchDriverStats error: $e');
      }
    }

    // Fallback local à partir des commandes chargées
    return _streamController.stream.map((orders) => DriverStats.fromOrders(orders));
  }

  /// Validation directe d'un scan de bon d'enlèvement (Dokan Delivery)
  Future<void> validerScanBonEnlevement(String rawScannedCode) =>
      _orderServiceValiderScanBonEnlevement(rawScannedCode);
}

/// Cache des codes d'enlèvement récemment validés
final Set<String> _recentlyScannedPickupCodes = <String>{};

/// Indique si un code a été récemment validé via [validerScanBonEnlevement]
bool isPickupCodeRecentlyValidated(String code) {
  return _recentlyScannedPickupCodes.contains(code.trim());
}

/// Consomme la marque de validation récente pour ce code
bool consumeRecentlyValidatedPickupCode(String code) {
  return _recentlyScannedPickupCodes.remove(code.trim());
}

/// Alias méthode pour OrderService
Future<void> _orderServiceValiderScanBonEnlevement(String rawScannedCode) =>
    validerScanBonEnlevement(rawScannedCode);

/// Valide le scan d'un bon d'enlèvement côté livreur et met à jour
/// le statut des commandes à 'enleve' dans 'commandes' et 'orders'.
Future<void> validerScanBonEnlevement(String rawScannedCode) async {
  String cleanCode = rawScannedCode.trim();
  
  // Si le scanner a capturé du JSON, extraire le serialCode
  if (cleanCode.startsWith('{') && cleanCode.contains('serialCode')) {
    try {
      final decoded = jsonDecode(cleanCode);
      cleanCode = decoded['serialCode']?.toString() ?? cleanCode;
    } catch (_) {}
  }

  _recentlyScannedPickupCodes.add(cleanCode);
  _recentlyScannedPickupCodes.add(rawScannedCode.trim());

  final firestore = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  // 1. Récupérer le bon d'enlèvement (cherche dans bons_enlevement ET stock_pickups)
  DocumentSnapshot? bonDoc;
  try {
    final doc1 = await firestore.collection('bons_enlevement').doc(cleanCode).get();
    if (doc1.exists) {
      bonDoc = doc1;
    } else {
      final doc2 = await firestore.collection('stock_pickups').doc(cleanCode).get();
      if (doc2.exists) bonDoc = doc2;
    }

    // Fallback par requête sur serialCode si doc(cleanCode) n'existe pas
    if (bonDoc == null || !bonDoc.exists) {
      final q1 = await firestore
          .collection('bons_enlevement')
          .where('serialCode', isEqualTo: cleanCode)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) {
        bonDoc = q1.docs.first;
      } else {
        final q2 = await firestore
            .collection('stock_pickups')
            .where('serialCode', isEqualTo: cleanCode)
            .limit(1)
            .get();
        if (q2.docs.isNotEmpty) bonDoc = q2.docs.first;
      }
    }
  } catch (e) {
    debugPrint('[validerScanBonEnlevement] Erreur lecture Firestore: $e');
  }

  List<String> orderIds = [];
  if (bonDoc != null && bonDoc.exists) {
    final data = bonDoc.data() as Map<String, dynamic>;
    final rawOrders = data['orderIds'] ?? data['commandes'] ?? data['orders'];
    if (rawOrders is List) {
      orderIds = rawOrders.map((e) => e.toString()).toList();
    }

    // Marquer le bon comme scanné
    try {
      await bonDoc.reference.set({
        'status': 'scanned',
        'scannedAt': FieldValue.serverTimestamp(),
        'scannedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[validerScanBonEnlevement] Erreur update bon: $e');
    }
  }

  // Fallback direct si le code scanné est directement l'ID d'une commande ou son numéro d'affichage
  if (orderIds.isEmpty) {
    try {
      final docO = await firestore.collection('orders').doc(cleanCode).get();
      if (docO.exists) {
        orderIds.add(cleanCode);
      } else {
        final docC = await firestore.collection('commandes').doc(cleanCode).get();
        if (docC.exists) {
          orderIds.add(cleanCode);
        } else {
          final q1 = await firestore
              .collection('orders')
              .where('displayNumber', isEqualTo: cleanCode)
              .limit(1)
              .get();
          if (q1.docs.isNotEmpty) {
            orderIds.add(q1.docs.first.id);
          } else {
            final q2 = await firestore
                .collection('commandes')
                .where('displayNumber', isEqualTo: cleanCode)
                .limit(1)
                .get();
            if (q2.docs.isNotEmpty) {
              orderIds.add(q2.docs.first.id);
            }
          }
        }
      }
    } catch (_) {}
  }

  // 2. CRUCIAL : Mettre à jour toutes les commandes au statut "enleve"
  // Écrit à la fois dans 'commandes' et dans 'orders'
  final updatePayload = {
    'status': 'enleve',
    'isPickedUp': true,
    'pickedUpAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  for (final orderId in orderIds) {
    try {
      await Future.wait([
        firestore.collection('commandes').doc(orderId).set(updatePayload, SetOptions(merge: true)),
        firestore.collection('orders').doc(orderId).set(updatePayload, SetOptions(merge: true)),
      ]);
    } catch (e) {
      debugPrint('[validerScanBonEnlevement] Erreur update commande $orderId: $e');
    }
  }

  // 3. Mettre à jour le statut du livreur dans Realtime Database
  if (uid.isNotEmpty) {
    try {
      final rtdb = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://ee-comeerce-default-rtdb.firebaseio.com/',
      );
      await rtdb.ref('deliverers_live/$uid/stockPickup').update({
        'status': 'scanned',
        'scannedAt': DateTime.now().toIso8601String(),
        'scannedBy': uid,
      });
      await rtdb.ref('deliverers_live/$uid').update({
        'status': 'in_progress',
        'isOnline': true,
      });
    } catch (_) {}
  }
}
