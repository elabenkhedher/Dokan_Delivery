import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Données extraites lors du scan QR ou de la saisie manuelle.
/// Supporte les formats JSON String et Plain Text Serial Code.
class StockPickupQrData {
  final String? serialCode;
  final String? pickupId;
  final String? delivererId;
  final String? type;
  final String rawInput;
  final bool isJson;

  const StockPickupQrData({
    this.serialCode,


    this.pickupId,
    this.delivererId,
    this.type,
    required this.rawInput,
    this.isJson = false,
  });

  /// Parse une chaîne de QR Code ou une saisie manuelle.
  /// Si la chaîne commence par `{`, extrait serialCode, pickupId, delivererId depuis le JSON.
  /// Sinon, traite la chaîne directement comme code série (ou pickupId si préfixé PKP_).
  factory StockPickupQrData.parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          final sCode = decoded['serialCode']?.toString().trim() ??
              decoded['serial']?.toString().trim() ??
              decoded['code']?.toString().trim();
          final pId = decoded['pickupId']?.toString().trim() ??
              decoded['id']?.toString().trim() ??
              decoded['pickup_id']?.toString().trim();
          final dId = decoded['delivererId']?.toString().trim() ??
              decoded['deliverer_id']?.toString().trim() ??
              decoded['livreurId']?.toString().trim();
          final type = decoded['type']?.toString().trim();

          return StockPickupQrData(
            serialCode: (sCode != null && sCode.isNotEmpty) ? sCode : null,
            pickupId: (pId != null && pId.isNotEmpty) ? pId : null,
            delivererId: (dId != null && dId.isNotEmpty) ? dId : null,
            type: type,
            rawInput: trimmed,
            isJson: true,
          );
        }
      } catch (_) {
        // En cas d'erreur JSON, on bascule en texte brut
      }
    }

    return StockPickupQrData(
      serialCode: trimmed.isNotEmpty ? trimmed : null,
      pickupId: trimmed.startsWith('PKP_') ? trimmed : null,
      rawInput: trimmed,
      isJson: false,
    );
  }

  /// Identifiant prioritaire pour la recherche
  String? get primaryCode => serialCode ?? pickupId ?? (rawInput.isNotEmpty ? rawInput : null);
}

/// Modèle représentant un enlèvement de stock en entrepôt (`stock_pickups`).
class StockPickup {
  static const String statusPending = 'pending';
  static const String statusScanned = 'scanned';

  final String id;
  final String serialCode;
  final String delivererId;
  final String delivererName;
  final String delivererPhone;
  final String vehiclePlate;
  final String vehicleType;
  final List<String> orderIds;
  final int orderCount;
  final double totalWeightKg;
  final String status;
  final DateTime? createdAt;
  final DateTime? scannedAt;
  final String? scannedBy;
  final String warehouseLocation;

  const StockPickup({
    required this.id,
    required this.serialCode,
    this.delivererId = '',
    this.delivererName = '',
    this.delivererPhone = '',
    this.vehiclePlate = '',
    this.vehicleType = 'camion',
    this.orderIds = const [],
    this.orderCount = 0,
    this.totalWeightKg = 0.0,
    this.status = statusPending,
    this.createdAt,
    this.scannedAt,
    this.scannedBy,
    this.warehouseLocation = 'Dépôt Central',
  });

  bool get isPending => status == statusPending;
  bool get isScanned => status == statusScanned;

  int get effectiveOrderCount => orderCount > 0 ? orderCount : orderIds.length;

  factory StockPickup.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
      return null;
    }

    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) {
        final clean = val.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.tryParse(clean) ?? 0.0;
      }
      return 0.0;
    }

    final rawOrders = data['orderIds'] ?? data['orders'] ?? data['commandesIds'];
    final List<String> orders = [];
    if (rawOrders is List) {
      for (final item in rawOrders) {
        if (item != null) {
          final s = item.toString().trim();
          if (s.isNotEmpty) orders.add(s);
        }
      }
    }

    final orderCount = (data['orderCount'] ?? data['ordersCount'] as num?)?.toInt() ?? orders.length;

    final docId = id ?? (data['id'] ?? '').toString();

    return StockPickup(
      id: docId,
      serialCode: (data['serialCode'] ?? data['serial'] ?? data['code'] ?? docId).toString(),
      delivererId: (data['delivererId'] ?? data['livreurId'] ?? '').toString(),
      delivererName: (data['delivererName'] ?? data['nomLivreur'] ?? '').toString(),
      delivererPhone: (data['delivererPhone'] ?? data['phone'] ?? '').toString(),
      vehiclePlate: (data['vehiclePlate'] ?? data['plate'] ?? '').toString(),
      vehicleType: (data['vehicleType'] ?? data['typeVehicule'] ?? 'camion').toString(),
      orderIds: orders,
      orderCount: orderCount,
      totalWeightKg: parseDouble(data['totalWeightKg'] ?? data['totalWeight'] ?? data['poidsTotalKg']),
      status: (data['status'] ?? statusPending).toString(),
      createdAt: parseDate(data['createdAt']),
      scannedAt: parseDate(data['scannedAt']),
      scannedBy: data['scannedBy']?.toString(),
      warehouseLocation: (data['warehouseLocation'] ?? data['warehouse'] ?? data['depot'] ?? 'Dépôt Central').toString(),
    );
  }

  factory StockPickup.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return StockPickup.fromMap(data, id: doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'serialCode': serialCode,
      'delivererId': delivererId,
      'delivererName': delivererName,
      'delivererPhone': delivererPhone,
      'vehiclePlate': vehiclePlate,
      'vehicleType': vehicleType,
      'orderIds': orderIds,
      'orderCount': effectiveOrderCount,
      'totalWeightKg': totalWeightKg,
      'status': status,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (scannedAt != null) 'scannedAt': Timestamp.fromDate(scannedAt!),
      if (scannedBy != null) 'scannedBy': scannedBy,
      'warehouseLocation': warehouseLocation,
    };
  }

  StockPickup copyWith({
    String? id,
    String? serialCode,
    String? delivererId,
    String? delivererName,
    String? delivererPhone,
    String? vehiclePlate,
    String? vehicleType,
    List<String>? orderIds,
    int? orderCount,
    double? totalWeightKg,
    String? status,
    DateTime? createdAt,
    DateTime? scannedAt,
    String? scannedBy,
    String warehouseLocation = 'Dépôt Central',
  }) {
    return StockPickup(
      id: id ?? this.id,
      serialCode: serialCode ?? this.serialCode,
      delivererId: delivererId ?? this.delivererId,
      delivererName: delivererName ?? this.delivererName,
      delivererPhone: delivererPhone ?? this.delivererPhone,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleType: vehicleType ?? this.vehicleType,
      orderIds: orderIds ?? this.orderIds,
      orderCount: orderCount ?? this.orderCount,
      totalWeightKg: totalWeightKg ?? this.totalWeightKg,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      scannedAt: scannedAt ?? this.scannedAt,
      scannedBy: scannedBy ?? this.scannedBy,
      warehouseLocation: warehouseLocation.isNotEmpty ? warehouseLocation : this.warehouseLocation,
    );
  }
}
