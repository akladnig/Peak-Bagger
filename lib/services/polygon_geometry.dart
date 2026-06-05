import 'package:latlong2/latlong.dart';

bool polygonContainsPoint(LatLng point, List<LatLng> vertices) {
  final normalizedVertices = _normalizeVertices(vertices);
  var inside = false;

  for (
    var i = 0, j = normalizedVertices.length - 1;
    i < normalizedVertices.length;
    j = i++
  ) {
    final current = normalizedVertices[i];
    final previous = normalizedVertices[j];
    final intersects =
        (current.latitude > point.latitude) !=
            (previous.latitude > point.latitude) &&
        point.longitude <
            (previous.longitude - current.longitude) *
                    (point.latitude - current.latitude) /
                    (previous.latitude - current.latitude) +
                current.longitude;
    if (intersects) {
      inside = !inside;
    }
  }

  return inside;
}

List<LatLng> _normalizeVertices(List<LatLng> vertices) {
  if (vertices.isEmpty) {
    throw ArgumentError.value(vertices, 'vertices', 'Polygon must not be empty.');
  }

  final normalizedVertices = List<LatLng>.of(vertices, growable: true);
  if (
      normalizedVertices.length >= 2 &&
      _samePoint(normalizedVertices.first, normalizedVertices.last)) {
    normalizedVertices.removeLast();
  }

  final distinctVertices = {
    for (final vertex in normalizedVertices)
      '${vertex.latitude},${vertex.longitude}',
  };
  if (distinctVertices.length < 3) {
    throw ArgumentError.value(
      vertices,
      'vertices',
      'Polygon must contain at least 3 distinct vertices.',
    );
  }

  return normalizedVertices;
}

bool _samePoint(LatLng left, LatLng right) {
  return left.latitude == right.latitude && left.longitude == right.longitude;
}
