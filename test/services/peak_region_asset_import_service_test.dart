import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_region_asset_import_service.dart';
import 'package:peak_bagger/services/peak_region_import_marker_store.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'seedIfRepositoryEmpty seeds all seedable regions and writes markers',
    () async {
      final repository = PeakRepository.test(InMemoryPeakStorage());
      final service = PeakRegionAssetImportService(
        assetLoader: _assetLoader({
          PeakRegionAssetImportService.manifestAssetPath: jsonEncode({
            'tasmania': {
              'fingerprint': 'tas-fp',
              'peaks': ['assets/peaks/tas.json'],
            },
            'new-south-wales': {
              'fingerprint': 'nsw-fp',
              'peaks': ['assets/peaks/nsw.json'],
            },
            'italy': {
              'composite': true,
              'peaks': ['assets/peaks/italy.json'],
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
          'assets/peaks/nsw.json': _overpassAsset([
            _peakNode(
              id: 2,
              name: 'Kosciuszko',
              lat: -36.4558303,
              lon: 148.2635105,
              ele: '2228',
            ),
          ]),
        }),
        markerStore: const PeakRegionImportMarkerStore(),
      );

      final result = await service.seedIfRepositoryEmpty(
        peakRepository: repository,
      );

      expect(result.importedRegions, ['tasmania', 'new-south-wales']);
      expect(result.importedPeakCount, 2);
      expect(result.skippedPeakCount, 0);

      final peaks = repository.getAllPeaks();
      expect(peaks, hasLength(2));
      expect(
        peaks.map((peak) => peak.region),
        containsAll(['tasmania', 'new-south-wales']),
      );
      expect(peaks.every((peak) => peak.gridZoneDesignator.isNotEmpty), isTrue);

      const markerStore = PeakRegionImportMarkerStore();
      expect(await markerStore.loadFingerprints(), {
        'new-south-wales': 'nsw-fp',
        'tasmania': 'tas-fp',
      });
    },
  );

  test(
    'seedIfRepositoryEmpty skips malformed rows but imports valid peaks',
    () async {
      final repository = PeakRepository.test(InMemoryPeakStorage());
      final service = PeakRegionAssetImportService(
        assetLoader: _assetLoader({
          PeakRegionAssetImportService.manifestAssetPath: jsonEncode({
            'tasmania': {
              'fingerprint': 'tas-fp',
              'peaks': ['assets/peaks/tas.json'],
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
            {
              'type': 'node',
              'id': 2,
              'tags': {'name': 'Broken'},
            },
          ]),
        }),
      );

      final result = await service.seedIfRepositoryEmpty(
        peakRepository: repository,
      );

      expect(result.importedPeakCount, 1);
      expect(result.skippedPeakCount, 1);
      expect(repository.getAllPeaks(), hasLength(1));
    },
  );

  test(
    'seedIfRepositoryEmpty fails cleanly when an asset is unreadable',
    () async {
      final repository = PeakRepository.test(InMemoryPeakStorage());
      final service = PeakRegionAssetImportService(
        assetLoader: _assetLoader({
          PeakRegionAssetImportService.manifestAssetPath: jsonEncode({
            'tasmania': {
              'fingerprint': 'tas-fp',
              'peaks': ['assets/peaks/tas.json'],
            },
          }),
        }),
      );

      await expectLater(
        service.seedIfRepositoryEmpty(peakRepository: repository),
        throwsA(isA<StateError>()),
      );
      expect(repository.getAllPeaks(), isEmpty);
      expect(
        await const PeakRegionImportMarkerStore().loadFingerprints(),
        isEmpty,
      );
    },
  );

  test(
    'syncOnStartup bootstraps only legacy tasmania and imports missing regions',
    () async {
      final repository = PeakRepository.test(
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
      final service = PeakRegionAssetImportService(
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
      );

      final result = await service.syncOnStartup(peakRepository: repository);

      expect(result.importedRegions, ['slovenia']);
      expect(repository.getAllPeaks(), hasLength(2));
      expect(await const PeakRegionImportMarkerStore().loadFingerprints(), {
        'slovenia': 'slo-fp',
        'tasmania': 'tas-fp',
      });
    },
  );

  test(
    'syncOnStartup does not infer non-tasmania imports from free-form region values',
    () async {
      final repository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(
            id: 7,
            osmId: 1,
            name: 'Manual Peak',
            latitude: 46.3783,
            longitude: 13.8369,
            region: 'slovenia',
            sourceOfTruth: Peak.sourceOfTruthHwc,
          ),
        ]),
      );
      final service = PeakRegionAssetImportService(
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
              id: 2,
              name: 'Cradle',
              lat: -41.7,
              lon: 145.9,
              ele: '1545',
            ),
          ]),
          'assets/peaks/slovenia.json': _overpassAsset([
            _peakNode(
              id: 3,
              name: 'Triglav',
              lat: 46.3783,
              lon: 13.8369,
              ele: '2864',
            ),
          ]),
        }),
      );

      final result = await service.syncOnStartup(peakRepository: repository);

      expect(result.importedRegions, ['tasmania', 'slovenia']);
      expect(await const PeakRegionImportMarkerStore().loadFingerprints(), {
        'slovenia': 'slo-fp',
        'tasmania': 'tas-fp',
      });
    },
  );

  test(
    'syncOnStartup leaves existing peaks untouched during bootstrap step',
    () async {
      final repository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(
            id: 7,
            osmId: 1,
            name: 'Stored Tasmania Peak',
            altName: 'Manual name',
            verified: true,
            latitude: -41.7,
            longitude: 145.9,
            region: Peak.defaultRegion,
            sourceOfTruth: Peak.sourceOfTruthHwc,
          ),
        ]),
      );
      final service = PeakRegionAssetImportService(
        assetLoader: _assetLoader({
          PeakRegionAssetImportService.manifestAssetPath: jsonEncode({
            'tasmania': {
              'fingerprint': 'tas-fp',
              'peaks': ['assets/peaks/tas.json'],
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
        }),
      );

      final result = await service.syncOnStartup(peakRepository: repository);
      final peak = repository.getAllPeaks().single;

      expect(result.importedRegions, isEmpty);
      expect(peak.name, 'Stored Tasmania Peak');
      expect(peak.altName, 'Manual name');
      expect(peak.verified, isTrue);
      expect(await const PeakRegionImportMarkerStore().loadFingerprints(), {
        'tasmania': 'tas-fp',
      });
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
