import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/route_repository.dart';

import 'route_info_robot.dart';

void main() {
  testWidgets('route journey opens the shared panel and closes cleanly', (
    tester,
  ) async {
    final route = routeFixture(id: 1, name: 'Robot Route');
    final robot = RouteInfoRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
      ),
      routeRepository: RouteRepository.test(InMemoryRouteStorage([route])),
    );

    await robot.pumpApp();
    await robot.hoverRoute();
    await robot.clickRoute();

    robot.expectSelectedRoute(1);
    robot.expectRoutePanelVisible('Robot Route');

    await robot.closeRoutePanel();

    robot.expectRoutePanelHidden();
  });

  testWidgets('route journey clears stale selection when the route disappears', (
    tester,
  ) async {
    final route = routeFixture(id: 1, name: 'Stale Route');
    final repository = RouteRepository.test(InMemoryRouteStorage([route]));
    final robot = RouteInfoRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
      ),
      routeRepository: repository,
    );

    await robot.pumpApp();
    await robot.hoverRoute();
    await robot.clickRoute();

    robot.expectSelectedRoute(1);
    robot.expectRoutePanelVisible('Stale Route');

    await robot.deleteRouteAndRefresh(1);

    robot.expectRoutePanelHidden();
  });
}
