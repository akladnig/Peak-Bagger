import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/manifest_priority.dart';
import 'package:peak_bagger/services/mapping_data_store.dart'
    show MappingCatalog, MappingCatalogRegion;
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/peak_region_asset_import_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test(
    'startup preserves a populated peak store without reading seed sources',
    () async {
      SharedPreferences.setMockInitialValues({});
      final peakRepository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(
            id: 7,
            osmId: 1,
            name: 'Stored Tasmania Peak',
            latitude: -41.7,
            longitude: 145.9,
            region: Peak.defaultRegion,
          ),
        ]),
      );
      final tasmapRepository = await TestTasmapRepository.create();
      final notifier = MapNotifier(
        peakRepository: peakRepository,
        peakRegionAssetImportService: PeakRegionAssetImportService(
          catalog: _catalog(),
          sourceReader: _sourceReader({
            'assets/peaks/tas.json': _overpassAsset([
              _peakNode(
                id: 1,
                name: 'Cradle',
                lat: -41.7,
                lon: 145.9,
                ele: '1545',
              ),
            ]),
            'assets/peaks/slovenia.json': _overpassAsset([
              _peakNode(
                id: 2,
                name: 'Triglav',
                lat: 46.3783,
                lon: 13.8369,
                ele: '2864',
              ),
            ]),
          }),
        ),
        tasmapRepository: tasmapRepository,
        gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
        routeRepository: RouteRepository.test(InMemoryRouteStorage()),
        routeElevationSampler: const NoopRouteElevationSampler(),
        routePlanner: _NoopRoutePlanner(),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage(),
        ),
        migrationMarkerStore: const MigrationMarkerStore(),
        loadPositionOnBuild: false,
        loadTracksOnBuild: false,
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider);
      expect(state.isLoadingPeaks, isFalse);
      expect(state.error, isNull);
      expect(state.peaks, hasLength(1));
      expect(state.peaks.single.name, 'Stored Tasmania Peak');
      expect(peakRepository.regionFingerprints(), isEmpty);
      expect(state.basemap, Basemap.tracestrack);
      expect(state.center, MapConstants.defaultCenter);
    },
  );

  test('startup leaves stored peak-list metadata untouched', () async {
    SharedPreferences.setMockInitialValues({});
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        Peak(
          id: 7,
          osmId: 1,
          name: 'FVG Peak',
          latitude: 46.4084,
          longitude: 13.0475,
          region: 'fvg',
        ),
        Peak(
          id: 8,
          osmId: 2,
          name: 'Veneto Peak',
          latitude: 45.7332,
          longitude: 10.8061,
          region: 'veneto',
        ),
      ]),
    );
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Italy North East',
          region: Peak.defaultRegion,
          minLat: 1,
          maxLat: 2,
          minLng: 3,
          maxLng: 4,
        )..peakListId = 1,
      ]),
      peakRepository: peakRepository,
    );
    final notifier = MapNotifier(
      peakRepository: peakRepository,
      peakRegionAssetImportService: PeakRegionAssetImportService(
        catalog: _catalog(),
        sourceReader: _sourceReader(const {}),
      ),
      tasmapRepository: await TestTasmapRepository.create(),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
      routeElevationSampler: const NoopRouteElevationSampler(),
      routePlanner: _NoopRoutePlanner(),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      migrationMarkerStore: const MigrationMarkerStore(),
      loadPositionOnBuild: false,
      loadTracksOnBuild: false,
    );
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        peakListRepositoryProvider.overrideWithValue(peakListRepository),
      ],
    );
    addTearDown(container.dispose);

    container.read(mapProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final updated = peakListRepository.findById(1)!;
    expect(updated.region, Peak.defaultRegion);
    expect(updated.minLat, 1);
    expect(updated.maxLat, 2);
    expect(updated.minLng, 3);
    expect(updated.maxLng, 4);
  });
}

PeakRegionSourceReader _sourceReader(Map<String, String> sources) {
  return (path) async {
    final source = sources[path];
    if (source == null) {
      throw StateError('Missing source: $path');
    }
    return source;
  };
}

MappingCatalog _catalog() {
  return MappingCatalog(
    rootPath: '/mapping',
    regions: [
      _region(
        key: 'tasmania',
        peaks: const ['assets/peaks/tas.json'],
        fingerprint: 'tas-fp',
      ),
      _region(
        key: 'slovenia',
        peaks: const ['assets/peaks/slovenia.json'],
        fingerprint: 'slo-fp',
      ),
    ],
    basemaps: const [],
    tasmapCatalogPath: 'Maps/tasmap50k.csv',
    naturalFeaturesCatalogPath: 'Features/features.json',
    demSources: const {},
    routingCoverageRegionKeys: const {},
  );
}

MappingCatalogRegion _region({
  required String key,
  required List<String> peaks,
  required String fingerprint,
}) {
  return MappingCatalogRegion(
    key: key,
    name: key,
    shortName: key,
    priority: ManifestPriority.parse('1'),
    showInPeakList: true,
    polyPaths: const [],
    polygons: const [],
    basemapKeys: const [],
    mapSet: const [],
    peakListFilterAliases: const [],
    routingCoverage: null,
    seedOnStartup: true,
    composite: false,
    peaks: peaks,
    highways: const [],
    fingerprint: fingerprint,
  );
}

String _overpassAsset(List<Map<String, Object?>> elements) {
  return jsonEncode({'elements': elements});
}

Map<String, Object?> _peakNode({
  required int id,
  required String name,
  required double lat,
  required double lon,
  required String ele,
}) {
  return {
    'type': 'node',
    'id': id,
    'lat': lat,
    'lon': lon,
    'tags': {'natural': 'peak', 'name': name, 'ele': ele},
  };
}

class _NoopRoutePlanner extends RoutePlanner {
  @override
  Future<PlannedRouteSegment> planSegment({
    required start,
    required end,
    double maxSnapDistanceMeters = 50.0,
  }) async {
    return const PlannedRouteSegment(points: [], distanceMeters: 0);
  }

  @override
  Future<RoutePlanningResult> planSegmentResult({
    required start,
    required end,
    double maxSnapDistanceMeters = 50.0,
  }) async {
    return const RoutePlanningResult(
      status: RoutePlanningStatus.failed,
      points: [],
      distanceMeters: 0,
      startAnchor: null,
      endAnchor: null,
    );
  }

  @override
  Future<RouteEndpointProbeResult> probeEndpoint({
    required point,
    double maxSnapDistanceMeters = 50.0,
  }) async {
    return const RouteEndpointProbeResult(isOnTrack: false);
  }
}
