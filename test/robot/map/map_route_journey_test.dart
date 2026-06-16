import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route_marker_display.dart';
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
    await robot.tapRoutePoint(const Offset(-40, 0));

    expect(
      tester.widget<FilledButton>(
        find.descendant(
          of: robot.routeToPeakButton,
          matching: find.byType(FilledButton),
        ),
      ).onPressed,
      isNotNull,
    );

    await robot.selectRouteMode(RouteMode.routeToPeak);

    expect(robot.routeDistanceText, findsOneWidget);
    robot.expectRouteDistanceContains('/ 1.0 km');
    expect(robot.routeAscentText, findsOneWidget);
    expect(find.text('321 m'), findsOneWidget);

    await robot.enterRouteName('Peak Route');
    await robot.saveRoute();

    robot.expectRouteDraftOverlaysHidden();
    expect(robot.savedRoutes(), hasLength(1));
    expect(robot.savedRoutes().single.gpxRoute, hasLength(3));
    expect(robot.savedRoutes().single.ascent, 321);
    expect(robot.savedRoutes().single.descent, 210);
    expect(robot.container().read(mapProvider).showRoutes, isTrue);
  });

  testWidgets('route journey out-and-backs and saves a waypoint route', (
    tester,
  ) async {
    final robot = MapRouteRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      routePlanningOutcomes: const [],
      routeElevationOutcomes: const [],
    );

    await robot.pumpApp();
    await robot.openMap();
    await robot.enterRouteMode();

    await robot.selectRouteMode(RouteMode.straightLine);

    await robot.tapRoutePoint(const Offset(-40, 0));
    await robot.tapRoutePoint(const Offset(40, 0));

    expect(robot.outAndBackButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(robot.outAndBackButton).onPressed,
      isNotNull,
    );

    await robot.applyOutAndBack();

    await robot.enterRouteName('Out and Back Route');
    await robot.saveRoute();

    robot.expectRouteDraftOverlaysHidden();
    expect(robot.savedRoutes(), hasLength(1));
    expect(robot.savedRoutes().single.routeWaypoints, hasLength(1));
    expect(robot.savedRoutes().single.routeWaypoints.single.label, 'Waypoint 1');
    expect(robot.container().read(mapProvider).showRoutes, isTrue);
  });

  testWidgets('route journey previews a segment and inserts it on click', (
    tester,
  ) async {
    final robot = MapRouteRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        isRouteDrafting: true,
        routeDraftStage: RouteDraftStage.awaitingNextPoint,
        routeDraftNextMarkerId: 3,
        routeDraftControlEndpoints: const [
          RouteDraftControlEndpoint(
            id: '0',
            point: LatLng(-41.5, 146.47),
            kind: RouteDraftEndpointKind.tapped,
          ),
          RouteDraftControlEndpoint(
            id: '1',
            point: LatLng(-41.5, 146.53),
            kind: RouteDraftEndpointKind.tapped,
          ),
          RouteDraftControlEndpoint(
            id: '2',
            point: LatLng(-41.5, 146.57),
            kind: RouteDraftEndpointKind.tapped,
          ),
        ],
        routeDraftDisplayMarkers: const [
          RouteDraftDisplayMarker(
            id: '0',
            point: LatLng(-41.5, 146.47),
            kind: RouteMarkerKind.circle,
          ),
          RouteDraftDisplayMarker(
            id: '1',
            point: LatLng(-41.5, 146.53),
            kind: RouteMarkerKind.numbered,
            number: 1,
          ),
          RouteDraftDisplayMarker(
            id: '2',
            point: LatLng(-41.5, 146.57),
            kind: RouteMarkerKind.target,
          ),
        ],
        routeDraftMarkers: const [
          LatLng(-41.5, 146.47),
          LatLng(-41.5, 146.53),
          LatLng(-41.5, 146.57),
        ],
        routeDraftCommittedPoints: const [
          LatLng(-41.5, 146.47),
          LatLng(-41.5, 146.53),
          LatLng(-41.5, 146.57),
        ],
      ),
      routePlanningOutcomes: const [],
      routeElevationOutcomes: const [],
    );

    await robot.pumpApp();
    await robot.openMap();

    await robot.hoverRoutePoint(const Offset(0, 0));
    robot.expectRouteSegmentPreview(0);
    await robot.hoverRoutePoint(const Offset(200, 200));
    expect(find.byKey(const Key('route-draft-segment-hover-0')), findsNothing);

    await robot.hoverRoutePoint(const Offset(0, 0));
    robot.expectRouteSegmentPreview(0);

    await robot.clickRoutePoint(const Offset(0, 0));

    final state = robot.container().read(mapProvider);
    expect(state.hoveredRouteDraftSegmentIndex, isNull);
    expect(state.routeDraftControlEndpoints, hasLength(4));
    expect(state.routeDraftDisplayMarkers, hasLength(4));
    expect(state.routeDraftDisplayMarkers[1].kind, RouteMarkerKind.numbered);
    expect(state.routeDraftDisplayMarkers[1].number, 1);
    expect(state.routeDraftDisplayMarkers[2].kind, RouteMarkerKind.numbered);
    expect(state.routeDraftDisplayMarkers[2].number, 2);
    expect(state.routeDraftDisplayMarkers[3].kind, RouteMarkerKind.target);
    expect(find.byKey(const Key('route-draft-segment-hover-0')), findsNothing);
  });

  testWidgets('route journey close-loops and saves a waypoint route', (
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
            LatLng(-41.6, 146.6),
            LatLng(-41.55, 146.55),
            LatLng(-41.5, 146.5),
          ],
          distanceMeters: 900,
        ),
      ],
      routeElevationOutcomes: const [
        RouteElevationSummary(
          requestId: 1,
          geometryVersion: 1,
          ascent: 111,
          descent: 100,
          distance3d: 1001,
        ),
        RouteElevationSummary(
          requestId: 2,
          geometryVersion: 2,
          ascent: 321,
          descent: 210,
          distance3d: 1010,
        ),
      ],
    );

    await robot.pumpApp();
    await robot.openMap();
    await robot.enterRouteMode();

    await robot.selectRouteMode(RouteMode.straightLine);

    await robot.tapRoutePoint(const Offset(-40, 0));
    await robot.tapRoutePoint(const Offset(40, 0));

    expect(robot.closeLoopButton, findsOneWidget);
    expect(
      tester.widget<FilledButton>(robot.closeLoopButton).onPressed,
      isNotNull,
    );

    await robot.applyCloseLoop();

    expect(robot.routeDistanceText, findsOneWidget);
    robot.expectRouteDistanceContains('/ 1.0 km');
    expect(find.text('321 m'), findsOneWidget);

    await robot.enterRouteName('Close Loop Route');
    await robot.saveRoute();

    robot.expectRouteDraftOverlaysHidden();
    expect(robot.savedRoutes(), hasLength(1));
    expect(robot.savedRoutes().single.gpxRoute, hasLength(greaterThan(5)));
    expect(robot.savedRoutes().single.routeWaypoints, hasLength(1));
    expect(robot.savedRoutes().single.routeWaypoints.single.label, 'Waypoint 1');
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
    robot.expectRouteDraftOverlaysVisible();

    await robot.tapRoutePoint(const Offset(-40, 0));
    await robot.tapRoutePoint(const Offset(40, 0));

    await robot.tapRoutePoint(const Offset(80, 0));

    robot.expectRouteDistanceContains('/ 2.2 km');
    expect(robot.routeAscentText, findsOneWidget);
    expect(find.text('654 m'), findsOneWidget);
    expect(robot.routeDescentText, findsOneWidget);
    expect(find.text('432 m'), findsOneWidget);

    await robot.enterRouteName('Robot Route');
    await robot.saveRoute();

    robot.expectRouteDraftOverlaysHidden();
    expect(robot.savedRoutes(), hasLength(1));
    expect(robot.savedRoutes().single.gpxRoute, hasLength(5));
    expect(robot.savedRoutes().single.ascent, 654);
    expect(robot.savedRoutes().single.descent, 432);
    expect(robot.savedRoutes().single.distance3d, 2222);
    expect(robot.container().read(mapProvider).showRoutes, isTrue);
  });

  testWidgets('route journey edits a draft with drag delete undo redo and saves', (
    tester,
  ) async {
    final robot = MapRouteRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      routePlanningOutcomes: const [],
      routeElevationOutcomes: const [],
    );

    await robot.pumpApp();
    await robot.openMap();
    await robot.enterRouteMode();

    await robot.selectRouteMode(RouteMode.straightLine);

    await robot.tapRoutePoint(const Offset(-60, 0));
    await robot.tapRoutePoint(const Offset(0, 0));
    await robot.tapRoutePoint(const Offset(60, 0));

    final originalMiddlePoint = robot.container().read(mapProvider).routeDraftMarkers[1];
    await robot.dragDraftMarker('1', const Offset(30, 0));

    final movedState = robot.container().read(mapProvider);
    expect(robot.routeDraftDeletePopup, findsNothing);
    expect(movedState.routeDraftMarkers, hasLength(3));
    expect(movedState.routeDraftMarkers[1], isNot(originalMiddlePoint));

    final movedMiddlePoint = movedState.routeDraftMarkers[1];
    await robot.clickDraftMarker('1');

    expect(robot.routeDraftDeletePopup, findsOneWidget);

    await robot.deleteDraftMarkerFromPopup();

    final deletedState = robot.container().read(mapProvider);
    expect(deletedState.routeDraftMarkers, hasLength(2));

    await robot.undoRouteEdit();

    final restoredState = robot.container().read(mapProvider);
    expect(restoredState.routeDraftMarkers, hasLength(3));
    expect(restoredState.routeDraftMarkers[1], movedMiddlePoint);

    await robot.redoRouteEdit();

    final redoneState = robot.container().read(mapProvider);
    expect(redoneState.routeDraftMarkers, hasLength(2));

    await robot.enterRouteName('Edited Robot Route');
    await robot.saveRoute();

    robot.expectRouteDraftOverlaysHidden();
    expect(robot.savedRoutes(), hasLength(1));
    expect(robot.savedRoutes().single.gpxRoute, hasLength(2));
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

    robot.expectRouteDraftOverlaysHidden();
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

    robot.expectRouteDraftOverlaysHidden();
    expect(robot.savedRoutes(), hasLength(1));
    expect(robot.savedRoutes().single.ascent, 0);
    expect(robot.savedRoutes().single.descent, 0);
    expect(robot.savedRoutes().single.distance3d, 0);
  });

  testWidgets('route journey resumes snapped routing after a rejoin probe', (
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
        RouteEndpointProbeResult(
          isOnTrack: true,
          anchor: RouteEndpointAnchor(
            point: LatLng(-41.8, 146.8),
            type: RouteEndpointAnchorType.node,
            nodeId: 4,
          ),
        ),
        PlannedRouteSegment(
          points: [
            LatLng(-41.8, 146.8),
            LatLng(-41.85, 146.85),
            LatLng(-41.9, 146.9),
          ],
          distanceMeters: 1400,
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
    await robot.tapRoutePoint(const Offset(160, 0));

    expect(robot.routeDistanceText, findsOneWidget);
    expect(robot.container().read(mapProvider).routeDraftMarkers, hasLength(5));

    await robot.enterRouteName('Rejoin Route');
    await robot.saveRoute();

    robot.expectRouteDraftOverlaysHidden();
    expect(robot.savedRoutes(), hasLength(1));
    expect(robot.savedRoutes().single.gpxRoute.length, greaterThan(6));
    expect(robot.container().read(mapProvider).showRoutes, isTrue);
  });

  testWidgets('trail journey enables the trail overlay from the map rail', (
    tester,
  ) async {
    final robot = MapRouteRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      routePlanningOutcomes: const [],
      routeElevationOutcomes: const [],
      routeGraphStore: TrailRouteGraphStore(),
    );

    await robot.pumpApp();
    await robot.openMap();
    await tester.pumpAndSettle();

    final showTrailsFab = find.byKey(const Key('show-trails-fab'));
    await tester.ensureVisible(showTrailsFab);
    for (var i = 0; i < 20; i++) {
      if (tester.widget<FloatingActionButton>(showTrailsFab).onPressed != null) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.widget<FloatingActionButton>(showTrailsFab).onPressed, isNotNull);
    await tester.tap(showTrailsFab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trail-polyline-layer')), findsOneWidget);
    expect(robot.container().read(mapProvider).showTrails, isTrue);

    final showTracksFab = find.byKey(const Key('show-tracks-fab'));
    await tester.ensureVisible(showTracksFab);
    await tester.pumpAndSettle();
    await tester.tap(showTracksFab);
    await tester.pumpAndSettle();

    final trailsSwitch = find.byKey(const Key('show-trails-switch'));
    expect(tester.widget<Switch>(trailsSwitch).value, isTrue);
    expect(find.byKey(const Key('tracks-routes-drawer')), findsOneWidget);

    await tester.drag(robot.mapInteractionRegion, const Offset(-60, 20));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trail-polyline-layer')), findsOneWidget);

    await tester.tap(trailsSwitch);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trail-polyline-layer')), findsNothing);
    expect(robot.container().read(mapProvider).showTrails, isFalse);
  });

  testWidgets('trail journey switches to the refreshed cached generation', (
    tester,
  ) async {
    final store = TrailRouteGraphStore();
    final robot = MapRouteRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      routePlanningOutcomes: const [],
      routeElevationOutcomes: const [],
      routeGraphStore: store,
    );

    await robot.pumpApp();
    await robot.openMap();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('show-trails-fab')));
    await tester.pumpAndSettle();

    PolylineLayer layer = tester.widget(
      find.byKey(const Key('trail-polyline-layer')),
    );
    expect(layer.polylines.first.points, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.55, 146.55),
    ]);

    await store.replaceVisibleTrailGeneration(const [
      LatLng(-41.5, 146.5),
      LatLng(-41.525, 146.525),
      LatLng(-41.55, 146.55),
    ]);
    await tester.drag(robot.mapInteractionRegion, const Offset(-60, 20));
    await tester.pumpAndSettle();

    layer = tester.widget(find.byKey(const Key('trail-polyline-layer')));
    expect(layer.polylines.first.points, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.525, 146.525),
      LatLng(-41.55, 146.55),
    ]);

    final gesture = await tester.startGesture(
      tester.getCenter(robot.mapInteractionRegion),
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomUpdate(
      tester.getCenter(robot.mapInteractionRegion),
      pan: const Offset(0, 120),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trail-polyline-layer')), findsOneWidget);
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
