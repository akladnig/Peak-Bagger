import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_summary_service.dart';

void main() {
  group('PeakListSummaryService', () {
    const service = PeakListSummaryService();

    test('sorts by climbed percentage and caps at five rows', () {
      final rows = service.buildRows(
        peakLists: [
          _peakList(10, 'Alpha', [1, 2]),
          _peakList(11, 'Alpha', [1, 3]),
          _peakList(12, 'Beta', [2, 4]),
          _peakList(13, 'Delta', [6]),
          _peakList(14, 'Gamma', [1, 5, 8]),
          _peakList(15, 'Epsilon', [9]),
        ],
        climbedPeakIds: {1, 2, 3, 4, 5, 6},
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

    test('skips malformed lists and keeps zero-peak rows', () {
      final rows = service.buildRows(
        peakLists: [
          _peakList(20, 'Empty', []),
          PeakList(name: 'Broken', peakList: 'not-json')..peakListId = 21,
        ],
        climbedPeakIds: const {},
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
      );

      expect(rows, isEmpty);
    });
  });
}

PeakList _peakList(
  int id,
  String name,
  List<int> peakIds,
) {
  return PeakList(
    peakListId: id,
    name: name,
    peakList: encodePeakListItems(
      peakIds
          .map((peakId) => PeakListItem(peakOsmId: peakId, points: 1))
          .toList(growable: false),
    ),
  );
}
