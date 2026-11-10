import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Modèle représentant un article d'une commande
class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final double poids; // Poids en kg (fallback 0.0)

  const OrderItem({
    this.id = '',
    required this.name,
    this.quantity = 1,
    this.price = 0.0,
    this.poids = 0.0,
  });

  /// Poids total pour cette ligne d'articles (poids * quantité)
  double get totalPoidsLigne => poids * (quantity > 0 ? quantity : 1);

  factory OrderItem.fromMap(Map<String, dynamic> data) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) {
        final clean = val.replaceAll(RegExp(r'[^0-9.]'), '');
        return double.tryParse(clean) ?? 0.0;
      }
      return 0.0;
    }

    final id = (data['id'] ?? data['productId'] ?? data['itemId'] ?? '').toString();
    final name = (data['name'] ??
            data['nom'] ??
            data['title'] ??
            data['designation'] ??
            data['label'] ??
            'Article')
        .toString();
    final quantity = (data['quantity'] ?? data['quantite'] ?? data['qty'] as num?)?.toInt() ?? 1;
    final price = parseDouble(data['price'] ?? data['prix'] ?? data['unitPrice']);
    final poids = parseDouble(data['poids'] ?? data['weight'] ?? data['poidsKg'] ?? data['weightKg']);

    return OrderItem(
      id: id,
      name: name,
      quantity: quantity,
      price: price,
      poids: poids,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
      'poids': poids,
    };
  }
}

class DeliveryOrder {
  // --- Cycle de vie strict Dokan (4 étapes partagées + exceptions) ---
  // 1. "en attente" : Commande initiée par le client
  // 2. "en cours"   : Confirmée par l'admin et assignée au livreur (en attente d'enlèvement stock)
  // 3. "enleve"     : Scannée au stock central, chargée dans le véhicule (tournée active)
  // 4. "livre"      : Remise au client à destination
  // Exceptions : "echec" (échec / refusée), "annule" (annulée)
  static const statusEnAttente = 'en attente';
  static const statusEnCours = 'en cours';
  static const statusEnleve = 'enleve';
  static const statusLivre = 'livre';
  static const statusEchec = 'echec';
  static const statusAnnule = 'annule';

  // --- Nomenclature UI Dokan (sans statut "À récupérer") ---
  static const inProgress = 'En cours';
  static const delivered = 'Livrée';
  static const deliveryFailed = 'Échec de livraison';
  static const cancelled = 'Annulée';

  // --- Rétro-compatibilité : tout est directement "En cours" ou "Échec de livraison" ---
  static const assigned = 'En cours';
  static const awaitingPickup = 'En cours';
  static const refused = 'Échec de livraison';

  // --- Statuts Firestore (collection 'orders' et 'commandes') ---
  static const _statusMap = <String, String>{
    'en attente': 'En cours',
    'confirmed': 'En cours',
    'preparing': 'En cours',
    'en cours': 'En cours',
    'enleve': 'En cours',
    'enlevé': 'En cours',
    'enlevée': 'En cours',
    'picked_up': 'En cours',
    'in_progress': 'En cours',
    'livre': 'Livrée',
    'livré': 'Livrée',
    'completed': 'Livrée',
    'delivered': 'Livrée',
    'echec': 'Échec de livraison',
    'failed': 'Échec de livraison',
    'refused': 'Échec de livraison',
    'refusé': 'Échec de livraison',
    'refusée': 'Échec de livraison',
    'retour': 'Échec de livraison',
    'returned': 'Échec de livraison',
    'annule': 'Annulée',
    'annulée': 'Annulée',
    'cancelled': 'Annulée',
  };

  // --- Correspondances inverse pour l'écriture Firestore ---
  static const _reverseStatusMap = <String, String>{
    'En cours': 'en cours',
    'En cours de livraison': 'en cours',
    'Enlevée': 'en cours',
    'Livrée': 'livre',
    'Échec de livraison': 'echec',
    'Refusée': 'echec',
    'Annulée': 'annule',
  };

  final String id;
  final String displayNumber;
  final String customerName;
  final String address;
  final String phone;
  final double total;
  final double subtotal;
  final double deliveryFee;
  final double discount;
  final String currency;
  final String livreurId;
  final String paymentMethod;
  final String paymentStatus;
  final int itemCount;
  final double totalPoids;
  final List<OrderItem> items;
  final double? latitude;
  final double? longitude;
  final bool isPickedUp;
  String? motifEchec;

  // --- Notation & Compliments reçus du client ---
  int? driverRating;
  String? driverFeedback;

  String _status;

  // --- Horodatage pour chaque étape (exigé par le cahier des charges) ---
  DateTime? assignedAt;
  DateTime? pickedUpAt;
  DateTime? inProgressAt;
  DateTime? deliveredAt;
  DateTime? failedAt;
  DateTime? cancelledAt;

  DeliveryOrder({
    required this.id,
    this.displayNumber = '',
    required this.customerName,
    required this.address,
    required this.phone,
    required this.total,
    this.subtotal = 0.0,
    this.deliveryFee = 0.0,
    this.discount = 0.0,
    this.currency = 'TND',
    this.livreurId = '',
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.itemCount = 0,
    this.totalPoids = 0.0,
    this.items = const [],
    this.latitude,
    this.longitude,
    this.isPickedUp = false,
    required String status,
    this.motifEchec,
    this.driverRating,
    this.driverFeedback,
    this.assignedAt,
    this.pickedUpAt,
    this.inProgressAt,
    this.deliveredAt,
    this.failedAt,
    this.cancelledAt,
  })  :
        // ignore: prefer_initializing_formals
        _status = status;

  LatLng get destinationLatLng {
    if (latitude != null && longitude != null && latitude != 0 && longitude != 0) {
      return LatLng(latitude!, longitude!);
    }
    final lowerAddr = address.toLowerCase();
    if (lowerAddr.contains('nabeul')) {
      return const LatLng(36.4560, 10.7376);
    } else if (lowerAddr.contains('sousse')) {
      return const LatLng(35.8256, 10.6084);
    } else if (lowerAddr.contains('sfax')) {
      return const LatLng(34.7406, 10.7603);
    } else if (lowerAddr.contains('bizerte')) {
      return const LatLng(37.2744, 9.8739);
    }
    // Coordonnées par défaut en Tunisie (Grand Tunis)
    return const LatLng(36.8065, 10.1815);
  }

  String get status => _status;

  bool get isAssigned => !isPickedUp && !isDelivered && !isFailedOrRefused;

  bool get isInProgress => !isDelivered && !isFailedOrRefused;

  bool get isDelivered =>
      _status == delivered ||
      _status == 'Livrée' ||
      _status == 'livre' ||
      _status == 'livré' ||
      _status == 'completed' ||
      _status == 'delivered';

  bool get isFailedOrRefused =>
      _status == refused ||
      _status == deliveryFailed ||
      _status == cancelled ||
      _status == 'Échec de livraison' ||
      _status == 'Échec' ||
      _status == 'Retour' ||
      _status == 'Retour / Échec' ||
      _status == 'Refusée' ||
      _status == 'Annulée' ||
      _status == 'echec' ||
      _status == 'failed' ||
      _status == 'refused' ||
      _status == 'annule' ||
      _status == 'cancelled' ||
      _status == 'retour' ||
      _status == 'returned';

  bool get hasRating => driverRating != null && driverRating! > 0;

  List<String> get feedbackTags =>
      (driverFeedback != null && driverFeedback!.trim().isNotEmpty)
          ? driverFeedback!
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList()
          : const [];

  // --- 1. Instanciation depuis Firestore (collection 'orders') ---
  factory DeliveryOrder.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime? parseTimestamp(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
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

    // --- Lecture robuste de l'adresse de livraison (supporte Map ET String) ---
    Map<String, dynamic>? deliveryAddressMap;
    String rawAddressText = '';

    final rawDeliveryAddress = data['deliveryAddress'] ??
        data['adresseLivraison'] ??
        data['address'] ??
        data['adresse'];
    if (rawDeliveryAddress is Map) {
      deliveryAddressMap = Map<String, dynamic>.from(rawDeliveryAddress);
    } else if (rawDeliveryAddress is String) {
      rawAddressText = rawDeliveryAddress.trim();
    }

    final addressLine = deliveryAddressMap != null
        ? '${deliveryAddressMap['addressLine'] ?? ''}, ${deliveryAddressMap['city'] ?? ''}'
            .trim()
            .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
        : rawAddressText;

    final deliveryPhone = deliveryAddressMap?['phone']?.toString() ?? '';

    final id = doc.id;
    final displayNumber = (data['displayNumber'] ?? '').toString();

    final customerName = (data['customerName'] ??
            data['clientName'] ??
            data['nomClient'] ??
            data['clientNom'] ??
            data['nom'] ??
            data['client'] ??
            '')
        .toString();

    final address = addressLine.isNotEmpty
        ? addressLine
        : (rawAddressText.isNotEmpty
            ? rawAddressText
            : (data['address'] ?? data['adresse'] ?? data['adresseLivraison'] ?? '').toString());

    final phone = deliveryPhone.isNotEmpty
        ? deliveryPhone
        : (data['phone'] ?? data['telephone'] ?? data['tel'] ?? data['numTel'] ?? '').toString();

    final total = parseDouble(data['total'] ?? data['montant'] ?? data['prix']);
    final subtotal = parseDouble(data['subtotal']);
    final deliveryFee = parseDouble(data['deliveryFee']);
    final discount = parseDouble(data['discount']);
    final currency = (data['currency'] ?? 'TND').toString();
    final paymentMethod = (data['paymentMethod'] ?? '').toString();
    final paymentStatus = (data['paymentStatus'] ?? '').toString();
    final itemCount = (data['itemCount'] as num?)?.toInt() ?? 0;

    // --- Lecture des articles et parsing poids ---
    final rawItems = data['items'] ?? data['articles'] ?? data['produits'];
    final items = <OrderItem>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          items.add(OrderItem.fromMap(it));
        } else if (it is Map) {
          items.add(OrderItem.fromMap(Map<String, dynamic>.from(it)));
        }
      }
    }

    // --- Lecture du poids total (fallback 0.0 ou somme des articles) ---
    final rawPoids = data['totalPoids'] ??
        data['total_poids'] ??
        data['poidsTotal'] ??
        data['totalWeight'] ??
        data['poids'];
    double totalPoids = parseDouble(rawPoids);
    if (totalPoids == 0.0 && items.isNotEmpty) {
      final itemsPoidsSum = items.fold<double>(0.0, (acc, it) => acc + it.totalPoidsLigne);
      if (itemsPoidsSum > 0) {
        totalPoids = itemsPoidsSum;
      }
    }

    // --- Lecture de livreurId (supporte livreurId et driverId) ---
    final livreurId = (data['livreurId'] ??
            data['driverId'] ??
            data['livreur_id'] ??
            data['delivererId'] ??
            data['idLivreur'] ??
            '')
        .toString();

    // --- Mapping des statuts Firestore → statuts internes Dokan ---
    final rawStatus = (data['status'] ?? data['statut'] ?? data['etat'] ?? '').toString().trim();
    final isPickedUp = data['isPickedUp'] == true ||
        rawStatus.toLowerCase() == 'enleve' ||
        rawStatus.toLowerCase() == 'enlevé' ||
        rawStatus.toLowerCase() == 'enlevée' ||
        data['pickedUpAt'] != null;

    final String status;
    if (isPickedUp && (rawStatus.toLowerCase() == 'en cours' || rawStatus.toLowerCase() == 'in_progress')) {
      status = inProgress;
    } else {
      status = DeliveryOrder._statusMap[rawStatus.toLowerCase()] ??
          (rawStatus.isNotEmpty ? rawStatus : assigned);
    }

    final motifEchec = (data['motifEchec'] ??
            data['motif'] ??
            data['failureReason'] ??
            data['raisonEchec'])
        ?.toString();

    // --- Lecture des horodatages depuis statusHistory ou champs directs ---
    DateTime? resolveTimestamp(dynamic direct, dynamic fallback, String historyStatus) {
      final direct0 = parseTimestamp(direct ?? fallback);
      if (direct0 != null) return direct0;
      final rawHistory = data['statusHistory'];
      if (rawHistory is List) {
        for (final entry in rawHistory) {
          if (entry is Map && entry['status'] == historyStatus) {
            return parseTimestamp(entry['at']);
          }
        }
      }
      return null;
    }

    final rawLat = data['latitude'] ??
        data['lat'] ??
        deliveryAddressMap?['latitude'] ??
        deliveryAddressMap?['lat'];
    final rawLng = data['longitude'] ??
        data['lng'] ??
        data['lon'] ??
        deliveryAddressMap?['longitude'] ??
        deliveryAddressMap?['lng'] ??
        deliveryAddressMap?['lon'];
    final latitude = rawLat != null ? parseDouble(rawLat) : null;
    final longitude = rawLng != null ? parseDouble(rawLng) : null;

    final rawRating = data['driverRating'] ?? data['rating'] ?? data['noteLivreur'] ?? data['note'];
    final int? driverRating = (rawRating is num)
        ? rawRating.toInt()
        : int.tryParse(rawRating?.toString() ?? '');
    final String? driverFeedback =
        (data['driverFeedback'] ?? data['feedback'] ?? data['avisLivreur'] ?? data['compliments'])?.toString();

    return DeliveryOrder(
      id: id,
      displayNumber: displayNumber,
      customerName: customerName.isNotEmpty ? customerName : 'Client',
      address: address.isNotEmpty ? address : 'Adresse non spécifiée',
      phone: phone,
      total: total,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      discount: discount,
      currency: currency,
      livreurId: livreurId,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      itemCount: itemCount > 0 ? itemCount : items.length,
      totalPoids: totalPoids,
      items: items,
      latitude: latitude,
      longitude: longitude,
      isPickedUp: isPickedUp,
      status: status,
      motifEchec: motifEchec,
      driverRating: driverRating,
      driverFeedback: driverFeedback,
      assignedAt: resolveTimestamp(data['assignedAt'], data['dateAffectation'], 'confirmed'),
      pickedUpAt: resolveTimestamp(data['pickedUpAt'], data['dateRamassage'], 'in_progress'),
      inProgressAt: resolveTimestamp(data['inProgressAt'], data['datePriseEnCharge'], 'in_progress'),
      deliveredAt: resolveTimestamp(data['deliveredAt'], data['dateLivraison'], 'delivered'),
      failedAt: resolveTimestamp(data['failedAt'], data['dateEchec'], 'failed'),
      cancelledAt: resolveTimestamp(data['cancelledAt'], data['dateAnnulation'], 'cancelled'),
    );
  }

  // --- 2. Conversion en Map pour Firestore (avec horodatage) ---
  Map<String, dynamic> toMap() {
    final firestoreStatus = _reverseStatusMap[_status] ?? _status;
    return {
      'customerName': customerName,
      'total': total,
      'totalPoids': totalPoids,
      if (items.isNotEmpty) 'items': items.map((e) => e.toMap()).toList(),
      'livreurId': livreurId,
      'driverId': livreurId,
      'isPickedUp': isPickedUp,
      'status': firestoreStatus,
      'motifEchec': motifEchec,
      if (driverRating != null) 'driverRating': driverRating,
      if (driverFeedback != null && driverFeedback!.isNotEmpty)
        'driverFeedback': driverFeedback,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'pickedUpAt': pickedUpAt != null ? Timestamp.fromDate(pickedUpAt!) : null,
      'inProgressAt': inProgressAt != null ? Timestamp.fromDate(inProgressAt!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'failedAt': failedAt != null ? Timestamp.fromDate(failedAt!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
    };
  }

  // --- 3. Méthodes métiers avec respect strict du cycle de vie et des dates ---

  void refuse([String? reason]) {
    _status = refused;
    failedAt = DateTime.now();
    if (reason != null && reason.isNotEmpty) {
      motifEchec = reason;
    }
  }

  String advanceStatus() {
    if (isDelivered) {
      throw StateError('Une commande livrée ne peut plus être modifiée.');
    }
    if (isFailedOrRefused) {
      throw StateError('Une commande échouée ou annulée ne peut plus être modifiée.');
    }
    _status = delivered;
    deliveredAt = DateTime.now();
    return _status;
  }

  /// Le livreur prend en charge la commande : Affectée -> En cours de livraison
  void startDelivery() => advanceStatus();

  /// La commande est livrée avec succès
  void markAsDelivered() {
    if (isDelivered) {
      throw StateError('Cette commande est déjà marquée comme livrée.');
    }
    if (isFailedOrRefused) {
      throw StateError('Une commande en échec ou annulée ne peut pas être marquée comme livrée.');
    }
    _status = delivered;
    deliveredAt = DateTime.now();
  }

  /// Gestion de l'échec de livraison
  void markAsFailed([String? reason]) {
    if (isDelivered) {
      throw StateError('Une commande déjà livrée ne peut plus être déclarée en échec.');
    }
    if (isFailedOrRefused) {
      throw StateError('Cette commande est déjà déclarée en échec.');
    }
    _status = deliveryFailed;
    failedAt = DateTime.now();
    if (reason != null && reason.isNotEmpty) {
      motifEchec = reason;
    }
  }

  /// Annulation de la commande
  void cancel() {
    if (_status == delivered || _status == deliveryFailed) {
      throw StateError('Impossible d\'annuler une commande déjà finalisée.');
    }
    _status = cancelled;
    cancelledAt = DateTime.now();
  }
}
