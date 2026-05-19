import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/screens/map_screen_layers.dart';

void main() {
  test('route polyline layer uses cached geometry when available', () {
    final route = app_route.Route(
      name: 'Cached',
      gpxRoute: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.6, 146.6),
      ],
      displayRoutePointsByZoom:
          '{"12":[[[-41.5,146.5],[-41.55,146.55],[-41.6,146.6]]]}',
      colour: 0xFFFF0000,
    );

    final layer = buildRoutePolylines([route], 12);

    expect(layer.polylines, hasLength(1));
    expect(layer.polylines.single.points, hasLength(3));
  });

  test('route polyline layer falls back to raw geometry when cache invalid', () {
    final route = app_route.Route(
      name: 'Fallback',
      gpxRoute: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.6, 146.6),
      ],
      displayRoutePointsByZoom: '{invalid}',
      colour: 0xFFFF0000,
    );

    final layer = buildRoutePolylines([route], 12);

    expect(layer.polylines, hasLength(1));
    expect(layer.polylines.single.points, route.gpxRoute);
  });
}
