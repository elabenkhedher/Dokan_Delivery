import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/delivery_order.dart';
import '../models/navigation/deliverer_location.dart';
import '../models/navigation/nav_step.dart';
import '../models/navigation/route_info.dart';
import '../services/deliverer_location_service.dart';
import '../services/navigation/live_location_publisher.dart';
import '../services/navigation/location_service.dart';
import '../services/navigation/osrm_routing_service.dart';
import '../services/order_service.dart';

/// Contrôleur de gestion d'état réactif pour l'écran de navigation GPS OpenStreetMap.
class NavigationController extends ChangeNotifier {
  final LocationService _locationService;
  final OsrmRoutingService _routingService;
  final LiveLocationPublisher _locationPublisher;
  final OrderService _orderService;

  NavigationController({
    LocationService? locationService,
    OsrmRoutingService? routingService,
    LiveLocationPublisher? locationPublisher,
    OrderService? orderService,
  })  : _locationService = locationService ?? LocationService(),
        _routingService = routingService ?? OsrmRoutingService(),
        _locationPublisher = locationPublisher ?? LiveLocationPublisher(),
        _orderService = orderService ?? OrderService();

  // ── Propriétés d'état ──────────────────────────────────────────
  late DeliveryOrder order;
  late LatLng destination;
  List<DeliveryOrder> _tourOrders = [];
  Map<String, dynamic>? vehicleInfo;

  DelivererLocation? _currentLocation;
  RouteInfo? _routeInfo;
  NavStep? _currentStep;

  bool _isTrackingCamera = true;
  bool _isArrived = false;
  bool _isDelivered = false;
  bool _isLoading = true;
  bool _isRecalculating = false;
  String? _errorMessage;

  DelivererLocationPermissionStatus _permissionStatus =
      DelivererLocationPermissionStatus.granted;

  final MapController mapController = MapController();

  DateTime? _lastRecalculationTime;
  StreamSubscription<DelivererLocation>? _locationSub;

  // ── Getters ────────────────────────────────────────────────────
  OrderService get orderService => _orderService;
  DelivererLocation? get currentLocation => _currentLocation;
  RouteInfo? get routeInfo => _routeInfo;
  NavStep? get currentStep => _currentStep;
  bool get isTrackingCamera => _isTrackingCamera;
  bool get isArrived => _isArrived;
  bool get isDelivered => _isDelivered;
  bool get isLoading => _isLoading;
  bool get isRecalculating => _isRecalculating;
  String? get errorMessage => _errorMessage;
  DelivererLocationPermissionStatus get permissionStatus => _permissionStatus;

  List<DeliveryOrder> get tourOrders => List.unmodifiable(_tourOrders);
  int get currentOrderIndex => _tourOrders.indexWhere((o) => o.id == order.id);
  int get remainingTourOrdersCount =>
      _tourOrders.where((o) => !o.isDelivered).length;

  double get distanceToClient => _currentLocation != null
      ? _currentLocation!.distanceTo(destination)
      : 0.0;

  List<LatLng> get routePoints => _routeInfo?.points ?? [];

  // ── Initialisation ─────────────────────────────────────────────
  Future<void> initialize({
    DeliveryOrder? deliveryOrder,
    LatLng? clientDestination,
    List<DeliveryOrder>? tourOrders,
    Map<String, dynamic>? assignedVehicle,
  }) async {
    if (tourOrders != null && tourOrders.isNotEmpty) {
      _tourOrders = List.from(tourOrders);
    } else if (deliveryOrder != null) {
      _tourOrders = [deliveryOrder];
    }

    final targetOrder = deliveryOrder ??
        _tourOrders.firstWhere(
          (o) => !o.isDelivered,
          orElse: () => _tourOrders.isNotEmpty
              ? _tourOrders.first
              : DeliveryOrder(
                  id: 'tour_target',
                  customerName: 'Client',
                  address: 'Tunis',
                  phone: '',
                  total: 0,
                  status: DeliveryOrder.inProgress,
                ),
        );

    order = targetOrder;
    destination = clientDestination ?? targetOrder.destinationLatLng;
    vehicleInfo = assignedVehicle ?? DelivererLocationService().vehicleInfo;
    DelivererLocationService().updateCurrentOrder(targetOrder.id);
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // 1. Vérification des permissions GPS
    try {
      _permissionStatus = await _locationService.checkAndRequestPermissions();
      if (_permissionStatus != DelivererLocationPermissionStatus.granted) {
        _isLoading = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('[NavigationController] Warning permissions: $e');
    }

    // 2. Récupération de la première position et calcul initial
    try {
      final initialPos = await _locationService.getCurrentLocation(referenceDestination: destination);
      if (initialPos != null) {
        _currentLocation = initialPos;
        await _calculateFullRoute(initialPos.latLng, destination);
        await _locationPublisher.publishLocation(
          location: initialPos,
          currentOrderId: order.id,
          vehicleInfo: vehicleInfo,
        );
        _animateCameraToDriver(initialPos);
      }
    } catch (e) {
      debugPrint('[NavigationController] Erreur initialPos / route: $e');
    }

    // 3. Démarrage de l'écoute du flux de coordonnées
    try {
      _locationSub = _locationService.startLocationStream().listen(_onPositionReceived);
    } catch (e) {
      debugPrint('[NavigationController] Erreur stream location: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Traitement à chaque coordonnée GPS ─────────────────────────
  Future<void> _onPositionReceived(DelivererLocation newLocation) async {
    _currentLocation = newLocation;

    // A. Publication temps réel vers Firebase RTDB (1/3s max)
    _locationPublisher.publishLocation(
      location: newLocation,
      currentOrderId: order.id,
      vehicleInfo: vehicleInfo,
    );

    // B. Détection d'arrivée à destination (<= 50 mètres)
    final dist = newLocation.distanceTo(destination);
    if (dist <= 50.0 && !_isArrived) {
      _isArrived = true;
    }

    // C. Si un itinéraire est tracé : sortie de route et raccourcissement
    if (_routeInfo != null && _routeInfo!.points.isNotEmpty) {
      _updateRouteProgress(newLocation);
    } else {
      await _calculateFullRoute(newLocation.latLng, destination);
    }

    // D. Suivi automatique de la caméra si activé
    if (_isTrackingCamera) {
      _animateCameraToDriver(newLocation);
    }

    notifyListeners();
  }

  // ── Mise à jour dynamique de l'itinéraire ──────────────────────
  void _updateRouteProgress(DelivererLocation loc) {
    final points = List<LatLng>.from(_routeInfo!.points);
    if (points.isEmpty) return;

    // Recherche de l'index du point le plus proche sur le tracé
    int closestIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < points.length; i++) {
      final d = loc.distanceTo(points[i]);
      if (d < minDistance) {
        minDistance = d;
        closestIndex = i;
      }
    }

    // 1. Détection de sortie de route : si livreur > 50 m du tracé
    if (minDistance > 50.0) {
      final now = DateTime.now();
      if (_lastRecalculationTime == null ||
          now.difference(_lastRecalculationTime!) >= const Duration(seconds: 10)) {
        _lastRecalculationTime = now;
        _recalculateRoute(loc.latLng);
        return;
      }
    }

    // 2. Raccourcissement de la ligne : suppression des points franchis
    if (closestIndex > 0 && closestIndex < points.length) {
      points.removeRange(0, closestIndex);
      points.insert(0, loc.latLng);
    }

    // 3. Calcul de la distance restante
    double remainingDist = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      remainingDist += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }

    final effectiveSpeed = loc.speed > 2.0 ? loc.speed : 6.94;
    final remainingDur = remainingDist / effectiveSpeed;

    // 4. Déterminer la prochaine instruction
    NavStep? nextStep;
    for (final step in _routeInfo!.steps) {
      final d = loc.distanceTo(step.location);
      if (d > 15.0) {
        nextStep = step;
        break;
      }
    }

    _currentStep =
        nextStep ?? (_routeInfo!.steps.isNotEmpty ? _routeInfo!.steps.last : null);

    _routeInfo = _routeInfo!.copyWith(
      points: points,
      remainingDistanceMeters: remainingDist,
      remainingDurationSeconds: remainingDur,
    );
  }

  Future<void> _calculateFullRoute(LatLng origin, LatLng dest) async {
    final route = await _routingService.calculateRoute(origin: origin, destination: dest);
    if (route != null) {
      _routeInfo = route;
      _currentStep = route.steps.isNotEmpty ? route.steps.first : null;
      notifyListeners();
    }
  }

  Future<void> _recalculateRoute(LatLng origin) async {
    _isRecalculating = true;
    notifyListeners();

    final newRoute = await _routingService.calculateRoute(origin: origin, destination: destination);
    if (newRoute != null) {
      _routeInfo = newRoute;
      _currentStep = newRoute.steps.isNotEmpty ? newRoute.steps.first : null;
    }
    _isRecalculating = false;
    notifyListeners();
  }

  // ── Contrôle de la Caméra ──────────────────────────────────────
  void _animateCameraToDriver(DelivererLocation loc) {
    try {
      mapController.move(loc.latLng, 16.5);
      mapController.rotate(loc.heading);
    } catch (_) {}
  }

  void onUserPanMap() {
    if (_isTrackingCamera) {
      _isTrackingCamera = false;
      notifyListeners();
    }
  }

  void recenterCamera() {
    _isTrackingCamera = true;
    if (_currentLocation != null) {
      _animateCameraToDriver(_currentLocation!);
    }
    notifyListeners();
  }

  /// Sélectionne une commande de la tournée et recalcule l'itinéraire vers elle
  Future<void> selectOrder(DeliveryOrder selected) async {
    if (order.id == selected.id && _routeInfo != null) {
      if (_currentLocation != null) {
        _animateCameraToDriver(_currentLocation!);
      }
      return;
    }

    order = selected;
    destination = selected.destinationLatLng;
    _isArrived = false;
    _isDelivered = selected.isDelivered;
    _routeInfo = null;
    _currentStep = null;
    _isTrackingCamera = true;
    _isRecalculating = true;
    DelivererLocationService().updateCurrentOrder(selected.id);
    notifyListeners();

    if (_currentLocation != null) {
      await _calculateFullRoute(_currentLocation!.latLng, destination);
      _animateCameraToDriver(_currentLocation!);
    }
    _isRecalculating = false;
    notifyListeners();
  }

  /// Ajuste le zoom et le cadre de la carte pour afficher l'ensemble des arrêts de la tournée
  void fitAllStops() {
    final points = <LatLng>[];
    if (_currentLocation != null) points.add(_currentLocation!.latLng);
    for (final o in _tourOrders) {
      points.add(o.destinationLatLng);
    }
    if (points.isEmpty) return;

    _isTrackingCamera = false;
    notifyListeners();

    if (points.length == 1) {
      mapController.move(points.first, 15.0);
      return;
    }

    try {
      final bounds = LatLngBounds.fromPoints(points);
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.only(
            left: 48,
            right: 48,
            top: 140,
            bottom: 240,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[NavigationController] Warning fitAllStops: $e');
    }
  }

  // ── Cycle de livraison ─────────────────────────────────────────
  Future<void> completeDelivery() async {
    try {
      await _orderService.marquerLivree(order);
    } catch (_) {
      try {
        _orderService.advanceStatus(order);
      } catch (_) {}
    }

    // Met à jour la commande livrée dans la liste de tournée
    final idx = _tourOrders.indexWhere((o) => o.id == order.id);
    if (idx != -1) {
      if (!_tourOrders[idx].isDelivered) {
        _tourOrders[idx].markAsDelivered();
      }
    }

    // Vérifie s'il reste d'autres commandes à livrer dans la tournée
    final remaining = _tourOrders.where((o) => !o.isDelivered).toList();
    if (remaining.isNotEmpty) {
      // Passer automatiquement à la commande suivante
      await selectOrder(remaining.first);
    } else {
      DelivererLocationService().updateCurrentOrder(null);

      await _locationPublisher.publishLocation(
        location: _currentLocation ??
            DelivererLocation(
              latitude: destination.latitude,
              longitude: destination.longitude,
              heading: 0,
              speed: 0,
              timestamp: DateTime.now(),
            ),
        currentOrderId: null,
        vehicleInfo: vehicleInfo,
      );

      await _locationSub?.cancel();
      _locationSub = null;
      await _locationService.stopLocationStream();

      _isDelivered = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _locationService.dispose();
    _routingService.dispose();
    super.dispose();
  }
}
