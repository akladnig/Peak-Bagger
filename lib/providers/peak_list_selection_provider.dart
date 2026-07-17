import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peak_ownership_ring_segment.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_ownership_ring_settings_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';
import 'package:peak_bagger/services/fab_colour_resolver.dart';
import 'package:peak_bagger/services/peak_list_visibility.dart';

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
  final peaks = ref.watch(mapProvider.select((state) => state.peaks));
  final visibleRegionKeys = visibleRegionKeysForBounds(visibleBounds);
  final hasResolvedVisibleBounds = visibleBounds != null;
  if (hasResolvedVisibleBounds && visibleRegionKeys.isEmpty) {
    return const PeakListSelectionSummary(chips: []);
  }
  final labelsById = {
    for (final peakList in peakLists) peakList.peakListId: peakList.name,
  };
  final peakListsById = {
    for (final peakList in peakLists) peakList.peakListId: peakList,
  };
  final regionKeysById = {
    for (final peakList in peakLists)
      peakList.peakListId: canonicalRegionKey(
        normalizePeakListRegionKey(peakList.region),
      ),
  };
  final visiblePinnedPeakListIds = {
    for (final peakList in peakLists)
      if ((!hasResolvedVisibleBounds ||
              peakListAppliesToVisibleRegions(
                peakList,
                visibleRegionKeys,
                visibleBounds: visibleBounds,
                peaks: peaks,
              )) &&
          peakListIsPinned(
            peakList: peakList,
            pinnedPeakListIdsByRegion: pinnedPeakListIdsByRegion,
            peaks: peaks,
          ))
        peakList.peakListId,
  };
  final visibleSelectedPeakListIds = hasResolvedVisibleBounds
      ? {
          for (final peakListId in selectedPeakListIds)
            if (() {
              final peakList = peakListsById[peakListId];
              return peakList != null &&
                  peakListAppliesToVisibleRegions(
                    peakList,
                    visibleRegionKeys,
                    visibleBounds: visibleBounds,
                    peaks: peaks,
                  );
            }())
              peakListId,
        }
      : selectedPeakListIds.toSet();
  final visibleSpecificPeakListIds =
      {...visiblePinnedPeakListIds, ...visibleSelectedPeakListIds}.toList()
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
      () {
        final peakList = peakListsById[peakListId];
        final usesNeutralStyle =
            peakList != null && !_isReadablePeakList(peakList);
        return PeakListSelectionChip.list(
          peakListId: peakListId,
          label: labelsById[peakListId] ?? 'List #$peakListId',
          regionKey: regionKeysById[peakListId],
          isSelected: visibleSelectedPeakListIds.contains(peakListId),
          isPinned: visiblePinnedPeakListIds.contains(peakListId),
          colourValue: usesNeutralStyle || peakList == null
              ? null
              : resolvePeakListColour(peakList),
          usesNeutralStyle: usesNeutralStyle,
        );
      }(),
  ];

  return PeakListSelectionSummary(chips: chips);
});

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

final mapDifficultyFilterOptionsProvider =
    Provider<List<PeakDifficultyFilterOption>>((ref) {
      final peaks = ref.watch(mapMetadataFilterScopePeaksProvider);
      return buildPeakDifficultyFilterOptions(peaks);
    });

final _activePeakListOwnersByPeakIdProvider =
    Provider<Map<int, List<_ActivePeakListOwner>>>((ref) {
      final peakListSelectionMode = ref.watch(
        mapProvider.select((state) => state.peakListSelectionMode),
      );
      if (peakListSelectionMode != PeakListSelectionMode.specificList) {
        return const <int, List<_ActivePeakListOwner>>{};
      }

      final (:selectedPeakListIds, :visibleBounds) = ref.watch(
        mapProvider.select(
          (state) => (
            selectedPeakListIds: state.selectedPeakListIds,
            visibleBounds: state.visibleBounds,
          ),
        ),
      );
      final peakLists = ref.watch(peakListsProvider);
      final peaks = ref.watch(mapProvider.select((state) => state.peaks));
      final visibleRegionKeys = visibleBounds == null
          ? const <String>{}
          : visibleRegionKeysForBounds(visibleBounds);
      final activeSelectedPeakListIds = visibleRegionKeys.isNotEmpty
          ? renderablePeakListIdsForVisibleRegions(
              peakLists: peakLists,
              selectedPeakListIds: selectedPeakListIds,
              visibleRegionKeys: visibleRegionKeys,
              visibleBounds: visibleBounds,
              peaks: peaks,
            )
          : selectedPeakListIds.toSet();
      if (activeSelectedPeakListIds.isEmpty) {
        return const <int, List<_ActivePeakListOwner>>{};
      }

      final ownersByPeakId = <int, List<_ActivePeakListOwner>>{};
      final sortedPeakListIds = activeSelectedPeakListIds.toList()..sort();
      for (final peakListId in sortedPeakListIds) {
        PeakList? peakList;
        for (final candidate in peakLists) {
          if (candidate.peakListId == peakListId) {
            peakList = candidate;
            break;
          }
        }
        if (peakList == null || !_isReadablePeakList(peakList)) {
          continue;
        }

        final owner = _ActivePeakListOwner(
          peakListId: peakList.peakListId,
          name: peakList.name,
          colourValue: resolvePeakListColour(peakList),
        );
        for (final item in decodePeakListItems(peakList.peakList)) {
          ownersByPeakId.putIfAbsent(item.peakOsmId, () => []).add(owner);
        }
      }

      return Map<int, List<_ActivePeakListOwner>>.unmodifiable({
        for (final entry in ownersByPeakId.entries)
          entry.key: List<_ActivePeakListOwner>.unmodifiable(entry.value),
      });
    });

final peakActiveOwnershipSegmentsProvider =
    Provider<Map<int, List<PeakOwnershipRingSegment>>>((ref) {
      final peaks = ref.watch(mapProvider.select((state) => state.peaks));
      final peaksById = {for (final peak in peaks) peak.osmId: peak};
      final ownersByPeakId = ref.watch(_activePeakListOwnersByPeakIdProvider);
      final segmentsByPeakId = <int, List<PeakOwnershipRingSegment>>{};

      for (final entry in ownersByPeakId.entries) {
        final orderedOwners = _orderedActivePeakListOwners(
          peak: peaksById[entry.key],
          owners: entry.value,
        );
        if (orderedOwners.isEmpty) {
          continue;
        }

        segmentsByPeakId[entry.key] =
            List<PeakOwnershipRingSegment>.unmodifiable([
              for (final owner in orderedOwners)
                PeakOwnershipRingSegment(
                  peakListId: owner.peakListId,
                  colourValue: owner.colourValue,
                ),
            ]);
      }

      return Map<int, List<PeakOwnershipRingSegment>>.unmodifiable(
        segmentsByPeakId,
      );
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
  final peaks = ref.watch(mapProvider.select((state) => state.peaks));
  final peaksById = {for (final peak in peaks) peak.osmId: peak};
  final ownersByPeakId = ref.watch(_activePeakListOwnersByPeakIdProvider);
  final coloursByPeakId = <int, int>{};

  for (final entry in ownersByPeakId.entries) {
    final peak = peaksById[entry.key];
    final orderedOwners = _orderedActivePeakListOwners(
      peak: peak,
      owners: entry.value,
    );
    if (orderedOwners.isEmpty) {
      continue;
    }

    coloursByPeakId[entry.key] = orderedOwners.first.colourValue;
  }

  return Map<int, int>.unmodifiable(coloursByPeakId);
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
    this.colourValue,
    this.usesNeutralStyle = false,
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
    required bool usesNeutralStyle,
  }) : this._(
         label: label,
         peakListId: peakListId,
         regionKey: regionKey,
         isSelected: isSelected,
         isPinned: isPinned,
         colourValue: colourValue,
         usesNeutralStyle: usesNeutralStyle,
       );

  final String label;
  final int? peakListId;
  final String? regionKey;
  final bool isSelected;
  final bool isPinned;
  final int? colourValue;
  final bool usesNeutralStyle;

  bool get isAllPeaks => peakListId == null && label == 'All Peaks';

  bool get isNone => peakListId == null && label == 'None';
}

bool _isReadablePeakList(PeakList peakList) {
  try {
    decodePeakListItems(peakList.peakList);
    return true;
  } catch (_) {
    return false;
  }
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
