import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/map_provider.dart';
import '../providers/peak_list_provider.dart';
import '../providers/peak_list_selection_provider.dart';
import '../services/peak_list_summary_service.dart';

final myListsSummaryProvider = Provider<List<PeakListSummaryRow>>((ref) {
  final peakLists = ref.watch(peakListsProvider);
  ref.watch(mapProvider.select((state) => state.tracks));
  final climbedPeakIds = _climbedPeakIds(ref);
  return const PeakListSummaryService().buildRows(
    peakLists: peakLists,
    climbedPeakIds: climbedPeakIds,
  );
});

Set<int> _climbedPeakIds(Ref ref) {
  try {
    return ref
        .watch(peaksBaggedRepositoryProvider)
        .latestAscentDatesByPeakId()
        .keys
        .toSet();
  } catch (_) {
    return const <int>{};
  }
}
