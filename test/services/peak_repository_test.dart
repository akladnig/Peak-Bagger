import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  group('PeakRepository', () {
    late InMemoryPeakStorage storage;
    late PeakRepository repository;

    setUp(() {
      storage = InMemoryPeakStorage();
      repository = PeakRepository.test(
        storage,
        peakListRewritePort: _NoopPeakListRewritePort(),
      );
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

    test('nextSyntheticOsmId returns the next negative id', () async {
      expect(repository.nextSyntheticOsmId(), -1);

      await repository.addPeaks([
        Peak(osmId: -1, name: 'Synthetic 1', latitude: -41, longitude: 146),
        Peak(osmId: -3, name: 'Synthetic 3', latitude: -42, longitude: 147),
        Peak(osmId: 101, name: 'Cradle', latitude: -41.5, longitude: 146.5),
      ]);

      expect(repository.nextSyntheticOsmId(), -4);
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

    test('delete removes the targeted peak', () async {
      await repository.addPeaks([
        Peak(id: 7, osmId: 123, name: 'Cradle', latitude: -41, longitude: 146),
        Peak(id: 8, osmId: 456, name: 'Ossa', latitude: -42, longitude: 147),
      ]);

      await repository.delete(7);

      expect(repository.findById(7), isNull);
      expect(repository.findById(8)?.name, 'Ossa');
    });

    test(
      'saveDetailed rewrites dependent PeakList and PeaksBagged rows',
      () async {
        final peakLists = [
          PeakList(
            name: 'Abels',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 123, points: 2),
              const PeakListItem(peakOsmId: 999, points: 4),
            ]),
          ),
          PeakList(name: 'Broken', peakList: '{not json'),
        ];
        final peaksBagged = [
          PeaksBagged(baggedId: 1, peakId: 123, gpxId: 7),
          PeaksBagged(baggedId: 2, peakId: 999, gpxId: 8),
        ];
        final rewritePort = _RecordingPeakListRewritePort(
          peakLists: peakLists,
          peaksBagged: peaksBagged,
        );
        final detailedRepository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              id: 7,
              osmId: 123,
              name: 'Cradle',
              latitude: -41,
              longitude: 146,
            ),
          ]),
          peakListRewritePort: rewritePort,
        );

        final result = await detailedRepository.saveDetailed(
          Peak(
            id: 7,
            osmId: 456,
            name: 'Cradle',
            latitude: -41.2,
            longitude: 146.3,
          ),
        );

        expect(result.peak.osmId, 456);
        expect(result.peak.latitude, -41.2);
        expect(result.peakListRewriteResult?.rewrittenCount, 1);
        expect(result.peakListRewriteResult?.skippedMalformedCount, 1);
        expect(
          result.peakListRewriteResult?.warningMessage,
          "1 PeakList has been skipped as it's malformed.",
        );
        expect(
          decodePeakListItems(
            peakLists.first.peakList,
          ).map((item) => item.peakOsmId).toList(),
          [456, 999],
        );
        expect(peaksBagged.first.peakId, 456);
        expect(peaksBagged.last.peakId, 999);
      },
    );
  });
}

class _NoopPeakListRewritePort implements PeakListRewritePort {
  @override
  PeakListRewriteResult rewriteOsmIdReferences({
    required int oldOsmId,
    required int newOsmId,
  }) {
    return const PeakListRewriteResult(
      rewrittenCount: 0,
      skippedMalformedCount: 0,
    );
  }
}

class _RecordingPeakListRewritePort implements PeakListRewritePort {
  _RecordingPeakListRewritePort({
    required this.peakLists,
    required this.peaksBagged,
  });

  final List<PeakList> peakLists;
  final List<PeaksBagged> peaksBagged;

  @override
  PeakListRewriteResult rewriteOsmIdReferences({
    required int oldOsmId,
    required int newOsmId,
  }) {
    var rewrittenCount = 0;
    var skippedMalformedCount = 0;

    for (final peakList in peakLists) {
      try {
        final items = decodePeakListItems(peakList.peakList);
        var changed = false;
        final updatedItems = <PeakListItem>[];
        for (final item in items) {
          if (item.peakOsmId == oldOsmId) {
            updatedItems.add(
              PeakListItem(peakOsmId: newOsmId, points: item.points),
            );
            changed = true;
          } else {
            updatedItems.add(item);
          }
        }
        if (changed) {
          rewrittenCount += 1;
          peakList.peakList = encodePeakListItems(updatedItems);
        }
      } catch (_) {
        skippedMalformedCount += 1;
      }
    }

    for (final row in peaksBagged) {
      if (row.peakId == oldOsmId) {
        row.peakId = newOsmId;
      }
    }

    return PeakListRewriteResult(
      rewrittenCount: rewrittenCount,
      skippedMalformedCount: skippedMalformedCount,
    );
  }
}
