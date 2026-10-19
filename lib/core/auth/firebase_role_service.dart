import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'role_denied_exception.dart';
import 'user_role.dart';

/// ============================================================
///  SERVICE D'AUTHENTIFICATION FIREBASE + CONTRÔLE DE RÔLE
///  Réutilisable tel quel dans les 3 apps (admin, deliverer, client) :
///  seule la valeur de `requiredRole` change à l'usage.
///
///  Principe : le rôle vit dans Firestore — collection `users`,
///  document avec l'uid, champ `role` ('admin' / 'deliverer' /
///  'client' / 'pending'). L'attribution se fait à la main depuis la
///  console Firestore (l'app ne peut modifier que SON rôle initial).
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

  // ── Rôle d'un utilisateur (document Firestore users/{uid}) ────────────────
  Future<UserRole?> roleOf(User user) async {
    final doc = await _users.doc(user.uid).get();
    return UserRole.fromField(doc.data()?[roleField]);
  }

  // ── Connexion contrôlée par rôle ──────────────────────────────────────────
  /// Ouvre la session Firebase puis exige que le compte porte [requiredRole].
  /// Sinon : déconnexion immédiate + [RoleDeniedException].
  Future<UserCredential> signInWithRole({
    required String email,
    required String password,
    required UserRole requiredRole,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;

    final role = await roleOf(user);
    if (role == requiredRole) return credential;

    // Rôle absent ou insuffisant → on referme la session
    await _auth.signOut();
    throw RoleDeniedException(expected: requiredRole, actual: role);
  }

  // ── Restauration contrôlée de la session ─────────────────────────────────
  /// Vérifie l'utilisateur déjà connecté au lancement de l'app :
  /// rôle correct → utilisateur renvoyé, sinon déconnecté + `null`.
  Future<User?> restoreUserWithRole(UserRole requiredRole) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final role = await roleOf(user);
      if (role == requiredRole) return user;
    } catch (_) {
      // Vérification impossible (ex : hors-ligne) → politique fail closed
    }

    await _auth.signOut();
    return null;
  }

  // ── Création du profil Firestore (à l'inscription) ────────────────────────
  /// Crée `users/{uid}` avec un rôle initial. Choisir le rôle de départ
  /// selon l'app : `pending` ici (admin) — un compte ne peut PAS se
  /// déclarer admin lui-même, l'attribution se fait via la console
  /// Firestore. Dans l'app client : `client`, app livreur : `deliverer`.
  Future<void> createUserDoc(
    User user, {
    required UserRole initialRole,
  }) async {
    final docRef = _users.doc(user.uid);
    final existing = await docRef.get();

    // Profil déjà présent (créé à la main) → ne jamais écraser son rôle
    if (existing.exists) return;

    await docRef.set({
      roleField: initialRole.role,
      'email': user.email ?? '',
      'name': user.displayName ?? '',
    });
  }

  // ── Déconnexion ──────────────────────────────────────────────────────────
  Future<void> signOut() => _auth.signOut();
}
