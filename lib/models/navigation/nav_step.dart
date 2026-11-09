import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Représente une étape de guidage virage par virage (Turn-by-Turn) issue d'OSRM.
class NavStep {
  final String instruction;
  final String maneuverType;
  final String? modifier;
  final String streetName;
  final double distanceMeters;
  final double durationSeconds;
  final LatLng location;

  const NavStep({
    required this.instruction,
    required this.maneuverType,
    this.modifier,
    required this.streetName,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
  });

  /// Construit une étape à partir du JSON brut d'un step OSRM
  factory NavStep.fromOsrm(Map<String, dynamic> json) {
    final distance = (json['distance'] as num?)?.toDouble() ?? 0.0;
    final duration = (json['duration'] as num?)?.toDouble() ?? 0.0;
    final name = (json['name'] as String?)?.trim() ?? '';
    final maneuver = json['maneuver'] as Map<String, dynamic>? ?? {};
    final type = (maneuver['type'] as String?) ?? 'turn';
    final modifier = maneuver['modifier'] as String?;

    LatLng stepLocation = const LatLng(0, 0);
    final rawLoc = maneuver['location'] as List<dynamic>?;
    if (rawLoc != null && rawLoc.length >= 2) {
      // OSRM renvoie [longitude, latitude]
      final lng = (rawLoc[0] as num).toDouble();
      final lat = (rawLoc[1] as num).toDouble();
      stepLocation = LatLng(lat, lng);
    }

    final instruction = _buildFrenchInstruction(type, modifier, name);

    return NavStep(
      instruction: instruction,
      maneuverType: type,
      modifier: modifier,
      streetName: name.isNotEmpty ? name : 'Route sans nom',
      distanceMeters: distance,
      durationSeconds: duration,
      location: stepLocation,
    );
  }

  /// Génère une instruction vocale et textuelle claire en français
  static String _buildFrenchInstruction(String type, String? modifier, String name) {
    final street = name.isNotEmpty ? ' sur $name' : '';
    switch (type) {
      case 'depart':
        return 'Prenez le départ$street';
      case 'arrive':
        return 'Vous êtes arrivé à destination$street';
      case 'roundabout':
      case 'rotary':
        return 'Prenez le rond-point$street';
      case 'turn':
      case 'end of road':
        switch (modifier) {
          case 'left':
            return 'Tournez à gauche$street';
          case 'right':
            return 'Tournez à droite$street';
          case 'sharp left':
            return 'Tournez franchement à gauche$street';
          case 'sharp right':
            return 'Tournez franchement à droite$street';
          case 'slight left':
            return 'Serrez à gauche$street';
          case 'slight right':
            return 'Serrez à droite$street';
          case 'straight':
            return 'Continuez tout droit$street';
          case 'uturn':
            return 'Faites demi-tour dès que possible';
          default:
            return 'Tournez$street';
        }
      case 'new name':
      case 'continue':
        return 'Continuez tout droit$street';
      case 'fork':
        if (modifier == 'left' || modifier == 'slight left') {
          return 'Prenez la bifurcation à gauche$street';
        }
        return 'Prenez la bifurcation à droite$street';
      default:
        return 'Continuez sur votre itinéraire$street';
    }
  }

  /// Icône Material adaptée à la manœuvre
  IconData get icon {
    switch (maneuverType) {
      case 'depart':
        return Icons.navigation_rounded;
      case 'arrive':
        return Icons.place_rounded;
      case 'roundabout':
      case 'rotary':
        return Icons.change_circle_outlined;
      case 'fork':
        return modifier?.contains('left') == true
            ? Icons.fork_left_rounded
            : Icons.fork_right_rounded;
      case 'turn':
      default:
        switch (modifier) {
          case 'left':
          case 'sharp left':
            return Icons.turn_left_rounded;
          case 'right':
          case 'sharp right':
            return Icons.turn_right_rounded;
          case 'slight left':
            return Icons.turn_slight_left_rounded;
          case 'slight right':
            return Icons.turn_slight_right_rounded;
          case 'straight':
            return Icons.straight_rounded;
          case 'uturn':
            return Icons.u_turn_left_rounded;
          default:
            return Icons.straight_rounded;
        }
    }
  }

  /// Formatage convivial de la distance restante jusqu'à cette manœuvre
  String formatDistance([double? customDistanceMeters]) {
    final d = customDistanceMeters ?? distanceMeters;
    if (d < 1000) {
      return 'Dans ${(d / 10).round() * 10} m';
    } else {
      return 'Dans ${(d / 1000).toStringAsFixed(1)} km';
    }
  }
}
