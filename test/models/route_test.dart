import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart';

void main() {
  test('gpxRouteJson round-trips valid points', () {
    final route = Route(
      name: 'Test Route',
      gpxRoute: [const LatLng(-41.1, 145.2), const LatLng(-41.2, 145.3)],
    );

    final decoded = Route(name: 'Decoded')..gpxRouteJson = route.gpxRouteJson;

    expect(route.gpxRouteJson, '[[-41.1,145.2],[-41.2,145.3]]');
    expect(decoded.gpxRoute, [
      const LatLng(-41.1, 145.2),
      const LatLng(-41.2, 145.3),
    ]);
  });

  test('gpxRouteJson falls back on malformed input', () {
    final route = Route(name: 'Decoded')
      ..gpxRouteJson = '[[-41.1,145.2],["bad"], [1], [1,2,3], [null, 145.3]]';

    expect(route.gpxRoute, [const LatLng(-41.1, 145.2)]);

    final empty = Route(name: 'Empty')..gpxRouteJson = 'not-json';

    expect(empty.gpxRoute, isEmpty);
  });
}
