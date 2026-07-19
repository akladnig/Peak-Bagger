import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_summary_service.dart';

void main() {
  group('PeakListSummaryService', () {
    const service = PeakListSummaryService();

    test('sorts by climbed percentage and caps at five rows', () {
      final itemsByPeakListId = {
        10: _items([1, 2]),
        11: _items([1, 3]),
        12: _items([2, 4]),
        13: _items([6]),
        14: _items([1, 5, 8]),
        15: _items([9]),
      };
      final rows = service.buildRows(
        peakLists: [
          _peakList(10, 'Alpha'),
          _peakList(11, 'Alpha'),
          _peakList(12, 'Beta'),
          _peakList(13, 'Delta'),
          _peakList(14, 'Gamma'),
          _peakList(15, 'Epsilon'),
        ],
        climbedPeakIds: {1, 2, 3, 4, 5, 6},
        itemsLoader: (peakList) => itemsByPeakListId[peakList.peakListId]!,
      );

      expect(rows, hasLength(5));
      expect(rows.map((row) => row.peakList.name).toList(), [
        'Alpha',
        'Alpha',
        'Beta',
        'Delta',
        'Gamma',
      ]);
      expect(rows.map((row) => row.peakList.peakListId).toList(), [
        10,
        11,
        12,
        13,
        14,
      ]);
      expect(rows.first.totalPeaks, 2);
      expect(rows.first.climbed, 2);
      expect(rows.first.percentageLabel, '100%');
      expect(rows.last.totalPeaks, 3);
      expect(rows.last.climbed, 2);
      expect(rows.last.unclimbed, 1);
      expect(rows.last.percentageLabel, '67%');
    });

    test('keeps zero-peak rows', () {
      final rows = service.buildRows(
        peakLists: [_peakList(20, 'Empty')],
        climbedPeakIds: const {},
        itemsLoader: (_) => const [],
      );

      expect(rows, hasLength(1));
      expect(rows.single.peakList.name, 'Empty');
      expect(rows.single.totalPeaks, 0);
      expect(rows.single.climbed, 0);
      expect(rows.single.unclimbed, 0);
      expect(rows.single.percentageLabel, '0%');
    });

    test('returns empty list when no usable peak lists exist', () {
      final rows = service.buildRows(
        peakLists: const [],
        climbedPeakIds: const {},
        itemsLoader: (_) => const [],
      );

      expect(rows, isEmpty);
    });
  });
}

PeakList _peakList(int id, String name) {
  return PeakList(peakListId: id, name: name);
}

List<PeakListItem> _items(List<int> peakIds) {
  return peakIds
      .map((peakId) => PeakListItem(peakOsmId: peakId, points: 1))
      .toList(growable: false);
}
