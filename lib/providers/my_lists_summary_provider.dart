import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/map_provider.dart';
import '../providers/peak_list_provider.dart';
import '../providers/peak_list_selection_provider.dart';
import '../services/peak_list_summary_service.dart';
import '../services/performance_measurement.dart';
import 'local_data_load_outcome_provider.dart';

final myListsSummaryProvider = Provider<List<PeakListSummaryRow>>((ref) {
  return ref.watch(myListsSummaryReadProvider).requireValue;
});

final myListsSummaryReadProvider =
    Provider<AsyncValue<List<PeakListSummaryRow>>>((ref) {
      final peakLists = ref.watch(peakListsProvider);
      final peakListRepository = ref.watch(peakListRepositoryProvider);
      ref.watch(mapProvider.select((state) => state.tracks));
      ref.watch(peaksBaggedRevisionProvider);
      final climbedPeakIds =
          ref.watch(myListsAscentDatesReadProvider).value ?? const <int>{};
      try {
        return AsyncData(
          performanceMeasurement.phaseSync(
            'dashboard.my-lists',
            () => const PeakListSummaryService().buildRows(
              peakLists: peakLists,
              climbedPeakIds: climbedPeakIds,
              itemsLoader: (peakList) {
                return peakListRepository.getPeakListItemsForList(
                  peakList.peakListId,
                );
              },
            ),
          ),
        );
      } catch (error, trace) {
        return AsyncError(error, trace);
      }
    });

final myListsAscentDatesReadProvider = Provider<AsyncValue<Set<int>>>((ref) {
  ref.watch(peaksBaggedRevisionProvider);
  ref.watch(mapDashboardLoadProvider);
  ref.watch(mapProvider.select((state) => state.tracks));
  try {
    return AsyncData(
      performanceMeasurement.phaseSync(
        'dashboard.list-ascent-dates',
        () => ref
            .watch(peaksBaggedRepositoryProvider)
            .latestAscentDatesByPeakId()
            .keys
            .toSet(),
      ),
    );
  } catch (error, trace) {
    return AsyncError(error, trace);
  }
});
