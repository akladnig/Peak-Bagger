import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/peak_region_asset_import_service.dart';
import 'package:peak_bagger/services/peak_region_import_marker_store.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_peak_overpass_service.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  test(
    'startup bootstraps tasmania marker and imports missing regions',
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
        overpassService: TestPeakOverpassService(),
        peakRegionAssetImportService: PeakRegionAssetImportService(
          assetLoader: _assetLoader({
            PeakRegionAssetImportService.manifestAssetPath: jsonEncode({
              'tasmania': {
                'fingerprint': 'tas-fp',
                'peaks': ['assets/peaks/tas.json'],
              },
              'slovenia': {
                'fingerprint': 'slo-fp',
                'peaks': ['assets/peaks/slovenia.json'],
              },
            }),
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
      expect(state.peaks, hasLength(2));
      expect(
        state.peaks.map((peak) => peak.region),
        containsAll([Peak.defaultRegion, 'slovenia']),
      );
      expect(await const PeakRegionImportMarkerStore().loadFingerprints(), {
        'slovenia': 'slo-fp',
        'tasmania': 'tas-fp',
      });
      expect(state.basemap, Basemap.tracestrack);
      expect(state.center, MapConstants.defaultCenter);
    },
  );
}

PeakRegionAssetLoader _assetLoader(Map<String, String> assets) {
  return (assetPath) async {
    final asset = assets[assetPath];
    if (asset == null) {
      throw StateError('Missing asset: $assetPath');
    }
    return asset;
  };
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
    'tags': {'name': name, 'ele': ele},
  };
}

class _NoopRoutePlanner implements RoutePlanner {
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
