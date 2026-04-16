import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/tasmap50k.dart';

String? formatTasmapPolygonLabel(Tasmap50k map) {
  final name = map.name.trim();
  final series = map.series.trim();

  if (name.isEmpty && series.isEmpty) {
    return null;
  }

  if (name.isEmpty) {
    return series;
  }

  if (series.isEmpty) {
    return name;
  }

  return '$name\n$series';
}

LatLng? tasmapPolygonLabelAnchor(List<LatLng> points) {
  if (points.length < 4) {
    return null;
  }

  final minLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
  final maxLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
  final maxLng = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
  final minLng = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);

  final latInset = ((maxLat - minLat).abs() * 0.08).clamp(0.0001, 0.02);
  final lngInset = ((maxLng - minLng).abs() * 0.08).clamp(0.0001, 0.02);

  return LatLng(minLat + latInset, maxLng - lngInset);
}

PolygonLabelPlacementCalculator? tasmapPolygonLabelPlacementCalculator(
  List<LatLng> points,
) {
  final anchor = tasmapPolygonLabelAnchor(points);
  if (anchor == null) {
    return null;
  }

  return _TasmapPolygonLabelPlacementCalculator(anchor);
}

TextStyle tasmapPolygonLabelStyle(Color color) {
  return TextStyle(
    fontSize: 12,
    color: color,
    shadows: const [
      Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 1)),
      Shadow(color: Colors.black26, blurRadius: 3, offset: Offset(-1, -1)),
    ],
  );
}

class _TasmapPolygonLabelPlacementCalculator
    implements PolygonLabelPlacementCalculator {
  const _TasmapPolygonLabelPlacementCalculator(this.anchor);

  final LatLng anchor;

  @override
  LatLng call(Polygon<Object> polygon) => anchor;

  @override
  bool operator ==(Object other) =>
      other is _TasmapPolygonLabelPlacementCalculator && other.anchor == anchor;

  @override
  int get hashCode => anchor.hashCode;
}
