import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  group('PeakRepository', () {
    late InMemoryPeakStorage storage;
    late PeakRepository repository;

    setUp(() {
      storage = InMemoryPeakStorage();
      repository = PeakRepository.test(storage);
    });

    test('replaceAll swaps stored peaks', () async {
      await repository.addPeaks([
        Peak(name: 'Old Peak', latitude: -41, longitude: 146),
      ]);

      await repository.replaceAll([
        Peak(name: 'New Peak', latitude: -42, longitude: 147),
      ]);

      final peaks = repository.getAllPeaks();

      expect(peaks, hasLength(1));
      expect(peaks.single.name, 'New Peak');
    });

    test('replaceAll preserves ids for matching osmId', () async {
      await repository.addPeaks([
        Peak(
          id: 7,
          osmId: 123,
          name: 'Old Peak',
          latitude: -41,
          longitude: 146,
        ),
      ]);

      await repository.replaceAll([
        Peak(osmId: 123, name: 'New Peak', latitude: -42, longitude: 147),
      ]);

      final peaks = repository.getAllPeaks();

      expect(peaks, hasLength(1));
      expect(peaks.single.id, 7);
      expect(peaks.single.name, 'New Peak');
    });

    test('replaceAll rolls back on failure', () async {
      await repository.addPeaks([
        Peak(name: 'Old Peak', latitude: -41, longitude: 146),
      ]);

      expect(
        () => repository.replaceAll(
          [Peak(name: 'New Peak', latitude: -42, longitude: 147)],
          beforePutManyForTest: () {
            throw StateError('boom');
          },
        ),
        throwsStateError,
      );

      final peaks = repository.getAllPeaks();

      expect(peaks, hasLength(1));
      expect(peaks.single.name, 'Old Peak');
    });

    test('findByOsmId returns the matching peak', () async {
      await repository.addPeaks([
        Peak(osmId: 123, name: 'Cradle', latitude: -41, longitude: 146),
        Peak(osmId: 456, name: 'Ossa', latitude: -42, longitude: 147),
      ]);

      final peak = repository.findByOsmId(456);

      expect(peak, isNotNull);
      expect(peak?.name, 'Ossa');
    });

    test('save persists corrected peak fields', () async {
      final original = Peak(
        id: 7,
        osmId: 123,
        name: 'Cradle',
        latitude: -41,
        longitude: 146,
        easting: '10000',
        northing: '20000',
      );
      await repository.addPeaks([original]);

      await repository.save(
        original.copyWith(
          latitude: -41.2,
          longitude: 146.3,
          elevation: 1545,
          easting: '10123',
          northing: '20123',
          sourceOfTruth: Peak.sourceOfTruthHwc,
        ),
      );

      final peak = repository.findByOsmId(123);

      expect(peak, isNotNull);
      expect(peak?.latitude, -41.2);
      expect(peak?.longitude, 146.3);
      expect(peak?.elevation, 1545);
      expect(peak?.easting, '10123');
      expect(peak?.northing, '20123');
      expect(peak?.sourceOfTruth, Peak.sourceOfTruthHwc);
    });
  });
}
