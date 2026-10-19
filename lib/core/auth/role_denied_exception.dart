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
      return "Ce compte n'a pas encore reçu de rôle. Contactez un administrateur.";
    }
    return "Rôle « ${actual!.role} » insuffisant : cette app est réservée au rôle « ${expected.role} ».";
  }
}
