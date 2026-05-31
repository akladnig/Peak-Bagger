import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../core/constants.dart';

class TrackDisplayCacheBuilder {
  static const minZoom = MapConstants.trackMinZoom;
  static const maxZoom = MapConstants.trackMaxZoom;

  static String buildJson(List<List<LatLng>> segments) {
    final caches = <String, List<List<List<double>>>>{};
    for (var zoom = minZoom; zoom <= maxZoom; zoom++) {
      caches['$zoom'] = encodeDisplaySegments(
        simplifyDisplaySegmentsForZoom(segments, zoom),
      );
    }
    return jsonEncode(caches);
  }
}

List<List<LatLng>> simplifyDisplaySegmentsForZoom(
  List<List<LatLng>> segments,
  int zoom,
) {
  return segments
      .map((segment) => simplifyDisplaySegmentForZoom(segment, zoom))
      .toList(growable: false);
}

List<LatLng> simplifyDisplaySegmentForZoom(List<LatLng> segment, int zoom) {
  if (segment.length <= 2) {
    return List<LatLng>.from(segment, growable: false);
  }

  final projected = segment
      .map((point) => _projectDisplayPoint(point, zoom))
      .toList(growable: false);
  final keep = <int>{0, segment.length - 1};
  _markDisplaySegmentKeep(projected, 0, projected.length - 1, keep);
  final ordered = keep.toList()..sort();
  return ordered.map((index) => segment[index]).toList(growable: false);
}

void _markDisplaySegmentKeep(
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
    final distance = _displayPerpendicularDistance(
      projected[i],
      startPoint,
      endPoint,
    );
    if (distance > maxDistance) {
      maxDistance = distance;
      maxIndex = i;
    }
  }

  if (maxDistance > _displaySimplifyEpsilon && maxIndex != -1) {
    keep.add(maxIndex);
    _markDisplaySegmentKeep(projected, start, maxIndex, keep);
    _markDisplaySegmentKeep(projected, maxIndex, end, keep);
  }
}

({double x, double y}) _projectDisplayPoint(LatLng point, int zoom) {
  final scale = _displayTileSize * math.pow(2, zoom).toDouble();
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

double _displayPerpendicularDistance(
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

List<List<List<double>>> encodeDisplaySegments(List<List<LatLng>> segments) {
  return segments
      .map(
        (segment) => segment
            .map((point) => [point.latitude, point.longitude])
            .toList(growable: false),
      )
      .toList(growable: false);
}

const _displaySimplifyEpsilon = 2.0;
const _displayTileSize = 256.0;
