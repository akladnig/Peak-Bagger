import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/models/route_waypoint.dart';
import 'package:peak_bagger/services/route_repository.dart';

void main() {
  test('saveRoute assigns an id on create and returns the saved entity', () {
    final repository = RouteRepository.test(InMemoryRouteStorage());
    final route = Route(
      name: 'Created Route',
      desc: 'Created route description',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
    );

    final saved = repository.saveRoute(route);

    expect(saved.id, greaterThan(0));
    expect(repository.getAllRoutes().single.id, saved.id);
    expect(repository.getAllRoutes().single.name, 'Created Route');
    expect(repository.getAllRoutes().single.desc, 'Created route description');
  });

  test('saveRoute preserves id on update', () {
    final repository = RouteRepository.test(InMemoryRouteStorage());
    final created = repository.saveRoute(
      Route(
        name: 'Original Route',
        desc: 'Original route description',
        gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
      ),
    );

    created.name = 'Updated Route';
    created.desc = 'Updated route description';
    final updated = repository.saveRoute(created);

    expect(updated.id, created.id);
    expect(repository.getAllRoutes(), hasLength(1));
    expect(repository.getAllRoutes().single.name, 'Updated Route');
    expect(repository.getAllRoutes().single.desc, 'Updated route description');
  });

  test('route waypoint metadata round-trips through JSON', () {
    final route = Route(
      name: 'Waypoint Route',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
      routeWaypoints: const [
        RouteWaypoint(
          latitude: -41.6,
          longitude: 146.6,
          label: 'Waypoint 1',
          sequence: 1,
          isPeakDerived: false,
        ),
      ],
    );

    final encoded = route.routeWaypointsJson;
    final decoded = Route(name: 'Decoded Route')..routeWaypointsJson = encoded;

    expect(encoded, contains('Waypoint 1'));
    expect(decoded.routeWaypoints, hasLength(1));
    expect(decoded.routeWaypoints.single, route.routeWaypoints.single);
  });
}
