import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/route_repository.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test('route draft starts clean and clears selected map state', () {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              selectedLocation: const LatLng(-41.6, 146.6),
              selectedTrackId: 7,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(mapProvider.notifier);
    notifier.beginRouteDraft();

    final state = container.read(mapProvider);
    expect(state.isRouteDrafting, isTrue);
    expect(state.routeDraftMode, RouteMode.snapToTrail);
    expect(state.routeDraftName, isEmpty);
    expect(state.routeDraftMarkers, isEmpty);
    expect(state.selectedLocation, isNull);
    expect(state.selectedTrackId, isNull);
  });

  test('route draft markers append in tap order', () {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(mapProvider.notifier);
    notifier.beginRouteDraft();
    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.5));
    notifier.addRouteDraftMarker(const LatLng(-41.6, 146.6));

    expect(
      container.read(mapProvider).routeDraftMarkers,
      [const LatLng(-41.5, 146.5), const LatLng(-41.6, 146.6)],
    );
  });

  test('route draft end clears draft state', () {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

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

  test('third tap appends a new routed segment from the current endpoint', () async {
    final routePlanner = _ControlledRoutePlanner();
    final realNotifier = await _buildRouteTestNotifier(routePlanner: routePlanner);
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => realNotifier),
      ],
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
    expect(
      routePlanner.requests,
      const [
        (start: point1, end: point2),
        (start: point2, end: point3),
      ],
    );
    expect(state.routeDraftMarkers, const [point1, point2, point3]);
    expect(
      state.routeDraftCommittedPoints,
      const [
        point1,
        LatLng(-41.55, 146.55),
        point2,
        LatLng(-41.65, 146.65),
        point3,
      ],
    );
    expect(state.routeDraftDistanceMeters, 2200);
  });

  test('identical next point is rejected before planner dispatch', () async {
    final routePlanner = _ControlledRoutePlanner();
    final realNotifier = await _buildRouteTestNotifier(routePlanner: routePlanner);
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => realNotifier),
      ],
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

  test('later segment no-path failure keeps subsequent taps straight', () async {
    final routePlanner = _ControlledRoutePlanner();
    final realNotifier = await _buildRouteTestNotifier(routePlanner: routePlanner);
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => realNotifier),
      ],
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
    routePlanner.failNext(const RoutePlanningException('No path found.'));
    await Future<void>.delayed(Duration.zero);

    notifier.addRouteDraftMarker(point4);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(mapProvider);
    expect(state.routeDraftStage, RouteDraftStage.awaitingNextPoint);
    expect(
      state.routeDraftCommittedPoints,
      const [
        point1,
        LatLng(-41.55, 146.55),
        point2,
        point3,
        point4,
      ],
    );
    expect(state.routeDraftProvisionalPoints, isEmpty);
    expect(state.routeDraftError, isNull);
    expect(
      routePlanner.requests,
      const [
        (start: point1, end: point2),
        (start: point2, end: point3),
      ],
    );
    expect(
      state.routeDraftDistanceMeters,
      closeTo(
        1000 + const Distance().as(
          LengthUnit.Meter,
          point2,
          point3,
        ) + const Distance().as(
          LengthUnit.Meter,
          point3,
          point4,
        ),
        0.001,
      ),
    );
  });

  test('late route result is ignored after cancelling the draft', () async {
    final routePlanner = _ControlledRoutePlanner();
    final realNotifier = await _buildRouteTestNotifier(routePlanner: routePlanner);
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => realNotifier),
      ],
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

  test('committed geometry changes trigger resample and stale elevation results are ignored', () async {
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
  });

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
}

class _InitialStateMapNotifier extends MapNotifier {
  _InitialStateMapNotifier(this.initialState);

  final MapState initialState;

  @override
  MapState build() => initialState;
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
    routeRepository: routeRepository ?? RouteRepository.test(InMemoryRouteStorage()),
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
  final _completers = <Completer<PlannedRouteSegment>>[];

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
  }) {
    requests.add((start: start, end: end));
    final completer = Completer<PlannedRouteSegment>();
    _completers.add(completer);
    return completer.future;
  }

  void completeNext(PlannedRouteSegment segment) {
    _completers.removeAt(0).complete(segment);
  }

  void failNext(Object error) {
    _completers.removeAt(0).completeError(error);
  }
}

class _ControlledRouteElevationSampler implements RouteElevationSampler {
  final requests = <({List<LatLng> points, int requestId, int geometryVersion})>[];
  final _completers = <Completer<RouteElevationSummary>>[];

  @override
  Future<RouteElevationSummary> sampleRoute({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  }) {
    requests.add(
      (
        points: List<LatLng>.from(points, growable: false),
        requestId: requestId,
        geometryVersion: geometryVersion,
      ),
    );
    final completer = Completer<RouteElevationSummary>();
    _completers.add(completer);
    return completer.future;
  }

  @override
  Future<List<double?>> samplePointElevations(List<LatLng> points) async {
    return List<double?>.filled(points.length, null, growable: false);
  }

  void completeNext(RouteElevationSummary summary) {
    _completers.removeAt(0).complete(summary);
  }
}
