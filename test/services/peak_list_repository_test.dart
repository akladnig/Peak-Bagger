import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  group('PeakListRepository', () {
    test('round-trips ordered peakList payload unchanged', () async {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage(),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([_peak(11), _peak(22)]),
        ),
      );

      await repository.save(
        PeakList(name: 'Abels'),
        items: const [
          PeakListItem(peakOsmId: 11, points: 2),
          PeakListItem(peakOsmId: 22, points: 10),
        ],
      );

      final stored = repository.getAllPeakLists().single;

      expect(stored.name, 'Abels');
      expect(
        repository
            .getPeakListItemsForList(stored.peakListId)
            .map((item) => (item.peakOsmId, item.points))
            .toList(),
        [(11, 2), (22, 10)],
      );
    });

    test('duplicate-name update preserves existing data on failure', () async {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage(),
        peakRepository: PeakRepository.test(InMemoryPeakStorage([_peak(11)])),
      );

      final saved = await repository.save(
        PeakList(name: 'Abels'),
        items: const [PeakListItem(peakOsmId: 11, points: 2)],
      );

      await expectLater(
        repository.save(
          PeakList(name: 'Abels'),
          items: const [PeakListItem(peakOsmId: 11, points: 2)],
          beforePutForTest: () {
            throw StateError('boom');
          },
        ),
        throwsStateError,
      );

      final stored = repository.getAllPeakLists().single;

      expect(stored.peakListId, saved.peakListId);
      expect(stored.name, 'Abels');
      expect(repository.getPeakListItemsForList(stored.peakListId), [
        const PeakListItem(peakOsmId: 11, points: 2),
      ]);
    });

    test('getById returns stored row', () async {
      final repository = PeakListRepository.test(InMemoryPeakListStorage());

      final saved = await repository.save(PeakList(name: 'Abels'));

      final stored = repository.findById(saved.peakListId);

      expect(stored, isNotNull);
      expect(stored?.name, 'Abels');
    });

    test('delete removes only the targeted row', () async {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(name: 'Abels')..peakListId = 1,
          PeakList(name: 'Connoisseurs')..peakListId = 2,
        ]),
      );

      await repository.delete(1);

      expect(repository.findById(1), isNull);
      expect(repository.findById(2)?.name, 'Connoisseurs');
      expect(repository.getAllPeakLists(), hasLength(1));
    });

    test('add update and remove peak items preserve list metadata', () async {
      final repository = _peakListRepository(
        peakLists: [PeakList(name: 'Abels')..peakListId = 1],
        peaks: [_peak(11), _peak(22)],
      );

      await repository.addPeakItem(
        peakListId: 1,
        item: const PeakListItem(peakOsmId: 11, points: 2),
      );
      await repository.addPeakItem(
        peakListId: 1,
        item: const PeakListItem(peakOsmId: 22, points: 4),
      );
      await repository.updatePeakItemPoints(
        peakListId: 1,
        peakOsmId: 11,
        points: 7,
      );
      await repository.removePeakItem(peakListId: 1, peakOsmId: 22);

      final stored = repository.findById(1);

      expect(stored?.name, 'Abels');
      expect(
        repository
            .getPeakListItemsForList(stored!.peakListId)
            .map((item) => (item.peakOsmId, item.points))
            .toList(),
        [(11, 7)],
      );
    });

    test(
      'addPeakItems updates an existing list in place and preserves prior memberships',
      () async {
        final repository = _peakListRepository(
          peakLists: [
            PeakList(
              peakListId: 7,
              name: 'Italy',
              colour: 0xFF123456,
              region: 'fvg',
              minLat: 46.4084,
              maxLat: 46.4084,
              minLng: 13.0475,
              maxLng: 13.0475,
            ),
          ],
          peaks: [
            Peak(
              osmId: 11,
              name: 'FVG Peak',
              latitude: 46.4084,
              longitude: 13.0475,
              region: 'fvg',
            ),
            Peak(
              osmId: 22,
              name: 'Veneto Peak',
              latitude: 45.7332,
              longitude: 10.8061,
              region: 'veneto',
            ),
          ],
          memberships: const [(peakListId: 7, peakOsmId: 11, points: 2)],
        );

        final updated = await repository.addPeakItems(
          peakListId: 7,
          items: const [PeakListItem(peakOsmId: 22, points: 7)],
        );

        expect(updated.peakListId, 7);
        expect(updated.name, 'Italy');
        expect(updated.colour, 0xFF123456);
        expect(updated.region, PeakList.mixedRegion);
        expect(updated.minLat, 45.7332);
        expect(updated.maxLat, 46.4084);
        expect(updated.minLng, 10.8061);
        expect(updated.maxLng, 13.0475);
        expect(repository.getAllPeakLists(), hasLength(1));
        expect(repository.findById(7), updated);
        expect(
          repository
              .getPeakListItemsForList(7)
              .map((item) => (item.peakOsmId, item.points))
              .toList(),
          [(11, 2), (22, 7)],
        );
      },
    );

    test(
      'addPeakItems rolls back metadata and memberships on item write failure',
      () async {
        final itemStorage = _PartiallyFailingAddPeakListItemEntityStorage([
          PeakListItemEntity(id: 1, points: 2)
            ..peakList.target = PeakList(
              peakListId: 7,
              name: 'Italy',
              colour: 0xFF123456,
              region: 'fvg',
              minLat: 46.4084,
              maxLat: 46.4084,
              minLng: 13.0475,
              maxLng: 13.0475,
            )
            ..peak.target = Peak(
              osmId: 11,
              name: 'FVG Peak',
              latitude: 46.4084,
              longitude: 13.0475,
              region: 'fvg',
            ),
        ]);
        final repository = PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(
              peakListId: 7,
              name: 'Italy',
              colour: 0xFF123456,
              region: 'fvg',
              minLat: 46.4084,
              maxLat: 46.4084,
              minLng: 13.0475,
              maxLng: 13.0475,
            ),
          ]),
          peakRepository: PeakRepository.test(
            InMemoryPeakStorage([
              Peak(
                osmId: 11,
                name: 'FVG Peak',
                latitude: 46.4084,
                longitude: 13.0475,
                region: 'fvg',
              ),
              Peak(
                osmId: 22,
                name: 'Veneto Peak',
                latitude: 45.7332,
                longitude: 10.8061,
                region: 'veneto',
              ),
            ]),
          ),
          itemStorage: itemStorage,
        );

        await expectLater(
          repository.addPeakItems(
            peakListId: 7,
            items: const [PeakListItem(peakOsmId: 22, points: 7)],
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'boom',
            ),
          ),
        );

        final stored = repository.findById(7);

        expect(stored?.peakListId, 7);
        expect(stored?.name, 'Italy');
        expect(stored?.colour, 0xFF123456);
        expect(stored?.region, 'fvg');
        expect(stored?.minLat, 46.4084);
        expect(stored?.maxLat, 46.4084);
        expect(stored?.minLng, 13.0475);
        expect(stored?.maxLng, 13.0475);
        expect(repository.getAllPeakLists(), hasLength(1));
        expect(
          repository
              .getPeakListItemsForList(7)
              .map((item) => (item.peakOsmId, item.points))
              .toList(),
          [(11, 2)],
        );
      },
    );

    test(
      'relational membership mutations update item rows without rewriting legacy payload',
      () async {
        final peakRepository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(osmId: 11, name: 'Peak 11', latitude: -41.5, longitude: 146.5),
            Peak(osmId: 22, name: 'Peak 22', latitude: -41.6, longitude: 146.6),
            Peak(osmId: 33, name: 'Peak 33', latitude: -41.7, longitude: 146.7),
          ]),
        );
        final repository = PeakListRepository.test(
          InMemoryPeakListStorage(),
          peakRepository: peakRepository,
        );
        final saved = await repository.save(
          PeakList(name: 'Abels'),
          items: const [PeakListItem(peakOsmId: 11, points: 2)],
        );

        await repository.addPeakItems(
          peakListId: saved.peakListId,
          items: const [
            PeakListItem(peakOsmId: 22, points: 4),
            PeakListItem(peakOsmId: 33, points: 6),
          ],
        );
        await repository.updatePeakItemPoints(
          peakListId: saved.peakListId,
          peakOsmId: 11,
          points: 7,
        );
        await repository.removePeakItem(
          peakListId: saved.peakListId,
          peakOsmId: 22,
        );

        expect(
          repository
              .getPeakListItemsForList(saved.peakListId)
              .map((item) => (item.peakOsmId, item.points))
              .toList(),
          [(11, 7), (33, 6)],
        );
        expect(repository.findPeakListNamesForPeak(33), ['Abels']);

        await repository.removePeakItem(
          peakListId: saved.peakListId,
          peakOsmId: 33,
        );
        await repository.removePeakItem(
          peakListId: saved.peakListId,
          peakOsmId: 11,
        );

        expect(repository.getPeakListItemsForList(saved.peakListId), isEmpty);
      },
    );

    test('copyWith preserves nullable derived bounds by default', () {
      final peakList = PeakList(
        peakListId: 1,
        name: 'Abels',
        minLat: -42.0,
        maxLat: -41.0,
        minLng: 145.0,
        maxLng: 146.0,
      );

      final copied = peakList.copyWith(name: 'Updated Abels');

      expect(copied.name, 'Updated Abels');
      expect(copied.minLat, -42.0);
      expect(copied.maxLat, -41.0);
      expect(copied.minLng, 145.0);
      expect(copied.maxLng, 146.0);
    });

    test(
      'save preserves derived bounds unless recompute is requested',
      () async {
        final peakRepository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(osmId: 11, name: 'Peak 11', latitude: -41.5, longitude: 146.5),
          ]),
        );
        final repository = PeakListRepository.test(
          InMemoryPeakListStorage(),
          peakRepository: peakRepository,
        );

        final preserved = await repository.save(
          PeakList(name: 'Abels', minLat: 1, maxLat: 2, minLng: 3, maxLng: 4),
          items: const [PeakListItem(peakOsmId: 11, points: 2)],
        );
        final recomputed = await repository.save(
          preserved,
          recomputeDerivedFields: true,
        );

        expect(preserved.minLat, 1);
        expect(preserved.maxLat, 2);
        expect(preserved.minLng, 3);
        expect(preserved.maxLng, 4);
        expect(recomputed.minLat, -41.5);
        expect(recomputed.maxLat, -41.5);
        expect(recomputed.minLng, 146.5);
        expect(recomputed.maxLng, 146.5);
      },
    );

    test(
      'membership changes recompute derived bounds and classification',
      () async {
        final peakRepository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              osmId: 11,
              name: 'FVG Peak',
              latitude: 46.4084,
              longitude: 13.0475,
              region: 'fvg',
            ),
            Peak(
              osmId: 22,
              name: 'Veneto Peak',
              latitude: 45.7332,
              longitude: 10.8061,
              region: 'veneto',
            ),
          ]),
        );
        final repository = PeakListRepository.test(
          InMemoryPeakListStorage(),
          peakRepository: peakRepository,
        );
        final saved = await repository.save(
          PeakList(
            name: 'Italy',
            region: Peak.defaultRegion,
            minLat: 0,
            maxLat: 0,
            minLng: 0,
            maxLng: 0,
          ),
          items: const [PeakListItem(peakOsmId: 11, points: 1)],
        );

        final afterAdd = await repository.addPeakItem(
          peakListId: saved.peakListId,
          item: const PeakListItem(peakOsmId: 22, points: 2),
        );
        final afterPointUpdate = await repository.updatePeakItemPoints(
          peakListId: saved.peakListId,
          peakOsmId: 11,
          points: 7,
        );
        final afterRemove = await repository.removePeakItem(
          peakListId: saved.peakListId,
          peakOsmId: 22,
        );

        expect(afterAdd.region, PeakList.mixedRegion);
        expect(afterAdd.minLat, 45.7332);
        expect(afterAdd.maxLat, 46.4084);
        expect(afterAdd.minLng, 10.8061);
        expect(afterAdd.maxLng, 13.0475);
        expect(afterPointUpdate.region, PeakList.mixedRegion);
        expect(afterPointUpdate.minLat, 45.7332);
        expect(afterPointUpdate.maxLat, 46.4084);
        expect(afterPointUpdate.minLng, 10.8061);
        expect(afterPointUpdate.maxLng, 13.0475);
        expect(afterRemove.region, 'fvg');
        expect(afterRemove.minLat, 46.4084);
        expect(afterRemove.maxLat, 46.4084);
        expect(afterRemove.minLng, 13.0475);
        expect(afterRemove.maxLng, 13.0475);
      },
    );

    test(
      'backfillStoredPeakLists updates mixed regions and null bounds',
      () async {
        final peakRepository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              osmId: 11,
              name: 'FVG Peak',
              latitude: 46.4084,
              longitude: 13.0475,
              region: 'fvg',
            ),
            Peak(
              osmId: 22,
              name: 'Veneto Peak',
              latitude: 45.7332,
              longitude: 10.8061,
              region: 'veneto',
            ),
          ]),
        );
        final repository = PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(
              peakListId: 2,
              name: 'Empty Ready',
              region: 'veneto',
              minLat: 1,
              maxLat: 2,
              minLng: 3,
              maxLng: 4,
            ),
          ]),
          peakRepository: peakRepository,
        );
        final mixedLegacy = await repository.save(
          PeakList(name: 'Mixed Legacy'),
          items: const [
            PeakListItem(peakOsmId: 11, points: 1),
            PeakListItem(peakOsmId: 22, points: 1),
          ],
        );

        final changed = await repository.backfillStoredPeakLists();

        expect(changed, isTrue);
        expect(
          repository.findById(mixedLegacy.peakListId)?.region,
          PeakList.mixedRegion,
        );
        expect(repository.findById(mixedLegacy.peakListId)?.minLat, 45.7332);
        expect(repository.findById(mixedLegacy.peakListId)?.maxLat, 46.4084);
        expect(repository.findById(mixedLegacy.peakListId)?.minLng, 10.8061);
        expect(repository.findById(mixedLegacy.peakListId)?.maxLng, 13.0475);
        expect(repository.findById(2)?.region, 'veneto');
        expect(repository.findById(2)?.minLat, isNull);
        expect(repository.findById(2)?.maxLat, isNull);
        expect(repository.findById(2)?.minLng, isNull);
        expect(repository.findById(2)?.maxLng, isNull);
      },
    );

    test('duplicate add is rejected', () async {
      final repository = _peakListRepository(
        peakLists: [PeakList(name: 'Abels')..peakListId = 1],
        peaks: [_peak(11)],
        memberships: const [(peakListId: 1, peakOsmId: 11, points: 2)],
      );

      await expectLater(
        repository.addPeakItem(
          peakListId: 1,
          item: const PeakListItem(peakOsmId: 11, points: 9),
        ),
        throwsStateError,
      );
    });

    test('Tassy Full single add rejects non-Tasmanian peaks', () async {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage([PeakList(name: 'Tassy Full')..peakListId = 1]),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              osmId: 11,
              name: 'Mainland Peak',
              latitude: -37,
              longitude: 145,
              region: 'victoria',
            ),
          ]),
        ),
      );

      await expectLater(
        repository.addPeakItem(
          peakListId: 1,
          item: const PeakListItem(peakOsmId: 11, points: 9),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            PeakListRepository.tassyFullTasmaniaOnlyError,
          ),
        ),
      );

      expect(repository.getPeakListItemsForList(1), isEmpty);
    });

    test(
      'Tassy Full batch add fails atomically when any peak is non-Tasmanian',
      () async {
        final repository = PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(name: 'Tassy Full')..peakListId = 1,
          ]),
          peakRepository: PeakRepository.test(
            InMemoryPeakStorage([
              Peak(osmId: 11, name: 'Tas Peak', latitude: -41, longitude: 146),
              Peak(
                osmId: 22,
                name: 'Mainland Peak',
                latitude: -37,
                longitude: 145,
                region: 'victoria',
              ),
            ]),
          ),
        );

        await expectLater(
          repository.addPeakItems(
            peakListId: 1,
            items: const [
              PeakListItem(peakOsmId: 11, points: 3),
              PeakListItem(peakOsmId: 22, points: 7),
            ],
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              PeakListRepository.tassyFullTasmaniaOnlyError,
            ),
          ),
        );

        expect(repository.getPeakListItemsForList(1), isEmpty);
      },
    );

    test(
      'Tassy Full add accepts peaks whose Tasmanian coordinates override stale stored region metadata',
      () async {
        final repository = PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(name: 'Tassy Full')..peakListId = 1,
          ]),
          peakRepository: PeakRepository.test(
            InMemoryPeakStorage([
              Peak(
                osmId: 11,
                name: 'Stale Region Peak',
                latitude: -42.291632,
                longitude: 145.884372,
                region: 'victoria',
              ),
            ]),
          ),
        );

        await repository.addPeakItem(
          peakListId: 1,
          item: const PeakListItem(peakOsmId: 11, points: 9),
        );

        expect(
          repository
              .getPeakListItemsForList(1)
              .map((item) => (item.peakOsmId, item.points))
              .toList(),
          [(11, 9)],
        );
      },
    );

    test(
      'findPeakListNamesForPeak returns sorted unique memberships',
      () async {
        final repository = _peakListRepository(
          peakLists: [
            PeakList(name: 'Zeta')..peakListId = 1,
            PeakList(name: 'Alpha')..peakListId = 2,
            PeakList(name: 'Gamma')..peakListId = 3,
          ],
          peaks: [_peak(11)],
          memberships: const [
            (peakListId: 1, peakOsmId: 11, points: 2),
            (peakListId: 1, peakOsmId: 11, points: 5),
            (peakListId: 2, peakOsmId: 11, points: 3),
          ],
        );

        final names = repository.findPeakListNamesForPeak(11);

        expect(names, ['Alpha', 'Zeta']);
      },
    );

    test('save normalizes Tasmania legacy region values only', () async {
      final repository = PeakListRepository.test(InMemoryPeakListStorage());

      final blank = await repository.save(PeakList(name: 'Blank', region: ''));
      final legacyCased = await repository.save(
        PeakList(name: 'Legacy', region: 'Tasmania'),
      );
      final victoria = await repository.save(
        PeakList(name: 'Victoria', region: 'victoria'),
      );

      expect(blank.region, Peak.defaultRegion);
      expect(legacyCased.region, Peak.defaultRegion);
      expect(victoria.region, 'victoria');
      expect(repository.findByName('Blank')?.region, Peak.defaultRegion);
      expect(repository.findByName('Legacy')?.region, Peak.defaultRegion);
      expect(repository.findByName('Victoria')?.region, 'victoria');
    });

    test(
      'save assigns the default palette colour when colour is zero',
      () async {
        final repository = PeakListRepository.test(InMemoryPeakListStorage());

        final saved = await repository.save(PeakList(name: 'Abels'));

        expect(saved.peakListId, 1);
        expect(saved.colour, 0xFF4C8BF5);
        expect(repository.findById(saved.peakListId)?.colour, 0xFF4C8BF5);
      },
    );

    test('save preserves an explicit non-zero colour', () async {
      final repository = PeakListRepository.test(InMemoryPeakListStorage());

      final saved = await repository.save(
        PeakList(name: 'Abels', colour: 0xFF123456),
      );

      expect(saved.colour, 0xFF123456);
      expect(repository.findById(saved.peakListId)?.colour, 0xFF123456);
    });
  });
}

PeakListRepository _peakListRepository({
  required List<PeakList> peakLists,
  List<Peak> peaks = const [],
  List<({int peakListId, int peakOsmId, int points})> memberships = const [],
}) {
  final peaksByOsmId = {
    for (final peak in peaks) peak.osmId: peak,
    for (final membership in memberships)
      if (!peaks.any((peak) => peak.osmId == membership.peakOsmId))
        membership.peakOsmId: _peak(membership.peakOsmId),
  };
  final peakListsById = {
    for (final peakList in peakLists) peakList.peakListId: peakList,
  };

  return PeakListRepository.test(
    InMemoryPeakListStorage(peakLists),
    peakRepository: PeakRepository.test(
      InMemoryPeakStorage(peaksByOsmId.values.toList(growable: false)),
    ),
    itemStorage: InMemoryPeakListItemEntityStorage([
      for (var index = 0; index < memberships.length; index++)
        PeakListItemEntity(id: index + 1, points: memberships[index].points)
          ..peakList.target = peakListsById[memberships[index].peakListId]!
          ..peak.target = peaksByOsmId[memberships[index].peakOsmId]!,
    ]),
  );
}

Peak _peak(int osmId) {
  return Peak(osmId: osmId, name: 'Peak $osmId', latitude: -42, longitude: 146);
}

class _PartiallyFailingAddPeakListItemEntityStorage
    extends InMemoryPeakListItemEntityStorage {
  _PartiallyFailingAddPeakListItemEntityStorage([super.items = const []]);

  @override
  Future<void> addForPeakList(
    PeakList peakList,
    List<PeakListItemEntity> items,
  ) async {
    if (items.isNotEmpty) {
      await super.addForPeakList(peakList, [items.first]);
    }
    throw StateError('boom');
  }
}
