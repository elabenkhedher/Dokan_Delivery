import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livreur_app/screens/history_screen.dart';
import 'package:livreur_app/screens/home_screen.dart';
import 'package:livreur_app/screens/orders_screen.dart';
import 'package:livreur_app/screens/profile_screen.dart';
import 'package:livreur_app/screens/working_hours_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HistoryScreen renders standalone with app bar and list',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HistoryScreen(isEmbedded: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Historique'), findsOneWidget);
    expect(find.text('Commandes terminées'), findsOneWidget);
  });

  testWidgets('OrdersScreen renders standalone with app bar and list',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OrdersScreen(isEmbedded: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes commandes'), findsOneWidget);
    expect(find.text('Toutes vos commandes'), findsOneWidget);
  });

  testWidgets('WorkingHoursScreen renders standalone with app bar and list',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WorkingHoursScreen(isEmbedded: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes horaires'), findsOneWidget);
    expect(find.text('Organisez votre semaine'), findsOneWidget);
  });

  testWidgets('ProfileScreen renders standalone with app bar and logout button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(isEmbedded: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Espace livreur'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });

  testWidgets('HomeScreen renders standalone with app bar and activity stats',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(isEmbedded: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard Livreur'), findsOneWidget);
    expect(find.text('Bonjour, Livreur !'), findsOneWidget);
    expect(find.text('Votre activité'), findsOneWidget);
  });
}
