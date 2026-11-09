import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../models/navigation/nav_step.dart';
import '../../models/navigation/route_info.dart';
import '../../utils/polyline_decoder.dart';

/// Service de calcul d'itinéraire routier basé sur l'API OSRM (Open Source Routing Machine).
class OsrmRoutingService {
  final http.Client _client;

  OsrmRoutingService({http.Client? client}) : _client = client ?? http.Client();

  /// Calcule l'itinéraire complet entre deux points avec les instructions de manœuvre.
  Future<RouteInfo?> calculateRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=polyline&steps=true',
    );

    try {
      final response = await _client.get(url).timeout(
        const Duration(seconds: 8),
      );

      if (response.statusCode != 200) {
        debugPrint('[OsrmRoutingService] Statut HTTP non-200 : ${response.statusCode}');
        return _fallbackDirectRoute(origin, destination);
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return _fallbackDirectRoute(origin, destination);
      }

      final primaryRoute = routes.first as Map<String, dynamic>;
      final encodedPolyline = primaryRoute['geometry'] as String? ?? '';
      final distance = (primaryRoute['distance'] as num?)?.toDouble() ?? 0.0;
      final duration = (primaryRoute['duration'] as num?)?.toDouble() ?? 0.0;

      // Décodage des points de la route
      final points = PolylineDecoder.decode(encodedPolyline);

      // Extraction des étapes détaillées (steps)
      final List<NavStep> steps = [];
      final legs = primaryRoute['legs'] as List<dynamic>?;
      if (legs != null && legs.isNotEmpty) {
        final firstLeg = legs.first as Map<String, dynamic>;
        final rawSteps = firstLeg['steps'] as List<dynamic>? ?? [];
        for (final s in rawSteps) {
          if (s is Map<String, dynamic>) {
            steps.add(NavStep.fromOsrm(s));
          }
        }
      }

      if (steps.isEmpty) {
        steps.add(
          NavStep(
            instruction: 'Rejoignez la destination',
            maneuverType: 'arrive',
            streetName: 'Destination',
            distanceMeters: distance,
            durationSeconds: duration,
            location: destination,
          ),
        );
      }

      return RouteInfo(
        points: points.isNotEmpty ? points : [origin, destination],
        steps: steps,
        totalDistanceMeters: distance,
        totalDurationSeconds: duration,
        remainingDistanceMeters: distance,
        remainingDurationSeconds: duration,
      );
    } catch (e) {
      debugPrint('[OsrmRoutingService] Erreur lors de l\'appel OSRM : $e');
      return _fallbackDirectRoute(origin, destination);
    }
  }

  /// Itinéraire de repli en ligne directe en cas d'indisponibilité du serveur OSRM
  RouteInfo _fallbackDirectRoute(LatLng origin, LatLng destination) {
    const distanceUtil = Distance();
    final distance = distanceUtil.as(LengthUnit.Meter, origin, destination);
    final duration = distance / 8.33; // 30 km/h en ville

    return RouteInfo(
      points: [origin, destination],
      steps: [
        NavStep(
          instruction: 'Dirigez-vous vers le point de livraison',
          maneuverType: 'depart',
          streetName: 'Itinéraire direct',
          distanceMeters: distance,
          durationSeconds: duration,
          location: origin,
        ),
      ],
      totalDistanceMeters: distance,
      totalDurationSeconds: duration,
      remainingDistanceMeters: distance,
      remainingDurationSeconds: duration,
    );
  }

  void dispose() {
    _client.close();
  }
}
