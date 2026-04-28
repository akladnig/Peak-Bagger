import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

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
        decodePeakListItems(stored!.peakList)
            .map((item) => (item.peakOsmId, item.points))
            .toList(),
        [(11, 7)],
      );
    });

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

    test('findPeakListNamesForPeak returns sorted unique memberships', () async {
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
    });
  });
}
