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
            PeakList(name: 'Abels')..peakListId = 1,
            PeakList(name: 'South West')..peakListId = 2,
            PeakList(name: 'Broken')..peakListId = 3,
            PeakList(name: 'Tassy Full')..peakListId = 4,
          ],
          peaks: [
            _peak(11),
            _peak(22),
            _peak(33),
            _peak(44),
            _peak(
              55,
              region: 'new-south-wales',
              latitude: -33.8688,
              longitude: 151.2093,
            ),
          ],
          memberships: const [
            (peakListId: 1, peakOsmId: 22, points: 4),
            (peakListId: 1, peakOsmId: 11, points: 2),
            (peakListId: 1, peakOsmId: 55, points: 8),
            (peakListId: 2, peakOsmId: 22, points: 7),
            (peakListId: 2, peakOsmId: 33, points: 1),
            (peakListId: 4, peakOsmId: 44, points: 9),
            (peakListId: 4, peakOsmId: 22, points: 1),
            (peakListId: 4, peakOsmId: 55, points: 5),
          ],
        );

        final result = await repository.refreshTassyFullPeakList();

        final stored = repository.findByName('Tassy Full');

        expect(result.addedCount, 2);
        expect(result.updatedCount, 1);
        expect(result.removedCount, 1);
        expect(
          repository
              .getPeakListItemsForList(stored!.peakListId)
              .map((item) => (item.peakOsmId, item.points))
              .toList(),
          [(11, 2), (22, 7), (33, 1), (44, 9)],
        );
      },
    );

    test(
      'creates a missing target and excludes non-Tasmanian source peaks',
      () async {
        final repository = _buildRepository(
          peakLists: [
            PeakList(name: 'Abels')..peakListId = 1,
          ],
          peaks: [
            _peak(5),
            _peak(
              6,
              region: 'new-south-wales',
              latitude: -33.8688,
              longitude: 151.2093,
            ),
          ],
          memberships: const [
            (peakListId: 1, peakOsmId: 5, points: 1),
            (peakListId: 1, peakOsmId: 6, points: 9),
          ],
        );

        final result = await repository.refreshTassyFullPeakList();

        expect(result.addedCount, 1);
        expect(result.updatedCount, 0);
        expect(result.removedCount, 0);
        expect(
          repository
              .getPeakListItemsForList(
                repository.findByName('Tassy Full')!.peakListId,
              )
              .map((item) => (item.peakOsmId, item.points))
              .toList(),
          [(5, 1)],
        );
      },
    );

    test(
      'refresh includes source peaks whose Tasmanian coordinates override stale stored region metadata',
      () async {
        final repository = _buildRepository(
          peakLists: [
            PeakList(name: 'Abels')..peakListId = 1,
          ],
          peaks: [
            Peak(
              osmId: 11,
              name: 'Mount Agamemnon',
              latitude: -42.291632,
              longitude: 145.884372,
              region: 'victoria',
            ),
            Peak(
              osmId: 22,
              name: 'Mainland Peak',
              latitude: -37,
              longitude: 145,
              region: 'victoria',
            ),
          ],
          memberships: const [
            (peakListId: 1, peakOsmId: 11, points: 4),
            (peakListId: 1, peakOsmId: 22, points: 9),
          ],
        );

        final result = await repository.refreshTassyFullPeakList();

        expect(result.addedCount, 1);
        expect(result.updatedCount, 0);
        expect(result.removedCount, 0);
        expect(
          repository
              .getPeakListItemsForList(
                repository.findByName('Tassy Full')!.peakListId,
              )
              .map((item) => (item.peakOsmId, item.points))
              .toList(),
          [(11, 4)],
        );
      },
    );

    test(
      'preserves existing Tasmanian target-only peaks and removes non-Tasmanian peaks when sources are empty',
      () async {
        final repository = _buildRepository(
          peakLists: [
            PeakList(name: 'Tassy Full')..peakListId = 4,
          ],
          peaks: [
            _peak(44),
            _peak(
              66,
              region: 'new-south-wales',
              latitude: -33.8688,
              longitude: 151.2093,
            ),
          ],
          memberships: const [
            (peakListId: 4, peakOsmId: 44, points: 9),
            (peakListId: 4, peakOsmId: 66, points: 3),
          ],
        );

        final result = await repository.refreshTassyFullPeakList();

        expect(result.addedCount, 0);
        expect(result.updatedCount, 0);
        expect(result.removedCount, 1);
        expect(
          repository
              .getPeakListItemsForList(
                repository.findByName('Tassy Full')!.peakListId,
              )
              .map((item) => (item.peakOsmId, item.points))
              .toList(),
          [(44, 9)],
        );
      },
    );

    test('refresh failure leaves an existing target unchanged', () async {
        final repository = _buildRepository(
          storage: _FailingReplaceStorage([
          PeakList(name: 'Abels')..peakListId = 1,
          PeakList(name: 'Tassy Full')..peakListId = 2,
        ]),
        peakLists: const [],
        peaks: [_peak(11), _peak(44)],
        memberships: const [
          (peakListId: 1, peakOsmId: 11, points: 5),
          (peakListId: 2, peakOsmId: 11, points: 1),
          (peakListId: 2, peakOsmId: 44, points: 9),
        ],
      );

      await expectLater(
        repository.refreshTassyFullPeakList(),
        throwsA(isA<StateError>()),
      );

      expect(
        repository
            .getPeakListItemsForList(repository.findByName('Tassy Full')!.peakListId)
            .map((item) => (item.peakOsmId, item.points))
            .toList(),
        [(11, 1), (44, 9)],
      );
    });
  });
}

PeakListRepository _buildRepository({
  PeakListStorage? storage,
  required List<PeakList> peakLists,
  required List<Peak> peaks,
  List<({int peakListId, int peakOsmId, int points})> memberships = const [],
}) {
  final peakRepository = PeakRepository.test(InMemoryPeakStorage(peaks));
  final peakListStorage = storage ?? InMemoryPeakListStorage(peakLists);
  final peakListsById = {
    for (final peakList in peakListStorage.getAll()) peakList.peakListId: peakList,
  };
  return PeakListRepository.test(
    peakListStorage,
    peakRepository: peakRepository,
    itemStorage: InMemoryPeakListItemEntityStorage([
      for (var index = 0; index < memberships.length; index++)
        PeakListItemEntity(id: index + 1, points: memberships[index].points)
          ..peakList.target = peakListsById[memberships[index].peakListId]!
          ..peak.target = peakRepository.findByOsmId(memberships[index].peakOsmId),
    ]),
  );
}

Peak _peak(
  int osmId, {
  String region = Peak.defaultRegion,
  double latitude = -41.5,
  double longitude = 146.5,
}) {
  return Peak(
    osmId: osmId,
    name: 'Peak $osmId',
    latitude: latitude,
    longitude: longitude,
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
