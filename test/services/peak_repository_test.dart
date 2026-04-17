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
  });
}
