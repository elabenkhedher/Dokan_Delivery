
class DeliveryOrder {
  static const awaitingPickup = 'À récupérer';
  static const inProgress = 'En cours';
  static const delivered = 'Livrée';
  static const refused = 'Refusée';

  final String id;
  final String customerName;
  final String address;
  final String phone;
  final double total;
  String _status;

  DeliveryOrder({
    required this.id,
    required this.customerName,
    required this.address,
    required this.phone,
    required this.total,
    required String status,
    // ignore: prefer_initializing_formals
  }) : _status = status;

  String get status => _status;

  void refuse() {
    if (_status != awaitingPickup) {
      throw StateError(
        'Seule une commande à récupérer peut être refusée.',
      );
    }

    _status = refused;
  }

  String advanceStatus() {
    switch (_status) {
      case awaitingPickup:
        _status = inProgress;
      case inProgress:
        _status = delivered;
      case delivered:
        throw StateError('Une commande livrée ne peut plus être modifiée.');
      case refused:
        throw StateError('Une commande refusée ne peut plus être modifiée.');
      default:
        throw StateError('Statut de commande inconnu : $_status');
    }

    return _status;
  }
}
