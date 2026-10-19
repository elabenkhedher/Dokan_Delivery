/// ============================================================
///  RÔLES APPLICATIFS — PARTAGÉ PAR LES 3 APPS
///  (admin : cette app · deliverer : app livreur · client : app client)
///
///  Le rôle est stocké dans Firestore : collection `users`, document
///  avec l'uid Firebase, champ `role` (voir docs/firebase_roles.md).
///  La valeur du champ correspond exactement au nom de l'enum.
/// ============================================================
enum UserRole {
  admin,
  deliverer,
  client,
  pending; // compte créé sans rôle, en attente d'attribution manuelle

  /// Valeur du champ `role` dans Firestore
  String get role => name;

  /// Lit la valeur du champ `role` et renvoie le rôle correspondant
  /// (null si absent/inconnu).
  static UserRole? fromField(Object? value) {
    if (value is! String) return null;
    for (final role in values) {
      if (role.role == value) return role;
    }
    return null;
  }
}
