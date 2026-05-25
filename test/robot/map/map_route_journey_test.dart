import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

import 'map_route_robot.dart';

void main() {
  testWidgets('route journey routes from one tap to the peak marker and saves', (
    tester,
  ) async {
    final robot = MapRouteRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: [
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -41.5,
            longitude: 146.5,
          ),
        ],
      ),
      routePlanningOutcomes: const [
        PlannedRouteSegment(
          points: [
            LatLng(-41.5, 146.5),
            LatLng(-41.55, 146.55),
            LatLng(-41.5, 146.5),
          ],
          distanceMeters: 1000,
        ),
      ],
      routeElevationOutcomes: const [
        RouteElevationSummary(
          requestId: 1,
          geometryVersion: 1,
          ascent: 321,
          descent: 210,
          distance3d: 1010,
        ),
      ],
    );

    await robot.pumpApp();
    await robot.openMap();
    await robot.openPeakPopup(6406);
    await robot.enterRouteMode();

    expect(robot.routeToPeakButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(
        find.descendant(
          of: robot.routeToPeakButton,
          matching: find.byType(FilledButton),
        ),
      ).onPressed,
      isNotNull,
    );

    await tester.tap(
      find.descendant(
        of: robot.routeToPeakButton,
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump();
    await robot.tapRoutePoint(const Offset(-40, 0));

    expect(robot.routeDistanceText, findsOneWidget);
    expect(robot.routeAscentText, findsOneWidget);
    expect(find.text('321 m'), findsOneWidget);

    await robot.enterRouteName('Peak Route');
    await robot.saveRoute();

    expect(robot.routeBottomSheet, findsNothing);
    expect(robot.savedRoutes(), hasLength(1));
    expect(robot.savedRoutes().single.gpxRoute, hasLength(3));
    expect(robot.savedRoutes().single.ascent, 321);
    expect(robot.savedRoutes().single.descent, 210);
    expect(robot.container().read(mapProvider).showRoutes, isTrue);
  });

  testWidgets('route journey drafts two segments and saves the route', (
    tester,
  ) async {
    final robot = MapRouteRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        tracks: [
          _routeTrack([
            const LatLng(-41.5, 146.498283),
            const LatLng(-41.5, 146.503433),
          ]),
        ],
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
      routeElevationOutcomes: const [
        RouteElevationSummary(
          requestId: 1,
          geometryVersion: 1,
          ascent: 321,
          descent: 210,
          distance3d: 1010,
        ),
        RouteElevationSummary(
          requestId: 2,
          geometryVersion: 2,
          ascent: 654,
          descent: 432,
          distance3d: 2222,
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

    expect(robot.routeAscentText, findsOneWidget);
    expect(find.text('654 m'), findsOneWidget);
    expect(robot.routeDescentText, findsOneWidget);
    expect(find.text('432 m'), findsOneWidget);

    await robot.enterRouteName('Robot Route');
    await robot.saveRoute();

    expect(robot.routeBottomSheet, findsNothing);
    expect(robot.savedRoutes(), hasLength(1));
    expect(robot.savedRoutes().single.gpxRoute, hasLength(5));
    expect(robot.savedRoutes().single.ascent, 654);
    expect(robot.savedRoutes().single.descent, 432);
    expect(robot.savedRoutes().single.distance3d, 2222);
    expect(robot.container().read(mapProvider).showRoutes, isTrue);
  });

  testWidgets('route journey falls back to a straight off-track segment', (
    tester,
  ) async {
    final robot = MapRouteRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        tracks: [
          _routeTrack([
            const LatLng(-41.5, 146.498283),
            const LatLng(-41.5, 146.501717),
          ]),
        ],
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
        RoutePlanningResult(
          status: RoutePlanningStatus.noPath,
          points: [],
          distanceMeters: 0,
          startAnchor: null,
          endAnchor: RouteEndpointAnchor(
            point: LatLng(-41.7, 146.7),
            type: RouteEndpointAnchorType.node,
            nodeId: 3,
          ),
        ),
      ],
    );

    await robot.pumpApp();
    await robot.openMap();
    await robot.enterRouteMode();

    await robot.tapRoutePoint(const Offset(-40, 0));
    await robot.tapRoutePoint(const Offset(40, 0));
    await robot.tapRoutePoint(const Offset(80, 0));
    await robot.tapRoutePoint(const Offset(120, 0));

    expect(robot.routeDistanceText, findsOneWidget);
    expect(robot.container().read(mapProvider).routeDraftMarkers, hasLength(4));

    await robot.enterRouteName('Fallback Route');
    await robot.saveRoute();

    expect(robot.routeBottomSheet, findsNothing);
    expect(robot.savedRoutes(), hasLength(1));
    expect(robot.savedRoutes().single.gpxRoute.length, greaterThan(4));
    expect(robot.container().read(mapProvider).showRoutes, isTrue);
  });

  testWidgets('route journey saves zero elevation while elevation sampling is still in flight', (
    tester,
  ) async {
    final pendingSummary = Completer<RouteElevationSummary>();
    final robot = MapRouteRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        tracks: [
          _routeTrack([
            const LatLng(-41.5, 146.498283),
            const LatLng(-41.5, 146.501717),
          ]),
        ],
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
      ],
      routeElevationOutcomes: [pendingSummary],
    );

    await robot.pumpApp();
    await robot.openMap();
    await robot.enterRouteMode();

    await robot.tapRoutePoint(const Offset(-40, 0));
    await robot.tapRoutePoint(const Offset(40, 0));

    expect(find.byKey(const Key('route-elevation-loading-text')), findsOneWidget);

    await robot.enterRouteName('Pending Route');
    await robot.saveRoute();

    expect(robot.routeBottomSheet, findsNothing);
    expect(robot.savedRoutes(), hasLength(1));
    expect(robot.savedRoutes().single.ascent, 0);
    expect(robot.savedRoutes().single.descent, 0);
    expect(robot.savedRoutes().single.distance3d, 0);
  });
}

GpxTrack _routeTrack(List<LatLng> points) {
  return GpxTrack(
    gpxTrackId: 1,
    contentHash: 'hash-route-track',
    trackName: 'Route Track',
    gpxFile: '<gpx></gpx>',
    displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([points]),
  );
}
