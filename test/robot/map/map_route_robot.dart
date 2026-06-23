import 'dart:io';

import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import '../../harness/test_tasmap_repository.dart';

class MapRouteRobot {
  MapRouteRobot(
    this.tester,
    this.initialState, {
    required this.routePlanningOutcomes,
    this.routeElevationOutcomes = const [],
    RouteRepository? routeRepository,
    this.routeGraphStore,
  }) : routeRepository =
            routeRepository ?? RouteRepository.test(InMemoryRouteStorage());

  final WidgetTester tester;
  final MapState initialState;
  final List<Object> routePlanningOutcomes;
  final List<Object> routeElevationOutcomes;
  final RouteRepository routeRepository;
  final RouteGraphStore? routeGraphStore;

  late final TestTasmapRepository _tasmapRepository;
  late final MapNotifier _mapNotifier;
  TestGesture? _mouseGesture;
  bool _mousePointerAdded = false;

  Finder get mapInteractionRegion =>
      find.byKey(const Key('map-interaction-region'));
  Finder get createRouteFab => find.byKey(const Key('create-route-fab'));
  Finder get routeSaveButton => find.byKey(const Key('route-save-button'));
  Finder get routeToPeakButton => find.byKey(const Key('route-mode-route-to-peak'));
  Finder get outAndBackButton => find.byKey(const Key('route-mode-out-and-back'));
  Finder get closeLoopButton => find.byKey(const Key('route-mode-close-loop'));
  Finder get undoButton => find.byKey(const Key('route-undo-button'));
  Finder get redoButton => find.byKey(const Key('route-redo-button'));
  Finder get routeDraftDeletePopup =>
      find.byKey(const Key('route-draft-delete-popup'));
  Finder get routeDraftDeleteAction =>
      find.byKey(const Key('route-draft-delete-action'));
  Finder get routeGraphOverlayRoot =>
      find.byKey(const Key('route-graph-overlay-root'));
  Finder get routeControlsOverlayRoot =>
      find.byKey(const Key('route-controls-overlay-root'));
  Finder get routeDistanceText => find.byKey(const Key('route-distance-text'));
  Finder get routeAscentText => find.byKey(const Key('route-ascent-text'));
  Finder get routeDescentText => find.byKey(const Key('route-descent-text'));
  Finder get routeElevationErrorText =>
      find.byKey(const Key('route-elevation-error-text'));
  Finder routeDraftMarkerHitbox(String markerId) =>
      find.byKey(Key('route-draft-marker-hitbox-$markerId'));
  void expectRouteDraftOverlaysVisible() {
    expect(routeGraphOverlayRoot, findsOneWidget);
    expect(routeControlsOverlayRoot, findsOneWidget);
  }

  void expectRouteDraftOverlaysHidden() {
    expect(routeGraphOverlayRoot, findsNothing);
    expect(routeControlsOverlayRoot, findsNothing);
  }

  void expectRouteDistanceContains(String valueFragment) {
    expect(routeDistanceText, findsOneWidget);
    final text = tester.widget<Text>(routeDistanceText).data;
    expect(text, contains(valueFragment));
  }

  Future<void> pumpApp() async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    _tasmapRepository = await TestTasmapRepository.create();
    router = createRouter();
    _mapNotifier = MapNotifier(
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      overpassService: OverpassService(),
      tasmapRepository: _tasmapRepository,
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: routeRepository,
      routeElevationSampler: _QueueRouteElevationSampler(routeElevationOutcomes),
      routePlanner: _QueueRoutePlanner(routePlanningOutcomes),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      loadPositionOnBuild: false,
      loadPeaksOnBuild: false,
      loadTracksOnBuild: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => _mapNotifier),
          routeGraphReadinessProvider.overrideWith(
            () => _ReadyRouteGraphReadinessNotifier(),
          ),
          routeGraphStoreProvider.overrideWithValue(
            routeGraphStore ?? _ReadyRouteGraphStore(),
          ),
          routeRepositoryProvider.overrideWithValue(routeRepository),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          tasmapRepositoryProvider.overrideWithValue(_tasmapRepository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    _mapNotifier.state = initialState;
  }

  Future<void> openMap() async {
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> enterRouteMode() async {
    await tester.tap(createRouteFab);
    await tester.pumpAndSettle();
  }

  Future<void> selectRouteMode(RouteMode mode) async {
    container().read(mapProvider.notifier).setRouteDraftMode(mode);
    await tester.pump();
  }

  Future<void> applyOutAndBack() async {
    container().read(mapProvider.notifier).applyRouteDraftOutAndBack();
    await tester.pumpAndSettle();
  }

  Future<void> applyCloseLoop() async {
    container().read(mapProvider.notifier).applyRouteDraftCloseLoop();
    await tester.pumpAndSettle();
  }

  Future<void> openPeakPopup(int peakOsmId) async {
    await tester.tapAt(tester.getCenter(mapInteractionRegion));
    await tester.pumpAndSettle();
  }

  Future<void> tapRoutePoint(Offset offset) async {
    await tester.tapAt(tester.getCenter(mapInteractionRegion) + offset);
    await tester.pumpAndSettle();
  }

  Future<void> hoverRoutePoint(Offset offset) async {
    final point = tester.getCenter(mapInteractionRegion) + offset;
    await _ensureMouse(point);
    await _mouseGesture!.moveTo(point);
    await tester.pump();
  }

  Future<void> clickRoutePoint(Offset offset) async {
    final point = tester.getCenter(mapInteractionRegion) + offset;
    await _ensureMouse(point);
    await _mouseGesture!.moveTo(point);
    await tester.pump();
    await _mouseGesture!.down(point);
    await tester.pump();
    await _mouseGesture!.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> clickDraftMarker(String markerId) async {
    await tester.tap(routeDraftMarkerHitbox(markerId));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> dragDraftMarker(String markerId, Offset delta) async {
    final hitbox = routeDraftMarkerHitbox(markerId);
    final gesture = await tester.startGesture(tester.getCenter(hitbox));
    await gesture.moveBy(delta);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> deleteDraftMarkerFromPopup() async {
    await tester.tap(routeDraftDeleteAction);
    await tester.pumpAndSettle();
  }

  Future<void> undoRouteEdit() async {
    await tester.ensureVisible(undoButton);
    await tester.pumpAndSettle();
    await tester.tap(undoButton);
    await tester.pumpAndSettle();
  }

  Future<void> redoRouteEdit() async {
    await tester.ensureVisible(redoButton);
    await tester.pumpAndSettle();
    await tester.tap(redoButton);
    await tester.pumpAndSettle();
  }

  void expectRouteSegmentPreview(int segmentIndex) {
    expect(find.byKey(Key('route-draft-segment-hover-$segmentIndex')), findsOneWidget);
    expect(
      tester.widget<MouseRegion>(mapInteractionRegion).cursor,
      SystemMouseCursors.click,
    );
  }

  Future<void> enterRouteName(String value) async {
    container().read(mapProvider.notifier).setRouteDraftName(value);
    await tester.pump();
  }

  Future<void> saveRoute() async {
    container().read(mapProvider.notifier).saveRouteDraft();
    await tester.pumpAndSettle();
  }

  ProviderContainer container() {
    return ProviderScope.containerOf(tester.element(mapInteractionRegion));
  }

  List<app_route.Route> savedRoutes() => routeRepository.getAllRoutes();

  Future<void> dispose() async {
    if (_mouseGesture != null && _mousePointerAdded) {
      await _mouseGesture!.removePointer();
      _mousePointerAdded = false;
    }
    await tester.binding.setSurfaceSize(null);
    await _tasmapRepository.dispose();
  }

  Future<void> _ensureMouse(Offset location) async {
    _mouseGesture ??= await tester.createGesture(kind: PointerDeviceKind.mouse);
    if (_mousePointerAdded) {
      return;
    }

    await _mouseGesture!.addPointer(location: location);
    await tester.pump();
    _mousePointerAdded = true;
  }
}

class _QueueRoutePlanner implements RoutePlanner {
  _QueueRoutePlanner(this._outcomes);

  final List<Object> _outcomes;
  var _index = 0;

  Future<Object?> _nextOutcome() async {
    final outcome = _outcomes[_index++];
    return outcome is Future ? await outcome : outcome;
  }

  @override
  Future<RoutePlanningResult> planSegmentResult({
    required LatLng start,
    required LatLng end,
    double maxSnapDistanceMeters = 50.0,
  }) async {
    final outcome = await _nextOutcome();
    if (outcome is RoutePlanningResult) {
      return outcome;
    }
    if (outcome is PlannedRouteSegment) {
      return RoutePlanningResult(
        status: RoutePlanningStatus.routed,
        points: outcome.points,
        distanceMeters: outcome.distanceMeters,
        startAnchor: null,
        endAnchor: null,
      );
    }
    if (outcome is RoutePlanningException) {
      return RoutePlanningResult(
        status: RoutePlanningStatus.failed,
        points: const [],
        distanceMeters: 0,
        startAnchor: null,
        endAnchor: null,
        errorMessage: outcome.message,
      );
    }
    if (outcome is String) {
      return RoutePlanningResult(
        status: RoutePlanningStatus.failed,
        points: const [],
        distanceMeters: 0,
        startAnchor: null,
        endAnchor: null,
        errorMessage: outcome,
      );
    }
    return const RoutePlanningResult(
      status: RoutePlanningStatus.failed,
      points: [],
      distanceMeters: 0,
      startAnchor: null,
      endAnchor: null,
      errorMessage: 'Unexpected queued route outcome.',
    );
  }

  @override
  Future<RouteEndpointProbeResult> probeEndpoint({
    required LatLng point,
    double maxSnapDistanceMeters = 50.0,
  }) async {
    if (_index >= _outcomes.length) {
      return const RouteEndpointProbeResult(isOnTrack: false);
    }

    final outcome = await _nextOutcome();
    if (outcome is RouteEndpointProbeResult) {
      return outcome;
    }
    if (outcome is RoutePlanningResult) {
      return RouteEndpointProbeResult(
        isOnTrack: outcome.status == RoutePlanningStatus.routed,
        anchor: outcome.startAnchor,
        errorMessage: outcome.errorMessage,
        failureKind: outcome.failureKind,
      );
    }
    if (outcome is PlannedRouteSegment) {
      return RouteEndpointProbeResult(
        isOnTrack: true,
        anchor: RouteEndpointAnchor(
          point: point,
          type: RouteEndpointAnchorType.raw,
        ),
      );
    }
    return const RouteEndpointProbeResult(isOnTrack: false);
  }

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
    double maxSnapDistanceMeters = 50.0,
  }) async {
    final result = await planSegmentResult(start: start, end: end);
    if (result.status != RoutePlanningStatus.routed) {
      throw RoutePlanningException(
        result.errorMessage ?? 'Unexpected queued route outcome.',
      );
    }
    return PlannedRouteSegment(
      points: result.points,
      distanceMeters: result.distanceMeters,
    );
  }
}

class _QueueRouteElevationSampler implements RouteElevationSampler {
  _QueueRouteElevationSampler(this._outcomes);

  final List<Object> _outcomes;
  var _index = 0;

  @override
  Future<RouteElevationSummary> sampleRoute({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  }) async {
    if (_outcomes.isEmpty) {
      return RouteElevationSummary.zero(
        requestId: requestId,
        geometryVersion: geometryVersion,
      );
    }

    final outcome = _outcomes[_index++];
    if (outcome is RouteElevationSummary) {
      return RouteElevationSummary(
        requestId: requestId,
        geometryVersion: geometryVersion,
        distance3d: outcome.distance3d,
        ascent: outcome.ascent,
        descent: outcome.descent,
        startElevation: outcome.startElevation,
        endElevation: outcome.endElevation,
        lowestElevation: outcome.lowestElevation,
        highestElevation: outcome.highestElevation,
      );
    }
    if (outcome is Completer<RouteElevationSummary>) {
      return outcome.future;
    }
    if (outcome is Exception) {
      throw outcome;
    }
    if (outcome is Error) {
      throw outcome;
    }
    throw Exception('Unexpected queued elevation outcome.');
  }

  @override
  Future<List<double?>> samplePointElevations(List<LatLng> points) async {
    return List<double?>.filled(points.length, null, growable: false);
  }
}

class _ReadyRouteGraphStore implements RouteGraphStore {
  @override
  Future<void> bootstrapData() async {}

  @override
  Future<trip_routing.TripService> preload() async => trip_routing.TripService();

  @override
  Future<trip_routing.TripService> reload() async => trip_routing.TripService();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}

class TrailRouteGraphStore implements RouteGraphStore, RouteGraphRepositoryProvider {
  @override
  Future<void> bootstrapData() async {}

  TrailRouteGraphStore()
    : repository = RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: RouteGraphManifest(
            activeGeneration: 1,
            readinessState: RouteGraphManifest.readinessReady,
          ),
          chunks: [
            RouteGraphChunk(
              recordKey: '1|0_0',
              chunkKey: '0_0',
              generation: 1,
              minLat: -42.0,
              minLon: 146.0,
              maxLat: -41.0,
              maxLon: 147.0,
              elementCount: 3,
              payloadJson: '{"elements":[{"type":"node","id":1,"lat":-41.5,"lon":146.5},{"type":"node","id":2,"lat":-41.55,"lon":146.55},{"type":"way","id":10,"nodes":[1,2],"tags":{"highway":"path"}}]}',
            ),
          ],
          wayIndexRows: [
            RouteGraphWayIndex(
              recordKey: '1|0_0|10',
              generation: 1,
              chunkKey: '0_0',
              osmWayId: 10,
              highway: 'path',
              access: 'public',
              name: 'Trail',
              normalizedName: 'trail',
              lengthMeters: 120,
              tagCount: 1,
              tagsJson: '{}',
            ),
          ],
          trailDisplayChunks: [
            ..._trailDisplayChunksForGeneration(1, const [
              LatLng(-41.5, 146.5),
              LatLng(-41.55, 146.55),
            ]),
          ],
        ),
      );

  @override
  final RouteGraphRepository repository;

  Future<void> replaceVisibleTrailGeneration(List<LatLng> points) async {
    final nextGeneration = repository.activeGeneration + 1;
    await repository.writePreparedGeneration(
      RouteGraphPreparedGeneration(
        generation: nextGeneration,
        sourceHash: 'trail-generation-$nextGeneration',
        schemaVersion: repository.manifest?.schemaVersion ?? 'route-graph-v2',
        importedAt: DateTime.utc(2026),
        chunkCount: 1,
        nodeCount: points.length,
        edgeCount: 1,
        chunks: [
          RouteGraphChunk(
            recordKey: '$nextGeneration|0_0',
            chunkKey: '0_0',
            generation: nextGeneration,
            minLat: -42.0,
            minLon: 146.0,
            maxLat: -41.0,
            maxLon: 147.0,
            elementCount: 0,
            payloadJson: '{"elements":[]}',
          ),
        ],
        wayIndexRows: const [],
        trailDisplayChunks: _trailDisplayChunksForGeneration(
          nextGeneration,
          points,
        ),
      ),
      pruneStaleGenerations: true,
    );
  }

  @override
  Future<trip_routing.TripService> preload() async {
    return trip_routing.TripService();
  }

  @override
  Future<trip_routing.TripService> reload() async {
    return trip_routing.TripService();
  }

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}

List<RouteGraphTrailDisplayChunk> _trailDisplayChunksForGeneration(
  int generation,
  List<LatLng> points,
) {
  return [
    for (
      var zoom = TrackDisplayCacheBuilder.minZoom;
      zoom <= TrackDisplayCacheBuilder.maxZoom;
      zoom++
    )
      RouteGraphTrailDisplayChunk(
        recordKey: RouteGraphTrailDisplayChunk.recordKeyFor(
          generation: generation,
          cacheZoom: zoom,
          chunkKey: '0_0',
        ),
        generation: generation,
        cacheZoom: zoom,
        chunkKey: '0_0',
        payloadJson: RouteGraphTrailDisplayChunk.encodeWays([
          RouteGraphTrailDisplayWay(osmWayId: 10, points: points),
        ]),
      ),
  ];
}

class _ReadyRouteGraphReadinessNotifier extends RouteGraphReadinessNotifier {
  @override
  RouteGraphReadinessState build() {
    return const RouteGraphReadinessState.ready();
  }

  @override
  void markPreloading() {}

  @override
  void markReady() {}

  @override
  void markFailed(String error) {}
}
