import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/mapping_store_operation_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/route_planner_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_graph_coverage_resolver.dart';
import 'package:peak_bagger/services/route_graph_import_coordinator.dart';
import 'package:peak_bagger/services/route_graph_import_service.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_repository.dart';

import 'mapping_coverage_fixture.dart';
import 'test_tasmap_repository.dart';

class RouteGraphMappingHarness {
  RouteGraphMappingHarness._();
  final access = MappingCoverageFileAccess();
  final operations = MappingStoreOperationCoordinator();
  final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
  final planner = CoverageRecordingPlanner();
  late final RouteGraphImportCoordinator coordinator;
  late final ProviderContainer container;
  MapNotifier get notifier => container.read(mapProvider.notifier);

  static Future<RouteGraphMappingHarness> create({
    MappingCatalog? catalog,
  }) async {
    final harness = RouteGraphMappingHarness._();
    final readyCatalog = catalog ?? mappingCoverageCatalog;
    harness.coordinator = RouteGraphImportCoordinator(
      coverageResolver: RouteGraphCoverageResolver(
        catalog: readyCatalog,
        fileAccess: harness.access,
      ),
      importService: RouteGraphImportService(
        harness.repository,
        generationPreparer: preparedCoverageFixture,
      ),
      repository: harness.repository,
      mappingOperationCoordinator: harness.operations,
    );
    final notifier = MapNotifier(
      mappingCatalog: readyCatalog,
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      tasmapRepository: await TestTasmapRepository.create(),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
      routePlanner: harness.planner,
      routeElevationSampler: const NoopRouteElevationSampler(),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      loadPositionOnBuild: false,
      loadPeaksOnBuild: false,
      loadTracksOnBuild: false,
    );
    harness.container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        mappingStoreOperationCoordinatorProvider.overrideWithValue(
          harness.operations,
        ),
        routeGraphImportCoordinatorProvider.overrideWithValue(
          harness.coordinator,
        ),
        routeGraphQueryServiceProvider.overrideWithValue(
          RouteGraphQueryService(harness.repository),
        ),
      ],
    );
    harness.container.read(mapProvider);
    return harness;
  }

  void plan({
    LatLng start = const LatLng(-42, 146),
    LatLng end = const LatLng(-42.001, 146.001),
  }) {
    notifier.beginRouteDraft();
    notifier.addRouteDraftMarker(start, straightLine: true);
    notifier.addRouteDraftMarker(end);
  }

  void dispose() {
    container.dispose();
    coordinator.dispose();
    operations.dispose();
  }
}

class CoverageRecordingPlanner extends RoutePlanner {
  final coverages = <String>[];
  @override
  Future<RoutePlanningResult> planSegmentForCoverage({
    required String routingCoverageKey,
    required LatLng start,
    required LatLng end,
    double maxSnapDistanceMeters = 50,
  }) async {
    coverages.add(routingCoverageKey);
    return RoutePlanningResult(
      status: RoutePlanningStatus.routed,
      points: [start, end],
      distanceMeters: 100,
      startAnchor: RouteEndpointAnchor(
        point: start,
        type: RouteEndpointAnchorType.raw,
      ),
      endAnchor: RouteEndpointAnchor(
        point: end,
        type: RouteEndpointAnchorType.raw,
      ),
    );
  }

  @override
  Future<RoutePlanningResult> planSegmentResult({
    required LatLng start,
    required LatLng end,
    double maxSnapDistanceMeters = 50,
  }) => throw StateError('Expected coverage');
  @override
  Future<RouteEndpointProbeResult> probeEndpoint({
    required LatLng point,
    double maxSnapDistanceMeters = 50,
  }) async => const RouteEndpointProbeResult(isOnTrack: false);
  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
    double maxSnapDistanceMeters = 50,
  }) => throw UnimplementedError();
}

Future<Map<String, Object?>> preparedCoverageFixture(
  String raw,
  String schema,
  int generation,
) async => {
  'generation': generation,
  'sourceHash': raw.hashCode.toString(),
  'schemaVersion': schema,
  'importedAtMillis': DateTime.utc(2026).millisecondsSinceEpoch,
  'chunkCount': 1,
  'nodeCount': 2,
  'edgeCount': 1,
  'chunks': [
    {
      'recordKey': '$generation|a',
      'chunkKey': 'a',
      'generation': generation,
      'minLat': -43.0,
      'minLon': 145.0,
      'maxLat': -41.0,
      'maxLon': 147.0,
      'elementCount': 3,
      'payloadJson': jsonEncode(mappingHighwaySource),
    },
  ],
  'wayIndexRows': [
    {
      'recordKey': '$generation|a|10',
      'chunkKey': 'a',
      'generation': generation,
      'osmWayId': 10,
      'lengthMeters': 100,
      'tagCount': 1,
      'tagsJson': '{"highway":"path"}',
    },
  ],
  'trailDisplayChunks': <Object?>[],
};
