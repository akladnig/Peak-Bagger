import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';

import 'map_route_robot.dart';

void main() {
  testWidgets('basemap drawer selects region-valid basemap after fallback', (
    tester,
  ) async {
    final robot = MapRouteRobot(
      tester,
      MapState(
        center: const LatLng(-37.75984, 158.7979),
        cursorPoint: const LatLng(-37.75984, 158.7979),
        zoom: 12,
        basemap: Basemap.tasmap50k,
      ),
      routePlanningOutcomes: const [],
    );
    addTearDown(robot.dispose);

    await robot.pumpApp();
    await robot.openMap();

    await tester.tap(find.byKey(const Key('show-basemaps-fab')));
    await tester.pumpAndSettle();

    expect(robot.container().read(mapProvider).basemap, Basemap.tracestrack);
    expect(find.byKey(const Key('basemaps-drawer')), findsOneWidget);
    expect(find.byKey(const Key('basemap-option-nswTopo')), findsOneWidget);

    await tester.tap(find.byKey(const Key('basemap-option-nswTopo')));
    await tester.pumpAndSettle();

    expect(robot.container().read(mapProvider).basemap, Basemap.nswTopo);
    expect(find.byKey(const Key('basemaps-drawer')), findsNothing);
  });

  testWidgets('basemap drawer selects slovenia ortofoto in slovenia', (
    tester,
  ) async {
    final robot = MapRouteRobot(
      tester,
      MapState(
        center: const LatLng(46.05, 14.5),
        cursorPoint: const LatLng(46.05, 14.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
      routePlanningOutcomes: const [],
    );
    addTearDown(robot.dispose);

    await robot.pumpApp();
    await robot.openMap();

    await tester.tap(find.byKey(const Key('show-basemaps-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('basemaps-drawer')), findsOneWidget);
    expect(find.byKey(const Key('basemap-option-sloveniaOrtofoto')), findsOneWidget);

    await tester.tap(find.byKey(const Key('basemap-option-sloveniaOrtofoto')));
    await tester.pumpAndSettle();

    expect(
      robot.container().read(mapProvider).basemap,
      Basemap.sloveniaOrtofoto,
    );
    expect(find.byKey(const Key('basemaps-drawer')), findsNothing);
  });
}
