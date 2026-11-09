import 'package:flutter_test/flutter_test.dart';
import 'package:livreur_app/controllers/navigation_controller.dart';
import 'package:livreur_app/models/delivery_order.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NavigationController Tour Management', () {
    final order1 = DeliveryOrder(
      id: 'order-1',
      displayNumber: 'DOKAN-101',
      customerName: 'Sami Karray',
      address: 'Centre Urbain Nord, Tunis',
      phone: '+21698000001',
      total: 35.0,
      status: DeliveryOrder.inProgress,
      latitude: 36.8400,
      longitude: 10.1900,
    );

    final order2 = DeliveryOrder(
      id: 'order-2',
      displayNumber: 'DOKAN-102',
      customerName: 'Fatma Dridi',
      address: 'Ennasr 2, Ariana',
      phone: '+21698000002',
      total: 54.0,
      status: DeliveryOrder.inProgress,
      latitude: 36.8600,
      longitude: 10.1600,
    );

    test('Initializes with multiple tour orders and picks first pending order', () async {
      final controller = NavigationController();
      await controller.initialize(
        tourOrders: [order1, order2],
      );

      expect(controller.tourOrders.length, 2);
      expect(controller.order.id, 'order-1');
      expect(controller.currentOrderIndex, 0);
      expect(controller.remainingTourOrdersCount, 2);
      expect(controller.destination.latitude, 36.8400);
      expect(controller.destination.longitude, 10.1900);
    });

    test('selectOrder switches destination and active target', () async {
      final controller = NavigationController();
      await controller.initialize(
        tourOrders: [order1, order2],
      );

      await controller.selectOrder(order2);

      expect(controller.order.id, 'order-2');
      expect(controller.currentOrderIndex, 1);
      expect(controller.destination.latitude, 36.8600);
      expect(controller.destination.longitude, 10.1600);
    });

    test('completeDelivery advances to the next remaining pending order', () async {
      final controller = NavigationController();
      await controller.initialize(
        tourOrders: [order1, order2],
      );

      expect(controller.order.id, 'order-1');
      expect(controller.remainingTourOrdersCount, 2);

      // Complete first order
      await controller.completeDelivery();

      expect(controller.tourOrders[0].isDelivered, isTrue);
      expect(controller.remainingTourOrdersCount, 1);
      // Automatically switches to order-2
      expect(controller.order.id, 'order-2');
      expect(controller.currentOrderIndex, 1);
    });
  });
}
