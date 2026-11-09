/// ============================================================
///  RÔLES APPLICATIFS — Dokan Delivery (Livreur)
///
///  Le rôle est stocké dans Firestore : collection `users`,
///  champ `role` (ex: "livreur" ou "deliverer").
/// ============================================================
enum UserRole {
  admin,
  deliverer,
  client,
  pending;

  /// Valeur standard du rôle
  String get role => name;

  /// Lit la valeur du champ `role` (ou synonyme) dans Firestore
  /// et renvoie le rôle correspondant (null si absent/inconnu).
  /// Reconnait les variantes : "livreur", "deliverer", "driver", "coursier".
  static UserRole? fromField(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim().toLowerCase();

    if (normalized == 'deliverer' ||
        normalized == 'livreur' ||
        normalized == 'driver' ||
        normalized == 'coursier') {
      return UserRole.deliverer;
    }
    if (normalized == 'admin' ||
        normalized == 'administrateur' ||
        normalized == 'manager') {
      return UserRole.admin;
    }
    if (normalized == 'client' ||
        normalized == 'acheteur' ||
        normalized == 'user' ||
        normalized == 'customer') {
      return UserRole.client;
    }

    for (final role in values) {
      if (role.role == normalized) return role;
    }
    return null;
  }
}
