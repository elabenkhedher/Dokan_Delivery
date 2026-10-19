import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livreur_app/main.dart';
import 'package:livreur_app/screens/dashboard_screen.dart';

void main() {
  testWidgets('app renders login screen and splash screen correctly', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const LivreurApp());
    await tester.pumpAndSettle();

    expect(find.text('Dokan Delivery'), findsWidgets);
    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
  });

  testWidgets('dashboard navigation and order flows work correctly', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Livreur'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('Commandes terminées'), findsOneWidget);
    expect(find.text('Commande #1002'), findsOneWidget);
    expect(find.text('Commande #1001'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    expect(find.text('Toutes vos commandes'), findsOneWidget);
    expect(find.text('Commande #1001'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('Organisez votre semaine'), findsOneWidget);
    expect(find.text('Lundi'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('order-card-1003')));
    await tester.pumpAndSettle();
    expect(find.text('Commande #1003'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('accept-order')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Accepter la commande'), findsOneWidget);
    expect(find.text('Refuser la commande'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('accept-order')));
    await tester.pumpAndSettle();
    expect(find.text('Marquer comme livrée'), findsOneWidget);
    expect(find.text('Accepter la commande'), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('advance-order-status')),
    );
    await tester.tap(find.byKey(const ValueKey('advance-order-status')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Commande terminée'));
    await tester.pumpAndSettle();
    expect(find.text('Commande terminée'), findsOneWidget);
    expect(find.byKey(const ValueKey('advance-order-status')), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('Commande #1003'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-0')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Déconnexion'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Bienvenue'), findsOneWidget);
  });

  testWidgets('refused orders appear in history with a final status', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('order-card-1003')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('refuse-order')),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('refuse-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('refuse-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer le refus'));
    await tester.pumpAndSettle();
    expect(find.text('Commande refusée'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('Commandes terminées'), findsOneWidget);
    expect(find.text('Refusée'), findsOneWidget);
  });
}
