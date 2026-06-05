import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/map_polygon_asset.dart';
import 'package:peak_bagger/widgets/map_chart_hover_marker.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/services/map_grid_geometry.dart';
import 'package:peak_bagger/theme.dart';

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

  test('buildPolygonAssetLayer uses a stable layer key', () {
    final layer = buildPolygonAssetLayer([
      const MapPolygonAsset(
        assetPath: 'assets/polygons/tasmania.poly',
        name: 'Tasmania',
        points: [
          LatLng(-43.643, 143.833),
          LatLng(-39.579, 148.482),
          LatLng(-41.5, 146.5),
        ],
      ),
    ]);

    expect(layer.key, const ValueKey('asset-polygon-layer'));
    expect(layer.polygons, hasLength(1));
    expect(layer.polygons.single.color, const Color(0x1AFF9800));
    expect(layer.polygons.single.borderColor, const Color(0xFFFF9800));
    expect(layer.polygons.single.points, const [
      LatLng(-43.643, 143.833),
      LatLng(-39.579, 148.482),
      LatLng(-41.5, 146.5),
    ]);
  });

  test('buildChartHoverMarkerLayer uses a stable layer key', () {
    final layer = buildChartHoverMarkerLayer(const LatLng(-41.5, 146.5));

    expect(layer.key, const Key('map-chart-hover-marker-layer'));
    expect(layer.markers, hasLength(1));
    expect(layer.markers.single.point, const LatLng(-41.5, 146.5));
    expect(layer.markers.single.width, MapChartHoverDotTheme.size);
    expect(layer.markers.single.height, MapChartHoverDotTheme.size);
  });
}
