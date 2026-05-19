import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/services/route_repository.dart';

void main() {
  test('saveRoute assigns an id on create and returns the saved entity', () {
    final repository = RouteRepository.test(InMemoryRouteStorage());
    final route = Route(
      name: 'Created Route',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
    );

    final saved = repository.saveRoute(route);

    expect(saved.id, greaterThan(0));
    expect(repository.getAllRoutes().single.id, saved.id);
    expect(repository.getAllRoutes().single.name, 'Created Route');
  });

  test('saveRoute preserves id on update', () {
    final repository = RouteRepository.test(InMemoryRouteStorage());
    final created = repository.saveRoute(
      Route(
        name: 'Original Route',
        gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
      ),
    );

    created.name = 'Updated Route';
    final updated = repository.saveRoute(created);

    expect(updated.id, created.id);
    expect(repository.getAllRoutes(), hasLength(1));
    expect(repository.getAllRoutes().single.name, 'Updated Route');
  });
}
