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
  final selectedPeakListIds = ref.watch(
    mapProvider.select((state) => state.selectedPeakListIds),
  );
  final peakLists = ref.watch(peakListsProvider);

  return switch (peakListSelectionMode) {
    PeakListSelectionMode.none => const [],
    PeakListSelectionMode.allPeaks => peaks,
    PeakListSelectionMode.specificList => _filterSpecificListPeaks(
      peaks: peaks,
      peakLists: peakLists,
      peakListIds: selectedPeakListIds,
    ),
  };
});

List<Peak> _filterSpecificListPeaks({
  required List<Peak> peaks,
  required List<PeakList> peakLists,
  required Set<int> peakListIds,
}) {
  if (peakListIds.isEmpty) {
    return const [];
  }

  final selectedPeakOsmIds = <int>{};
  var resolvedListCount = 0;
  for (final candidate in peakLists) {
    if (!peakListIds.contains(candidate.peakListId)) {
      continue;
    }
    resolvedListCount += 1;
    try {
      final items = decodePeakListItems(candidate.peakList);
      selectedPeakOsmIds.addAll(items.map((item) => item.peakOsmId));
    } catch (error, stackTrace) {
      developer.log(
        'Failed to decode selected peak list ${candidate.peakListId}.',
        error: error,
        stackTrace: stackTrace,
        name: 'peak_list_selection_provider',
      );
    }
  }

  if (resolvedListCount == 0) {
    return peaks;
  }

  return peaks
      .where((peak) => selectedPeakOsmIds.contains(peak.osmId))
      .toList(growable: false);
}

class PeakListRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state += 1;
  }
}
