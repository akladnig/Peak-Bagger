import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  group('PeakListRepository', () {
    test('round-trips ordered peakList payload unchanged', () async {
      final repository = PeakListRepository.test(InMemoryPeakListStorage());
      final payload = encodePeakListItems([
        const PeakListItem(peakOsmId: 11, points: 2),
        const PeakListItem(peakOsmId: 22, points: 10),
      ]);

      await repository.save(PeakList(name: 'Abels', peakList: payload));

      final stored = repository.getAllPeakLists().single;

      expect(stored.name, 'Abels');
      expect(stored.peakList, payload);
      expect(
        decodePeakListItems(
          stored.peakList,
        ).map((item) => (item.peakOsmId, item.points)).toList(),
        [(11, 2), (22, 10)],
      );
    });

    test('duplicate-name update preserves existing data on failure', () async {
      final repository = PeakListRepository.test(InMemoryPeakListStorage());
      final originalPayload = encodePeakListItems([
        const PeakListItem(peakOsmId: 11, points: 2),
      ]);

      final saved = await repository.save(
        PeakList(name: 'Abels', peakList: originalPayload),
      );

      await expectLater(
        repository.save(
          PeakList(
            name: 'Abels',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 22, points: 10),
            ]),
          ),
          beforePutForTest: () {
            throw StateError('boom');
          },
        ),
        throwsStateError,
      );

      final stored = repository.getAllPeakLists().single;

      expect(stored.peakListId, saved.peakListId);
      expect(stored.name, 'Abels');
      expect(stored.peakList, originalPayload);
    });

    test('getById returns stored row', () async {
      final repository = PeakListRepository.test(InMemoryPeakListStorage());

      final saved = await repository.save(
        PeakList(name: 'Abels', peakList: '[]'),
      );

      final stored = repository.findById(saved.peakListId);

      expect(stored, isNotNull);
      expect(stored?.name, 'Abels');
    });

    test('delete removes only the targeted row', () async {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(name: 'Abels', peakList: '[]')..peakListId = 1,
          PeakList(name: 'Connoisseurs', peakList: '[]')..peakListId = 2,
        ]),
      );

      await repository.delete(1);

      expect(repository.findById(1), isNull);
      expect(repository.findById(2)?.name, 'Connoisseurs');
      expect(repository.getAllPeakLists(), hasLength(1));
    });

    test('add update and remove peak items preserve list metadata', () async {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(name: 'Abels', peakList: '[]')..peakListId = 1,
        ]),
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
        decodePeakListItems(
          stored!.peakList,
        ).map((item) => (item.peakOsmId, item.points)).toList(),
        [(11, 7)],
      );
    });

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
        final initialPayload = encodePeakListItems([
          const PeakListItem(peakOsmId: 11, points: 2),
        ]);
        final saved = await repository.save(
          PeakList(name: 'Abels', peakList: initialPayload),
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

        expect(repository.findById(saved.peakListId)?.peakList, initialPayload);
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

        expect(repository.findById(saved.peakListId)?.peakList, initialPayload);
        expect(repository.getPeakListItemsForList(saved.peakListId), isEmpty);
      },
    );

    test('copyWith preserves nullable derived bounds by default', () {
      final peakList = PeakList(
        peakListId: 1,
        name: 'Abels',
        peakList: '[]',
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
          PeakList(
            name: 'Abels',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 11, points: 2),
            ]),
            minLat: 1,
            maxLat: 2,
            minLng: 3,
            maxLng: 4,
          ),
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
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 11, points: 1),
            ]),
            minLat: 0,
            maxLat: 0,
            minLng: 0,
            maxLng: 0,
          ),
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
              peakList: '[]',
              minLat: 1,
              maxLat: 2,
              minLng: 3,
              maxLng: 4,
            ),
          ]),
          peakRepository: peakRepository,
        );
        final mixedLegacy = await repository.save(
          PeakList(
            name: 'Mixed Legacy',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 11, points: 1),
              const PeakListItem(peakOsmId: 22, points: 1),
            ]),
          ),
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
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Abels',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 11, points: 2),
            ]),
          )..peakListId = 1,
        ]),
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
        InMemoryPeakListStorage([
          PeakList(name: 'Tassy Full', peakList: '[]')..peakListId = 1,
        ]),
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

      expect(decodePeakListItems(repository.findById(1)!.peakList), isEmpty);
    });

    test(
      'Tassy Full batch add fails atomically when any peak is non-Tasmanian',
      () async {
        final repository = PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(name: 'Tassy Full', peakList: '[]')..peakListId = 1,
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

        expect(decodePeakListItems(repository.findById(1)!.peakList), isEmpty);
      },
    );

    test(
      'Tassy Full add accepts peaks whose Tasmanian coordinates override stale stored region metadata',
      () async {
        final repository = PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(name: 'Tassy Full', peakList: '[]')..peakListId = 1,
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
          repository.getPeakListItemsForList(1)
              .map((item) => (item.peakOsmId, item.points))
              .toList(),
          [(11, 9)],
        );
      },
    );

    test(
      'findPeakListNamesForPeak returns sorted unique memberships',
      () async {
        final repository = PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(
              name: 'Zeta',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 11, points: 2),
                const PeakListItem(peakOsmId: 11, points: 5),
              ]),
            )..peakListId = 1,
            PeakList(
              name: 'Alpha',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 11, points: 3),
              ]),
            )..peakListId = 2,
            PeakList(name: 'Gamma', peakList: '[]')..peakListId = 3,
          ]),
        );

        final names = repository.findPeakListNamesForPeak(11);

        expect(names, ['Alpha', 'Zeta']);
      },
    );

    test('findPeakListNamesForPeak skips malformed list payloads', () async {
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Valid',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 11, points: 2),
            ]),
          )..peakListId = 1,
          PeakList(name: 'Broken', peakList: '{not json')..peakListId = 2,
        ]),
      );

      expect(repository.findPeakListNamesForPeak(11), ['Valid']);
    });

    test('save normalizes Tasmania legacy region values only', () async {
      final repository = PeakListRepository.test(InMemoryPeakListStorage());

      final blank = await repository.save(
        PeakList(name: 'Blank', region: '', peakList: '[]'),
      );
      final legacyCased = await repository.save(
        PeakList(name: 'Legacy', region: 'Tasmania', peakList: '[]'),
      );
      final victoria = await repository.save(
        PeakList(name: 'Victoria', region: 'victoria', peakList: '[]'),
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

        final saved = await repository.save(
          PeakList(name: 'Abels', peakList: '[]'),
        );

        expect(saved.peakListId, 1);
        expect(saved.colour, 0xFF4C8BF5);
        expect(repository.findById(saved.peakListId)?.colour, 0xFF4C8BF5);
      },
    );

    test('save preserves an explicit non-zero colour', () async {
      final repository = PeakListRepository.test(InMemoryPeakListStorage());

      final saved = await repository.save(
        PeakList(name: 'Abels', peakList: '[]', colour: 0xFF123456),
      );

      expect(saved.colour, 0xFF123456);
      expect(repository.findById(saved.peakListId)?.colour, 0xFF123456);
    });
  });
}
