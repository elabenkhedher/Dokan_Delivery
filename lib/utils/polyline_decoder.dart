import 'package:latlong2/latlong.dart';

/// Décodeur d'algorithme Polyline encodée (précision standard 1e-5 OSRM / OpenStreetMap).
class PolylineDecoder {
  /// Décode une chaîne polyline compressée en une liste ordonnée de coordonnées [LatLng].
  static List<LatLng> decode(String encoded) {
    final List<LatLng> points = [];
    if (encoded.isEmpty) return points;

    int index = 0;
    final int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
