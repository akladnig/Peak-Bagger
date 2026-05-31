import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../core/constants.dart';

class TrackDisplayCacheBuilder {
  static const minZoom = MapConstants.trackMinZoom;
  static const maxZoom = MapConstants.trackMaxZoom;
  static const _epsilon = 2.0;
  static const _tileSize = 256.0;

  static String buildJson(List<List<LatLng>> segments) {
    final caches = <String, List<List<List<double>>>>{};
    for (var zoom = minZoom; zoom <= maxZoom; zoom++) {
      caches['$zoom'] = _encodeSegments(_simplifyForZoom(segments, zoom));
    }
    return jsonEncode(caches);
  }

  static List<List<LatLng>> _simplifyForZoom(
    List<List<LatLng>> segments,
    int zoom,
  ) {
    return segments
        .map((segment) => _simplifySegment(segment, zoom))
        .toList(growable: false);
  }

  static List<LatLng> _simplifySegment(List<LatLng> segment, int zoom) {
    if (segment.length <= 2) {
      return List<LatLng>.from(segment, growable: false);
    }

    final projected = segment
        .map((point) => _project(point, zoom))
        .toList(growable: false);
    final keep = <int>{0, segment.length - 1};
    _markKeep(projected, 0, projected.length - 1, keep);
    final ordered = keep.toList()..sort();
    return ordered.map((index) => segment[index]).toList(growable: false);
  }

  static void _markKeep(
    List<({double x, double y})> projected,
    int start,
    int end,
    Set<int> keep,
  ) {
    if (end - start <= 1) {
      return;
    }

    final startPoint = projected[start];
    final endPoint = projected[end];
    var maxDistance = -1.0;
    var maxIndex = -1;

    for (var i = start + 1; i < end; i++) {
      final distance = _perpendicularDistance(
        projected[i],
        startPoint,
        endPoint,
      );
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    if (maxDistance > _epsilon && maxIndex != -1) {
      keep.add(maxIndex);
      _markKeep(projected, start, maxIndex, keep);
      _markKeep(projected, maxIndex, end, keep);
    }
  }

  static ({double x, double y}) _project(LatLng point, int zoom) {
    final scale = _tileSize * math.pow(2, zoom).toDouble();
    final x = (point.longitude + 180.0) / 360.0 * scale;
    final sinLatitude = math
        .sin(point.latitude * math.pi / 180.0)
        .clamp(-0.9999, 0.9999);
    final y =
        (0.5 -
            math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi)) *
        scale;
    return (x: x, y: y);
  }

  static double _perpendicularDistance(
    ({double x, double y}) point,
    ({double x, double y}) start,
    ({double x, double y}) end,
  ) {
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    if (dx == 0 && dy == 0) {
      return math.sqrt(
        math.pow(point.x - start.x, 2) + math.pow(point.y - start.y, 2),
      );
    }

    final numerator =
        (dy * point.x - dx * point.y + end.x * start.y - end.y * start.x).abs();
    final denominator = math.sqrt(dx * dx + dy * dy);
    return numerator / denominator;
  }

  static List<List<List<double>>> _encodeSegments(List<List<LatLng>> segments) {
    return segments
        .map(
          (segment) => segment
              .map((point) => [point.latitude, point.longitude])
              .toList(growable: false),
        )
        .toList(growable: false);
  }
}
