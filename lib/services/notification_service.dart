import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/auth/firebase_role_service.dart';
import '../models/delivery_order.dart';
import '../screens/order_details_screen.dart';
import '../utils/page_transitions.dart';
import 'order_service.dart';
import 'working_hours_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NotificationService
//  Gère les permissions FCM, le token, les notifications locales et la
//  navigation vers OrderDetailsScreen lors d'un tap sur une notification.
// ─────────────────────────────────────────────────────────────────────────────

/// Clé globale du navigateur, requise pour naviguer depuis un callback FCM
/// qui s'exécute en dehors de l'arbre Widget.
/// À injecter dans MaterialApp.navigatorKey.
final GlobalKey<NavigatorState> notificationNavigatorKey =
    GlobalKey<NavigatorState>();

class NotificationService {
  NotificationService._();

  // ── Instances ──────────────────────────────────────────────────────────────
  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static Future<void>? _initialization;

  /// Canal Android — doit correspondre à channelId dans la Cloud Function.
  static const _androidChannel = AndroidNotificationChannel(
    'nouvelles_commandes',
    'Nouvelles commandes',
    description: 'Alertes pour les nouvelles commandes assignées au livreur.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  // ── Point d'entrée unique ──────────────────────────────────────────────────
  /// Appeler une seule fois, juste après que le rôle livreur est validé.
  static Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) return;
    } catch (_) {
      return;
    }

    try {
      final initialization = _initialization ??= _initialize();
      await initialization;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _saveToken(await _messaging.getToken(), uid: user.uid);
    } catch (e) {
      debugPrint('[NotificationService] Erreur init : $e');
    }
  }

  static Future<void> _initialize() async {
    final notifPermission = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
      '[NotificationService] Statut permission FCM : ${notifPermission.authorizationStatus}',
    );

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(_androidChannel);
    await androidImpl?.requestNotificationsPermission();

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    final initial = await _messaging.getInitialMessage();

    _messaging.onTokenRefresh.listen((newToken) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) _saveToken(newToken, uid: uid);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    if (initial != null) _handleMessageTap(initial);

    debugPrint('[NotificationService] Initialisé avec succès.');
  }

  // ── Nettoyage à la déconnexion ─────────────────────────────────────────────
  /// Retirer le token FCM du compte pour que l'ancien téléphone ne reçoive
  /// plus les alertes de ce livreur.
  static Future<void> removeToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await _messaging.getToken();
      if (token == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'fcmTokens': FieldValue.arrayRemove([token]),
          }, SetOptions(merge: true));

      debugPrint('[NotificationService] Token retiré pour ${user.uid}.');
    } catch (e) {
      debugPrint('[NotificationService] Erreur removeToken : $e');
    }
  }

  // ── Helpers privés ─────────────────────────────────────────────────────────

  /// Enregistre (ou rafraîchit) le token FCM dans Firestore.
  static Future<void> _saveToken(String? token, {required String uid}) async {
    if (token == null || token.isEmpty) return;
    try {
      // 1. Enregistrement direct sur users/{uid} avec merge pour éviter toute erreur si non existant
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));

      // 2. Si le compte dans Firestore est indexé sous un autre ID (ex: email ou doc auto)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final doc = await FirebaseRoleService().getUserDoc(currentUser);
        if (doc != null && doc.id != uid) {
          await doc.reference.set({
            'fcmTokens': FieldValue.arrayUnion([token]),
          }, SetOptions(merge: true));
        }
      }

      debugPrint('[NotificationService] Token FCM enregistré avec succès pour $uid : $token');
    } catch (e) {
      debugPrint('[NotificationService] Erreur _saveToken : $e');
    }
  }

  /// Affiche une notification locale quand l'app est au premier plan.
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ??
        message.data['title'] ??
        'Nouvelle commande reçue !';
    final body = notification?.body ??
        message.data['body'] ??
        message.data['message'] ??
        'Une nouvelle livraison a été assignée à votre tournée.';
    final orderId = message.data['orderId'];

    await showLocalNotification(
      title: title,
      body: body,
      orderId: orderId,
    );
  }

  /// Méthode publique pour afficher directement une notification locale
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? orderId,
  }) async {
    try {
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
        payload: orderId,
      );
      debugPrint('[NotificationService] Notification affichée : $title - $body');
    } catch (e) {
      debugPrint('[NotificationService] Affichage local impossible : $e');
    }
  }

  /// Tap sur la notification locale (app premier plan).
  static void _onLocalNotificationTap(NotificationResponse response) {
    final orderId = response.payload;
    if (orderId != null && orderId.isNotEmpty) {
      _navigateToOrder(orderId);
    }
  }

  /// Tap sur une notification FCM (background / terminated).
  static void _handleMessageTap(RemoteMessage message) {
    final orderId = message.data['orderId'];
    if (orderId != null && orderId.isNotEmpty) {
      _navigateToOrder(orderId);
    }
  }

  /// Charge la commande depuis Firestore puis ouvre OrderDetailsScreen
  /// via le navigateur global.
  static void _navigateToOrder(String orderId) {
    // Attendre que le widget tree soit prêt (cas app lancée par la notif).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .get();
        if (!doc.exists) {
          debugPrint('[NotificationService] Commande $orderId introuvable.');
          return;
        }

        final order = DeliveryOrder.fromFirestore(doc);
        final workingHours = WorkingHoursService();
        try {
          await workingHours.load();
        } catch (e) {
          debugPrint(
            '[NotificationService] Chargement des horaires échoué : $e',
          );
        }

        final navigator = notificationNavigatorKey.currentState;
        if (navigator == null) {
          debugPrint(
            '[NotificationService] Navigateur indisponible pour $orderId.',
          );
          return;
        }
        navigator.push(
          SlideFadePageRoute(
            page: OrderDetailsScreen(
              order: order,
              orderService: OrderService(),
              workingHoursService: workingHours,
            ),
          ),
        );
      } catch (e) {
        debugPrint('[NotificationService] Erreur navigation : $e');
      }
    });
  }
}
