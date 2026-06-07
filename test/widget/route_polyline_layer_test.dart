import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/theme.dart';

void main() {
  test('route polyline layer uses cached geometry when available', () {
    final route = app_route.Route(
      name: 'Cached',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
      displayRoutePointsByZoom:
          '{"12":[[[-41.5,146.5],[-41.55,146.55],[-41.6,146.6]]]}',
      colour: 0xFFFF0000,
    );

    final layer = buildRoutePolylines([route], 12);

    expect(layer.polylines, hasLength(1));
    expect(layer.polylines.single.points, hasLength(3));
    expect(layer.polylines.single.strokeWidth, TrackRouteLineTheme.strokeWidth);
  });

  test(
    'route polyline layer falls back to raw geometry when cache invalid',
    () {
      final route = app_route.Route(
        name: 'Fallback',
        gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
        displayRoutePointsByZoom: '{invalid}',
        colour: 0xFFFF0000,
      );

      final layer = buildRoutePolylines([route], 12);

      expect(layer.polylines, hasLength(1));
      expect(layer.polylines.single.points, route.gpxRoute);
      expect(
        layer.polylines.single.strokeWidth,
        TrackRouteLineTheme.strokeWidth,
      );
    },
  );

  test('draft route builder uses themed stroke width', () {
    final layer = buildDraftRoutePolylines(
      committedPoints: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
      provisionalPoints: const [LatLng(-41.6, 146.6), LatLng(-41.7, 146.7)],
      colour: 0xFF112233,
    );

    expect(layer.polylines, hasLength(2));
    expect(
      layer.polylines.every(
        (polyline) => polyline.strokeWidth == TrackRouteLineTheme.strokeWidth,
      ),
      isTrue,
    );
    expect(
      layer.polylines.every(
        (polyline) => polyline.color == const Color(0xFF112233),
      ),
      isTrue,
    );
  });

  test('selected route renders stacked highlight last', () {
    final routes = [
      app_route.Route(
        id: 1,
        name: 'Route 1',
        gpxRoute: const [LatLng(-41.5, 146.4), LatLng(-41.5, 146.45)],
        displayRoutePointsByZoom: '{"12":[[[-41.5,146.4],[-41.5,146.45]]]}',
        colour: 0xFF112233,
      ),
      app_route.Route(
        id: 2,
        name: 'Route 2',
        gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.5, 146.55)],
        displayRoutePointsByZoom: '{"12":[[[-41.5,146.5],[-41.5,146.55]]]}',
        colour: 0xFF445566,
      ),
    ];

    final layer = buildRoutePolylines(routes, 12, selectedRouteId: 2);

    expect(layer.polylines, hasLength(3));
    expect(
      layer.polylines.first.color,
      const Color(
        0xFF112233,
      ).withValues(alpha: TrackRouteLineTheme.inactiveOpacity),
    );
    expect(layer.polylines[1].color, const Color(0xFF445566));
    expect(
      layer.polylines[1].strokeWidth,
      TrackRouteLineTheme.selectedStrokeWidth,
    );
    expect(
      layer.polylines[1].borderStrokeWidth,
      TrackRouteLineTheme.selectedBorderStrokeWidth,
    );
    expect(
      layer.polylines[1].borderColor,
      TrackRouteLineTheme.selectedBorderColor,
    );
    expect(
      layer.polylines.last.color,
      TrackRouteLineTheme.selectedOverlayColor,
    );
    expect(
      layer.polylines.last.strokeWidth,
      TrackRouteLineTheme.selectedOverlayStrokeWidth,
    );
  });
}
