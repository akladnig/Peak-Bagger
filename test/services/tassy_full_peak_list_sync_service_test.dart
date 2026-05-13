// ignore_for_file: use_super_parameters

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

void main() {
  group('TassyFullPeakListSyncService', () {
    test('merges source lists and preserves target-only peaks', () async {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Abels',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 22, points: 4),
              const PeakListItem(peakOsmId: 11, points: 2),
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
            ]),
          )..peakListId = 4,
        ]),
      );

      final result = await repository.refreshTassyFullPeakList();

      final stored = repository.findByName('Tassy Full');

      expect(result.addedCount, 2);
      expect(result.updatedCount, 1);
      expect(
        decodePeakListItems(stored!.peakList)
            .map((item) => (item.peakOsmId, item.points))
            .toList(),
        [(11, 2), (22, 7), (33, 1), (44, 9)],
      );
    });

    test('creates a missing target without calling save', () async {
      final repository = _SaveGuardPeakListRepository(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Abels',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 5, points: 1),
            ]),
          )..peakListId = 1,
        ]),
      );

      final result = await repository.refreshTassyFullPeakList();

      expect(result.addedCount, 1);
      expect(result.updatedCount, 0);
      expect(
        decodePeakListItems(repository.findByName('Tassy Full')!.peakList)
            .map((item) => (item.peakOsmId, item.points))
            .toList(),
        [(5, 1)],
      );
    });

    test('leaves an existing target unchanged when sources are empty', () async {
      final repository = _WriteGuardPeakListRepository(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Tassy Full',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 44, points: 9),
            ]),
          )..peakListId = 4,
        ]),
      );

      final result = await repository.refreshTassyFullPeakList();

      expect(result.addedCount, 0);
      expect(result.updatedCount, 0);
      expect(
        decodePeakListItems(repository.findByName('Tassy Full')!.peakList)
            .map((item) => (item.peakOsmId, item.points))
            .toList(),
        [(44, 9)],
      );
    });
  });
}

class _SaveGuardPeakListRepository extends PeakListRepository {
  _SaveGuardPeakListRepository(PeakListStorage storage) : super.test(storage);

  @override
  Future<PeakList> save(
    PeakList peakList, {
    void Function()? beforePutForTest,
  }) {
    throw StateError('save should not be called');
  }
}

class _WriteGuardPeakListRepository extends PeakListRepository {
  _WriteGuardPeakListRepository(PeakListStorage storage) : super.test(storage);

  @override
  Future<PeakList> saveWithoutSync(
    PeakList peakList, {
    void Function()? beforePutForTest,
  }) {
    throw StateError('saveWithoutSync should not be called');
  }
}
