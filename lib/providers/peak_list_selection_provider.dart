import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';

final peakListRevisionProvider = NotifierProvider<PeakListRevisionNotifier, int>(
  PeakListRevisionNotifier.new,
);

final peakListsProvider = Provider<List<PeakList>>((ref) {
  ref.watch(peakListRevisionProvider);
  try {
    final repo = ref.watch(peakListRepositoryProvider);
    return repo.getAllPeakLists();
  } catch (error, stackTrace) {
    developer.log(
      'Failed to load peak lists.',
      error: error,
      stackTrace: stackTrace,
      name: 'peak_list_selection_provider',
    );
    return const [];
  }
});

final filteredPeaksProvider = Provider<List<Peak>>((ref) {
  final peaks = ref.watch(mapProvider.select((state) => state.peaks));
  final peakListSelectionMode = ref.watch(
    mapProvider.select((state) => state.peakListSelectionMode),
  );
  final selectedPeakListId = ref.watch(
    mapProvider.select((state) => state.selectedPeakListId),
  );
  final peakLists = ref.watch(peakListsProvider);

  return switch (peakListSelectionMode) {
    PeakListSelectionMode.none => const [],
    PeakListSelectionMode.allPeaks => peaks,
    PeakListSelectionMode.specificList => _filterSpecificListPeaks(
      peaks: peaks,
      peakLists: peakLists,
      peakListId: selectedPeakListId,
    ),
  };
});

List<Peak> _filterSpecificListPeaks({
  required List<Peak> peaks,
  required List<PeakList> peakLists,
  required int? peakListId,
}) {
  if (peakListId == null) {
    return peaks;
  }

  PeakList? peakList;
  for (final candidate in peakLists) {
    if (candidate.peakListId == peakListId) {
      peakList = candidate;
      break;
    }
  }
  if (peakList == null) {
    return peaks;
  }

  try {
    final items = decodePeakListItems(peakList.peakList);
    final osmIds = items
        .map((item) => item.peakOsmId)
        .toSet();
    return peaks
        .where((peak) => osmIds.contains(peak.osmId))
        .toList(growable: false);
  } catch (error, stackTrace) {
    developer.log(
      'Failed to decode selected peak list ${peakList.peakListId}.',
      error: error,
      stackTrace: stackTrace,
      name: 'peak_list_selection_provider',
    );
    return peaks;
  }
}

class PeakListRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state += 1;
  }
}
