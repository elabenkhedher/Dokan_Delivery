import 'package:flutter/material.dart';

/// Régions officielles de livraison pour Dokan Delivery.
class DeliveryRegion {
  final String id;
  final String name;
  final String fullLabel;

  const DeliveryRegion({
    required this.id,
    required this.name,
    required this.fullLabel,
  });

  /// Les 3 régions officielles définies par l'architecture Dokan.
  static const DeliveryRegion nord = DeliveryRegion(
    id: 'nord',
    name: 'Nord',
    fullLabel: 'Nord (الشمال) • Grand Tunis, Nabeul, Bizerte...',
  );

  static const DeliveryRegion centre = DeliveryRegion(
    id: 'centre',
    name: 'Centre',
    fullLabel: 'Centre (الوسط) • Sousse, Monastir, Sfax...',
  );

  static const DeliveryRegion sud = DeliveryRegion(
    id: 'sud',
    name: 'Sud',
    fullLabel: 'Sud (الجنوب) • Médenine, Djerba, Zarzis, Gabès...',
  );

  static const List<DeliveryRegion> officialRegions = [nord, centre, sud];

  static DeliveryRegion? findById(String? id) {
    if (id == null) return null;
    final normalized = id.trim().toLowerCase();
    for (final region in officialRegions) {
      if (region.id == normalized || region.name.toLowerCase() == normalized) {
        return region;
      }
    }
    return null;
  }
}

/// Types de véhicules de la flotte Dokan.
enum VehicleType {
  voiture,
  camion,
  moto,
  autre;

  static VehicleType fromString(String? type) {
    if (type == null) return VehicleType.autre;
    switch (type.toLowerCase().trim()) {
      case 'voiture':
      case 'car':
        return VehicleType.voiture;
      case 'camion':
      case 'truck':
        return VehicleType.camion;
      case 'moto':
      case 'scooter':
      case 'motorcycle':
        return VehicleType.moto;
      default:
        return VehicleType.autre;
    }
  }

  String get displayName {
    switch (this) {
      case VehicleType.voiture:
        return 'Voiture';
      case VehicleType.camion:
        return 'Camion';
      case VehicleType.moto:
        return 'Moto';
      case VehicleType.autre:
        return 'Véhicule';
    }
  }

  IconData get icon {
    switch (this) {
      case VehicleType.voiture:
        return Icons.directions_car_rounded;
      case VehicleType.camion:
        return Icons.local_shipping_rounded;
      case VehicleType.moto:
        return Icons.two_wheeler_rounded;
      case VehicleType.autre:
        return Icons.commute_rounded;
    }
  }
}

/// Modèle complet du profil livreur synchronisé avec Firestore `users/{uid}`.
class DriverProfile {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String role;
  final String? assignedRegionId;
  final String? assignedRegionName;
  final String? assignedVehicleId;
  final String? assignedVehiclePlate;
  final String? assignedVehicleType;
  final String? assignedVehicleModel;
  final double maxCapacityKg;

  const DriverProfile({
    required this.uid,
    this.name = '',
    this.phone = '',
    this.email = '',
    this.role = 'livreur',
    this.assignedRegionId,
    this.assignedRegionName,
    this.assignedVehicleId,
    this.assignedVehiclePlate,
    this.assignedVehicleType,
    this.assignedVehicleModel,
    this.maxCapacityKg = 100.0,
  });

  /// Indique si un véhicule de flotte officiel est assigné au livreur.
  bool get hasAssignedVehicle =>
      assignedVehiclePlate != null && assignedVehiclePlate!.trim().isNotEmpty;

  VehicleType get vehicleType => VehicleType.fromString(assignedVehicleType);

  DeliveryRegion? get region => DeliveryRegion.findById(assignedRegionId);

  /// Détermine la capacité maximale en kg selon Firestore ou les types par défaut :
  /// 500.0 kg pour 'camion', 100.0 kg pour 'voiture', 20.0 kg pour 'moto'.
  static double resolveMaxCapacity(dynamic rawCapacity, String? vehicleType) {
    if (rawCapacity != null) {
      if (rawCapacity is num) {
        final d = rawCapacity.toDouble();
        if (d > 0) return d;
      } else if (rawCapacity is String) {
        final clean = rawCapacity.replaceAll(RegExp(r'[^0-9.]'), '');
        final d = double.tryParse(clean);
        if (d != null && d > 0) return d;
      }
    }
    final vt = vehicleType?.toLowerCase().trim();
    if (vt == 'camion' || vt == 'truck') {
      return 500.0;
    } else if (vt == 'voiture' || vt == 'car') {
      return 100.0;
    } else if (vt == 'moto' || vt == 'scooter' || vt == 'motorcycle') {
      return 20.0;
    }
    return 100.0;
  }

  factory DriverProfile.fromMap(Map<String, dynamic> data, {required String uid}) {
    final vehicleType = data['assignedVehicleType']?.toString();
    final rawCapacity = data['maxCapacityKg'] ?? data['max_capacity_kg'] ?? data['capaciteMax'];
    final maxCapacity = resolveMaxCapacity(rawCapacity, vehicleType);

    return DriverProfile(
      uid: uid,
      name: (data['name'] ?? data['nom'] ?? data['displayName'] ?? '').toString(),
      phone: (data['phone'] ?? data['telephone'] ?? data['numTel'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      role: (data['role'] ?? 'livreur').toString(),
      assignedRegionId: data['assignedRegionId']?.toString(),
      assignedRegionName: data['assignedRegionName']?.toString(),
      assignedVehicleId: data['assignedVehicleId']?.toString(),
      assignedVehiclePlate: data['assignedVehiclePlate']?.toString(),
      assignedVehicleType: vehicleType,
      assignedVehicleModel: data['assignedVehicleModel']?.toString(),
      maxCapacityKg: maxCapacity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      if (email.isNotEmpty) 'email': email,
      'role': role,
      'assignedRegionId': assignedRegionId,
      'assignedRegionName': assignedRegionName,
      'assignedVehicleId': assignedVehicleId,
      'assignedVehiclePlate': assignedVehiclePlate,
      'assignedVehicleType': assignedVehicleType,
      'assignedVehicleModel': assignedVehicleModel,
      'maxCapacityKg': maxCapacityKg,
    };
  }

  DriverProfile copyWith({
    String? name,
    String? phone,
    String? email,
    String? role,
    String? assignedRegionId,
    String? assignedRegionName,
    String? assignedVehicleId,
    String? assignedVehiclePlate,
    String? assignedVehicleType,
    String? assignedVehicleModel,
    double? maxCapacityKg,
  }) {
    return DriverProfile(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      assignedRegionId: assignedRegionId ?? this.assignedRegionId,
      assignedRegionName: assignedRegionName ?? this.assignedRegionName,
      assignedVehicleId: assignedVehicleId ?? this.assignedVehicleId,
      assignedVehiclePlate: assignedVehiclePlate ?? this.assignedVehiclePlate,
      assignedVehicleType: assignedVehicleType ?? this.assignedVehicleType,
      assignedVehicleModel: assignedVehicleModel ?? this.assignedVehicleModel,
      maxCapacityKg: maxCapacityKg ?? this.maxCapacityKg,
    );
  }
}
