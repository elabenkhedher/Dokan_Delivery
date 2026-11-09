import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livreur_app/models/delivery_order.dart';
import 'package:livreur_app/services/order_service.dart';
import 'package:livreur_app/widgets/delivery_qr_dialog.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  testWidgets('DeliveryQrDialog displays QR code, order info and handles simulation',
      (WidgetTester tester) async {
    final order = DeliveryOrder(
      id: 'cmd-999',
      displayNumber: 'DOKAN-999',
      customerName: 'Mohamed Ben Ali',
      address: 'Avenue Habib Bourguiba, Tunis',
      phone: '+21698123456',
      total: 45.5,
      status: 'En cours',
      paymentMethod: 'Espèces',
      paymentStatus: 'pending',
    );

    final orderService = OrderService(initialOrders: [order]);

    bool? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  dialogResult = await DeliveryQrDialog.show(
                    context: context,
                    order: order,
                    orderService: orderService,
                  );
                },
                child: const Text('Open QR Dialog'),
              );
            },
          ),
        ),
      ),
    );

    // Click button to open dialog
    await tester.tap(find.text('Open QR Dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify dialog title & badge
    expect(find.text('Validation par le client'), findsOneWidget);
    expect(find.text('Scan QR Dokan'), findsOneWidget);

    // Verify customer info & order number
    expect(find.text('Mohamed Ben Ali'), findsOneWidget);
    expect(find.text('#DOKAN-999'), findsOneWidget);

    // Verify cash on delivery amount to collect
    expect(find.text('Montant à encaisser :'), findsOneWidget);
    expect(find.textContaining('45.500'), findsOneWidget);

    // Verify QR code is rendered with correct properties
    final qrFinder = find.byType(QrImageView);
    expect(qrFinder, findsOneWidget);
    final qrWidget = tester.widget<QrImageView>(qrFinder);
    expect(qrWidget.size, 200.0);
    expect(qrWidget.version, QrVersions.auto);

    // Verify fallback code label
    expect(find.text('Code de secours (oral) :'), findsOneWidget);

    // Verify explanation text & listening pulse
    expect(
      find.text('Présentez ce QR Code au client. Dès que le client le scanne, la livraison sera validée.'),
      findsOneWidget,
    );
    expect(find.text('En attente du scan client...'), findsOneWidget);

    // Verify test simulation button exists
    final simulateBtn = find.byKey(const ValueKey('delivery-qr-simulate-btn'));
    expect(simulateBtn, findsOneWidget);

    // Scroll to button and tap
    await tester.ensureVisible(simulateBtn);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(simulateBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify success view is displayed
    expect(find.text('Livraison Validée !'), findsOneWidget);
    expect(find.text('Le scan client a été confirmé avec succès.'), findsOneWidget);

    // Order should now be marked as delivered
    expect(order.isDelivered, isTrue);

    // Wait for auto-dismiss timer (1400ms)
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Dialog should have closed with true
    expect(dialogResult, isTrue);
  });

  testWidgets('DeliveryQrDialog displays online payment badge for prepaid orders',
      (WidgetTester tester) async {
    final order = DeliveryOrder(
      id: 'cmd-888',
      displayNumber: 'DOKAN-888',
      customerName: 'Sonia Trabelsi',
      address: 'Les Berges du Lac, Tunis',
      phone: '+21620123456',
      total: 82.0,
      status: 'En cours',
      paymentMethod: 'Carte Bancaire (En ligne)',
      paymentStatus: 'paid',
    );

    final orderService = OrderService(initialOrders: [order]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  DeliveryQrDialog.show(
                    context: context,
                    order: order,
                    orderService: orderService,
                  );
                },
                child: const Text('Open QR Dialog'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open QR Dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Payé en ligne :'), findsOneWidget);
    expect(find.textContaining('82.000'), findsOneWidget);

    // Close with X button
    final closeBtn = find.byTooltip('Fermer');
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Validation par le client'), findsNothing);
  });
}
