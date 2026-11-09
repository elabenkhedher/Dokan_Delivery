import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class AuthService {
  final FirebaseAuth? _customAuth;

  AuthService({FirebaseAuth? auth}) : _customAuth = auth;

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  // ── Stream to listen to real-time auth changes ─────────────────────────────
  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return Stream.value(currentUser);
    }
  }

  // ── Get currently logged-in user ──────────────────────────────────────────
  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  // ── 1. Sign Up (Email & Password) ──────────────────────────────────────────
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ── 2. Sign In (Email & Password) ──────────────────────────────────────────
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ── 3. Password Reset ──────────────────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ── 4. Sign Out ────────────────────────────────────────────────────────────
  /// Retire d'abord le token FCM de Firestore pour que l'ancien téléphone
  /// ne reçoive plus les alertes, puis déconnecte l'utilisateur.
  Future<void> signOut() async {
    try {
      // Retirer le token FCM avant la déconnexion (uid encore disponible)
      await NotificationService.removeToken();
    } catch (_) {
      // Ne jamais bloquer la déconnexion si les notifs échouent
    }
    try {
      await _auth.signOut();
    } catch (_) {}
  }
}
