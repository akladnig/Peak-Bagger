import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/route_planner.dart';

import 'route_graph_robot.dart';

void main() {
  testWidgets('route graph journey shows a cold-start loading state', (
    tester,
  ) async {
    final loadCompleter = Completer<PlannedRouteSegment>();
    final robot = RouteGraphRobot(
      tester,
      _baseState(),
      routePlanningOutcomes: [loadCompleter.future],
    );

    await robot.pumpApp();
    await robot.openMap();
    await robot.enterRouteMode();

    await robot.tapRoutePoint(const Offset(-40, 0));
    await robot.tapRoutePoint(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 300));

    robot.expectLoadingVisible();

    loadCompleter.complete(
      const PlannedRouteSegment(
        points: [
          LatLng(-41.5, 146.5),
          LatLng(-41.55, 146.55),
          LatLng(-41.6, 146.6),
        ],
        distanceMeters: 1234.5,
      ),
    );
    await tester.pumpAndSettle();

    robot.expectRouteReady();
    await robot.enterRouteName('Cold Start Route');
    await robot.saveRoute();

    expect(robot.routeBottomSheet, findsNothing);
    expect(robot.savedRoutes(), hasLength(1));
  });

  testWidgets('route graph journey stays warm on a cached follow-up segment', (
    tester,
  ) async {
    final loadCompleter = Completer<PlannedRouteSegment>();
    final robot = RouteGraphRobot(
      tester,
      _baseState(),
      routePlanningOutcomes: [
        loadCompleter.future,
        const PlannedRouteSegment(
          points: [
            LatLng(-41.6, 146.6),
            LatLng(-41.65, 146.65),
            LatLng(-41.7, 146.7),
          ],
          distanceMeters: 900,
        ),
      ],
    );

    await robot.pumpApp();
    await robot.openMap();
    await robot.enterRouteMode();

    await robot.tapRoutePoint(const Offset(-40, 0));
    await robot.tapRoutePoint(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 300));
    robot.expectLoadingVisible();

    loadCompleter.complete(
      const PlannedRouteSegment(
        points: [
          LatLng(-41.5, 146.5),
          LatLng(-41.55, 146.55),
          LatLng(-41.6, 146.6),
        ],
        distanceMeters: 1234.5,
      ),
    );
    await tester.pumpAndSettle();

    await robot.tapRoutePoint(const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(robot.routeLoadingText, findsNothing);
    expect(robot.routeErrorText, findsNothing);
    expect(robot.routeDistanceText, findsOneWidget);
  });

  testWidgets('route graph journey retries after load failure', (tester) async {
    final robot = RouteGraphRobot(
      tester,
      _baseState(),
      routePlanningOutcomes: [
        const RoutePlanningResult(
          status: RoutePlanningStatus.failed,
          points: [],
          distanceMeters: 0,
          startAnchor: null,
          endAnchor: null,
          errorMessage: 'Local route graph unavailable.',
          failureKind: RoutePlanningFailureKind.routeGraphLoad,
        ),
        const PlannedRouteSegment(
          points: [
            LatLng(-41.5, 146.5),
            LatLng(-41.55, 146.55),
            LatLng(-41.6, 146.6),
          ],
          distanceMeters: 1234.5,
        ),
      ],
    );

    await robot.pumpApp();
    await robot.openMap();
    await robot.enterRouteMode();

    await robot.tapRoutePoint(const Offset(-40, 0));
    await robot.tapRoutePoint(const Offset(40, 0));
    await tester.pumpAndSettle();

    robot.expectErrorVisible('Local route graph unavailable.');
    robot.expectRetryVisible();

    await robot.tapRetry();

    robot.expectRouteReady();
    expect(robot.routeRetryButton, findsNothing);
    await robot.enterRouteName('Retry Route');
    await robot.saveRoute();

    expect(robot.savedRoutes(), hasLength(1));
  });
}

MapState _baseState() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
  );
}
