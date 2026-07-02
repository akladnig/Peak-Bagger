import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/services/peak_list_visibility.dart';

final peakListRevisionProvider =
    NotifierProvider<PeakListRevisionNotifier, int>(
      PeakListRevisionNotifier.new,
    );

final peakListsLoadProvider =
    NotifierProvider<PeakListsLoadNotifier, PeakListsLoadState>(
      PeakListsLoadNotifier.new,
    );

final peakListsProvider = Provider<List<PeakList>>((ref) {
  return ref.watch(peakListsLoadProvider).peakLists;
});

final peakListsLoadFailedProvider = Provider<bool>((ref) {
  return ref.watch(peakListsLoadProvider).failed;
});

final peakListSelectionSummaryProvider = Provider<PeakListSelectionSummary>((
  ref,
) {
  final (
    :peakListSelectionMode,
    :selectedPeakListIds,
    :pinnedPeakListIdsByRegion,
    :visibleBounds,
  ) = ref.watch(
    mapProvider.select(
      (state) => (
        peakListSelectionMode: state.peakListSelectionMode,
        selectedPeakListIds: state.selectedPeakListIds,
        pinnedPeakListIdsByRegion: state.pinnedPeakListIdsByRegion,
        visibleBounds: state.visibleBounds,
      ),
    ),
  );
  final peakLists = ref.watch(peakListsProvider);
  final visibleRegionKeys = visibleRegionKeysForBounds(visibleBounds);
  final hasResolvedVisibleBounds = visibleBounds != null;
  if (hasResolvedVisibleBounds && visibleRegionKeys.isEmpty) {
    return const PeakListSelectionSummary(chips: []);
  }
  final labelsById = {
    for (final peakList in peakLists) peakList.peakListId: peakList.name,
  };
  final regionKeysById = {
    for (final peakList in peakLists)
      peakList.peakListId: canonicalRegionKey(
        normalizePeakListRegionKey(peakList.region),
      ),
  };
  final visiblePinnedPeakListIds = hasResolvedVisibleBounds
      ? <int>{
          for (final regionKey in visibleRegionKeys)
            ...?pinnedPeakListIdsByRegion[regionKey],
        }
      : <int>{
          for (final ids in pinnedPeakListIdsByRegion.values) ...ids,
        };
  final visibleSelectedPeakListIds = hasResolvedVisibleBounds
      ? {
          for (final peakListId in selectedPeakListIds)
            if (visibleRegionKeys.contains(regionKeysById[peakListId])) peakListId,
        }
      : selectedPeakListIds.toSet();
  final visibleSpecificPeakListIds = {
    ...visiblePinnedPeakListIds,
    ...visibleSelectedPeakListIds,
  }.toList()
    ..sort((left, right) {
      return (labelsById[left] ?? 'List #$left').toLowerCase().compareTo(
        (labelsById[right] ?? 'List #$right').toLowerCase(),
      );
    });
  final chips = <PeakListSelectionChip>[
    if (peakListSelectionMode == PeakListSelectionMode.allPeaks)
      const PeakListSelectionChip.allPeaks(),
    if (peakListSelectionMode == PeakListSelectionMode.none)
      const PeakListSelectionChip.none(),
    for (final peakListId in visibleSpecificPeakListIds)
      PeakListSelectionChip.list(
        peakListId: peakListId,
        label: labelsById[peakListId] ?? 'List #$peakListId',
        regionKey: regionKeysById[peakListId],
        isSelected: visibleSelectedPeakListIds.contains(peakListId),
        isPinned: visiblePinnedPeakListIds.contains(peakListId),
      ),
  ];

  return PeakListSelectionSummary(chips: chips);
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

class PeakListsLoadState {
  const PeakListsLoadState._({required this.peakLists, required this.failed});

  const PeakListsLoadState.success(List<PeakList> peakLists)
    : this._(peakLists: peakLists, failed: false);

  const PeakListsLoadState.failure(List<PeakList> peakLists)
    : this._(peakLists: peakLists, failed: true);

  final List<PeakList> peakLists;
  final bool failed;
}

class PeakListSelectionSummary {
  const PeakListSelectionSummary({required this.chips});

  final List<PeakListSelectionChip> chips;
}

class PeakListSelectionChip {
  const PeakListSelectionChip._({
    required this.label,
    this.peakListId,
    this.regionKey,
    this.isSelected = true,
    this.isPinned = false,
  });

  const PeakListSelectionChip.allPeaks() : this._(label: 'All Peaks');

  const PeakListSelectionChip.none() : this._(label: 'None');

  const PeakListSelectionChip.list({
    required int peakListId,
    required String label,
    required String? regionKey,
    required bool isSelected,
    required bool isPinned,
  }) : this._(
         label: label,
         peakListId: peakListId,
         regionKey: regionKey,
         isSelected: isSelected,
         isPinned: isPinned,
       );

  final String label;
  final int? peakListId;
  final String? regionKey;
  final bool isSelected;
  final bool isPinned;

  bool get isAllPeaks => peakListId == null && label == 'All Peaks';

  bool get isNone => peakListId == null && label == 'None';
}

class PeakListsLoadNotifier extends Notifier<PeakListsLoadState> {
  List<PeakList> _cachedPeakLists = const [];

  @override
  PeakListsLoadState build() {
    ref.watch(peakListRevisionProvider);
    try {
      final repo = ref.read(peakListRepositoryProvider);
      final peakLists = repo.getAllPeakLists();
      _cachedPeakLists = peakLists;
      return PeakListsLoadState.success(peakLists);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load peak lists.',
        error: error,
        stackTrace: stackTrace,
        name: 'peak_list_selection_provider',
      );
      return PeakListsLoadState.failure(_cachedPeakLists);
    }
  }
}
