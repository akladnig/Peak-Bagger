import 'dart:convert';

import 'package:latlong2/latlong.dart';

typedef ParsedPolygonData = ({String name, List<LatLng> vertices});

class PolygonTextParseResult {
  const PolygonTextParseResult.success(this.polygon) : error = null;

  const PolygonTextParseResult.failure(this.error) : polygon = null;

  final ParsedPolygonData? polygon;
  final String? error;

  bool get isSuccess => polygon != null;
}

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

PolygonTextParseResult parsePolygonText(String contents) {
  final lines = const LineSplitter()
      .convert(contents)
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  if (lines.length < 4) {
    return const PolygonTextParseResult.failure(
      'Polygon text does not contain a complete ring.',
    );
  }

  final name = lines.first;
  final vertices = <LatLng>[];

  var index = 2;
  for (; index < lines.length; index++) {
    final line = lines[index];
    if (line == 'END') {
      break;
    }

    final parts = line.split(RegExp(r'\s+'));
    if (parts.length != 2) {
      return PolygonTextParseResult.failure(
        'Polygon text has an invalid coordinate line: $line',
      );
    }

    final longitude = double.tryParse(parts[0]);
    final latitude = double.tryParse(parts[1]);
    if (longitude == null || latitude == null) {
      return PolygonTextParseResult.failure(
        'Polygon text has an invalid coordinate line: $line',
      );
    }

    vertices.add(LatLng(latitude, longitude));
  }

  if (index >= lines.length || lines[index] != 'END') {
    return const PolygonTextParseResult.failure(
      'Polygon text is missing the end of the first ring.',
    );
  }

  try {
    final normalizedVertices = List<LatLng>.unmodifiable(
      _normalizeVertices(vertices),
    );

    for (final line in lines.skip(index + 1)) {
      if (line != 'END') {
        return const PolygonTextParseResult.failure(
          'Polygon text contains unsupported additional rings.',
        );
      }
    }

    return PolygonTextParseResult.success((
      name: name,
      vertices: normalizedVertices,
    ));
  } on ArgumentError catch (error) {
    final message = error.message?.toString();
    return PolygonTextParseResult.failure(
      message == 'Polygon must not be empty.'
          ? 'Polygon text does not contain a complete ring.'
          : 'Polygon text needs at least 3 distinct vertices.',
    );
  }
}

List<LatLng> _normalizeVertices(List<LatLng> vertices) {
  if (vertices.isEmpty) {
    throw ArgumentError.value(
      vertices,
      'vertices',
      'Polygon must not be empty.',
    );
  }

  final normalizedVertices = List<LatLng>.of(vertices, growable: true);
  if (normalizedVertices.length >= 2 &&
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
