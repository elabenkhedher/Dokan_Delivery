import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/auth/firebase_role_service.dart';
import '../core/auth/user_role.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      // Listen to real-time authentication state changes
      stream: authService.authStateChanges,
      initialData: authService.currentUser,
      builder: (context, snapshot) {
        // If user is logged in -> verify the deliverer role first
        if (snapshot.hasData && snapshot.data != null) {
          return const _DelivererRoleGate();
        }

        // While Firebase is checking the active session
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is NOT logged in -> Go to Login
        return const LoginScreen();
      },
    );
  }
}

/// Vérifie le rôle Firestore « deliverer » pour la session restaurée.
/// Rôle absent / insuffisant → déconnexion automatique → écran de connexion.
class _DelivererRoleGate extends StatefulWidget {
  const _DelivererRoleGate();

  @override
  State<_DelivererRoleGate> createState() => _DelivererRoleGateState();
}

class _DelivererRoleGateState extends State<_DelivererRoleGate> {
  late final Future<User?> _check =
      FirebaseRoleService().restoreUserWithRole(UserRole.deliverer);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _check,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
