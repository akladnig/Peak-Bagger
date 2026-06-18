import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
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

  test('buildVisibleMgrsGridGeometry keeps 1 km lines at viewport edges', () {
    final visibleBounds = _boundsFromUtm(
      westEasting: 440000,
      eastEasting: 445000,
      southNorthing: 5399000,
      northNorthing: 5404000,
    );

    final geometry = buildVisibleMgrsGridGeometry(
      visibleBounds: visibleBounds,
      zoom: 15,
      latitude: -41.5,
    );
    final verticalLine = geometry.lines.firstWhere(
      (line) =>
          (line.last.latitude - line.first.latitude).abs() >
          (line.last.longitude - line.first.longitude).abs(),
    );
    final bottomLabel = geometry.labels.firstWhere(
      (label) => label.side == MapGridLabelSide.bottom,
    );
    final topLabel = geometry.labels.firstWhere(
      (label) => label.side == MapGridLabelSide.top,
    );

    expect(verticalLine.first.latitude, closeTo(bottomLabel.anchor.latitude, 0.001));
    expect(verticalLine.last.latitude, closeTo(topLabel.anchor.latitude, 0.001));
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

LatLngBounds _boundsFromUtm({
  required int westEasting,
  required int eastEasting,
  required int southNorthing,
  required int northNorthing,
}) {
  final southWest = _latLngFromUtm(westEasting, southNorthing);
  final northWest = _latLngFromUtm(westEasting, northNorthing);
  final southEast = _latLngFromUtm(eastEasting, southNorthing);
  final northEast = _latLngFromUtm(eastEasting, northNorthing);
  return LatLngBounds.fromPoints([southWest, northWest, southEast, northEast]);
}

LatLng _latLngFromUtm(int easting, int northing) {
  final utm = mgrs.UTM(
    easting: easting.toDouble(),
    northing: northing.toDouble(),
    zoneLetter: 'G',
    zoneNumber: 55,
  );
  final coords = mgrs.Mgrs.toPoint(mgrs.Mgrs.encode(utm, 5));
  return LatLng(coords[1], coords[0]);
}
