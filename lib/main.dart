import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Handler de messages FCM reçus lorsque l'application est en arrière-plan
//  ou terminée. Doit être une fonction top-level (hors de toute classe).
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ré-initialiser Firebase car l'isolate background ne le connaît pas encore.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Pas besoin d'afficher une notification ici : FCM le fait automatiquement
  // grâce au payload `notification` défini dans la Cloud Function.
  debugPrint('[FCM Background] Message reçu : ${message.messageId}');
}

// ─────────────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Enregistrer le handler background APRÈS initializeApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(const LivreurApp());
}

// ─────────────────────────────────────────────────────────────────────────────
class LivreurApp extends StatelessWidget {
  final Widget? home;

  const LivreurApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dokan Delivery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Clé globale pour la navigation depuis les callbacks FCM
      navigatorKey: notificationNavigatorKey,

      home: home ?? const SplashScreen(nextScreen: AuthGate()),
    );
  }
}
