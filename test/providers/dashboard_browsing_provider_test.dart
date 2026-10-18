import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/providers/dashboard_browsing_provider.dart';
import 'package:peak_bagger/providers/my_ascents_summary_provider.dart';
import 'package:peak_bagger/providers/my_lists_summary_provider.dart';
import 'package:peak_bagger/services/my_ascents_summary_service.dart';
import 'package:peak_bagger/services/peak_list_summary_service.dart';

void main() {
  test(
    'list selection reconciles live identities, empty data and focus re-entry',
    () {
      final container = ProviderContainer(
        overrides: [
          myListsSummaryProvider.overrideWithValue(_lists([1, 2, 3])),
        ],
      );
      addTearDown(container.dispose);
      final provider = dashboardRowSelectionProvider('my-lists');
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final controller = container.read(provider.notifier);
      expect(container.read(provider).selectedId, isNull);
      controller.enter();
      controller.move(true);
      expect(container.read(provider).selectedId, 2);
      container.updateOverrides([
        myListsSummaryProvider.overrideWithValue(_lists([3, 2, 4])),
      ]);
      expect(container.read(provider).selectedId, 2);
      controller.move(true);
      controller.move(true);
      expect(container.read(provider).selectedId, 4);
      container.updateOverrides([
        myListsSummaryProvider.overrideWithValue(_lists([3, 5])),
      ]);
      expect(container.read(provider).selectedId, 3);
      container.updateOverrides([myListsSummaryProvider.overrideWithValue([])]);
      expect(container.read(provider).selectedId, isNull);
      controller.move(true);
      expect(container.read(provider).selectedId, isNull);
      container.updateOverrides([
        myListsSummaryProvider.overrideWithValue(_lists([5, 6])),
      ]);
      expect(container.read(provider).selectedId, 5);
      controller.move(true);
      controller.enter();
      expect(container.read(provider).selectedId, 5);
    },
  );

  test(
    'ascent sort preserves bagged identity across years, refresh and removal',
    () {
      MyAscentsDataset data(List<int> ids) => MyAscentsDataset(
        baggedRows: [
          for (final id in ids)
            PeaksBagged(
              baggedId: id,
              peakId: id,
              gpxId: id + 100,
              date: DateTime.utc(2020 + id, 1, 1),
            ),
        ],
        peaksByOsmId: const {},
      );
      final container = ProviderContainer(
        overrides: [
          myAscentsSummaryProvider.overrideWithValue(data([1, 2, 3])),
        ],
      );
      addTearDown(container.dispose);
      final provider = dashboardRowSelectionProvider('my-ascents');
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      final controller = container.read(provider.notifier);
      controller.enter();
      expect(container.read(provider).selectedId, 3);
      container.read(myAscentsAscendingProvider.notifier).toggle();
      expect(container.read(provider).ids, [1, 2, 3]);
      expect(container.read(provider).selectedId, 3);
      controller.move(true);
      expect(container.read(provider).selectedId, 3);
      container.updateOverrides([
        myAscentsSummaryProvider.overrideWithValue(data([1, 2, 4])),
      ]);
      expect(container.read(provider).selectedId, 1);
      controller.move(false);
      expect(container.read(provider).selectedId, 1);
      // A new screen lifecycle has no newly persisted sort or row selection.
      final next = ProviderContainer(
        overrides: [
          myAscentsSummaryProvider.overrideWithValue(data([1, 2, 4])),
        ],
      );
      addTearDown(next.dispose);
      expect(next.read(myAscentsAscendingProvider), isFalse);
      expect(next.read(provider).selectedId, isNull);
    },
  );
}

List<PeakListSummaryRow> _lists(List<int> ids) => [
  for (final id in ids)
    PeakListSummaryRow(
      peakList: PeakList(peakListId: id, name: 'List $id'),
      totalPeaks: 0,
      climbed: 0,
      unclimbed: 0,
      percentageValue: 0,
    ),
];
