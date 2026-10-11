import 'package:flutter_test/flutter_test.dart';
import 'package:livreur_app/services/order_service.dart';

void main() {
  test('order status advances one way and cannot change after delivery', () {
    final orderService = OrderService();
    final order = orderService.getOrders().singleWhere(
      (order) => order.id == '1003',
    );

    expect(order.status, 'À récupérer');
    expect(orderService.advanceStatus(order), 'En cours');
    expect(order.status, 'En cours');

    expect(orderService.advanceStatus(order), 'Livrée');
    expect(order.status, 'Livrée');
    expect(() => orderService.advanceStatus(order), throwsStateError);
    expect(order.status, 'Livrée');
  });

  test('refused orders are final and excluded from active orders', () {
    final orderService = OrderService();
    final order = orderService.getOrders().singleWhere(
      (order) => order.id == '1003',
    );

    orderService.refuseOrder(order);

    expect(order.status, 'Refusée');
    expect(orderService.activeOrders, 2);
    expect(() => orderService.refuseOrder(order), throwsStateError);
    expect(() => orderService.advanceStatus(order), throwsStateError);
    expect(order.status, 'Refusée');
  });
}
