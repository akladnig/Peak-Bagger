import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/route_planner.dart';

import 'map_route_robot.dart';

void main() {
  testWidgets('route journey drafts two segments and saves the route', (
    tester,
  ) async {
    final robot = MapRouteRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      routePlanningOutcomes: const [
        PlannedRouteSegment(
          points: [
            LatLng(-41.5, 146.5),
            LatLng(-41.55, 146.55),
            LatLng(-41.6, 146.6),
          ],
          distanceMeters: 1000,
        ),
        PlannedRouteSegment(
          points: [
            LatLng(-41.6, 146.6),
            LatLng(-41.65, 146.65),
            LatLng(-41.7, 146.7),
          ],
          distanceMeters: 1200,
        ),
      ],
    );

    await robot.pumpApp();
    await robot.openMap();
    await robot.enterRouteMode();
    expect(robot.routeBottomSheet, findsOneWidget);

    await robot.tapRoutePoint(const Offset(-40, 0));
    await robot.tapRoutePoint(const Offset(40, 0));

    await robot.tapRoutePoint(const Offset(80, 0));

    await robot.enterRouteName('Robot Route');
    await robot.saveRoute();

    expect(robot.routeBottomSheet, findsNothing);
    expect(robot.savedRoutes(), hasLength(1));
    expect(robot.savedRoutes().single.gpxRoute, hasLength(5));
    expect(robot.container().read(mapProvider).showRoutes, isTrue);
  });
}
