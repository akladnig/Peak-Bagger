import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/route_timing_service.dart';

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
    robot.expectRouteEstimatedTime('—');
    robot.expectRoutePolylineVisible(true);

    await robot.toggleRouteVisibility();

    robot.expectRoutePanelVisible('Robot Route');
    robot.expectRoutePolylineVisible(false);

    await robot.toggleRouteVisibility();

    robot.expectRoutePolylineVisible(true);

    await robot.closeRoutePanel();

    robot.expectRoutePanelHidden();
  });

  testWidgets('route journey edits and saves in place', (tester) async {
    final route = routeFixture(id: 1, name: 'Robot Route');
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
    robot.expectRoutePanelVisible('Robot Route');
    robot.expectRouteEstimatedTime('—');

    await robot.tapEditRoute();

    robot.expectRouteDraftVisible();
    robot.expectRoutePanelHidden();

    await robot.enterRouteName('Edited Robot Route');
    await robot.saveRouteDraft();

    robot.expectSelectedRoute(1);
    robot.expectRoutePanelVisible('Edited Robot Route');
    robot.expectRouteEstimatedTime('—');
    robot.expectRouteDraftHidden();
    expect(repository.findById(1)!.name, 'Edited Robot Route');
  });

  testWidgets('route journey cancels edit and restores the panel', (
    tester,
  ) async {
    final route = routeFixture(id: 1, name: 'Robot Route');
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
    await robot.tapEditRoute();

    await robot.enterRouteName('Cancelled Robot Route');
    await robot.cancelRouteDraft();

    robot.expectSelectedRoute(1);
    robot.expectRoutePanelVisible('Robot Route');
    robot.expectRouteEstimatedTime('—');
    robot.expectRouteDraftHidden();
    expect(repository.findById(1)!.name, 'Robot Route');
  });

  testWidgets(
    'route journey clears stale edit state when the route disappears',
    (tester) async {
      final route = routeFixture(id: 1, name: 'Stale Edit Route');
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
      await robot.tapEditRoute();

      robot.expectRouteDraftVisible();
      await robot.deleteRouteAndRefresh(1);

      robot.expectRoutePanelHidden();
      robot.expectRouteDraftHidden();
    },
  );

  testWidgets(
    'route journey clears stale selection when the route disappears',
    (tester) async {
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
    },
  );

  testWidgets('route journey adjusts walking speed and restores it on reopen', (
    tester,
  ) async {
    final route = app_route.Route(
      id: 1,
      name: 'Adjustable Robot Route',
      routeTimingSource: RouteTimingSources.naismith,
      walkingSpeedKmh: 4.0,
      gpxRoute: const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.89)],
      gpxRouteElevations: const [0, 0],
    );
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

    robot.expectRoutePanelVisible('Adjustable Robot Route');
    robot.expectWalkingSpeed('4.0');

    await robot.incrementWalkingSpeed();

    robot.expectWalkingSpeed('4.1');
    expect(repository.findById(1)!.walkingSpeedKmh, 4.1);

    await robot.closeRoutePanel();
    await robot.hoverRoute();
    await robot.clickRoute();

    robot.expectRoutePanelVisible('Adjustable Robot Route');
    robot.expectWalkingSpeed('4.1');
  });
}
