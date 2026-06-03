import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/screens/map_screen_layers.dart';

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
    },
  );

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
    expect(layer.polylines.first.color, const Color(0x99112233));
    expect(layer.polylines[1].color, const Color(0xFF445566));
    expect(layer.polylines[1].strokeWidth, 4.0);
    expect(layer.polylines[1].borderStrokeWidth, 2.0);
    expect(layer.polylines[1].borderColor, const Color(0x66000000));
    expect(layer.polylines.last.color, Colors.white);
    expect(layer.polylines.last.strokeWidth, 0.6);
  });
}
