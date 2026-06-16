import 'dart:io';

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:peak_bagger/models/route_marker_display.dart';
import 'package:peak_bagger/widgets/route_marker.dart';
import 'package:peak_bagger/widgets/map_route_bottom_sheet.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';
import '../harness/test_map_notifier.dart';

void main() {
  final routeGraphOverlayRoot = find.byKey(
    const Key('route-graph-overlay-root'),
  );
  final routeControlsOverlayRoot = find.byKey(
    const Key('route-controls-overlay-root'),
  );

  void expectRouteDraftOverlaysVisible() {
    expect(routeGraphOverlayRoot, findsOneWidget);
    expect(routeControlsOverlayRoot, findsOneWidget);
  }

  void expectRouteDraftOverlaysHidden() {
    expect(routeGraphOverlayRoot, findsNothing);
    expect(routeControlsOverlayRoot, findsNothing);
  }

  testWidgets('create route opens draft sheet and clears selection state', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        selectedLocation: const LatLng(-41.6, 146.6),
        showTracks: true,
        tracks: [_track(10)],
        selectedTrackId: 10,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final container = _container(tester);
    final state = container.read(mapProvider);
    expect(state.isRouteDrafting, isTrue);
    expect(state.routeDraftMode, RouteMode.snapToTrail);
    expect(state.routeDraftName, isEmpty);
    expect(state.routeDraftMarkers, isEmpty);
    expect(state.selectedLocation, const LatLng(-41.6, 146.6));
    expect(state.selectedTrackId, isNull);

    expectRouteDraftOverlaysVisible();
    expect(find.byKey(const Key('route-name-field')), findsOneWidget);
    expect(find.text('Tap a point to start routing'), findsOneWidget);
    expect(find.byKey(const Key('route-mode-snap-to-trail')), findsOneWidget);
    expect(find.byKey(const Key('route-mode-route-to-peak')), findsOneWidget);
    expect(find.byKey(const Key('route-mode-straight-line')), findsOneWidget);
    expect(
      find.byKey(const Key('route-distance-elevation-group')),
      findsOneWidget,
    );
  });

  testWidgets('route draft elevation chart expands with more points', (
    tester,
  ) async {
    final point1 = const LatLng(-41.5, 146.5);
    final point2 = const LatLng(-41.5, 146.505);
    final point3 = const LatLng(-41.5, 146.51);
    final point4 = const LatLng(-41.5, 146.515);
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        isRouteDrafting: true,
        routeDraftName: 'Draft route',
        routeDraftStage: RouteDraftStage.awaitingNextPoint,
        routeDraftCommittedPoints: [point1, point2, point3],
        routeDraftPointElevations: const [100, 120, 140],
        routeDraftDistanceMeters:
            const Distance().as(LengthUnit.Meter, point1, point2) +
            const Distance().as(LengthUnit.Meter, point2, point3),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mapProvider.overrideWith(() => notifier)],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 640, child: RouteDraftGraphOverlay()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final initialMaxX = lineChart.data.maxX;

    notifier.state = notifier.state.copyWith(
      routeDraftCommittedPoints: [point1, point2, point3, point4],
      routeDraftPointElevations: const [100, 120, 140, 160],
      routeDraftDistanceMeters:
          const Distance().as(LengthUnit.Meter, point1, point2) +
          const Distance().as(LengthUnit.Meter, point2, point3) +
          const Distance().as(LengthUnit.Meter, point3, point4),
    );
    await tester.pumpAndSettle();

    lineChart = tester.widget<LineChart>(find.byType(LineChart));
    expect(lineChart.data.maxX, greaterThan(initialMaxX));
  });

  testWidgets('route to peak stays disabled without a captured peak target', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final routeToPeakButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('route-mode-route-to-peak')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(routeToPeakButton.onPressed, isNull);

    final snapToTrailButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('route-mode-snap-to-trail')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(snapToTrailButton.style?.backgroundColor?.resolve({}), Colors.green);
  });

  testWidgets('route to peak enables from a captured peak popup target', (
    tester,
  ) async {
    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -41.5,
      longitude: 146.5,
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: [peak],
      ),
    );
    await _pumpMap(tester, notifier);

    notifier.openPeakInfoPopup(peak);
    await tester.pump();

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final routeState = _container(tester).read(mapProvider);
    expect(routeState.routeDraftPeak, isNotNull);

    final snapToTrailButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('route-mode-snap-to-trail')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(snapToTrailButton.style?.backgroundColor?.resolve({}), Colors.green);

    final routeToPeakButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('route-mode-route-to-peak')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(routeToPeakButton.onPressed, isNull);

    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.45));
    await tester.pump();

    final enabledRouteToPeakButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('route-mode-route-to-peak')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(enabledRouteToPeakButton.onPressed, isNotNull);
    expect(
      enabledRouteToPeakButton.style?.backgroundColor?.resolve({}),
      Colors.purple,
    );
  });

  testWidgets('route to peak disables after editing the peak-target marker', (
    tester,
  ) async {
    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -41.5,
      longitude: 146.5,
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: [peak],
        selectedLocation: const LatLng(-41.5, 146.5),
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.45));
    await tester.pump();

    final routeToPeakButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('route-mode-route-to-peak')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(routeToPeakButton.onPressed, isNotNull);

    await notifier.moveRouteDraftMarker('0', const LatLng(-41.52, 146.47));
    await tester.pump();

    final disabledRouteToPeakButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('route-mode-route-to-peak')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(disabledRouteToPeakButton.onPressed, isNull);

    final routeState = _container(tester).read(mapProvider);
    expect(routeState.routeDraftPeakTargetLocked, isTrue);
    expect(routeState.routeDraftPeakTarget, isNull);
  });

  testWidgets('route to peak enables from a dropped peak marker location', (
    tester,
  ) async {
    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -41.5,
      longitude: 146.5,
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: [peak],
        selectedLocation: const LatLng(-41.5, 146.5),
      ),
      routePlanningOutcomes: const [
        PlannedRouteSegment(
          points: [LatLng(-41.5, 146.5), LatLng(-41.55, 146.55)],
          distanceMeters: 500,
        ),
      ],
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final routeToPeakButtonBeforePoint = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('route-mode-route-to-peak')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(routeToPeakButtonBeforePoint.onPressed, isNull);

    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.45));
    await tester.pump();

    final routeState = _container(tester).read(mapProvider);
    expect(routeState.routeDraftPeakTarget, isNotNull);

    final routeToPeakButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('route-mode-route-to-peak')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(routeToPeakButton.onPressed, isNotNull);

    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.45));
    await tester.pump();

    final enabledRouteToPeakButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('route-mode-route-to-peak')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(enabledRouteToPeakButton.onPressed, isNotNull);
    expect(
      enabledRouteToPeakButton.style?.backgroundColor?.resolve({}),
      Colors.purple,
    );

    final snapToTrailButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('route-mode-snap-to-trail')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(snapToTrailButton.style?.backgroundColor?.resolve({}), Colors.green);
  });

  testWidgets('route mode buttons are disabled while routing a segment', (
    tester,
  ) async {
    final routePlanner = _CompletingRoutePlanner();
    final tasmapRepository = await TestTasmapRepository.create();
    final notifier = MapNotifier(
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      overpassService: OverpassService(),
      tasmapRepository: tasmapRepository,
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
      routeElevationSampler: const _ImmediateRouteElevationSampler(
        RouteElevationSummary(
          requestId: 0,
          geometryVersion: 0,
          ascent: 0,
          descent: 0,
          distance3d: 0,
        ),
      ),
      routePlanner: routePlanner,
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      loadPositionOnBuild: false,
      loadPeaksOnBuild: false,
      loadTracksOnBuild: false,
    );
    await _pumpMap(tester, notifier, tasmapRepository: tasmapRepository);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region) + const Offset(-40, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(region) + const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 300));

    FilledButton button(Finder keyFinder) => tester.widget<FilledButton>(
      find.descendant(of: keyFinder, matching: find.byType(FilledButton)),
    );

    expect(
      button(find.byKey(const Key('route-mode-snap-to-trail'))).onPressed,
      isNull,
    );
    expect(
      button(find.byKey(const Key('route-mode-straight-line'))).onPressed,
      isNull,
    );
  });

  testWidgets(
    'out and back button sits in the route strip and toggles enabled state',
    (tester) async {
      final notifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      );
      await _pumpMap(tester, notifier);

      await tester.tap(find.byKey(const Key('create-route-fab')));
      await tester.pumpAndSettle();

      final outAndBackKey = find.byKey(const Key('route-mode-out-and-back'));
      final closeLoopKey = find.byKey(const Key('route-mode-close-loop'));
      final undoKey = find.byKey(const Key('route-undo-button'));
      final redoKey = find.byKey(const Key('route-redo-button'));
      expect(outAndBackKey, findsOneWidget);
      expect(closeLoopKey, findsOneWidget);
      expect(undoKey, findsOneWidget);
      expect(redoKey, findsOneWidget);
      expect(find.byTooltip('Out and Back'), findsOneWidget);
      expect(find.byTooltip('Close Loop'), findsOneWidget);
      expect(find.byTooltip('Undo (⌘ Z)'), findsOneWidget);
      expect(find.byTooltip('Redo (⌘ ⇧ Z)'), findsOneWidget);
      expect(
        find.descendant(of: outAndBackKey, matching: find.text('Out and Back')),
        findsNothing,
      );
      expect(
        find.descendant(of: closeLoopKey, matching: find.text('Close Loop')),
        findsNothing,
      );

      final container = _container(tester);
      FilledButton button(Finder keyFinder) => tester.widget<FilledButton>(keyFinder);

      expect(button(outAndBackKey).onPressed, isNull);
      expect(button(outAndBackKey).style?.shape?.resolve({}), isA<RoundedRectangleBorder>());
      expect(button(closeLoopKey).onPressed, isNull);
      expect(button(closeLoopKey).style?.shape?.resolve({}), isA<RoundedRectangleBorder>());
      expect(button(undoKey).onPressed, isNull);
      expect(button(redoKey).onPressed, isNull);

      final straightRect = tester.getRect(
        find.byKey(const Key('route-mode-straight-line')),
      );
      final outAndBackRect = tester.getRect(outAndBackKey);
      final closeLoopRect = tester.getRect(closeLoopKey);
      final nameRect = tester.getRect(
        find.byKey(const Key('route-name-field')),
      );

      expect(outAndBackRect.left, greaterThan(straightRect.right));
      expect(closeLoopRect.left, greaterThan(outAndBackRect.right));
      expect(closeLoopRect.right, lessThan(nameRect.left));

      container.read(mapProvider.notifier).state = container
          .read(mapProvider)
          .copyWith(routeDraftCanUndo: true, routeDraftCanRedo: true);
      await tester.pump();

      expect(button(undoKey).onPressed, isNotNull);
      expect(button(redoKey).onPressed, isNotNull);

      container.read(mapProvider.notifier).state = container
          .read(mapProvider)
          .copyWith(
            routeDraftStage: RouteDraftStage.awaitingNextPoint,
            routeDraftControlEndpoints: const [
              RouteDraftControlEndpoint(
                id: 'endpoint-0',
                point: LatLng(-41.5, 146.5),
                kind: RouteDraftEndpointKind.tapped,
              ),
              RouteDraftControlEndpoint(
                id: 'endpoint-1',
                point: LatLng(-41.6, 146.6),
                kind: RouteDraftEndpointKind.tapped,
              ),
            ],
            routeDraftMarkers: const [
              LatLng(-41.5, 146.5),
              LatLng(-41.6, 146.6),
            ],
            routeDraftCommittedPoints: const [
              LatLng(-41.5, 146.5),
              LatLng(-41.55, 146.55),
              LatLng(-41.6, 146.6),
            ],
      );
      await tester.pump();

      expect(button(outAndBackKey).onPressed, isNotNull);
      expect(button(closeLoopKey).onPressed, isNotNull);
      expect(button(outAndBackKey).style?.shape?.resolve({}), isA<RoundedRectangleBorder>());
      expect(button(closeLoopKey).style?.shape?.resolve({}), isA<RoundedRectangleBorder>());

      container.read(mapProvider.notifier).state = container
          .read(mapProvider)
          .copyWith(
            routeDraftCommittedPoints: const [
              LatLng(-41.5, 146.5),
              LatLng(-41.55, 146.55),
              LatLng(-41.6, 146.6),
              LatLng(-41.55, 146.55),
              LatLng(-41.5, 146.5),
            ],
          );
      await tester.pump();

      expect(button(outAndBackKey).onPressed, isNull);
      expect(button(closeLoopKey).onPressed, isNull);
    },
  );

  testWidgets('route strip keeps route name width on a narrow viewport', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(
      tester,
      notifier,
      surfaceSize: const Size(420, 900),
    );

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final nameRect = tester.getRect(find.byKey(const Key('route-name-field')));
    final outAndBackRect = tester.getRect(
      find.byKey(const Key('route-mode-out-and-back')),
    );
    final closeLoopRect = tester.getRect(
      find.byKey(const Key('route-mode-close-loop')),
    );

    expect(nameRect.width, 244);
    expect(outAndBackRect.right, lessThan(closeLoopRect.left));
    expect(closeLoopRect.right, lessThan(nameRect.left));
  });

  testWidgets(
    'closed route draft disables both route to peak and out and back', (
      tester,
    ) async {
      final peak = Peak(
        osmId: 6406,
        name: 'Bonnet Hill',
        latitude: -41.5,
        longitude: 146.5,
      );
      final notifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          isRouteDrafting: true,
          routeDraftPeak: peak,
          routeDraftStage: RouteDraftStage.awaitingNextPoint,
          routeDraftMarkers: const [
            LatLng(-41.5, 146.45),
            LatLng(-41.5, 146.5),
            LatLng(-41.5, 146.45),
          ],
          routeDraftCommittedPoints: const [
            LatLng(-41.5, 146.45),
            LatLng(-41.5, 146.5),
            LatLng(-41.5, 146.45),
          ],
        ),
      );
      await _pumpMap(tester, notifier);

      final routeToPeakButton = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('route-mode-route-to-peak')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(routeToPeakButton.onPressed, isNull);

      final outAndBackButton = tester.widget<FilledButton>(
        find.byKey(const Key('route-mode-out-and-back')),
      );
      expect(outAndBackButton.onPressed, isNull);
    },
  );

  testWidgets('route sheet accepts name input and closes on cancel', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('route-name-field')),
      'Ridge Loop',
    );
    await tester.pump();

    expect(_container(tester).read(mapProvider).routeDraftName, 'Ridge Loop');

    await tester.tap(find.byKey(const Key('route-cancel-button')));
    await tester.pumpAndSettle();

    final state = _container(tester).read(mapProvider);
    expect(state.isRouteDrafting, isFalse);
    expect(state.routeDraftName, isEmpty);
    expect(state.routeDraftMarkers, isEmpty);
    expectRouteDraftOverlaysHidden();
  });

  testWidgets('route taps append temporary markers and stay isolated', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final state = _container(tester).read(mapProvider);
    expect(state.routeDraftMarkers, hasLength(1));
    expect(state.routeDraftMarkers.first.latitude, closeTo(-41.5, 0.000001));
    expect(state.routeDraftMarkers.first.longitude, closeTo(146.5, 0.000001));
    expect(state.routeDraftDisplayMarkers, hasLength(1));
    expect(state.routeDraftDisplayMarkers.first.kind, RouteMarkerKind.circle);
    expect(state.selectedLocation, isNull);
    expect(state.selectedTrackId, isNull);
    expect(find.byKey(const Key('route-draft-marker-layer')), findsOneWidget);
    expect(find.byKey(const Key('route-draft-marker-0')), findsOneWidget);
    final routeMarker = tester.widget<RouteMarker>(
      find.descendant(
        of: find.byKey(const Key('route-draft-marker-0')),
        matching: find.byType(RouteMarker),
      ),
    );
    expect(routeMarker.kind, RouteMarkerKind.circle);
    expect(routeMarker.color, const Color(0xFFFF0000));
    expect(routeMarker.number, isNull);
  });

  testWidgets('route taps advance to numbered markers and a target', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final notifier = MapNotifier(
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      overpassService: OverpassService(),
      tasmapRepository: tasmapRepository,
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
      routeElevationSampler: const _ImmediateRouteElevationSampler(
        RouteElevationSummary(
          requestId: 0,
          geometryVersion: 0,
          ascent: 0,
          descent: 0,
          distance3d: 0,
        ),
      ),
      routePlanner: _QueuedRoutePlanner([
        const RoutePlanningResult(
          status: RoutePlanningStatus.routed,
          points: [LatLng(-41.5, 146.5), LatLng(-41.55, 146.55)],
          distanceMeters: 500,
          startAnchor: null,
          endAnchor: null,
        ),
        const RoutePlanningResult(
          status: RoutePlanningStatus.routed,
          points: [LatLng(-41.55, 146.55), LatLng(-41.6, 146.6)],
          distanceMeters: 500,
          startAnchor: null,
          endAnchor: null,
        ),
      ]),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      loadPositionOnBuild: false,
      loadPeaksOnBuild: false,
      loadTracksOnBuild: false,
    );
    await _pumpMap(tester, notifier, tasmapRepository: tasmapRepository);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region) + const Offset(-40, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(region) + const Offset(40, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(region) + const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final state = _container(tester).read(mapProvider);
    expect(
      state.routeDraftDisplayMarkers.map((marker) => marker.kind),
      [
        RouteMarkerKind.circle,
        RouteMarkerKind.numbered,
        RouteMarkerKind.target,
      ],
    );
    expect(state.routeDraftDisplayMarkers[1].number, 1);

    expect(find.byKey(const Key('route-draft-marker-0')), findsOneWidget);
    expect(find.byKey(const Key('route-draft-marker-1')), findsOneWidget);
    expect(find.byKey(const Key('route-draft-marker-2')), findsOneWidget);

    expect(
      tester.widget<RouteMarker>(
        find.descendant(
          of: find.byKey(const Key('route-draft-marker-0')),
          matching: find.byType(RouteMarker),
        ),
      ).kind,
      RouteMarkerKind.circle,
    );
    expect(
      tester.widget<RouteMarker>(
        find.descendant(
          of: find.byKey(const Key('route-draft-marker-1')),
          matching: find.byType(RouteMarker),
        ),
      ).kind,
      RouteMarkerKind.numbered,
    );
    expect(
      tester.widget<RouteMarker>(
        find.descendant(
          of: find.byKey(const Key('route-draft-marker-2')),
          matching: find.byType(RouteMarker),
        ),
      ).kind,
      RouteMarkerKind.target,
    );
  });

  testWidgets(
    'route mode tap on a peak adds a route marker instead of opening popup',
    (tester) async {
      final notifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          peaks: [
            Peak(
              osmId: 7001,
              name: 'Route Peak',
              latitude: -41.5,
              longitude: 146.5,
            ),
          ],
        ),
      );
      await _pumpMap(tester, notifier);

      await tester.tap(find.byKey(const Key('create-route-fab')));
      await tester.pumpAndSettle();

      final region = find.byKey(const Key('map-interaction-region'));
      await tester.tapAt(tester.getCenter(region));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('route-draft-marker-0')), findsOneWidget);
      expect(find.byKey(const Key('peak-info-popup')), findsNothing);
      expect(_container(tester).read(mapProvider).selectedLocation, isNull);
    },
  );

  testWidgets('route draft rejects the 100th numbered point inline', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final notifier = MapNotifier(
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      overpassService: OverpassService(),
      tasmapRepository: tasmapRepository,
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
      routeElevationSampler: const _ImmediateRouteElevationSampler(
        RouteElevationSummary(
          requestId: 0,
          geometryVersion: 0,
          ascent: 0,
          descent: 0,
          distance3d: 0,
        ),
      ),
      routePlanner: _QueuedRoutePlanner([
        const RoutePlanningResult(
          status: RoutePlanningStatus.routed,
          points: [LatLng(-41.5, 146.5), LatLng(-41.5, 146.95)],
          distanceMeters: 500,
          startAnchor: null,
          endAnchor: null,
        ),
      ]),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      loadPositionOnBuild: false,
      loadPeaksOnBuild: false,
      loadTracksOnBuild: false,
    );
    await _pumpMap(tester, notifier, tasmapRepository: tasmapRepository);

    final controlEndpoints = <RouteDraftControlEndpoint>[
      RouteDraftControlEndpoint(
        id: 'endpoint-0',
        point: const LatLng(-41.5, 146.5),
        kind: RouteDraftEndpointKind.tapped,
      ),
      for (var index = 1; index <= 99; index++)
        RouteDraftControlEndpoint(
          id: 'endpoint-$index',
          point: LatLng(-41.5, 146.5 + index * 0.001),
          kind: RouteDraftEndpointKind.tapped,
        ),
      RouteDraftControlEndpoint(
        id: 'endpoint-100',
        point: const LatLng(-41.5, 146.9),
        kind: RouteDraftEndpointKind.tapped,
      ),
    ];

    final displayMarkers = [
      RouteMarkerDisplay(
        id: 'endpoint-0',
        point: const LatLng(-41.5, 146.5),
        kind: RouteMarkerKind.circle,
      ),
      for (var index = 1; index <= 99; index++)
        RouteMarkerDisplay(
          id: 'endpoint-$index',
          point: LatLng(-41.5, 146.5 + index * 0.001),
          kind: RouteMarkerKind.numbered,
          number: index,
        ),
      RouteMarkerDisplay(
        id: 'endpoint-100',
        point: const LatLng(-41.5, 146.9),
        kind: RouteMarkerKind.target,
      ),
    ];

    final container = _container(tester);
    container.read(mapProvider.notifier).state = container.read(mapProvider).copyWith(
      isRouteDrafting: true,
      routeDraftName: 'Long Route',
      routeDraftNameError: null,
      routeDraftStage: RouteDraftStage.awaitingNextPoint,
      routeDraftControlEndpoints: controlEndpoints,
      routeDraftDisplayMarkers: displayMarkers,
      routeDraftMarkers: controlEndpoints.map((endpoint) => endpoint.point).toList(),
      routeDraftCommittedPoints: controlEndpoints.map((endpoint) => endpoint.point).toList(),
      routeDraftDistanceMeters: 1234,
      routeDraftError: null,
    );
    await tester.pump();

    final stateBefore = container.read(mapProvider);
    container.read(mapProvider.notifier).addRouteDraftMarker(
      const LatLng(-41.5, 146.95),
    );
    await tester.pump();

    final stateAfter = container.read(mapProvider);
    expect(stateAfter.routeDraftError, 'Peak Bagger only supports a maximum of 99 route points');
    expect(stateAfter.routeDraftDisplayMarkers, stateBefore.routeDraftDisplayMarkers);
    expect(find.text('Peak Bagger only supports a maximum of 99 route points'), findsOneWidget);
  });

  testWidgets('blank route name shows inline error and save stays disabled', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    expect(find.text('A Route name must be entered'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('route-save-button')),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('route name error clears on first typed character', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    expect(find.text('A Route name must be entered'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('route-name-field')), 't');
    await tester.pump();

    final state = _container(tester).read(mapProvider);
    expect(state.routeDraftName, 't');
    expect(state.routeDraftNameError, isNull);
    expect(find.text('A Route name must be entered'), findsNothing);
  });

  testWidgets('valid route save persists routed geometry and closes sheet', (
    tester,
  ) async {
    final routeRepository = RouteRepository.test(InMemoryRouteStorage());
    final tasmapRepository = await TestTasmapRepository.create();
    final routePlanner = _CompletingRoutePlanner();
    final routeElevationSampler = _ImmediateRouteElevationSampler(
      const RouteElevationSummary(
        requestId: 1,
        geometryVersion: 1,
        ascent: 432,
        descent: 210,
        distance3d: 1250,
      ),
    );
    final notifier = MapNotifier(
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      overpassService: OverpassService(),
      tasmapRepository: tasmapRepository,
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: routeRepository,
      routeElevationSampler: routeElevationSampler,
      routePlanner: routePlanner,
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      loadPositionOnBuild: false,
      loadPeaksOnBuild: false,
      loadTracksOnBuild: false,
    );
    await _pumpMap(
      tester,
      notifier,
      routeRepository: routeRepository,
      tasmapRepository: tasmapRepository,
    );
    notifier.state = notifier.state.copyWith(
      tracks: [
        _track(
          10,
          points: [
            const LatLng(-41.5, 146.498283),
            const LatLng(-41.5, 146.501717),
          ],
        ),
      ],
      showTracks: true,
    );

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region) + const Offset(-40, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(region) + const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('route-loading-text')), findsOneWidget);

    routePlanner.complete(
      const PlannedRouteSegment(
        points: [
          LatLng(-41.5, 146.5),
          LatLng(-41.55, 146.55),
          LatLng(-41.6, 146.6),
        ],
        distanceMeters: 1234.5,
      ),
    );
    await tester.pump();
    await tester.pump();

    final routedDistance =
        const Distance().as(
          LengthUnit.Meter,
          const LatLng(-41.5, 146.5),
          const LatLng(-41.55, 146.55),
        ) +
        const Distance().as(
          LengthUnit.Meter,
          const LatLng(-41.55, 146.55),
          const LatLng(-41.6, 146.6),
        );
    expect(find.text('Distance (2d/3d)'), findsOneWidget);
    expect(find.byKey(const Key('route-distance-text')), findsOneWidget);
    expect(find.text('13.9 / 1.3 km'), findsOneWidget);
    expect(find.text('Ascent'), findsOneWidget);
    expect(find.text('432 m'), findsOneWidget);
    expect(find.text('Descent'), findsOneWidget);
    expect(find.text('210 m'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('route-name-field')),
      'Ridge Loop',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('route-save-button')));
    await tester.pumpAndSettle();

    expectRouteDraftOverlaysHidden();
    final savedRoutes = routeRepository.getAllRoutes();
    expect(savedRoutes, hasLength(1));
    expect(savedRoutes.single.name, 'Ridge Loop');
    expect(savedRoutes.single.colour, 0xFFFF0000);
    expect(savedRoutes.single.gpxRoute, hasLength(3));
    expect(savedRoutes.single.distance2d, closeTo(routedDistance, 0.001));
    expect(savedRoutes.single.displayRoutePointsByZoom, isNot('{}'));
    expect(_container(tester).read(mapProvider).showRoutes, isTrue);
  });

  testWidgets('route save failure shows snackbar and keeps sheet open', (
    tester,
  ) async {
    final routeRepository = RouteRepository.test(_FailingRouteStorage());
    final tasmapRepository = await TestTasmapRepository.create();
    final routePlanner = _ImmediateRoutePlanner(
      const PlannedRouteSegment(
        points: [
          LatLng(-41.5, 146.5),
          LatLng(-41.55, 146.55),
          LatLng(-41.6, 146.6),
        ],
        distanceMeters: 1234.5,
      ),
    );
    const routeElevationSampler = _ImmediateRouteElevationSampler(
      RouteElevationSummary(
        requestId: 0,
        geometryVersion: 0,
        ascent: 0,
        descent: 0,
        distance3d: 0,
      ),
    );
    final notifier = MapNotifier(
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      overpassService: OverpassService(),
      tasmapRepository: tasmapRepository,
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: routeRepository,
      routeElevationSampler: routeElevationSampler,
      routePlanner: routePlanner,
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      loadPositionOnBuild: false,
      loadPeaksOnBuild: false,
      loadTracksOnBuild: false,
    );
    await _pumpMap(
      tester,
      notifier,
      routeRepository: routeRepository,
      tasmapRepository: tasmapRepository,
    );

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region) + const Offset(-40, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(region) + const Offset(40, 0));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('route-name-field')),
      'Failure Route',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('route-save-button')));
    await tester.pumpAndSettle();

    expectRouteDraftOverlaysVisible();
    expect(find.byKey(const Key('route-save-button')), findsOneWidget);
  });

  testWidgets('off-track route tap falls back to a straight segment', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final notifier = MapNotifier(
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      overpassService: OverpassService(),
      tasmapRepository: tasmapRepository,
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
      routeElevationSampler: _ImmediateRouteElevationSampler(
        const RouteElevationSummary(
          requestId: 1,
          geometryVersion: 1,
          ascent: 150,
          descent: 75,
        ),
      ),
      routePlanner: _QueuedRoutePlanner([
        RoutePlanningResult(
          status: RoutePlanningStatus.routed,
          points: const [
            LatLng(-41.5, 146.5),
            LatLng(-41.55, 146.55),
            LatLng(-41.6, 146.6),
          ],
          distanceMeters: 1234.5,
          startAnchor: null,
          endAnchor: null,
        ),
        RoutePlanningResult(
          status: RoutePlanningStatus.noPath,
          points: const [],
          distanceMeters: 0,
          startAnchor: null,
          endAnchor: const RouteEndpointAnchor(
            point: LatLng(-41.7, 146.7),
            type: RouteEndpointAnchorType.node,
            nodeId: 3,
          ),
        ),
      ]),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      loadPositionOnBuild: false,
      loadPeaksOnBuild: false,
      loadTracksOnBuild: false,
    );
    await _pumpMap(tester, notifier, tasmapRepository: tasmapRepository);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region) + const Offset(-40, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(region) + const Offset(40, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(region) + const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('route-name-field')),
      'Fallback Route',
    );
    await tester.pump();

    expect(find.byKey(const Key('route-distance-text')), findsOneWidget);
    expect(find.text('Distance (2d/3d)'), findsOneWidget);
    expect(find.text('Ascent'), findsOneWidget);
    expect(find.text('150 m'), findsOneWidget);
    expect(find.text('Descent'), findsOneWidget);
    expect(find.text('75 m'), findsOneWidget);
    final fallbackDistance = tester.widget<Text>(
      find.byKey(const Key('route-distance-text')),
    );
    expect(fallbackDistance.data, endsWith(' / 0.0 km'));
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byKey(const Key('route-error-text')), findsNothing);
    expect(
      _container(tester).read(mapProvider).routeDraftMarkers,
      hasLength(3),
    );
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('route-save-button')),
    );
    expect(saveButton.onPressed, isNotNull);
  });

  testWidgets('route mode secondary tap is a no-op for draft state', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final container = _container(tester);
    final currentState = container.read(mapProvider);
    container.read(mapProvider.notifier).state = currentState.copyWith(
      selectedLocation: const LatLng(-41.7, 146.7),
    );
    await tester.pump();

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onSecondaryTap?.call(
      const TapPosition(Offset.zero, Offset.zero),
      const LatLng(-41.4, 146.4),
    );
    await tester.pump();

    final state = container.read(mapProvider);
    expect(state.center, currentState.center);
    expect(state.routeDraftMarkers, isEmpty);
    expect(state.isRouteDrafting, isTrue);
  });

  testWidgets('create route hides the entry button while drafting', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    final fab = find.byKey(const Key('create-route-fab'));
    await tester.tap(fab);
    await tester.pumpAndSettle();

    expectRouteDraftOverlaysVisible();
    expect(fab, findsNothing);
  });

  testWidgets(
    'route sheet shows elevation loading and error states after routing completes',
    (tester) async {
      final tasmapRepository = await TestTasmapRepository.create();
      final routeElevationSampler = _ControlledRouteElevationSampler();
      final notifier = MapNotifier(
        peakRepository: PeakRepository.test(InMemoryPeakStorage()),
        overpassService: OverpassService(),
        tasmapRepository: tasmapRepository,
        gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
        routeRepository: RouteRepository.test(InMemoryRouteStorage()),
        routeElevationSampler: routeElevationSampler,
        routePlanner: const _ImmediateRoutePlanner(
          PlannedRouteSegment(
            points: [
              LatLng(-41.5, 146.5),
              LatLng(-41.55, 146.55),
              LatLng(-41.6, 146.6),
            ],
            distanceMeters: 1234.5,
          ),
        ),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage(),
        ),
        loadPositionOnBuild: false,
        loadPeaksOnBuild: false,
        loadTracksOnBuild: false,
      );
      await _pumpMap(tester, notifier, tasmapRepository: tasmapRepository);

      await tester.tap(find.byKey(const Key('create-route-fab')));
      await tester.pumpAndSettle();

      final region = find.byKey(const Key('map-interaction-region'));
      await tester.tapAt(tester.getCenter(region) + const Offset(-40, 0));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(region) + const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const Key('route-elevation-loading-text')),
        findsOneWidget,
      );
      expect(find.text('Distance (2d/3d)'), findsNothing);

      routeElevationSampler.failNext(Exception('DEM offline'));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('route-distance-text')), findsOneWidget);
      expect(
        find.byKey(const Key('route-elevation-loading-text')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('route-elevation-error-text')),
        findsOneWidget,
      );
      expect(find.text('Distance (2d/3d)'), findsNothing);
      expect(find.text('315 m'), findsNothing);
      expect(find.text('234 m'), findsNothing);
    },
  );

  testWidgets(
    'route sheet uses shared meter and kilometer distance formatting',
    (tester) async {
      final notifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          isRouteDrafting: true,
          routeDraftName: 'Short route',
          routeDraftStage: RouteDraftStage.awaitingNextPoint,
          routeDraftCommittedPoints: const [
            LatLng(-41.5, 146.5),
            LatLng(-41.5005, 146.5005),
          ],
          routeDraftDistanceMeters: 850,
          routeDraftElevationSummary: const RouteElevationSummary(
            requestId: 1,
            geometryVersion: 1,
            ascent: 10,
            descent: 12,
          ),
        ),
      );
      await _pumpMap(tester, notifier);

      final distanceText = tester.widget<Text>(
        find.byKey(const Key('route-distance-text')),
      );
      expect(find.text('Distance (2d/3d)'), findsOneWidget);
      expect(distanceText.data, '0.8 / 0.0 km');
    },
  );
}

class _CompletingRoutePlanner implements RoutePlanner {
  final _completer = Completer<PlannedRouteSegment>();

  @override
  Future<RoutePlanningResult> planSegmentResult({
    required LatLng start,
    required LatLng end,
  }) async {
    try {
      final segment = await planSegment(start: start, end: end);
      return RoutePlanningResult(
        status: RoutePlanningStatus.routed,
        points: segment.points,
        distanceMeters: segment.distanceMeters,
        startAnchor: null,
        endAnchor: null,
      );
    } catch (error) {
      return RoutePlanningResult(
        status: RoutePlanningStatus.failed,
        points: const [],
        distanceMeters: 0,
        startAnchor: null,
        endAnchor: null,
        errorMessage: '$error',
      );
    }
  }

  @override
  Future<RouteEndpointProbeResult> probeEndpoint({
    required LatLng point,
  }) async {
    return const RouteEndpointProbeResult(isOnTrack: false);
  }

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
  }) {
    return _completer.future;
  }

  void complete(PlannedRouteSegment segment) {
    if (!_completer.isCompleted) {
      _completer.complete(segment);
    }
  }
}

class _ImmediateRoutePlanner implements RoutePlanner {
  const _ImmediateRoutePlanner(this.segment);

  final PlannedRouteSegment segment;

  @override
  Future<RoutePlanningResult> planSegmentResult({
    required LatLng start,
    required LatLng end,
  }) async {
    return RoutePlanningResult(
      status: RoutePlanningStatus.routed,
      points: segment.points,
      distanceMeters: segment.distanceMeters,
      startAnchor: null,
      endAnchor: null,
    );
  }

  @override
  Future<RouteEndpointProbeResult> probeEndpoint({
    required LatLng point,
  }) async {
    return const RouteEndpointProbeResult(isOnTrack: false);
  }

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
  }) async {
    return segment;
  }
}

class _QueuedRoutePlanner implements RoutePlanner {
  _QueuedRoutePlanner(this._results);

  final List<RoutePlanningResult> _results;
  var _index = 0;

  @override
  Future<RoutePlanningResult> planSegmentResult({
    required LatLng start,
    required LatLng end,
  }) async {
    return _results[_index++];
  }

  @override
  Future<RouteEndpointProbeResult> probeEndpoint({
    required LatLng point,
  }) async {
    return const RouteEndpointProbeResult(isOnTrack: false);
  }

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
  }) async {
    final result = await planSegmentResult(start: start, end: end);
    if (result.status != RoutePlanningStatus.routed) {
      throw RoutePlanningException(
        result.errorMessage ?? 'Routing returned no usable segment.',
      );
    }
    return PlannedRouteSegment(
      points: result.points,
      distanceMeters: result.distanceMeters,
    );
  }
}

class _ImmediateRouteElevationSampler implements RouteElevationSampler {
  const _ImmediateRouteElevationSampler(this.summary);

  final RouteElevationSummary summary;

  @override
  Future<RouteElevationSummary> sampleRoute({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  }) async {
    return RouteElevationSummary(
      requestId: requestId,
      geometryVersion: geometryVersion,
      distance3d: summary.distance3d,
      ascent: summary.ascent,
      descent: summary.descent,
      startElevation: summary.startElevation,
      endElevation: summary.endElevation,
      lowestElevation: summary.lowestElevation,
      highestElevation: summary.highestElevation,
    );
  }

  @override
  Future<List<double?>> samplePointElevations(List<LatLng> points) async {
    return List<double?>.filled(points.length, null, growable: false);
  }
}

class _ControlledRouteElevationSampler implements RouteElevationSampler {
  final _completers = <Completer<RouteElevationSummary>>[];

  @override
  Future<RouteElevationSummary> sampleRoute({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  }) {
    final completer = Completer<RouteElevationSummary>();
    _completers.add(completer);
    return completer.future;
  }

  @override
  Future<List<double?>> samplePointElevations(List<LatLng> points) async {
    return List<double?>.filled(points.length, null, growable: false);
  }

  void failNext(Object error) {
    _completers.removeAt(0).completeError(error);
  }
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byKey(const Key('map-interaction-region'))),
  );
}

Future<void> _pumpMap(
  WidgetTester tester,
  MapNotifier notifier, {
  RouteRepository? routeRepository,
  TasmapRepository? tasmapRepository,
  Size surfaceSize = const Size(1600, 900),
}) async {
  final effectiveTasmapRepository =
      tasmapRepository ?? await TestTasmapRepository.create();
  final effectiveRouteRepository =
      routeRepository ?? RouteRepository.test(InMemoryRouteStorage());
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        routeGraphStoreProvider.overrideWithValue(_ReadyRouteGraphStore()),
        routeRepositoryProvider.overrideWithValue(effectiveRouteRepository),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        tasmapRepositoryProvider.overrideWithValue(effectiveTasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(effectiveTasmapRepository),
        ),
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

class _ReadyRouteGraphStore implements RouteGraphStore {
  @override
  Future<void> bootstrapData() async {}

  @override
  Future<trip_routing.TripService> preload() async =>
      trip_routing.TripService();

  @override
  Future<trip_routing.TripService> reload() async => trip_routing.TripService();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}

GpxTrack _track(int id, {List<LatLng>? points}) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    gpxFile: '<gpx></gpx>',
    displayTrackPointsByZoom: points == null
        ? '{}'
        : TrackDisplayCacheBuilder.buildJson([points]),
  );
}

class _FailingRouteStorage implements RouteStorage {
  @override
  bool delete(int id) => false;

  @override
  List<app_route.Route> getAll() => const [];

  @override
  app_route.Route? getById(int id) => null;

  @override
  int save(app_route.Route route) {
    throw Exception('write failed');
  }
}
