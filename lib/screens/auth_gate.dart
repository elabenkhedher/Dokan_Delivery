import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/auth/firebase_role_service.dart';
import '../core/auth/user_role.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'password_screen.dart';

enum _AuthDestination { login, passwordChange, dashboard }

/// Point d'entrée sécurisé de l'application :
/// - Vérifie en temps réel l'état d'authentification
/// - Vérifie le rôle « livreur » directement dans la collection Firestore `users`
/// - Redirige vers DashboardScreen si le rôle est valide
/// - Redirige vers LoginScreen si déconnecté ou si le rôle n'est plus livreur
class AuthGate extends StatelessWidget {
  final bool afterExplicitSignIn;

  const AuthGate({super.key, this.afterExplicitSignIn = false});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return _DelivererRoleGate(
            user: snapshot.data!,
            afterExplicitSignIn: afterExplicitSignIn,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const LoginScreen();
      },
    );
  }
}

class _DelivererRoleGate extends StatefulWidget {
  final User user;
  final bool afterExplicitSignIn;

  const _DelivererRoleGate({
    required this.user,
    required this.afterExplicitSignIn,
  });

  @override
  State<_DelivererRoleGate> createState() => _DelivererRoleGateState();
}

class _DelivererRoleGateState extends State<_DelivererRoleGate> {
  late Future<_AuthDestination> _roleCheck;

  @override
  void initState() {
    super.initState();
    _roleCheck = _verifyDeliverer();
  }

  @override
  void didUpdateWidget(covariant _DelivererRoleGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _roleCheck = _verifyDeliverer();
    }
  }

  Future<_AuthDestination> _verifyDeliverer() async {
    // Vérification du rôle « livreur » dans la collection Firestore `users`
    final roleService = FirebaseRoleService();
    final user = await roleService.restoreUserWithRole(UserRole.deliverer);
    if (user == null) {
      return _AuthDestination.login;
    }

    if (await roleService.requiresPasswordChange(user)) {
      return _AuthDestination.passwordChange;
    }

    // Initialisation des notifications FCM sans bloquer l'affichage
    try {
      await NotificationService.init();
    } catch (e) {
      debugPrint('[AuthGate] NotificationService.init() : $e');
    }

    return _AuthDestination.dashboard;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AuthDestination>(
      future: _roleCheck,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        switch (snapshot.data) {
          case _AuthDestination.dashboard:
            return const DashboardScreen();
          case _AuthDestination.passwordChange:
            return const PasswordScreen();
          case _AuthDestination.login:
            return const LoginScreen();
          case null:
            break;
        }

        // Rôle non trouvé ou révoqué dans Firestore -> Écran de connexion
        return const LoginScreen();
      },
    );
  }
}
