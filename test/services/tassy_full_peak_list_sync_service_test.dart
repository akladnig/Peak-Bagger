// ignore_for_file: use_super_parameters

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  group('TassyFullPeakListSyncService', () {
    test(
      'keeps Tasmanian peaks only, removes non-Tasmanian target peaks, and keeps highest source points',
      () async {
        final repository = _buildRepository(
          peakLists: [
            PeakList(
              name: 'Abels',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 22, points: 4),
                const PeakListItem(peakOsmId: 11, points: 2),
                const PeakListItem(peakOsmId: 55, points: 8),
              ]),
            )..peakListId = 1,
            PeakList(
              name: 'South West',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 22, points: 7),
                const PeakListItem(peakOsmId: 33, points: 1),
              ]),
            )..peakListId = 2,
            PeakList(name: 'Broken', peakList: '{not json')..peakListId = 3,
            PeakList(
              name: 'Tassy Full',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 44, points: 9),
                const PeakListItem(peakOsmId: 22, points: 1),
                const PeakListItem(peakOsmId: 55, points: 5),
              ]),
            )..peakListId = 4,
          ],
          peaks: [
            _peak(11),
            _peak(22),
            _peak(33),
            _peak(44),
            _peak(55, region: 'new-south-wales'),
          ],
        );

        final result = await repository.refreshTassyFullPeakList();

        final stored = repository.findByName('Tassy Full');

        expect(result.addedCount, 2);
        expect(result.updatedCount, 1);
        expect(result.removedCount, 1);
        expect(
          decodePeakListItems(
            stored!.peakList,
          ).map((item) => (item.peakOsmId, item.points)).toList(),
          [(11, 2), (22, 7), (33, 1), (44, 9)],
        );
      },
    );

    test(
      'creates a missing target and excludes non-Tasmanian source peaks',
      () async {
        final repository = _buildRepository(
          peakLists: [
            PeakList(
              name: 'Abels',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 5, points: 1),
                const PeakListItem(peakOsmId: 6, points: 9),
              ]),
            )..peakListId = 1,
          ],
          peaks: [
            _peak(5),
            _peak(6, region: 'new-south-wales'),
          ],
        );

        final result = await repository.refreshTassyFullPeakList();

        expect(result.addedCount, 1);
        expect(result.updatedCount, 0);
        expect(result.removedCount, 0);
        expect(
          decodePeakListItems(
            repository.findByName('Tassy Full')!.peakList,
          ).map((item) => (item.peakOsmId, item.points)).toList(),
          [(5, 1)],
        );
      },
    );

    test(
      'preserves existing Tasmanian target-only peaks and removes non-Tasmanian peaks when sources are empty',
      () async {
        final repository = _buildRepository(
          peakLists: [
            PeakList(
              name: 'Tassy Full',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 44, points: 9),
                const PeakListItem(peakOsmId: 66, points: 3),
              ]),
            )..peakListId = 4,
          ],
          peaks: [
            _peak(44),
            _peak(66, region: 'new-south-wales'),
          ],
        );

        final result = await repository.refreshTassyFullPeakList();

        expect(result.addedCount, 0);
        expect(result.updatedCount, 0);
        expect(result.removedCount, 1);
        expect(
          decodePeakListItems(
            repository.findByName('Tassy Full')!.peakList,
          ).map((item) => (item.peakOsmId, item.points)).toList(),
          [(44, 9)],
        );
      },
    );

    test('refresh failure leaves an existing target unchanged', () async {
      final repository = _buildRepository(
        storage: _FailingReplaceStorage([
          PeakList(
            name: 'Abels',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 11, points: 5),
            ]),
          )..peakListId = 1,
          PeakList(
            name: 'Tassy Full',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 11, points: 1),
              const PeakListItem(peakOsmId: 44, points: 9),
            ]),
          )..peakListId = 2,
        ]),
        peakLists: const [],
        peaks: [_peak(11), _peak(44)],
      );

      await expectLater(
        repository.refreshTassyFullPeakList(),
        throwsA(isA<StateError>()),
      );

      expect(
        decodePeakListItems(
          repository.findByName('Tassy Full')!.peakList,
        ).map((item) => (item.peakOsmId, item.points)).toList(),
        [(11, 1), (44, 9)],
      );
    });
  });
}

PeakListRepository _buildRepository({
  PeakListStorage? storage,
  required List<PeakList> peakLists,
  required List<Peak> peaks,
}) {
  final peakRepository = PeakRepository.test(InMemoryPeakStorage(peaks));
  return PeakListRepository.test(
    storage ?? InMemoryPeakListStorage(peakLists),
    peakRepository: peakRepository,
  );
}

Peak _peak(int osmId, {String region = Peak.defaultRegion}) {
  return Peak(
    osmId: osmId,
    name: 'Peak $osmId',
    latitude: -41.5,
    longitude: 146.5,
    region: region,
  );
}

class _FailingReplaceStorage extends InMemoryPeakListStorage {
  _FailingReplaceStorage([List<PeakList> peakLists = const []])
    : super(peakLists);

  @override
  Future<PeakList> replaceByName(
    PeakList peakList, {
    void Function()? beforePutForTest,
  }) {
    if (peakList.name == 'Tassy Full') {
      throw StateError('boom');
    }

    return super.replaceByName(peakList, beforePutForTest: beforePutForTest);
  }
}
