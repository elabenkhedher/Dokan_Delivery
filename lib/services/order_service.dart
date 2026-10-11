
import '../models/delivery_order.dart';

class OrderService {
  final List<DeliveryOrder> _orders = [
    DeliveryOrder(
      id: '1001',
      customerName: 'Ahmed Ben Ali',
      address: 'Tunis Centre',
      phone: '20000001',
      total: 85.500,
      status: 'En cours',
    ),
    DeliveryOrder(
      id: '1002',
      customerName: 'Sarra Mansouri',
      address: 'La Marsa',
      phone: '20000002',
      total: 42.000,
      status: 'Livrée',
    ),
    DeliveryOrder(
      id: '1003',
      customerName: 'Mohamed Trabelsi',
      address: 'Ariana',
      phone: '20000003',
      total: 120.000,
      status: 'À récupérer',
    ),
    DeliveryOrder(
      id: '1004',
      customerName: 'Amira Gharbi',
      address: 'Nabeul',
      phone: '20000004',
      total: 63.000,
      status: 'En cours',
    ),
  ];

  List<DeliveryOrder> getOrders() {
    return List.unmodifiable(_orders);
  }

  int get totalOrders => _orders.length;

  int get deliveredOrders =>
      _orders.where((order) => order.status == 'Livrée').length;

  int get activeOrders =>
      _orders
          .where(
            (order) =>
                order.status != DeliveryOrder.delivered &&
                order.status != DeliveryOrder.refused,
          )
          .length;

  String advanceStatus(DeliveryOrder order) {
    _ensureOrderExists(order);
    return order.advanceStatus();
  }

  void refuseOrder(DeliveryOrder order) {
    _ensureOrderExists(order);
    order.refuse();
  }

  void _ensureOrderExists(DeliveryOrder order) {
    if (!_orders.contains(order)) {
      throw StateError('Cette commande ne fait pas partie de la tournée.');
    }
  }
}
