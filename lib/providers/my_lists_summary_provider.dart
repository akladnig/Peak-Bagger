import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/map_provider.dart';
import '../providers/peak_list_selection_provider.dart';
import '../services/peak_list_summary_service.dart';

final myListsSummaryProvider = Provider<List<PeakListSummaryRow>>((ref) {
  final peakLists = ref.watch(peakListsProvider);
  final tracks = ref.watch(mapProvider.select((state) => state.tracks));
  return const PeakListSummaryService().buildRows(
    peakLists: peakLists,
    tracks: tracks,
  );
});
