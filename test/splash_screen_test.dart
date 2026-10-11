import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livreur_app/screens/splash_screen.dart';

void main() {
  testWidgets('SplashScreen displays Soukna Delivery and navigates to next screen', (
    WidgetTester tester,
  ) async {
    const destinationKey = ValueKey('destination-screen');

    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(
          duration: Duration(milliseconds: 500),
          nextScreen: Scaffold(
            key: destinationKey,
            body: Text('Page de destination'),
          ),
        ),
      ),
    );

    // Vérifie le logo et les textes de branding
    expect(find.text('Soukna Delivery'), findsOneWidget);
    expect(find.text('Espace Livreur'), findsOneWidget);
    expect(find.text('Rapidité • Fiabilité • Sécurité'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Avance le temps pour déclencher la navigation automatique
    await tester.pumpAndSettle();

    // Vérifie l'arrivée sur la page de destination
    expect(find.byKey(destinationKey), findsOneWidget);
    expect(find.text('Page de destination'), findsOneWidget);
    expect(find.text('Soukna Delivery'), findsNothing);
  });
}
