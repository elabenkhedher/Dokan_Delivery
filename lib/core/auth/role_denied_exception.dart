import 'user_role.dart';

/// ============================================================
///  EXCEPTION — COMPTE CONNECTÉ MAIS SANS LE RÔLE REQUIS
/// ============================================================
class RoleDeniedException implements Exception {
  final UserRole expected;
  final UserRole? actual;

  const RoleDeniedException({required this.expected, this.actual});

  @override
  String toString() {
    if (actual == null) {
      return "Accès refusé : ce compte n'a pas le rôle « livreur » dans la collection users de Firestore.";
    }
    return "Accès refusé : rôle « ${actual!.role} » non autorisé. Cette application est exclusivement réservée aux livreurs (rôle « livreur »).";
  }
}
