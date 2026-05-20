import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
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

  test('later segment failure preserves the last successful routed geometry', () async {
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
    routePlanner.failNext(const RoutePlanningException('No path found.'));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(mapProvider);
    expect(state.routeDraftStage, RouteDraftStage.segmentFailure);
    expect(
      state.routeDraftCommittedPoints,
      const [point1, LatLng(-41.55, 146.55), point2],
    );
    expect(state.routeDraftProvisionalPoints, isEmpty);
    expect(state.routeDraftError, 'No path found.');
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
}

class _InitialStateMapNotifier extends MapNotifier {
  _InitialStateMapNotifier(this.initialState);

  final MapState initialState;

  @override
  MapState build() => initialState;
}

Future<MapNotifier> _buildRouteTestNotifier({
  required RoutePlanner routePlanner,
}) async {
  return MapNotifier(
    peakRepository: PeakRepository.test(InMemoryPeakStorage()),
    overpassService: OverpassService(),
    tasmapRepository: await TestTasmapRepository.create(),
    gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
    routeRepository: RouteRepository.test(InMemoryRouteStorage()),
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
