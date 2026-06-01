import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/services/map_grid_geometry.dart';

void main() {
  test('buildTrailPolylines uses a stable layer key', () {
    final layer = buildTrailPolylines([
      Polyline(
        points: const [
          LatLng(-41.5, 146.5),
          LatLng(-41.6, 146.6),
        ],
      ),
    ]);

    expect(layer.key, const ValueKey('trail-polyline-layer'));
    expect(layer.polylines, hasLength(1));
    expect(layer.polylines.single.points, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.6, 146.6),
    ]);
  });

  test('buildMgrsGridLayer uses a stable layer key', () {
    final layer = buildMgrsGridLayer(
      const MapMgrsGridGeometry(
        lines: [
          [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
        ],
      ),
    );

    expect(layer.key, const ValueKey('mgrs-grid-layer'));
    expect(layer.polylines, hasLength(1));
    expect(layer.polylines.single.points, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.6, 146.6),
    ]);
  });
}
