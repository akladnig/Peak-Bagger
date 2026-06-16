import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route_marker_display.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/models/route_waypoint.dart';
import 'package:peak_bagger/services/route_repository.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  test('route draft starts clean and clears selected map state', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    container.read(mapProvider.notifier).state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      selectedLocation: const LatLng(-41.6, 146.6),
      selectedTrackId: 7,
    );

    final notifier = container.read(mapProvider.notifier);
    notifier.beginRouteDraft();

    final state = container.read(mapProvider);
    expect(state.isRouteDrafting, isTrue);
    expect(state.routeDraftMode, RouteMode.snapToTrail);
    expect(state.routeDraftName, isEmpty);
    expect(state.routeDraftMarkers, isEmpty);
    expect(state.selectedLocation, const LatLng(-41.6, 146.6));
    expect(state.selectedTrackId, isNull);
  });

  test('route edit seeds the draft from the saved route', () async {
    final route = Route(
      id: 7,
      name: 'Seed Route',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.55, 146.55)],
      gpxRouteElevations: const [100, 120],
      routeWaypoints: const [
        RouteWaypoint(
          latitude: -41.55,
          longitude: 146.55,
          label: 'Bonnet Hill',
          sequence: 1,
          isPeakDerived: true,
          peakOsmId: 42,
          peakName: 'Bonnet Hill',
        ),
      ],
      colour: 0xFF112233,
      distance2d: 17450,
      distance3d: 17920,
      ascent: 912,
      descent: 456,
      startElevation: 100,
      endElevation: 120,
      lowestElevation: 90,
      highestElevation: 130,
    );
    final routeRepository = RouteRepository.test(
      InMemoryRouteStorage([route]),
    );
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
      routeRepository: routeRepository,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    container.read(mapProvider.notifier).state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      selectedLocation: const LatLng(-41.6, 146.6),
      showRoutes: true,
      selectedRouteId: 7,
    );

    final notifier = container.read(mapProvider.notifier);
    notifier.beginRouteEdit(route);

    final state = container.read(mapProvider);
    expect(state.isRouteDrafting, isTrue);
    expect(state.sourceRouteId, 7);
    expect(state.selectedRouteId, isNull);
    expect(state.selectedLocation, isNull);
    expect(state.routeDraftName, 'Seed Route');
    expect(state.routeDraftColour, 0xFF112233);
    expect(state.routeDraftCommittedPoints, route.gpxRoute);
    expect(state.routeDraftMarkers, route.gpxRoute);
    expect(state.routeDraftStage, RouteDraftStage.awaitingNextPoint);
    expect(state.routeDraftPointElevations, const [100.0, 120.0]);
    expect(state.routeDraftDistanceMeters, 17450);
    expect(state.routeDraftElevationSummary, isNotNull);
    expect(state.routeDraftElevationSummary!.distance3d, 17920);
    expect(state.routeDraftElevationSummary!.ascent, 912);
    expect(state.routeDraftElevationSummary!.descent, 456);
    expect(state.routeDraftElevationSummary!.startElevation, 100);
    expect(state.routeDraftElevationSummary!.endElevation, 120);
    expect(state.routeDraftElevationSummary!.lowestElevation, 90);
    expect(state.routeDraftElevationSummary!.highestElevation, 130);
    expect(state.routeDraftControlEndpoints, hasLength(2));
    expect(
      state.routeDraftControlEndpoints.last.kind,
      RouteDraftEndpointKind.peakTarget,
    );
    expect(state.routeDraftPeak, isNotNull);
    expect(state.routeDraftPeak!.name, 'Bonnet Hill');
    expect(state.routeDraftPeak!.osmId, 42);
  });

  test('route draft markers append in tap order', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    container.read(mapProvider.notifier).state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    final notifier = container.read(mapProvider.notifier);
    notifier.beginRouteDraft();
    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.5));
    notifier.addRouteDraftMarker(const LatLng(-41.6, 146.6));
    await Future<void>.delayed(Duration.zero);

    expect(container.read(mapProvider).routeDraftMarkers, [
      const LatLng(-41.5, 146.5),
      const LatLng(-41.6, 146.6),
    ]);
  });

  test('route draft end clears draft state', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    container.read(mapProvider.notifier).state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    final notifier = container.read(mapProvider.notifier);
    notifier.beginRouteDraft();
    notifier.setRouteDraftName('Test route');
    notifier.setRouteDraftMode(RouteMode.straightLine);
    expect(container.read(mapProvider).routeDraftMode, RouteMode.straightLine);
    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.5));

    notifier.endRouteDraft();

    final state = container.read(mapProvider);
    expect(state.isRouteDrafting, isFalse);
    expect(state.routeDraftMode, RouteMode.snapToTrail);
    expect(state.routeDraftName, isEmpty);
    expect(state.routeDraftMarkers, isEmpty);
  });

  test('undo and redo restore a straight-line point placement', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    notifier.beginRouteDraft();
    notifier.setRouteDraftMode(RouteMode.straightLine);
    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.5));
    notifier.addRouteDraftMarker(
      const LatLng(-41.6, 146.6),
      straightLine: true,
    );

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.6, 146.6),
    ]);

    notifier.undoRouteDraftEdit();

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
    ]);

    notifier.redoRouteDraftEdit();

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.6, 146.6),
    ]);
  });

  test('deleting the final remaining marker keeps the draft open and undo restores it', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    notifier.beginRouteDraft();
    notifier.setRouteDraftMode(RouteMode.straightLine);
    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.5));

    await notifier.deleteRouteDraftMarker('0');

    final emptiedState = container.read(mapProvider);
    expect(emptiedState.isRouteDrafting, isTrue);
    expect(emptiedState.routeDraftStage, RouteDraftStage.awaitingStart);
    expect(emptiedState.routeDraftMarkers, isEmpty);
    expect(emptiedState.routeDraftCommittedPoints, isEmpty);

    notifier.undoRouteDraftEdit();

    expect(container.read(mapProvider).routeDraftMarkers, const [
      LatLng(-41.5, 146.5),
    ]);
  });

  test('moving a straight-line marker updates geometry and undo restores it', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    notifier.beginRouteDraft();
    notifier.setRouteDraftMode(RouteMode.straightLine);
    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.5));
    notifier.addRouteDraftMarker(const LatLng(-41.6, 146.6), straightLine: true);

    await notifier.moveRouteDraftMarker('1', const LatLng(-41.65, 146.65));

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.65, 146.65),
    ]);

    notifier.undoRouteDraftEdit();

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.6, 146.6),
    ]);
  });

  test('dragging a marker creates one undo step across multiple updates', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    notifier.beginRouteDraft();
    notifier.setRouteDraftMode(RouteMode.straightLine);
    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.5));
    notifier.addRouteDraftMarker(const LatLng(-41.6, 146.6), straightLine: true);

    notifier.beginRouteDraftMarkerDrag('1');
    await notifier.updateRouteDraftMarkerDrag('1', const LatLng(-41.62, 146.62));
    await notifier.updateRouteDraftMarkerDrag('1', const LatLng(-41.65, 146.65));
    notifier.endRouteDraftMarkerDrag('1');

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.65, 146.65),
    ]);

    notifier.undoRouteDraftEdit();

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.6, 146.6),
    ]);
  });

  test('moving a peak-derived marker invalidates the draft peak target fallback', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    const start = LatLng(-41.5, 146.5);
    const peakPoint = LatLng(-41.6, 146.6);
    const nextPoint = LatLng(-41.7, 146.7);
    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: peakPoint.latitude,
      longitude: peakPoint.longitude,
    );
    notifier.state = MapState(
      center: start,
      zoom: 15,
      basemap: Basemap.tracestrack,
      peaks: [peak],
      selectedLocation: peakPoint,
    );

    notifier.beginRouteDraft();
    notifier.setRouteDraftMode(RouteMode.straightLine);
    notifier.addRouteDraftMarker(start, straightLine: true);
    notifier.addRouteDraftMarker(peakPoint, straightLine: true);
    notifier.addRouteDraftMarker(nextPoint, straightLine: true);

    expect(container.read(mapProvider).routeDraftPeakTarget?.osmId, peak.osmId);

    await notifier.moveRouteDraftMarker('1', const LatLng(-41.61, 146.61));

    final state = container.read(mapProvider);
    expect(state.routeDraftPeakTargetLocked, isTrue);
    expect(state.routeDraftPeakTarget, isNull);
  });

  test('moving the first open-route marker updates the start and undo restores it', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    const start = LatLng(-41.5, 146.5);
    const middle = LatLng(-41.6, 146.6);
    const end = LatLng(-41.7, 146.7);
    notifier.beginRouteDraft();
    notifier.setRouteDraftMode(RouteMode.straightLine);
    notifier.addRouteDraftMarker(start);
    notifier.addRouteDraftMarker(middle, straightLine: true);
    notifier.addRouteDraftMarker(end, straightLine: true);
    await Future<void>.delayed(Duration.zero);

    await notifier.moveRouteDraftMarker('0', const LatLng(-41.45, 146.45));

    final movedState = container.read(mapProvider);
    expect(movedState.routeDraftCommittedPoints, const [
      LatLng(-41.45, 146.45),
      middle,
      end,
    ]);
    expect(movedState.routeDraftMarkers, const [
      LatLng(-41.45, 146.45),
      middle,
      end,
    ]);

    notifier.undoRouteDraftEdit();

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      start,
      middle,
      end,
    ]);
  });

  test('deleting the last open-route marker removes it and undo restores it', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    const start = LatLng(-41.5, 146.5);
    const middle = LatLng(-41.6, 146.6);
    const end = LatLng(-41.7, 146.7);
    notifier.beginRouteDraft();
    notifier.setRouteDraftMode(RouteMode.straightLine);
    notifier.addRouteDraftMarker(start);
    notifier.addRouteDraftMarker(middle, straightLine: true);
    notifier.addRouteDraftMarker(end, straightLine: true);
    await Future<void>.delayed(Duration.zero);

    await notifier.deleteRouteDraftMarker('2');

    final deletedState = container.read(mapProvider);
    expect(deletedState.routeDraftCommittedPoints, const [start, middle]);
    expect(deletedState.routeDraftMarkers, const [start, middle]);
    expect(deletedState.routeDraftStage, RouteDraftStage.awaitingNextPoint);

    notifier.undoRouteDraftEdit();

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      start,
      middle,
      end,
    ]);
  });

  test('moving a closed-loop terminal marker reopens the route and undo restores it', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    const start = LatLng(-41.5, 146.5);
    const middle = LatLng(-41.6, 146.6);
    const end = LatLng(-41.7, 146.7);
    notifier.beginRouteDraft();
    notifier.setRouteDraftMode(RouteMode.straightLine);
    notifier.addRouteDraftMarker(start);
    notifier.addRouteDraftMarker(middle, straightLine: true);
    notifier.addRouteDraftMarker(end, straightLine: true);
    await Future<void>.delayed(Duration.zero);

    await notifier.applyRouteDraftCloseLoop();

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      start,
      middle,
      end,
      start,
    ]);

    await notifier.moveRouteDraftMarker('0', const LatLng(-41.45, 146.45));

    final reopenedState = container.read(mapProvider);
    expect(reopenedState.routeDraftCommittedPoints, const [
      LatLng(-41.45, 146.45),
      middle,
      end,
      start,
    ]);
    expect(reopenedState.routeDraftMarkers, const [
      LatLng(-41.45, 146.45),
      middle,
      end,
      start,
    ]);

    notifier.undoRouteDraftEdit();

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      start,
      middle,
      end,
      start,
    ]);
  });

  test('stale drag results are ignored while the latest marker move wins', () async {
    final routePlanner = _ControlledRoutePlanner();
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: routePlanner,
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    const start = LatLng(-41.5, 146.5);
    const end = LatLng(-41.6, 146.6);
    const firstDragPoint = LatLng(-41.62, 146.62);
    const secondDragPoint = LatLng(-41.65, 146.65);
    notifier.beginRouteDraft();
    notifier.addRouteDraftMarker(start);
    notifier.addRouteDraftMarker(end);
    await Future<void>.delayed(Duration.zero);

    routePlanner.completeNext(
      const PlannedRouteSegment(
        points: [start, LatLng(-41.55, 146.55), end],
        distanceMeters: 1000,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    notifier.beginRouteDraftMarkerDrag('1');
    final firstUpdate = notifier.updateRouteDraftMarkerDrag('1', firstDragPoint);
    final secondUpdate = notifier.updateRouteDraftMarkerDrag('1', secondDragPoint);

    expect(routePlanner.requests, const [
      (start: start, end: end),
      (start: start, end: firstDragPoint),
      (start: start, end: secondDragPoint),
    ]);

    routePlanner.completeNext(
      const PlannedRouteSegment(
        points: [start, LatLng(-41.61, 146.61), firstDragPoint],
        distanceMeters: 1000,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      start,
      LatLng(-41.55, 146.55),
      end,
    ]);

    routePlanner.completeNext(
      const PlannedRouteSegment(
        points: [start, LatLng(-41.63, 146.63), secondDragPoint],
        distanceMeters: 1000,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(mapProvider).routeDraftCommittedPoints, const [
      start,
      LatLng(-41.63, 146.63),
      secondDragPoint,
    ]);

    notifier.endRouteDraftMarkerDrag('1');
    await firstUpdate;
    await secondUpdate;
  });

  test(
    'route to peak routes the first tap to the captured peak target',
    () async {
      final routePlanner = _ControlledRoutePlanner();
      final realNotifier = await _buildRouteTestNotifier(
        routePlanner: routePlanner,
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => realNotifier)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(mapProvider.notifier);
      notifier.state = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      );

      const start = LatLng(-41.5, 146.5);
      const peakPoint = LatLng(-41.6, 146.6);
      final peak = Peak(
        osmId: 6406,
        name: 'Bonnet Hill',
        latitude: peakPoint.latitude,
        longitude: peakPoint.longitude,
      );

      notifier.beginRouteDraft(peakTarget: peak);
      notifier.setRouteDraftMode(RouteMode.routeToPeak);
      notifier.addRouteDraftMarker(start);
      await Future<void>.delayed(Duration.zero);
      routePlanner.completeNext(
        const PlannedRouteSegment(
          points: [start, LatLng(-41.55, 146.55), peakPoint],
          distanceMeters: 1000,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider);
      expect(routePlanner.requests, const [(start: start, end: peakPoint)]);
      expect(state.routeDraftMarkers, const [start, peakPoint]);
      expect(state.routeDraftCommittedPoints, const [
        start,
        LatLng(-41.55, 146.55),
        peakPoint,
      ]);
      expect(
        state.routeDraftDistanceMeters,
        closeTo(
          const Distance().as(
                LengthUnit.Meter,
                start,
                const LatLng(-41.55, 146.55),
              ) +
              const Distance().as(
                LengthUnit.Meter,
                const LatLng(-41.55, 146.55),
                peakPoint,
              ),
          0.001,
        ),
      );
      expect(state.routeDraftMode, RouteMode.snapToTrail);
      expect(state.routeDraftPeak, isNull);
    },
  );

  test(
    'route to peak calculates after switching with a start already tapped',
    () async {
      final routePlanner = _ControlledRoutePlanner();
      final realNotifier = await _buildRouteTestNotifier(
        routePlanner: routePlanner,
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => realNotifier)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(mapProvider.notifier);
      notifier.state = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      );

      const start = LatLng(-41.5, 146.5);
      const peakPoint = LatLng(-41.6, 146.6);
      final peak = Peak(
        osmId: 6406,
        name: 'Bonnet Hill',
        latitude: peakPoint.latitude,
        longitude: peakPoint.longitude,
      );

      notifier.beginRouteDraft(peakTarget: peak);
      notifier.addRouteDraftMarker(start);
      await Future<void>.delayed(Duration.zero);

      expect(routePlanner.requests, isEmpty);

      notifier.setRouteDraftMode(RouteMode.routeToPeak);
      await Future<void>.delayed(Duration.zero);
      routePlanner.completeNext(
        const PlannedRouteSegment(
          points: [start, LatLng(-41.55, 146.55), peakPoint],
          distanceMeters: 1000,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider);
      expect(routePlanner.requests, const [(start: start, end: peakPoint)]);
      expect(state.routeDraftMarkers, const [start, peakPoint]);
      expect(state.routeDraftCommittedPoints, const [
        start,
        LatLng(-41.55, 146.55),
        peakPoint,
      ]);
      expect(
        state.routeDraftDistanceMeters,
        closeTo(
          const Distance().as(
                LengthUnit.Meter,
                start,
                const LatLng(-41.55, 146.55),
              ) +
              const Distance().as(
                LengthUnit.Meter,
                const LatLng(-41.55, 146.55),
                peakPoint,
              ),
          0.001,
        ),
      );
      expect(state.routeDraftMode, RouteMode.snapToTrail);
      expect(state.routeDraftPeak, isNull);
    },
  );

  test('adding a point after a routed peak keeps the peak marker as target', () async {
    final routePlanner = _ControlledRoutePlanner();
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: routePlanner,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    const start = LatLng(-41.5, 146.5);
    const peakPoint = LatLng(-41.6, 146.6);
    const nextPoint = LatLng(-41.7, 146.7);
    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: peakPoint.latitude,
      longitude: peakPoint.longitude,
    );

    notifier.beginRouteDraft(peakTarget: peak);
    notifier.setRouteDraftMode(RouteMode.routeToPeak);
    notifier.addRouteDraftMarker(start);
    await Future<void>.delayed(Duration.zero);
    routePlanner.completeNext(
      const PlannedRouteSegment(
        points: [start, LatLng(-41.55, 146.55), peakPoint],
        distanceMeters: 1000,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    notifier.addRouteDraftMarker(nextPoint);
    await Future<void>.delayed(Duration.zero);
    routePlanner.completeNext(
      const PlannedRouteSegment(
        points: [peakPoint, LatLng(-41.65, 146.65), nextPoint],
        distanceMeters: 1000,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(mapProvider);
    expect(state.routeDraftDisplayMarkers, hasLength(3));
    expect(state.routeDraftDisplayMarkers[0].kind, RouteMarkerKind.circle);
    expect(state.routeDraftDisplayMarkers[1].kind, RouteMarkerKind.target);
    expect(state.routeDraftDisplayMarkers[1].number, isNull);
    expect(state.routeDraftDisplayMarkers[2].kind, RouteMarkerKind.target);
  });

  test('manually adding a point on a peak keeps it as a peak marker', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: const _ImmediateStraightRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    const start = LatLng(-41.5, 146.5);
    const peakPoint = LatLng(-41.6, 146.6);
    const nextPoint = LatLng(-41.7, 146.7);
    notifier.state = MapState(
      center: start,
      zoom: 15,
      basemap: Basemap.tracestrack,
      peaks: [
        Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          latitude: peakPoint.latitude,
          longitude: peakPoint.longitude,
        ),
      ],
    );

    notifier.beginRouteDraft();
    notifier.addRouteDraftMarker(start, straightLine: true);
    notifier.addRouteDraftMarker(peakPoint, straightLine: true);
    notifier.addRouteDraftMarker(nextPoint, straightLine: true);

    final state = container.read(mapProvider);
    expect(state.routeDraftControlEndpoints, hasLength(3));
    expect(
      state.routeDraftControlEndpoints[1].kind,
      RouteDraftEndpointKind.peakTarget,
    );
    expect(state.routeDraftDisplayMarkers[0].kind, RouteMarkerKind.circle);
    expect(state.routeDraftDisplayMarkers[1].kind, RouteMarkerKind.target);
    expect(state.routeDraftDisplayMarkers[1].number, isNull);
    expect(state.routeDraftDisplayMarkers[2].kind, RouteMarkerKind.target);
  });

  test(
    'third tap appends a new routed segment from the current endpoint',
    () async {
      final routePlanner = _ControlledRoutePlanner();
      final realNotifier = await _buildRouteTestNotifier(
        routePlanner: routePlanner,
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => realNotifier)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(mapProvider.notifier);
      notifier.state = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      );

      const point1 = LatLng(-41.5, 146.5);
      const point2 = LatLng(-41.6, 146.6);
      const point3 = LatLng(-41.7, 146.7);
      notifier.beginRouteDraft();
      notifier.addRouteDraftMarker(point1);
      notifier.addRouteDraftMarker(point2);
      await Future<void>.delayed(Duration.zero);
      routePlanner.completeNext(
        const PlannedRouteSegment(
          points: [point1, LatLng(-41.55, 146.55), point2],
          distanceMeters: 1000,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      notifier.addRouteDraftMarker(point3);
      await Future<void>.delayed(Duration.zero);
      routePlanner.completeNext(
        const PlannedRouteSegment(
          points: [point2, LatLng(-41.65, 146.65), point3],
          distanceMeters: 1200,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider);
      expect(routePlanner.requests, const [
        (start: point1, end: point2),
        (start: point2, end: point3),
      ]);
      expect(state.routeDraftMarkers, const [point1, point2, point3]);
      expect(state.routeDraftCommittedPoints, const [
        point1,
        LatLng(-41.55, 146.55),
        point2,
        LatLng(-41.65, 146.65),
        point3,
      ]);
      expect(
        state.routeDraftDistanceMeters,
        closeTo(
          const Distance().as(
                LengthUnit.Meter,
                point1,
                const LatLng(-41.55, 146.55),
              ) +
              const Distance().as(
                LengthUnit.Meter,
                const LatLng(-41.55, 146.55),
                point2,
              ) +
              const Distance().as(
                LengthUnit.Meter,
                point2,
                const LatLng(-41.65, 146.65),
              ) +
              const Distance().as(
                LengthUnit.Meter,
                const LatLng(-41.65, 146.65),
                point3,
              ),
          0.001,
        ),
      );
    },
  );

  test('identical next point is rejected before planner dispatch', () async {
    final routePlanner = _ControlledRoutePlanner();
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: routePlanner,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    const point = LatLng(-41.5, 146.5);
    notifier.beginRouteDraft();
    notifier.addRouteDraftMarker(point);
    notifier.addRouteDraftMarker(point);

    final state = container.read(mapProvider);
    expect(routePlanner.requests, isEmpty);
    expect(state.routeDraftStage, RouteDraftStage.segmentFailure);
    expect(state.routeDraftMarkers, const [point, point]);
    expect(state.routeDraftError, isNotNull);
  });

  test(
    'later segment no-path failure keeps subsequent taps straight',
    () async {
      final routePlanner = _ControlledRoutePlanner();
      final realNotifier = await _buildRouteTestNotifier(
        routePlanner: routePlanner,
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => realNotifier)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(mapProvider.notifier);
      notifier.state = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      );

      const point1 = LatLng(-41.5, 146.5);
      const point2 = LatLng(-41.6, 146.6);
      const point3 = LatLng(-41.7, 146.7);
      const point4 = LatLng(-41.8, 146.8);
      notifier.beginRouteDraft();
      notifier.addRouteDraftMarker(point1);
      notifier.addRouteDraftMarker(point2);
      await Future<void>.delayed(Duration.zero);
      routePlanner.completeNext(
        const PlannedRouteSegment(
          points: [point1, LatLng(-41.55, 146.55), point2],
          distanceMeters: 1000,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      notifier.addRouteDraftMarker(point3);
      await Future<void>.delayed(Duration.zero);
      routePlanner.completeResult(
        RoutePlanningResult(
          status: RoutePlanningStatus.noPath,
          points: const [],
          distanceMeters: 0,
          startAnchor: null,
          endAnchor: const RouteEndpointAnchor(
            point: point3,
            type: RouteEndpointAnchorType.node,
            nodeId: 3,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      notifier.addRouteDraftMarker(point4);
      await Future<void>.delayed(Duration.zero);
      routePlanner.completeProbe(
        const RouteEndpointProbeResult(isOnTrack: false),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider);
      expect(state.routeDraftStage, RouteDraftStage.awaitingNextPoint);
      expect(state.routeDraftCommittedPoints, const [
        point1,
        LatLng(-41.55, 146.55),
        point2,
        point3,
        point4,
      ]);
      expect(state.routeDraftProvisionalPoints, isEmpty);
      expect(state.routeDraftError, isNull);
      expect(routePlanner.requests, const [
        (start: point1, end: point2),
        (start: point2, end: point3),
      ]);
      expect(
        state.routeDraftDistanceMeters,
        closeTo(
          const Distance().as(
                LengthUnit.Meter,
                point1,
                const LatLng(-41.55, 146.55),
              ) +
              const Distance().as(
                LengthUnit.Meter,
                const LatLng(-41.55, 146.55),
                point2,
              ) +
              const Distance().as(LengthUnit.Meter, point2, point3) +
              const Distance().as(LengthUnit.Meter, point3, point4),
          0.001,
        ),
      );
    },
  );

  test(
    'later segment generic failure keeps the failed endpoint editable',
    () async {
      final routePlanner = _ControlledRoutePlanner();
      final realNotifier = await _buildRouteTestNotifier(
        routePlanner: routePlanner,
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => realNotifier)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(mapProvider.notifier);
      notifier.state = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      );

      const point1 = LatLng(-41.5, 146.5);
      const point2 = LatLng(-41.6, 146.6);
      const point3 = LatLng(-41.7, 146.7);
      notifier.beginRouteDraft();
      notifier.addRouteDraftMarker(point1);
      notifier.addRouteDraftMarker(point2);
      await Future<void>.delayed(Duration.zero);
      routePlanner.completeNext(
        const PlannedRouteSegment(
          points: [point1, LatLng(-41.55, 146.55), point2],
          distanceMeters: 1000,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      notifier.addRouteDraftMarker(point3);
      await Future<void>.delayed(Duration.zero);
      routePlanner.failNext(StateError('Unexpected routing failure.'));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider);
      expect(state.routeDraftStage, RouteDraftStage.segmentFailure);
      expect(state.routeDraftCommittedPoints, const [
        point1,
        LatLng(-41.55, 146.55),
        point2,
      ]);
      expect(state.routeDraftProvisionalPoints, isEmpty);
      expect(state.routeDraftError, contains('Unexpected routing failure.'));
      expect(state.routeDraftMarkers, const [point1, point2, point3]);
      expect(routePlanner.requests, const [
        (start: point1, end: point2),
        (start: point2, end: point3),
      ]);
    },
  );

  test('late route result is ignored after cancelling the draft', () async {
    final routePlanner = _ControlledRoutePlanner();
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: routePlanner,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    const point1 = LatLng(-41.5, 146.5);
    const point2 = LatLng(-41.6, 146.6);
    notifier.beginRouteDraft();
    notifier.addRouteDraftMarker(point1);
    notifier.addRouteDraftMarker(point2);
    await Future<void>.delayed(Duration.zero);

    notifier.endRouteDraft();
    routePlanner.completeNext(
      const PlannedRouteSegment(
        points: [point1, LatLng(-41.55, 146.55), point2],
        distanceMeters: 1000,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(mapProvider);
    expect(state.isRouteDrafting, isFalse);
    expect(state.routeDraftCommittedPoints, isEmpty);
    expect(state.routeDraftMarkers, isEmpty);
  });

  test(
    'committed geometry changes trigger resample and stale elevation results are ignored',
    () async {
      final routeElevationSampler = _ControlledRouteElevationSampler();
      final realNotifier = await _buildRouteTestNotifier(
        routePlanner: _ControlledRoutePlanner(),
        routeElevationSampler: routeElevationSampler,
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => realNotifier)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(mapProvider.notifier);
      notifier.state = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      );

      const point1 = LatLng(-41.5, 146.5);
      const point2 = LatLng(-41.6, 146.6);
      const point3 = LatLng(-41.7, 146.7);
      notifier.beginRouteDraft();
      notifier.addRouteDraftMarker(point1);
      notifier.addRouteDraftMarker(point2, straightLine: true);
      await Future<void>.delayed(Duration.zero);

      expect(routeElevationSampler.requests, hasLength(1));
      expect(container.read(mapProvider).routeDraftElevationLoading, isTrue);

      notifier.addRouteDraftMarker(point3, straightLine: true);
      await Future<void>.delayed(Duration.zero);

      expect(routeElevationSampler.requests, hasLength(2));

      routeElevationSampler.completeNext(
        const RouteElevationSummary(
          requestId: 1,
          geometryVersion: 1,
          ascent: 111,
          descent: 22,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(container.read(mapProvider).routeDraftElevationSummary, isNull);

      routeElevationSampler.completeNext(
        const RouteElevationSummary(
          requestId: 2,
          geometryVersion: 2,
          ascent: 345,
          descent: 210,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider);
      expect(state.routeDraftElevationLoading, isFalse);
      expect(state.routeDraftElevationSummary?.ascent, 345);
      expect(state.routeDraftElevationSummary?.descent, 210);
      expect(state.routeDraftPointElevations, hasLength(3));
      expect(state.routeDraftPointElevations, everyElement(isNotNull));
    },
  );

  test('save uses matching elevation summary else zeros', () async {
    final routeRepository = RouteRepository.test(InMemoryRouteStorage());
    final routeElevationSampler = _ControlledRouteElevationSampler();
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: _ControlledRoutePlanner(),
      routeRepository: routeRepository,
      routeElevationSampler: routeElevationSampler,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    );

    const point1 = LatLng(-41.5, 146.5);
    const point2 = LatLng(-41.6, 146.6);
    notifier.beginRouteDraft();
    notifier.setRouteDraftName('Sampled route');
    notifier.addRouteDraftMarker(point1);
    notifier.addRouteDraftMarker(point2, straightLine: true);
    await Future<void>.delayed(Duration.zero);

    routeElevationSampler.completeNext(
      const RouteElevationSummary(
        requestId: 1,
        geometryVersion: 1,
        distance3d: 1500,
        ascent: 320,
        descent: 210,
        startElevation: 100,
        endElevation: 180,
        lowestElevation: 95,
        highestElevation: 220,
      ),
    );
    await Future<void>.delayed(Duration.zero);

    await notifier.saveRouteDraft();

    var savedRoute = routeRepository.getAllRoutes().single;
    expect(savedRoute.ascent, 320);
    expect(savedRoute.descent, 210);
    expect(savedRoute.distance3d, 1500);

    notifier.beginRouteDraft();
    notifier.setRouteDraftName('Zero route');
    notifier.addRouteDraftMarker(point1);
    notifier.addRouteDraftMarker(point2, straightLine: true);
    await Future<void>.delayed(Duration.zero);

    await notifier.saveRouteDraft();

    savedRoute = routeRepository.getAllRoutes().last;
    expect(savedRoute.ascent, 0);
    expect(savedRoute.descent, 0);
    expect(savedRoute.distance3d, 0);
  });

  test('applyRouteDraftOutAndBack rejects inconsistent draft state', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: _ControlledRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      isRouteDrafting: true,
      routeDraftMode: RouteMode.straightLine,
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
      routeDraftMarkers: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
      routeDraftCommittedPoints: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.55, 146.55),
        LatLng(-41.7, 146.7),
      ],
      routeDraftDistanceMeters: 1000,
    );

    notifier.applyRouteDraftOutAndBack();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(mapProvider);
    expect(state.routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.55, 146.55),
      LatLng(-41.7, 146.7),
    ]);
    expect(state.routeDraftError, contains('inconsistent'));
    expect(state.routeDraftGeometryVersion, 0);
  });

  test(
    'save failure retry recomputes waypoint metadata from current draft',
    () async {
      final routeRepository = RouteRepository.test(
        _FailOnceRouteStorage(InMemoryRouteStorage()),
      );
      final realNotifier = await _buildRouteTestNotifier(
        routePlanner: _ControlledRoutePlanner(),
        routeRepository: routeRepository,
        routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => realNotifier)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(mapProvider.notifier);
      notifier.state = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        isRouteDrafting: true,
        routeDraftName: 'Retry route',
        routeDraftMode: RouteMode.straightLine,
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
        routeDraftMarkers: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
        routeDraftCommittedPoints: const [
          LatLng(-41.5, 146.5),
          LatLng(-41.55, 146.55),
          LatLng(-41.6, 146.6),
        ],
        routeDraftDistanceMeters: 1000,
      );

      await notifier.saveRouteDraft();
      expect(routeRepository.getAllRoutes(), isEmpty);
      expect(container.read(mapProvider).isRouteDrafting, isTrue);

      notifier.state = notifier.state.copyWith(
        routeDraftControlEndpoints: const [
          RouteDraftControlEndpoint(
            id: 'endpoint-0',
            point: LatLng(-41.5, 146.5),
            kind: RouteDraftEndpointKind.tapped,
          ),
          RouteDraftControlEndpoint(
            id: 'endpoint-1',
            point: LatLng(-41.7, 146.7),
            kind: RouteDraftEndpointKind.tapped,
          ),
        ],
        routeDraftMarkers: const [LatLng(-41.5, 146.5), LatLng(-41.7, 146.7)],
        routeDraftCommittedPoints: const [
          LatLng(-41.5, 146.5),
          LatLng(-41.55, 146.55),
          LatLng(-41.7, 146.7),
        ],
        routeDraftDistanceMeters: 1200,
      );

      await notifier.saveRouteDraft();

      final savedRoute = routeRepository.getAllRoutes().single;
      expect(savedRoute.routeWaypoints, hasLength(1));
      expect(savedRoute.routeWaypoints.single.latitude, -41.7);
      expect(savedRoute.routeWaypoints.single.longitude, 146.7);
      expect(savedRoute.routeWaypoints.single.label, 'Waypoint 1');
      expect(container.read(mapProvider).isRouteDrafting, isFalse);
    },
  );

  test('applyRouteDraftOutAndBack mirrors the committed path once', () async {
    final routeElevationSampler = _ControlledRouteElevationSampler();
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: _ControlledRoutePlanner(),
      routeElevationSampler: routeElevationSampler,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      isRouteDrafting: true,
      routeDraftMode: RouteMode.straightLine,
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
      routeDraftMarkers: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
      routeDraftCommittedPoints: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.55, 146.55),
        LatLng(-41.6, 146.6),
      ],
      routeDraftDistanceMeters: 1000,
    );

    notifier.applyRouteDraftOutAndBack();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(mapProvider);
    expect(state.routeDraftMode, RouteMode.straightLine);
    expect(state.routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.55, 146.55),
      LatLng(-41.6, 146.6),
      LatLng(-41.55, 146.55),
      LatLng(-41.5, 146.5),
    ]);
    expect(state.routeDraftControlEndpoints, hasLength(3));
    expect(
      state.routeDraftControlEndpoints.last.point,
      const LatLng(-41.5, 146.5),
    );
    expect(routeElevationSampler.requests, hasLength(1));
    expect(routeElevationSampler.requests.single.requestId, 1);
    expect(routeElevationSampler.requests.single.geometryVersion, 1);
    expect(state.routeDraftGeometryVersion, 1);
    expect(state.routeDraftElevationLoading, isTrue);
  });

  test(
    'applyRouteDraftOutAndBack is a no-op after the return leg is added',
    () async {
      final routeElevationSampler = _ControlledRouteElevationSampler();
      final realNotifier = await _buildRouteTestNotifier(
        routePlanner: _ControlledRoutePlanner(),
        routeElevationSampler: routeElevationSampler,
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => realNotifier)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(mapProvider.notifier);
      notifier.state = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        isRouteDrafting: true,
        routeDraftMode: RouteMode.straightLine,
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
        routeDraftMarkers: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
        routeDraftCommittedPoints: const [
          LatLng(-41.5, 146.5),
          LatLng(-41.55, 146.55),
          LatLng(-41.6, 146.6),
        ],
        routeDraftDistanceMeters: 1000,
      );

      notifier.applyRouteDraftOutAndBack();
      await Future<void>.delayed(Duration.zero);
      final afterFirstApplication = container.read(mapProvider);

      notifier.applyRouteDraftOutAndBack();

      final state = container.read(mapProvider);
      expect(
        state.routeDraftCommittedPoints,
        afterFirstApplication.routeDraftCommittedPoints,
      );
      expect(
        state.routeDraftControlEndpoints,
        afterFirstApplication.routeDraftControlEndpoints,
      );
      expect(
        state.routeDraftDistanceMeters,
        afterFirstApplication.routeDraftDistanceMeters,
      );
      expect(routeElevationSampler.requests, hasLength(1));
    },
  );
  test('applyRouteDraftCloseLoop routes back to the start point', () async {
    final routePlanner = _ControlledRoutePlanner();
    final routeElevationSampler = _ControlledRouteElevationSampler();
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: routePlanner,
      routeElevationSampler: routeElevationSampler,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      isRouteDrafting: true,
      routeDraftMode: RouteMode.straightLine,
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
        RouteDraftControlEndpoint(
          id: 'endpoint-2',
          point: LatLng(-41.7, 146.7),
          kind: RouteDraftEndpointKind.tapped,
        ),
      ],
      routeDraftMarkers: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.6, 146.6),
        LatLng(-41.7, 146.7),
      ],
      routeDraftCommittedPoints: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.6, 146.6),
        LatLng(-41.7, 146.7),
      ],
      routeDraftDistanceMeters: 1000,
    );

    final closeLoop = notifier.applyRouteDraftCloseLoop();
    await Future<void>.delayed(Duration.zero);
    routePlanner.completeResult(
      const RoutePlanningResult(
        status: RoutePlanningStatus.routed,
        points: [
          LatLng(-41.7, 146.7),
          LatLng(-41.65, 146.65),
          LatLng(-41.5, 146.5),
        ],
        distanceMeters: 900,
        startAnchor: null,
        endAnchor: null,
      ),
    );
    await closeLoop;
    await Future<void>.delayed(Duration.zero);

    final state = container.read(mapProvider);
    expect(routePlanner.requests, const [
      (start: LatLng(-41.7, 146.7), end: LatLng(-41.5, 146.5)),
    ]);
    expect(state.routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.6, 146.6),
      LatLng(-41.7, 146.7),
      LatLng(-41.65, 146.65),
      LatLng(-41.5, 146.5),
    ]);
    expect(state.routeDraftControlEndpoints, hasLength(4));
    expect(
      state.routeDraftControlEndpoints.last.point,
      const LatLng(-41.5, 146.5),
    );
    expect(state.routeDraftMarkers, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.6, 146.6),
      LatLng(-41.7, 146.7),
      LatLng(-41.5, 146.5),
    ]);
    expect(routeElevationSampler.requests, hasLength(1));
    expect(routeElevationSampler.requests.single.requestId, 1);
    expect(routeElevationSampler.requests.single.geometryVersion, 1);
    expect(state.routeDraftGeometryVersion, 1);
    expect(state.routeDraftMode, RouteMode.straightLine);
    expect(state.routeDraftStage, RouteDraftStage.awaitingNextPoint);
    expect(state.routeDraftElevationLoading, isTrue);
  });
  test('applyRouteDraftCloseLoop falls back to out and back when noPath', () async {
    final routePlanner = _ControlledRoutePlanner();
    final routeElevationSampler = _ControlledRouteElevationSampler();
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: routePlanner,
      routeElevationSampler: routeElevationSampler,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      isRouteDrafting: true,
      routeDraftMode: RouteMode.straightLine,
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
        RouteDraftControlEndpoint(
          id: 'endpoint-2',
          point: LatLng(-41.7, 146.7),
          kind: RouteDraftEndpointKind.tapped,
        ),
      ],
      routeDraftMarkers: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.6, 146.6),
        LatLng(-41.7, 146.7),
      ],
      routeDraftCommittedPoints: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.6, 146.6),
        LatLng(-41.7, 146.7),
      ],
      routeDraftDistanceMeters: 1000,
    );

    final closeLoop = notifier.applyRouteDraftCloseLoop();
    await Future<void>.delayed(Duration.zero);
    routePlanner.completeResult(
      const RoutePlanningResult(
        status: RoutePlanningStatus.noPath,
        points: [],
        distanceMeters: 0,
        startAnchor: null,
        endAnchor: null,
      ),
    );
    await closeLoop;
    await Future<void>.delayed(Duration.zero);

    final state = container.read(mapProvider);
    expect(state.routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.6, 146.6),
      LatLng(-41.7, 146.7),
      LatLng(-41.6, 146.6),
      LatLng(-41.5, 146.5),
    ]);
    expect(state.routeDraftControlEndpoints, hasLength(4));
    expect(routeElevationSampler.requests, hasLength(1));
    expect(state.routeDraftGeometryVersion, 1);
  });

  test('applyRouteDraftCloseLoop falls back to straight line when off track',
      () async {
    final routePlanner = _ControlledRoutePlanner();
    final routeElevationSampler = _ControlledRouteElevationSampler();
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: routePlanner,
      routeElevationSampler: routeElevationSampler,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      isRouteDrafting: true,
      routeDraftMode: RouteMode.straightLine,
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
        RouteDraftControlEndpoint(
          id: 'endpoint-2',
          point: LatLng(-41.7, 146.7),
          kind: RouteDraftEndpointKind.tapped,
        ),
      ],
      routeDraftMarkers: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.6, 146.6),
        LatLng(-41.7, 146.7),
      ],
      routeDraftCommittedPoints: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.6, 146.6),
        LatLng(-41.7, 146.7),
      ],
      routeDraftDistanceMeters: 1000,
    );

    final closeLoop = notifier.applyRouteDraftCloseLoop();
    await Future<void>.delayed(Duration.zero);
    routePlanner.completeResult(
      const RoutePlanningResult(
        status: RoutePlanningStatus.offTrack,
        points: [],
        distanceMeters: 0,
        startAnchor: null,
        endAnchor: null,
      ),
    );
    await closeLoop;
    await Future<void>.delayed(Duration.zero);

    final state = container.read(mapProvider);
    expect(state.routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.6, 146.6),
      LatLng(-41.7, 146.7),
      LatLng(-41.5, 146.5),
    ]);
    expect(state.routeDraftControlEndpoints, hasLength(4));
    expect(routeElevationSampler.requests, hasLength(1));
    expect(state.routeDraftGeometryVersion, 1);
  });

  test('applyRouteDraftCloseLoop rejects inconsistent draft state', () async {
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: _ControlledRoutePlanner(),
      routeElevationSampler: const _ImmediateZeroRouteElevationSampler(),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      isRouteDrafting: true,
      routeDraftMode: RouteMode.straightLine,
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
      routeDraftMarkers: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
      routeDraftCommittedPoints: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.55, 146.55),
        LatLng(-41.7, 146.7),
      ],
      routeDraftDistanceMeters: 1000,
    );

    await notifier.applyRouteDraftCloseLoop();

    final state = container.read(mapProvider);
    expect(state.routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.55, 146.55),
      LatLng(-41.7, 146.7),
    ]);
    expect(state.routeDraftError, contains('inconsistent'));
    expect(state.routeDraftGeometryVersion, 0);
  });

  test('applyRouteDraftCloseLoop is a no-op after the loop is closed', () async {
    final routePlanner = _ControlledRoutePlanner();
    final routeElevationSampler = _ControlledRouteElevationSampler();
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: routePlanner,
      routeElevationSampler: routeElevationSampler,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      isRouteDrafting: true,
      routeDraftMode: RouteMode.straightLine,
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
        RouteDraftControlEndpoint(
          id: 'endpoint-2',
          point: LatLng(-41.7, 146.7),
          kind: RouteDraftEndpointKind.tapped,
        ),
        RouteDraftControlEndpoint(
          id: 'endpoint-3',
          point: LatLng(-41.6, 146.6),
          kind: RouteDraftEndpointKind.tapped,
        ),
        RouteDraftControlEndpoint(
          id: 'endpoint-4',
          point: LatLng(-41.5, 146.5),
          kind: RouteDraftEndpointKind.tapped,
        ),
      ],
      routeDraftMarkers: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.6, 146.6),
        LatLng(-41.7, 146.7),
        LatLng(-41.6, 146.6),
        LatLng(-41.5, 146.5),
      ],
      routeDraftCommittedPoints: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.6, 146.6),
        LatLng(-41.7, 146.7),
        LatLng(-41.6, 146.6),
        LatLng(-41.5, 146.5),
      ],
      routeDraftDistanceMeters: 1400,
    );

    await notifier.applyRouteDraftCloseLoop();

    final state = container.read(mapProvider);
    expect(routePlanner.requests, isEmpty);
    expect(state.routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.6, 146.6),
      LatLng(-41.7, 146.7),
      LatLng(-41.6, 146.6),
      LatLng(-41.5, 146.5),
    ]);
    expect(routeElevationSampler.requests, isEmpty);
  });

  test('applyRouteDraftCloseLoop is disabled in segmentFailure', () async {
    final routePlanner = _ControlledRoutePlanner();
    final routeElevationSampler = _ControlledRouteElevationSampler();
    final realNotifier = await _buildRouteTestNotifier(
      routePlanner: routePlanner,
      routeElevationSampler: routeElevationSampler,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => realNotifier)],
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      isRouteDrafting: true,
      routeDraftMode: RouteMode.straightLine,
      routeDraftStage: RouteDraftStage.segmentFailure,
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
      routeDraftMarkers: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
      routeDraftCommittedPoints: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.55, 146.55),
        LatLng(-41.6, 146.6),
      ],
      routeDraftDistanceMeters: 1000,
      routeDraftError: 'Unexpected routing failure.',
    );

    await notifier.applyRouteDraftCloseLoop();

    final state = container.read(mapProvider);
    expect(routePlanner.requests, isEmpty);
    expect(state.routeDraftCommittedPoints, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.55, 146.55),
      LatLng(-41.6, 146.6),
    ]);
    expect(state.routeDraftError, 'Unexpected routing failure.');
  });

}

Future<MapNotifier> _buildRouteTestNotifier({
  required RoutePlanner routePlanner,
  RouteRepository? routeRepository,
  RouteElevationSampler? routeElevationSampler,
}) async {
  return MapNotifier(
    peakRepository: PeakRepository.test(InMemoryPeakStorage()),
    overpassService: OverpassService(),
    tasmapRepository: await TestTasmapRepository.create(),
    gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
    routeRepository:
        routeRepository ?? RouteRepository.test(InMemoryRouteStorage()),
    routeElevationSampler: routeElevationSampler,
    routePlanner: routePlanner,
    peaksBaggedRepository: PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage(),
    ),
    loadPositionOnBuild: false,
    loadPeaksOnBuild: false,
    loadTracksOnBuild: false,
  );
}

class _ControlledRoutePlanner implements RoutePlanner {
  final requests = <({LatLng start, LatLng end})>[];
  final _segmentCompleters = <Completer<RoutePlanningResult>>[];
  final _probeCompleters = <Completer<RouteEndpointProbeResult>>[];

  @override
  Future<RoutePlanningResult> planSegmentResult({
    required LatLng start,
    required LatLng end,
  }) {
    requests.add((start: start, end: end));
    final completer = Completer<RoutePlanningResult>();
    _segmentCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<RouteEndpointProbeResult> probeEndpoint({
    required LatLng point,
  }) async {
    final completer = Completer<RouteEndpointProbeResult>();
    _probeCompleters.add(completer);
    return completer.future;
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

  void completeNext(PlannedRouteSegment segment) {
    completeResult(
      RoutePlanningResult(
        status: RoutePlanningStatus.routed,
        points: segment.points,
        distanceMeters: segment.distanceMeters,
        startAnchor: null,
        endAnchor: null,
      ),
    );
  }

  void failNext(Object error) {
    completeResult(
      RoutePlanningResult(
        status: RoutePlanningStatus.failed,
        points: const [],
        distanceMeters: 0,
        startAnchor: null,
        endAnchor: null,
        errorMessage: '$error',
      ),
    );
  }

  void completeResult(RoutePlanningResult result) {
    _segmentCompleters.removeAt(0).complete(result);
  }

  void completeProbe(RouteEndpointProbeResult result) {
    _probeCompleters.removeAt(0).complete(result);
  }
}

class _ImmediateStraightRoutePlanner implements RoutePlanner {
  const _ImmediateStraightRoutePlanner();

  @override
  Future<RoutePlanningResult> planSegmentResult({
    required LatLng start,
    required LatLng end,
  }) async {
    return RoutePlanningResult(
      status: RoutePlanningStatus.routed,
      points: [start, end],
      distanceMeters: const Distance().as(LengthUnit.Meter, start, end),
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
    return PlannedRouteSegment(
      points: [start, end],
      distanceMeters: const Distance().as(LengthUnit.Meter, start, end),
    );
  }
}

class _ImmediateZeroRouteElevationSampler implements RouteElevationSampler {
  const _ImmediateZeroRouteElevationSampler();

  @override
  Future<RouteElevationSummary> sampleRoute({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  }) async {
    return RouteElevationSummary.zero(
      requestId: requestId,
      geometryVersion: geometryVersion,
    );
  }

  @override
  Future<List<double?>> samplePointElevations(List<LatLng> points) async {
    return List<double?>.generate(
      points.length,
      (index) => 100.0 + (index * 10),
      growable: false,
    );
  }
}

class _FailOnceRouteStorage implements RouteStorage {
  _FailOnceRouteStorage(this._delegate);

  final InMemoryRouteStorage _delegate;
  var _hasFailed = false;

  @override
  bool delete(int id) => _delegate.delete(id);

  @override
  List<Route> getAll() => _delegate.getAll();

  @override
  Route? getById(int id) => _delegate.getById(id);

  @override
  int save(Route route) {
    if (!_hasFailed) {
      _hasFailed = true;
      throw Exception('write failed');
    }

    return _delegate.save(route);
  }
}

class _ControlledRouteElevationSampler implements RouteElevationSampler {
  final requests =
      <({List<LatLng> points, int requestId, int geometryVersion})>[];
  final _completers = <Completer<RouteElevationSummary>>[];

  @override
  Future<RouteElevationSummary> sampleRoute({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  }) {
    requests.add((
      points: List<LatLng>.from(points, growable: false),
      requestId: requestId,
      geometryVersion: geometryVersion,
    ));
    final completer = Completer<RouteElevationSummary>();
    _completers.add(completer);
    return completer.future;
  }

  @override
  Future<List<double?>> samplePointElevations(List<LatLng> points) async {
    return List<double?>.generate(
      points.length,
      (index) => 100.0 + index,
      growable: false,
    );
  }

  void completeNext(RouteElevationSummary summary) {
    _completers.removeAt(0).complete(summary);
  }
}
