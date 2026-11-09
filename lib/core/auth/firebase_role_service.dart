import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'role_denied_exception.dart';
import 'user_role.dart';

/// ============================================================
///  SERVICE D'AUTHENTIFICATION FIREBASE + VÉRIFICATION DU RÔLE
///
///  Vérifie le rôle dans la collection Firestore `users` :
///  1. Recherche du document par UID (users/{uid})
///  2. Repli par e-mail si présent
///  3. Validation stricte du champ `role` == 'livreur' / 'deliverer'
/// ============================================================
class FirebaseRoleService {
  /// Nom du champ qui porte le rôle dans le document utilisateur
  static const String roleField = 'role';

  /// Collection Firestore des profils utilisateurs
  static const String usersCollection = 'users';

  FirebaseRoleService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(usersCollection);

  // ── Recherche du document utilisateur dans Firestore ─────────────────────
  /// Trouve le document correspondant dans `users` :
  /// 1. Par UID (users/{uid}, structure officielle vérifiée par isDeliverer())
  /// 2. Par e-mail en repli si le document a été créé avec un autre identifiant
  Future<DocumentSnapshot<Map<String, dynamic>>?> getUserDoc(User user) async {
    // 1. Recherche par UID (users/{uid})
    try {
      final docByUid = await _users.doc(user.uid).get();
      if (docByUid.exists) {
        debugPrint(
          '[FirebaseRoleService] Utilisateur trouvé par UID : ${user.uid}',
        );
        return docByUid;
      }
    } catch (e) {
      debugPrint('[FirebaseRoleService] Erreur lors de la requête par UID : $e');
    }

    // 2. Recherche par e-mail en repli
    final rawEmail = user.email?.trim();
    if (rawEmail != null && rawEmail.isNotEmpty) {
      try {
        // A. Recherche par champ `email` exact
        final queryExact = await _users
            .where('email', isEqualTo: rawEmail)
            .limit(1)
            .get();
        if (queryExact.docs.isNotEmpty) {
          debugPrint(
            '[FirebaseRoleService] Utilisateur trouvé par champ email exact : ${queryExact.docs.first.id}',
          );
          return queryExact.docs.first;
        }

        // B. Recherche par champ `email` en minuscules
        final queryLower = await _users
            .where('email', isEqualTo: rawEmail.toLowerCase())
            .limit(1)
            .get();
        if (queryLower.docs.isNotEmpty) {
          debugPrint(
            '[FirebaseRoleService] Utilisateur trouvé par champ email minuscule : ${queryLower.docs.first.id}',
          );
          return queryLower.docs.first;
        }

        // C. Recherche par ID direct = email
        final docByEmailId = await _users.doc(rawEmail).get();
        if (docByEmailId.exists) {
          debugPrint(
            '[FirebaseRoleService] Utilisateur trouvé par ID = email : ${docByEmailId.id}',
          );
          return docByEmailId;
        }
      } catch (e) {
        debugPrint(
          '[FirebaseRoleService] Erreur lors de la requête par email: $e',
        );
      }
    }

    debugPrint(
      '[FirebaseRoleService] Aucun document trouvé dans "$usersCollection" pour uid="${user.uid}" / email="$rawEmail"',
    );
    return null;
  }

  // ── Rôle d'un utilisateur depuis Firestore ────────────────────────────────
  Future<UserRole?> roleOf(User user) async {
    try {
      final doc = await getUserDoc(user);
      if (doc == null || !doc.exists) {
        return null;
      }
      final data = doc.data();
      if (data == null) return null;

      // Cherche dans `role`, `statut`, ou `type`
      final rawRole = data[roleField] ?? data['statut'] ?? data['type'];
      final parsedRole = UserRole.fromField(rawRole);

      debugPrint(
        '[FirebaseRoleService] Rôle Firestore pour ${user.email} (doc: ${doc.id}) : '
        'brut="$rawRole" -> analysé=$parsedRole',
      );
      return parsedRole;
    } catch (e) {
      debugPrint('[FirebaseRoleService] Exception dans roleOf: $e');
      return null;
    }
  }

  /// Détermine si le compte nécessite un changement de mot de passe (première connexion).
  Future<bool> requiresPasswordChange(User user) async {
    try {
      // 1. Vérification dans SharedPreferences locales
      final prefs = await SharedPreferences.getInstance();
      final localChanged = prefs.getBool('first_password_changed_${user.uid}');

      // 2. Vérification dans le document Firestore
      final doc = await getUserDoc(user);
      final data = doc?.data();

      // A. Si l'admin a explicitement configuré `mustChangePassword` :
      final mustChange = data?['mustChangePassword'];
      if (mustChange == true) return true;

      // B. Si `firstPasswordChanged` est présent sur le document :
      final serverChanged = data?['firstPasswordChanged'];
      if (serverChanged == true) {
        if (localChanged != true) {
          await prefs.setBool('first_password_changed_${user.uid}', true);
        }
        return false;
      }
      if (mustChange == false && (serverChanged != false)) {
        return false;
      }
      if (serverChanged == false) {
        return true;
      }

      // C. Si le mot de passe a déjà été changé sur cet appareil :
      if (localChanged == true) {
        return false;
      }

      // D. Nouveau livreur sans indicateur existant :
      // Première connexion -> doit obligatoirement changer de mot de passe !
      return true;
    } catch (e) {
      debugPrint('[FirebaseRoleService] Erreur requiresPasswordChange: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        final localChanged =
            prefs.getBool('first_password_changed_${user.uid}') ?? false;
        return !localChanged;
      } catch (_) {
        return false;
      }
    }
  }

  /// Enregistre la validation du mot de passe (localement et dans Firestore).
  Future<void> markPasswordChanged(User user) async {
    // 1. Sauvegarde locale persistante
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('first_password_changed_${user.uid}', true);
      debugPrint(
        '[FirebaseRoleService] first_password_changed_${user.uid} enregistré en local.',
      );
    } catch (e) {
      debugPrint('[FirebaseRoleService] Erreur SharedPreferences markPasswordChanged: $e');
    }

    // 2. Sauvegarde Firestore
    try {
      final doc = await getUserDoc(user);
      final targetRef = (doc != null && doc.exists)
          ? doc.reference
          : _users.doc(user.uid);

      await targetRef.set({
        'mustChangePassword': false,
        'firstPasswordChanged': true,
        'passwordChangedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
        '[FirebaseRoleService] markPasswordChanged validé dans Firestore pour ${user.uid}',
      );
    } catch (e) {
      debugPrint('[FirebaseRoleService] Info Firestore markPasswordChanged : $e');
    }
  }

  // ── Connexion contrôlée par rôle ──────────────────────────────────────────
  /// Ouvre la session Firebase puis exige que le compte porte le rôle [requiredRole]
  /// dans la collection Firestore `users`.
  /// Si le rôle est absent ou non conforme : déconnexion immédiate + [RoleDeniedException].
  Future<UserCredential> signInWithRole({
    required String email,
    required String password,
    required UserRole requiredRole,
  }) async {
    // 1. Authentification Firebase
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;

    // 2. Vérification stricte du rôle dans Firestore
    final role = await roleOf(user);

    if (role == requiredRole) {
      debugPrint(
        '[FirebaseRoleService] Connexion réussie : rôle livreur validé pour ${user.email}',
      );
      return credential;
    }

    // 3. Rôle absent ou non autorisé -> Déconnexion immédiate
    debugPrint(
      '[FirebaseRoleService] Connexion rejetée pour ${user.email} : '
      'rôle actuel=$role, rôle requis=$requiredRole',
    );
    await _auth.signOut();
    throw RoleDeniedException(expected: requiredRole, actual: role);
  }

  // ── Restauration contrôlée de la session existante ─────────────────────────
  /// Vérifie l'utilisateur déjà connecté au lancement de l'application :
  /// Si le rôle a été supprimé ou modifié dans Firestore entre-temps,
  /// déconnecte immédiatement et renvoie `null`.
  Future<User?> restoreUserWithRole(UserRole requiredRole) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final role = await roleOf(user);
      if (role == requiredRole) {
        return user;
      }
      debugPrint(
        '[FirebaseRoleService] Session active rejetée : le rôle Firestore '
        'pour ${user.email} n\'est plus $requiredRole (actuel: $role)',
      );
    } catch (e) {
      debugPrint('[FirebaseRoleService] Erreur restoreUserWithRole: $e');
      return null;
    }

    // Le rôle a été retiré dans Firestore : déconnexion immédiate
    await _auth.signOut();
    return null;
  }

  // ── Déconnexion ──────────────────────────────────────────────────────────
  Future<void> signOut() => _auth.signOut();
}
