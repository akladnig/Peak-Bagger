import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_refresh_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';

import '../harness/test_peak_overpass_service.dart';

void main() {
  test('refreshPeaks enriches and replaces stored peaks', () async {
    final repository = PeakRepository.test(
      InMemoryPeakStorage([
        Peak(name: 'Old Peak', latitude: -40, longitude: 145),
      ]),
    );
    final service = PeakRefreshService(
      TestPeakOverpassService(
        peaks: [
          Peak(name: 'Cradle', latitude: -41.7, longitude: 145.9),
          Peak(name: 'Ossa', latitude: -41.8, longitude: 145.8),
        ],
      ),
      repository,
    );

    final result = await service.refreshPeaks();

    expect(result.importedCount, 2);
    expect(result.skippedCount, 0);
    expect(result.warning, isNull);

    final peaks = repository.getAllPeaks();
    expect(peaks, hasLength(2));
    expect(peaks.first.gridZoneDesignator, '55G');
    expect(peaks.first.mgrs100kId, isNotEmpty);
    expect(peaks.first.easting, hasLength(5));
    expect(peaks.first.northing, hasLength(5));
    expect(peaks.map((peak) => peak.name), containsAll(['Cradle', 'Ossa']));
  });

  test('refreshPeaks preserves ids for matching osmId', () async {
    final repository = PeakRepository.test(
      InMemoryPeakStorage([
        Peak(
          id: 7,
          osmId: 321,
          name: 'Old Peak',
          latitude: -40,
          longitude: 145,
        ),
      ]),
    );
    final service = PeakRefreshService(
      TestPeakOverpassService(
        peaks: [
          Peak(osmId: 321, name: 'Old Peak', latitude: -40, longitude: 145),
        ],
      ),
      repository,
    );

    await service.refreshPeaks();

    final peaks = repository.getAllPeaks();
    expect(peaks.single.id, 7);
    expect(peaks.single.osmId, 321);
  });

  test('refreshPeaks skips peaks rejected by converter', () async {
    final repository = PeakRepository.test(InMemoryPeakStorage());
    final service = PeakRefreshService(
      TestPeakOverpassService(
        peaks: [
          Peak(name: 'Valid', latitude: -41.0, longitude: 146.0),
          Peak(name: 'Invalid', latitude: -42.0, longitude: 147.0),
        ],
      ),
      repository,
      converter: (location) {
        if (location.latitude == -42.0) {
          throw const FormatException('bad peak');
        }
        return PeakMgrsComponents(
          gridZoneDesignator: '55G',
          mgrs100kId: 'EN',
          easting: '12345',
          northing: '67890',
        );
      },
    );

    final result = await service.refreshPeaks();

    expect(result.importedCount, 1);
    expect(result.skippedCount, 1);
    expect(result.warning, isNotNull);
    expect(repository.getAllPeaks(), hasLength(1));
    expect(repository.getAllPeaks().single.name, 'Valid');
  });

  test('refreshPeaks throws when overpass returns no peaks', () async {
    final repository = PeakRepository.test(
      InMemoryPeakStorage([
        Peak(name: 'Old Peak', latitude: -40, longitude: 145),
      ]),
    );
    final service = PeakRefreshService(TestPeakOverpassService(), repository);

    expect(service.refreshPeaks(), throwsStateError);
    expect(repository.getAllPeaks(), hasLength(1));
    expect(repository.getAllPeaks().single.name, 'Old Peak');
  });

  test(
    'backfillStoredPeaks populates missing fields without overpass',
    () async {
      final overpass = TestPeakOverpassService();
      final repository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(name: 'Legacy Peak', latitude: -41.5, longitude: 146.5),
        ]),
      );
      final service = PeakRefreshService(overpass, repository);

      final updated = await service.backfillStoredPeaks();

      expect(updated, isTrue);
      expect(overpass.fetchCallCount, 0);

      final peak = repository.getAllPeaks().single;
      expect(peak.gridZoneDesignator, isNotEmpty);
      expect(peak.mgrs100kId, isNotEmpty);
      expect(peak.easting, hasLength(5));
      expect(peak.northing, hasLength(5));
    },
  );
}
