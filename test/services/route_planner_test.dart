import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

void main() {
  test(
    'local file client preloads graph for anchored segment and probe',
    () async {
      const start = LatLng(-41.5, 146.5);
      const end = LatLng(-41.6, 146.6);
      final service = _FakeTripService(
        anchoredResult: const trip_routing.AnchoredSegmentResult(
          status: trip_routing.AnchoredSegmentStatus.routed,
          route: [start, end],
          distance: 1234.5,
          errors: [],
          startAnchor: trip_routing.EndpointAnchor(
            point: start,
            type: trip_routing.EndpointAnchorType.node,
            nodeId: 1,
          ),
          endAnchor: trip_routing.EndpointAnchor(
            point: end,
            type: trip_routing.EndpointAnchorType.node,
            nodeId: 2,
          ),
        ),
        probeResult: const trip_routing.EndpointProbeResult(
          isOnTrack: true,
          anchor: trip_routing.EndpointAnchor(
            point: end,
            type: trip_routing.EndpointAnchorType.edgeProjection,
            originalSegmentId: '100:0',
          ),
        ),
      );
      final store = _FakeRouteGraphStore(service);
      final client = LocalFileTripRoutingClient(routeGraphStore: store);

      final anchored = await client.findAnchoredSegment(
        start: start,
        end: end,
        maxSnapDistanceMeters: 50,
      );
      final probe = await client.probeEndpointAnchor(
        point: end,
        maxSnapDistanceMeters: 50,
      );

      expect(store.preloadCallCount, 2);
      expect(service.recordedAnchoredRequests, const [
        (start: start, end: end, maxSnapDistanceMeters: 50),
      ]);
      expect(service.recordedProbeRequests, const [
        (point: end, maxSnapDistanceMeters: 50),
      ]);
      expect(anchored.status, trip_routing.AnchoredSegmentStatus.routed);
      expect(probe.isOnTrack, isTrue);
    },
  );

  test(
    'local file client routes from repository-backed chunks without preload',
    () async {
      const start = LatLng(-41.5, 146.5);
      const end = LatLng(-41.6, 146.6);
      final repository = RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: RouteGraphManifest(
            sourceHash: 'hash',
            schemaVersion: 'route-graph-v1',
            activeGeneration: 1,
            importedAt: DateTime.utc(2025),
            chunkCount: 1,
            nodeCount: 2,
            edgeCount: 1,
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
              payloadJson: '''
            {"elements":[
              {"type":"node","id":1,"lat":-41.5,"lon":146.5},
              {"type":"node","id":2,"lat":-41.6,"lon":146.6},
              {"type":"way","id":10,"nodes":[1,2],"tags":{"highway":"path"}}
            ]}
            ''',
            ),
          ],
        ),
      );
      final store = _FakeRouteGraphStore(
        _FakeTripService(),
        repository: repository,
      );
      final client = LocalFileTripRoutingClient(routeGraphStore: store);

      final anchored = await client.findAnchoredSegment(
        start: start,
        end: end,
        maxSnapDistanceMeters: 50,
      );

      expect(store.preloadCallCount, 0);
      expect(anchored.status, trip_routing.AnchoredSegmentStatus.routed);
    },
  );

  test('planner maps routed result into app-owned routed result', () async {
    const start = LatLng(-41.5, 146.5);
    const end = LatLng(-41.6, 146.6);
    const midpoint = LatLng(-41.55, 146.55);
    final client = _FakeTripRoutingClient(
      anchoredResult: const trip_routing.AnchoredSegmentResult(
        status: trip_routing.AnchoredSegmentStatus.routed,
        route: [start, midpoint, end],
        distance: 1234.5,
        errors: [],
        startAnchor: trip_routing.EndpointAnchor(
          point: start,
          type: trip_routing.EndpointAnchorType.node,
          nodeId: 1,
        ),
        endAnchor: trip_routing.EndpointAnchor(
          point: end,
          type: trip_routing.EndpointAnchorType.edgeProjection,
          originalSegmentId: '100:0',
        ),
      ),
    );
    final planner = TripRoutingRoutePlanner(client: client);

    final result = await planner.planSegmentResult(start: start, end: end);

    expect(result.status, RoutePlanningStatus.routed);
    expect(result.points, const [start, midpoint, end]);
    expect(result.distanceMeters, 1234.5);
    expect(result.startAnchor?.type, RouteEndpointAnchorType.node);
    expect(result.startAnchor?.nodeId, 1);
    expect(result.endAnchor?.type, RouteEndpointAnchorType.edgeProjection);
    expect(result.endAnchor?.originalSegmentId, '100:0');
  });

  test('planner maps offTrack result into app-owned offTrack result', () async {
    const start = LatLng(-41.5, 146.5);
    const end = LatLng(-41.6, 146.6);
    final client = _FakeTripRoutingClient(
      anchoredResult: const trip_routing.AnchoredSegmentResult(
        status: trip_routing.AnchoredSegmentStatus.offTrack,
        route: [],
        distance: 0,
        errors: [],
        startAnchor: trip_routing.EndpointAnchor(
          point: start,
          type: trip_routing.EndpointAnchorType.raw,
        ),
      ),
    );
    final planner = TripRoutingRoutePlanner(client: client);

    final result = await planner.planSegmentResult(start: start, end: end);

    expect(result.status, RoutePlanningStatus.offTrack);
    expect(result.points, isEmpty);
    expect(result.distanceMeters, 0);
    expect(result.errorMessage, isNull);
  });

  test('planner maps noPath result into app-owned noPath result', () async {
    const start = LatLng(-41.5, 146.5);
    const end = LatLng(-41.6, 146.6);
    final client = _FakeTripRoutingClient(
      anchoredResult: const trip_routing.AnchoredSegmentResult(
        status: trip_routing.AnchoredSegmentStatus.noPath,
        route: [],
        distance: 0,
        errors: [],
        startAnchor: trip_routing.EndpointAnchor(
          point: start,
          type: trip_routing.EndpointAnchorType.node,
          nodeId: 1,
        ),
        endAnchor: trip_routing.EndpointAnchor(
          point: end,
          type: trip_routing.EndpointAnchorType.edgeProjection,
          originalSegmentId: '100:0',
        ),
      ),
    );
    final planner = TripRoutingRoutePlanner(client: client);

    final result = await planner.planSegmentResult(start: start, end: end);

    expect(result.status, RoutePlanningStatus.noPath);
    expect(result.endAnchor?.type, RouteEndpointAnchorType.edgeProjection);
    expect(result.errorMessage, isNull);
  });

  test('planner maps failed result into app-owned failed result', () async {
    const start = LatLng(-41.5, 146.5);
    const end = LatLng(-41.6, 146.6);
    final client = _FakeTripRoutingClient(
      anchoredResult: const trip_routing.AnchoredSegmentResult(
        status: trip_routing.AnchoredSegmentStatus.failed,
        route: [],
        distance: 0,
        errors: ['Graph data unavailable'],
      ),
    );
    final planner = TripRoutingRoutePlanner(client: client);

    final result = await planner.planSegmentResult(start: start, end: end);

    expect(result.status, RoutePlanningStatus.failed);
    expect(result.errorMessage, 'Graph data unavailable');
  });

  test(
    'planner converts malformed routed payload into failed result',
    () async {
      const start = LatLng(-41.5, 146.5);
      const end = LatLng(-41.6, 146.6);
      final client = _FakeTripRoutingClient(
        anchoredResult: const trip_routing.AnchoredSegmentResult(
          status: trip_routing.AnchoredSegmentStatus.routed,
          route: [start],
          distance: 0,
          errors: [],
        ),
      );
      final planner = TripRoutingRoutePlanner(client: client);

      final result = await planner.planSegmentResult(start: start, end: end);

      expect(result.status, RoutePlanningStatus.failed);
      expect(result.errorMessage, 'Routing returned no usable segment.');
    },
  );

  test('planner probes endpoint through app-owned result seam', () async {
    const point = LatLng(-41.6, 146.6);
    final client = _FakeTripRoutingClient(
      probeResult: const trip_routing.EndpointProbeResult(
        isOnTrack: true,
        anchor: trip_routing.EndpointAnchor(
          point: point,
          type: trip_routing.EndpointAnchorType.edgeProjection,
          originalSegmentId: '100:0',
        ),
      ),
    );
    final planner = TripRoutingRoutePlanner(client: client);

    final result = await planner.probeEndpoint(point: point);

    expect(result.isOnTrack, isTrue);
    expect(result.anchor?.type, RouteEndpointAnchorType.edgeProjection);
    expect(result.anchor?.originalSegmentId, '100:0');
  });

  test(
    'planCloseLoopResult reconnects through the closest usable track before falling back straight',
    () async {
      const current = LatLng(-41.7, 146.7);
      const start = LatLng(-41.5, 146.5);
      const reconnect = LatLng(-41.68, 146.68);
      final planner = _SequenceRoutePlanner(
        segmentResults: [
          const RoutePlanningResult(
            status: RoutePlanningStatus.noPath,
            points: [],
            distanceMeters: 0,
            startAnchor: null,
            endAnchor: null,
          ),
          const RoutePlanningResult(
            status: RoutePlanningStatus.routed,
            points: [reconnect, LatLng(-41.6, 146.6), start],
            distanceMeters: 850,
            startAnchor: RouteEndpointAnchor(
              point: reconnect,
              type: RouteEndpointAnchorType.edgeProjection,
            ),
            endAnchor: RouteEndpointAnchor(
              point: start,
              type: RouteEndpointAnchorType.node,
              nodeId: 3,
            ),
          ),
        ],
        probeResults: const [
          RouteEndpointProbeResult(
            isOnTrack: true,
            anchor: RouteEndpointAnchor(
              point: reconnect,
              type: RouteEndpointAnchorType.edgeProjection,
            ),
          ),
        ],
      );

      final result = await planner.planCloseLoopResult(
        currentPoint: current,
        startPoint: start,
      );

      expect(result.status, RouteLoopClosureStatus.reconnected);
      expect(result.points, const [
        current,
        reconnect,
        LatLng(-41.6, 146.6),
        start,
      ]);
      expect(planner.segmentRequests, const [
        (start: current, end: start, maxSnapDistanceMeters: 50.0),
        (start: reconnect, end: start, maxSnapDistanceMeters: 50.0),
      ]);
      expect(planner.probeRequests, const [
        (point: current, maxSnapDistanceMeters: 50.0),
      ]);
    },
  );

  test(
    'planCloseLoopResult falls back to a straight segment when closest-track reconnection is unavailable',
    () async {
      const current = LatLng(-41.7, 146.7);
      const start = LatLng(-41.5, 146.5);
      final planner = _SequenceRoutePlanner(
        segmentResults: const [
          RoutePlanningResult(
            status: RoutePlanningStatus.noPath,
            points: [],
            distanceMeters: 0,
            startAnchor: null,
            endAnchor: null,
          ),
        ],
        probeResults: const [RouteEndpointProbeResult(isOnTrack: false)],
      );

      final result = await planner.planCloseLoopResult(
        currentPoint: current,
        startPoint: start,
      );

      expect(result.status, RouteLoopClosureStatus.straightLine);
      expect(result.points, const [current, start]);
      expect(planner.segmentRequests, const [
        (start: current, end: start, maxSnapDistanceMeters: 50.0),
      ]);
      expect(planner.probeRequests, const [
        (point: current, maxSnapDistanceMeters: 50.0),
      ]);
    },
  );

  test(
    'legacy planSegment wrapper still throws for non-routed result',
    () async {
      const start = LatLng(-41.5, 146.5);
      const end = LatLng(-41.6, 146.6);
      final client = _FakeTripRoutingClient(
        anchoredResult: const trip_routing.AnchoredSegmentResult(
          status: trip_routing.AnchoredSegmentStatus.noPath,
          route: [],
          distance: 0,
          errors: [],
        ),
      );
      final planner = TripRoutingRoutePlanner(client: client);

      await expectLater(
        () => planner.planSegment(start: start, end: end),
        throwsA(isA<RoutePlanningException>()),
      );
    },
  );

  test(
    'planner surfaces route graph load failure through client error',
    () async {
      const start = LatLng(-41.5, 146.5);
      const end = LatLng(-41.6, 146.6);
      final store = _ThrowingRouteGraphStore();
      final client = LocalFileTripRoutingClient(routeGraphStore: store);
      final planner = TripRoutingRoutePlanner(client: client);

      final result = await planner.planSegmentResult(start: start, end: end);

      expect(result.status, RoutePlanningStatus.failed);
      expect(result.errorMessage, contains('route graph unavailable'));
    },
  );
}

class _FakeTripRoutingClient implements TripRoutingClient {
  _FakeTripRoutingClient({
    trip_routing.AnchoredSegmentResult? anchoredResult,
    trip_routing.EndpointProbeResult? probeResult,
  }) : anchoredResult =
           anchoredResult ??
           const trip_routing.AnchoredSegmentResult(
             status: trip_routing.AnchoredSegmentStatus.failed,
             route: [],
             distance: 0,
             errors: ['Missing fake anchored result'],
           ),
       probeResult =
           probeResult ??
           const trip_routing.EndpointProbeResult(isOnTrack: false);

  final trip_routing.AnchoredSegmentResult anchoredResult;
  final trip_routing.EndpointProbeResult probeResult;
  final recordedAnchoredRequests =
      <({LatLng start, LatLng end, double maxSnapDistanceMeters})>[];
  final recordedProbeRequests =
      <({LatLng point, double maxSnapDistanceMeters})>[];

  @override
  Future<trip_routing.AnchoredSegmentResult> findAnchoredSegment({
    required LatLng start,
    required LatLng end,
    required double maxSnapDistanceMeters,
  }) async {
    recordedAnchoredRequests.add((
      start: start,
      end: end,
      maxSnapDistanceMeters: maxSnapDistanceMeters,
    ));
    return anchoredResult;
  }

  @override
  Future<trip_routing.EndpointProbeResult> probeEndpointAnchor({
    required LatLng point,
    required double maxSnapDistanceMeters,
  }) async {
    recordedProbeRequests.add((
      point: point,
      maxSnapDistanceMeters: maxSnapDistanceMeters,
    ));
    return probeResult;
  }
}

class _SequenceRoutePlanner extends RoutePlanner {
  _SequenceRoutePlanner({
    required this.segmentResults,
    required this.probeResults,
  });

  final List<RoutePlanningResult> segmentResults;
  final List<RouteEndpointProbeResult> probeResults;
  final segmentRequests =
      <({LatLng start, LatLng end, double maxSnapDistanceMeters})>[];
  final probeRequests = <({LatLng point, double maxSnapDistanceMeters})>[];
  var _segmentIndex = 0;
  var _probeIndex = 0;

  @override
  Future<RoutePlanningResult> planSegmentResult({
    required LatLng start,
    required LatLng end,
    double maxSnapDistanceMeters = 50.0,
  }) async {
    segmentRequests.add((
      start: start,
      end: end,
      maxSnapDistanceMeters: maxSnapDistanceMeters,
    ));
    return segmentResults[_segmentIndex++];
  }

  @override
  Future<RouteEndpointProbeResult> probeEndpoint({
    required LatLng point,
    double maxSnapDistanceMeters = 50.0,
  }) async {
    probeRequests.add((
      point: point,
      maxSnapDistanceMeters: maxSnapDistanceMeters,
    ));
    return probeResults[_probeIndex++];
  }

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
    double maxSnapDistanceMeters = 50.0,
  }) async {
    final result = await planSegmentResult(
      start: start,
      end: end,
      maxSnapDistanceMeters: maxSnapDistanceMeters,
    );
    if (!result.isRouted) {
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

class _FakeRouteGraphStore
    implements RouteGraphStore, RouteGraphRepositoryProvider {
  @override
  Future<void> bootstrapData() async {}

  _FakeRouteGraphStore(this.service, {this.repository});

  final _FakeTripService service;
  @override
  final RouteGraphRepository? repository;
  int preloadCallCount = 0;

  @override
  Future<trip_routing.TripService> preload() async {
    preloadCallCount += 1;
    return service;
  }

  @override
  Future<trip_routing.TripService> reload() async => service;

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}

class _ThrowingRouteGraphStore implements RouteGraphStore {
  @override
  Future<void> bootstrapData() async {}

  @override
  Future<trip_routing.TripService> preload() async {
    throw const RouteGraphLoadException('route graph unavailable');
  }

  @override
  Future<trip_routing.TripService> reload() => preload();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}

class _FakeTripService extends trip_routing.TripService {
  _FakeTripService({
    trip_routing.AnchoredSegmentResult? anchoredResult,
    trip_routing.EndpointProbeResult? probeResult,
  }) : anchoredResult =
           anchoredResult ??
           const trip_routing.AnchoredSegmentResult(
             status: trip_routing.AnchoredSegmentStatus.failed,
             route: [],
             distance: 0,
             errors: ['Missing fake anchored result'],
           ),
       probeResult =
           probeResult ??
           const trip_routing.EndpointProbeResult(isOnTrack: false);

  final trip_routing.AnchoredSegmentResult anchoredResult;
  final trip_routing.EndpointProbeResult probeResult;
  final recordedAnchoredRequests =
      <({LatLng start, LatLng end, double maxSnapDistanceMeters})>[];
  final recordedProbeRequests =
      <({LatLng point, double maxSnapDistanceMeters})>[];

  @override
  Future<trip_routing.AnchoredSegmentResult> findAnchoredSegment({
    required LatLng start,
    required LatLng end,
    required double maxSnapDistanceMeters,
  }) async {
    recordedAnchoredRequests.add((
      start: start,
      end: end,
      maxSnapDistanceMeters: maxSnapDistanceMeters,
    ));
    return anchoredResult;
  }

  @override
  Future<trip_routing.EndpointProbeResult> probeEndpointAnchor({
    required LatLng point,
    required double maxSnapDistanceMeters,
  }) async {
    recordedProbeRequests.add((
      point: point,
      maxSnapDistanceMeters: maxSnapDistanceMeters,
    ));
    return probeResult;
  }
}
