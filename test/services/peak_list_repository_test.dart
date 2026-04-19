import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

void main() {
  group('PeakListRepository', () {
    test('round-trips ordered peakList payload unchanged', () async {
      final repository = PeakListRepository.test(InMemoryPeakListStorage());
      final payload = encodePeakListItems([
        const PeakListItem(peakOsmId: 11, points: '2'),
        const PeakListItem(peakOsmId: 22, points: '10'),
      ]);

      await repository.save(PeakList(name: 'Abels', peakList: payload));

      final stored = repository.getAllPeakLists().single;

      expect(stored.name, 'Abels');
      expect(stored.peakList, payload);
      expect(
        decodePeakListItems(
          stored.peakList,
        ).map((item) => (item.peakOsmId, item.points)).toList(),
        [(11, '2'), (22, '10')],
      );
    });

    test('duplicate-name update preserves existing data on failure', () async {
      final repository = PeakListRepository.test(InMemoryPeakListStorage());
      final originalPayload = encodePeakListItems([
        const PeakListItem(peakOsmId: 11, points: '2'),
      ]);

      final saved = await repository.save(
        PeakList(name: 'Abels', peakList: originalPayload),
      );

      await expectLater(
        repository.save(
          PeakList(
            name: 'Abels',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 22, points: '10'),
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
  });
}
