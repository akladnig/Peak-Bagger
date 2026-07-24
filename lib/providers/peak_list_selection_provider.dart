import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peak_ownership_ring_segment.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_ownership_ring_settings_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';
import 'package:peak_bagger/services/fab_colour_resolver.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_list_visibility.dart';
import 'package:peak_bagger/widgets/map_rebuild_debug_counters.dart';

const _tasmaniaPeakOwnershipPriority = <String, int>{
  'abels': 0,
  'hwc peak baggers': 1,
  'poimenas': 2,
  'tassy full': 3,
};

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

typedef PeakListSelectionRefreshScheduler =
    Future<void> Function(FutureOr<void> Function() task);

final peakListSelectionRefreshSchedulerProvider =
    Provider<PeakListSelectionRefreshScheduler>((ref) {
      return (task) {
        return Future<void>(() async {
          await task();
        });
      };
    });

typedef _PeakListSelectionRefreshInputs = ({
  PeakListSelectionMode peakListSelectionMode,
  Set<int> selectedPeakListIds,
  Map<String, Set<int>> pinnedPeakListIdsByRegion,
  LatLngBounds? visibleBounds,
  List<Peak> peaks,
  List<PeakList> peakLists,
  int revision,
});

final _peakListSelectionRefreshInputsProvider =
    Provider<_PeakListSelectionRefreshInputs>((ref) {
      final peakLists = ref.watch(peakListsProvider);
      final revision = ref.watch(peakListRevisionProvider);
      final (
        :peakListSelectionMode,
        :selectedPeakListIds,
        :pinnedPeakListIdsByRegion,
        :visibleBounds,
        :peaks,
      ) = ref.watch(
        mapProvider.select(
          (state) => (
            peakListSelectionMode: state.peakListSelectionMode,
            selectedPeakListIds: state.selectedPeakListIds,
            pinnedPeakListIdsByRegion: state.pinnedPeakListIdsByRegion,
            visibleBounds: state.visibleBounds,
            peaks: state.peaks,
          ),
        ),
      );

      return (
        peakListSelectionMode: peakListSelectionMode,
        selectedPeakListIds: selectedPeakListIds,
        pinnedPeakListIdsByRegion: pinnedPeakListIdsByRegion,
        visibleBounds: visibleBounds,
        peaks: peaks,
        peakLists: peakLists,
        revision: revision,
      );
    });

final _peakListSelectionDerivedStateProvider =
    NotifierProvider<
      _PeakListSelectionDerivedStateNotifier,
      _PeakListSelectionDerivedState
    >(_PeakListSelectionDerivedStateNotifier.new);

final peakListSelectionSummaryProvider = Provider<PeakListSelectionSummary>((
  ref,
) {
  return ref.watch(_peakListSelectionDerivedStateProvider).summary;
});

final mapPeakListDrawerEntriesProvider = Provider<List<MapPeakListDrawerEntry>>(
  (ref) {
    return ref.watch(_peakListSelectionDerivedStateProvider).drawerEntries;
  },
);

final filteredPeaksProvider = Provider<List<Peak>>((ref) {
  final peaks = ref.watch(mapMetadataFilterScopePeaksProvider);
  final (:ratingFilter, :difficultyFilter, :durationFilter) = ref.watch(
    mapProvider.select(
      (state) => (
        ratingFilter: state.peakRatingFilter,
        difficultyFilter: state.peakDifficultyFilter,
        durationFilter: state.peakDurationFilter,
      ),
    ),
  );

  return peaks
      .where((peak) {
        return peakMatchesRatingFilter(peak, ratingFilter) &&
            peakMatchesDifficultyFilter(peak, difficultyFilter) &&
            peakMatchesDurationFilter(peak, durationFilter);
      })
      .toList(growable: false);
});

final mapMetadataFilterScopePeaksProvider = Provider<List<Peak>>((ref) {
  return ref
      .watch(_peakListSelectionDerivedStateProvider)
      .metadataFilterScopePeaks;
});

final mapDifficultyFilterOptionsProvider =
    Provider<List<PeakDifficultyFilterOption>>((ref) {
      final peaks = ref.watch(mapMetadataFilterScopePeaksProvider);
      return buildPeakDifficultyFilterOptions(peaks);
    });

final peakActiveOwnershipSegmentsProvider =
    Provider<Map<int, List<PeakOwnershipRingSegment>>>((ref) {
      return ref
          .watch(_peakListSelectionDerivedStateProvider)
          .activeOwnershipSegments;
    });

final peakOwnershipRingSegmentsProvider =
    Provider<Map<int, List<PeakOwnershipRingSegment>>>((ref) {
      final showPeakOwnershipRings = ref.watch(
        peakOwnershipRingSettingsProvider,
      );
      if (!showPeakOwnershipRings) {
        return const <int, List<PeakOwnershipRingSegment>>{};
      }

      final activeSegmentsByPeakId = ref.watch(
        peakActiveOwnershipSegmentsProvider,
      );
      final segmentsByPeakId = <int, List<PeakOwnershipRingSegment>>{};

      for (final entry in activeSegmentsByPeakId.entries) {
        if (entry.value.length < 2) {
          continue;
        }

        segmentsByPeakId[entry.key] = entry.value;
      }

      return Map<int, List<PeakOwnershipRingSegment>>.unmodifiable(
        segmentsByPeakId,
      );
    });

final peakMarkerColourAssignmentsProvider = Provider<Map<int, int>>((ref) {
  return ref.watch(_peakListSelectionDerivedStateProvider).peakMarkerColours;
});

class PeakViewportSelectionData {
  const PeakViewportSelectionData({
    required this.filteredPeaks,
    required this.activeOwnershipSegments,
    required this.ownershipRingSegments,
    required this.peakMarkerColours,
  });

  final List<Peak> filteredPeaks;
  final Map<int, List<PeakOwnershipRingSegment>> activeOwnershipSegments;
  final Map<int, List<PeakOwnershipRingSegment>> ownershipRingSegments;
  final Map<int, int> peakMarkerColours;
}

PeakViewportSelectionData buildPeakViewportSelectionData({
  required PeakListSelectionMode peakListSelectionMode,
  required Set<int> selectedPeakListIds,
  required Map<String, Set<int>> pinnedPeakListIdsByRegion,
  required LatLngBounds? visibleBounds,
  required List<Peak> peaks,
  required List<PeakList> peakLists,
  required PeakRatingFilterOption ratingFilter,
  required PeakDifficultyFilterOption? difficultyFilter,
  required PeakDurationFilterOption durationFilter,
  required bool showPeakOwnershipRings,
  required PeakListRepository repo,
}) {
  final derivedState = _buildDerivedState(
    inputs: (
      peakListSelectionMode: peakListSelectionMode,
      selectedPeakListIds: selectedPeakListIds,
      pinnedPeakListIdsByRegion: pinnedPeakListIdsByRegion,
      visibleBounds: visibleBounds,
      peaks: peaks,
      peakLists: peakLists,
      revision: 0,
    ),
    repo: repo,
  );

  final filteredPeaks = derivedState.metadataFilterScopePeaks
      .where((peak) {
        return peakMatchesRatingFilter(peak, ratingFilter) &&
            peakMatchesDifficultyFilter(peak, difficultyFilter) &&
            peakMatchesDurationFilter(peak, durationFilter);
      })
      .toList(growable: false);

  return PeakViewportSelectionData(
    filteredPeaks: filteredPeaks,
    activeOwnershipSegments: derivedState.activeOwnershipSegments,
    ownershipRingSegments: _buildOwnershipRingSegments(
      activeOwnershipSegments: derivedState.activeOwnershipSegments,
      showPeakOwnershipRings: showPeakOwnershipRings,
    ),
    peakMarkerColours: derivedState.peakMarkerColours,
  );
}

class MapPeakListDrawerEntry {
  const MapPeakListDrawerEntry({
    required this.peakList,
    required this.renderableCount,
    required this.isPinned,
  });

  final PeakList peakList;
  final int renderableCount;
  final bool isPinned;
}

class _PeakListSelectionDerivedState {
  const _PeakListSelectionDerivedState({
    required this.summary,
    required this.drawerEntries,
    required this.metadataFilterScopePeaks,
    required this.activeOwnershipSegments,
    required this.peakMarkerColours,
  });

  final PeakListSelectionSummary summary;
  final List<MapPeakListDrawerEntry> drawerEntries;
  final List<Peak> metadataFilterScopePeaks;
  final Map<int, List<PeakOwnershipRingSegment>> activeOwnershipSegments;
  final Map<int, int> peakMarkerColours;
}

Map<int, List<PeakOwnershipRingSegment>> _buildOwnershipRingSegments({
  required Map<int, List<PeakOwnershipRingSegment>> activeOwnershipSegments,
  required bool showPeakOwnershipRings,
}) {
  if (!showPeakOwnershipRings) {
    return const <int, List<PeakOwnershipRingSegment>>{};
  }

  final segmentsByPeakId = <int, List<PeakOwnershipRingSegment>>{};
  for (final entry in activeOwnershipSegments.entries) {
    if (entry.value.length < 2) {
      continue;
    }
    segmentsByPeakId[entry.key] = entry.value;
  }

  return Map<int, List<PeakOwnershipRingSegment>>.unmodifiable(
    segmentsByPeakId,
  );
}

class _PeakListSelectionDerivedStateNotifier
    extends Notifier<_PeakListSelectionDerivedState> {
  @override
  _PeakListSelectionDerivedState build() {
    final inputs = ref.watch(_peakListSelectionRefreshInputsProvider);
    return _buildDerivedState(
      inputs: inputs,
      repo: ref.watch(peakListRepositoryProvider),
    );
  }
}

_PeakListSelectionDerivedState _buildDerivedState({
  required _PeakListSelectionRefreshInputs inputs,
  required PeakListRepository repo,
}) {
  MapRebuildDebugCounters.recordPeakListDerivedRefresh();
  final peakListsById = {
    for (final peakList in inputs.peakLists) peakList.peakListId: peakList,
  };
  final peaksById = {for (final peak in inputs.peaks) peak.osmId: peak};
  final visibilityLookup = _PeakListMembershipLookup(repo: repo);
  final visibleRegionKeys = visibleRegionKeysForBounds(inputs.visibleBounds);
  final hasResolvedVisibleBounds = inputs.visibleBounds != null;
  final peakRegionKeysByOsmId = {
    for (final peak in inputs.peaks) peak.osmId: canonicalPeakRegionKey(peak),
  };
  final visibilityStateByPeakListId = _buildPeakListVisibilityStateByPeakListId(
    inputs: inputs,
    visibleRegionKeys: visibleRegionKeys,
    peakRegionKeysByOsmId: peakRegionKeysByOsmId,
    visibilityLookup: visibilityLookup,
  );

  final summary = _buildPeakListSelectionSummary(
    inputs: inputs,
    peakListsById: peakListsById,
    visibleRegionKeys: visibleRegionKeys,
    hasResolvedVisibleBounds: hasResolvedVisibleBounds,
    visibilityStateByPeakListId: visibilityStateByPeakListId,
  );
  final drawerEntries = _buildMapPeakListDrawerEntries(
    inputs: inputs,
    visibilityStateByPeakListId: visibilityStateByPeakListId,
  );
  final metadataFilterScopePeaks = switch (inputs.peakListSelectionMode) {
    PeakListSelectionMode.none => const <Peak>[],
    PeakListSelectionMode.allPeaks => inputs.peaks,
    PeakListSelectionMode.specificList => _filterSpecificListPeaks(
      repo: repo,
      peaks: inputs.peaks,
      peakListIds: inputs.selectedPeakListIds,
    ),
  };
  final (
    activeOwnershipSegments: activeOwnershipSegments,
    peakMarkerColours: peakMarkerColours,
  ) = _buildActiveOwnershipOutputs(
    inputs: inputs,
    peakListsById: peakListsById,
    peaksById: peaksById,
    visibleRegionKeys: visibleRegionKeys,
    visibilityLookup: visibilityLookup,
    visibilityStateByPeakListId: visibilityStateByPeakListId,
  );

  return _PeakListSelectionDerivedState(
    summary: summary,
    drawerEntries: drawerEntries,
    metadataFilterScopePeaks: metadataFilterScopePeaks,
    activeOwnershipSegments: activeOwnershipSegments,
    peakMarkerColours: peakMarkerColours,
  );
}

PeakListSelectionSummary _buildPeakListSelectionSummary({
  required _PeakListSelectionRefreshInputs inputs,
  required Map<int, PeakList> peakListsById,
  required Set<String> visibleRegionKeys,
  required bool hasResolvedVisibleBounds,
  required Map<int, _PeakListVisibilityState> visibilityStateByPeakListId,
}) {
  if (hasResolvedVisibleBounds && visibleRegionKeys.isEmpty) {
    return const PeakListSelectionSummary(chips: []);
  }

  final labelsById = {
    for (final peakList in inputs.peakLists) peakList.peakListId: peakList.name,
  };
  final regionKeysById = {
    for (final peakList in inputs.peakLists)
      peakList.peakListId: canonicalRegionKey(
        normalizePeakListRegionKey(peakList.region),
      ),
  };
  final visiblePinnedPeakListIds = {
    for (final peakList in inputs.peakLists)
      if ((!hasResolvedVisibleBounds ||
              (visibilityStateByPeakListId[peakList.peakListId]
                      ?.appliesToVisibleRegions ??
                  false)) &&
          (visibilityStateByPeakListId[peakList.peakListId]?.isPinned ?? false))
        peakList.peakListId,
  };
  final visibleSelectedPeakListIds = hasResolvedVisibleBounds
      ? {
          for (final peakListId in inputs.selectedPeakListIds)
            if (() {
              return visibilityStateByPeakListId[peakListId]
                      ?.appliesToVisibleRegions ??
                  false;
            }())
              peakListId,
        }
      : inputs.selectedPeakListIds.toSet();
  final visibleSpecificPeakListIds =
      {...visiblePinnedPeakListIds, ...visibleSelectedPeakListIds}.toList()
        ..sort((left, right) {
          return (labelsById[left] ?? 'List #$left').toLowerCase().compareTo(
            (labelsById[right] ?? 'List #$right').toLowerCase(),
          );
        });
  final chips = <PeakListSelectionChip>[
    if (inputs.peakListSelectionMode == PeakListSelectionMode.allPeaks)
      const PeakListSelectionChip.allPeaks(),
    if (inputs.peakListSelectionMode == PeakListSelectionMode.none)
      const PeakListSelectionChip.none(),
    for (final peakListId in visibleSpecificPeakListIds)
      () {
        final peakList = peakListsById[peakListId];
        return PeakListSelectionChip.list(
          peakListId: peakListId,
          label: labelsById[peakListId] ?? 'List #$peakListId',
          regionKey: regionKeysById[peakListId],
          isSelected: visibleSelectedPeakListIds.contains(peakListId),
          isPinned: visiblePinnedPeakListIds.contains(peakListId),
          colourValue: peakList == null
              ? null
              : resolvePeakListColour(peakList),
        );
      }(),
  ];

  return PeakListSelectionSummary(chips: chips);
}

List<MapPeakListDrawerEntry> _buildMapPeakListDrawerEntries({
  required _PeakListSelectionRefreshInputs inputs,
  required Map<int, _PeakListVisibilityState> visibilityStateByPeakListId,
}) {
  final visiblePeakLists = <MapPeakListDrawerEntry>[];

  for (final peakList in inputs.peakLists) {
    final visibilityState = visibilityStateByPeakListId[peakList.peakListId];
    if (visibilityState == null || !visibilityState.appliesToVisibleRegions) {
      continue;
    }

    final items = visibilityState.items;
    if (items == null || items.isEmpty) {
      continue;
    }

    visiblePeakLists.add(
      MapPeakListDrawerEntry(
        peakList: peakList,
        renderableCount: items.length,
        isPinned: visibilityState.isPinned,
      ),
    );
  }

  visiblePeakLists.sort(
    (left, right) => left.peakList.name.toLowerCase().compareTo(
      right.peakList.name.toLowerCase(),
    ),
  );
  return List<MapPeakListDrawerEntry>.unmodifiable(visiblePeakLists);
}

({
  Map<int, List<PeakOwnershipRingSegment>> activeOwnershipSegments,
  Map<int, int> peakMarkerColours,
})
_buildActiveOwnershipOutputs({
  required _PeakListSelectionRefreshInputs inputs,
  required Map<int, PeakList> peakListsById,
  required Map<int, Peak> peaksById,
  required Set<String> visibleRegionKeys,
  required _PeakListMembershipLookup visibilityLookup,
  required Map<int, _PeakListVisibilityState> visibilityStateByPeakListId,
}) {
  if (inputs.peakListSelectionMode != PeakListSelectionMode.specificList) {
    return (
      activeOwnershipSegments: const <int, List<PeakOwnershipRingSegment>>{},
      peakMarkerColours: const <int, int>{},
    );
  }

  final activeSelectedPeakListIds = visibleRegionKeys.isNotEmpty
      ? {
          for (final peakListId in inputs.selectedPeakListIds)
            if (visibilityStateByPeakListId[peakListId]
                    ?.appliesToVisibleRegions ??
                false)
              peakListId,
        }
      : inputs.selectedPeakListIds.toSet();
  if (activeSelectedPeakListIds.isEmpty) {
    return (
      activeOwnershipSegments: const <int, List<PeakOwnershipRingSegment>>{},
      peakMarkerColours: const <int, int>{},
    );
  }

  final ownersByPeakId = <int, List<_ActivePeakListOwner>>{};
  final sortedPeakListIds = activeSelectedPeakListIds.toList()..sort();
  for (final peakListId in sortedPeakListIds) {
    final peakList = peakListsById[peakListId];
    final items = peakList == null ? null : visibilityLookup.itemsFor(peakList);
    if (peakList == null || items == null) {
      continue;
    }

    final owner = _ActivePeakListOwner(
      peakListId: peakList.peakListId,
      name: peakList.name,
      colourValue: resolvePeakListColour(peakList),
    );
    for (final item in items) {
      ownersByPeakId.putIfAbsent(item.peakOsmId, () => []).add(owner);
    }
  }

  final activeOwnershipSegments = <int, List<PeakOwnershipRingSegment>>{};
  final peakMarkerColours = <int, int>{};
  for (final entry in ownersByPeakId.entries) {
    final orderedOwners = _orderedActivePeakListOwners(
      peak: peaksById[entry.key],
      owners: entry.value,
    );
    if (orderedOwners.isEmpty) {
      continue;
    }

    activeOwnershipSegments[entry.key] =
        List<PeakOwnershipRingSegment>.unmodifiable([
          for (final owner in orderedOwners)
            PeakOwnershipRingSegment(
              peakListId: owner.peakListId,
              colourValue: owner.colourValue,
            ),
        ]);
    peakMarkerColours[entry.key] = orderedOwners.first.colourValue;
  }

  return (
    activeOwnershipSegments:
        Map<int, List<PeakOwnershipRingSegment>>.unmodifiable(
          activeOwnershipSegments,
        ),
    peakMarkerColours: Map<int, int>.unmodifiable(peakMarkerColours),
  );
}

class _PeakListMembershipLookup {
  _PeakListMembershipLookup({required this.repo});

  final PeakListRepository repo;
  final Map<int, List<PeakListItem>?> _itemsByPeakListId = {};

  List<PeakListItem> itemsOrEmpty(PeakList peakList) {
    return itemsFor(peakList) ?? const <PeakListItem>[];
  }

  List<PeakListItem>? itemsFor(PeakList peakList) {
    return _itemsByPeakListId.putIfAbsent(peakList.peakListId, () {
      try {
        return repo.getPeakListItemsForList(peakList.peakListId);
      } catch (error, stackTrace) {
        developer.log(
          'Failed to load membership for peak list ${peakList.peakListId}.',
          error: error,
          stackTrace: stackTrace,
          name: 'peak_list_selection_provider',
        );
        return null;
      }
    });
  }
}

Map<int, _PeakListVisibilityState> _buildPeakListVisibilityStateByPeakListId({
  required _PeakListSelectionRefreshInputs inputs,
  required Set<String> visibleRegionKeys,
  required Map<int, String?> peakRegionKeysByOsmId,
  required _PeakListMembershipLookup visibilityLookup,
}) {
  final states = <int, _PeakListVisibilityState>{};

  for (final peakList in inputs.peakLists) {
    final items = visibilityLookup.itemsFor(peakList);
    final appliesToVisibleRegions = peakListAppliesToVisibleRegions(
      peakList,
      visibleRegionKeys,
      visibleBounds: inputs.visibleBounds,
      peaks: inputs.peaks,
      peakRegionKeysByOsmId: peakRegionKeysByOsmId,
      itemsLoader: visibilityLookup.itemsOrEmpty,
    );
    final isPinned = peakListIsPinned(
      peakList: peakList,
      pinnedPeakListIdsByRegion: inputs.pinnedPeakListIdsByRegion,
      peaks: inputs.peaks,
      peakRegionKeysByOsmId: peakRegionKeysByOsmId,
      itemsLoader: visibilityLookup.itemsOrEmpty,
    );

    states[peakList.peakListId] = _PeakListVisibilityState(
      items: items,
      appliesToVisibleRegions: appliesToVisibleRegions,
      isPinned: isPinned,
    );
  }

  return Map<int, _PeakListVisibilityState>.unmodifiable(states);
}

class _PeakListVisibilityState {
  const _PeakListVisibilityState({
    required this.items,
    required this.appliesToVisibleRegions,
    required this.isPinned,
  });

  final List<PeakListItem>? items;
  final bool appliesToVisibleRegions;
  final bool isPinned;
}

List<Peak> _filterSpecificListPeaks({
  required PeakListRepository repo,
  required List<Peak> peaks,
  required Set<int> peakListIds,
}) {
  if (peakListIds.isEmpty) {
    return const [];
  }

  final selectedPeakOsmIds = <int>{};
  var resolvedListCount = 0;
  for (final peakListId in peakListIds) {
    try {
      final items = repo.getPeakListItemsForList(peakListId);
      selectedPeakOsmIds.addAll(items.map((item) => item.peakOsmId));
      resolvedListCount += 1;
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load selected peak list $peakListId.',
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
    this.colourValue,
  });

  const PeakListSelectionChip.allPeaks() : this._(label: 'All Peaks');

  const PeakListSelectionChip.none() : this._(label: 'None');

  const PeakListSelectionChip.list({
    required int peakListId,
    required String label,
    required String? regionKey,
    required bool isSelected,
    required bool isPinned,
    required int? colourValue,
  }) : this._(
         label: label,
         peakListId: peakListId,
         regionKey: regionKey,
         isSelected: isSelected,
         isPinned: isPinned,
         colourValue: colourValue,
       );

  final String label;
  final int? peakListId;
  final String? regionKey;
  final bool isSelected;
  final bool isPinned;
  final int? colourValue;

  bool get isAllPeaks => peakListId == null && label == 'All Peaks';

  bool get isNone => peakListId == null && label == 'None';
}

List<_ActivePeakListOwner> _orderedActivePeakListOwners({
  required Peak? peak,
  required List<_ActivePeakListOwner> owners,
}) {
  final orderedOwners = owners.toList(growable: false);
  orderedOwners.sort((left, right) {
    final leftPriority = _peakOwnershipPriority(peak: peak, owner: left);
    final rightPriority = _peakOwnershipPriority(peak: peak, owner: right);
    if (leftPriority != rightPriority) {
      return leftPriority.compareTo(rightPriority);
    }
    return left.peakListId.compareTo(right.peakListId);
  });
  return orderedOwners;
}

int _peakOwnershipPriority({
  required Peak? peak,
  required _ActivePeakListOwner owner,
}) {
  if (peak == null ||
      canonicalRegionKey(normalizePeakListRegionKey(peak.region)) !=
          Peak.defaultRegion) {
    return owner.peakListId;
  }

  return _tasmaniaPeakOwnershipPriority[owner.name.trim().toLowerCase()] ??
      (_tasmaniaPeakOwnershipPriority.length + owner.peakListId);
}

class _ActivePeakListOwner {
  const _ActivePeakListOwner({
    required this.peakListId,
    required this.name,
    required this.colourValue,
  });

  final int peakListId;
  final String name;
  final int colourValue;
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
