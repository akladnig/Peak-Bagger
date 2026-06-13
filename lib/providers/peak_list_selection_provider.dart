import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';

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
  final peakListSelectionMode = ref.watch(
    mapProvider.select((state) => state.peakListSelectionMode),
  );
  final selectedPeakListIds = ref.watch(
    mapProvider.select((state) => state.selectedPeakListIds),
  );
  final peakLists = ref.watch(peakListsProvider);
  final labelsById = {
    for (final peakList in peakLists) peakList.peakListId: peakList.name,
  };

  return switch (peakListSelectionMode) {
    PeakListSelectionMode.none => const PeakListSelectionSummary(
      chips: [PeakListSelectionChip.none()],
    ),
    PeakListSelectionMode.allPeaks => const PeakListSelectionSummary(
      chips: [PeakListSelectionChip.allPeaks()],
    ),
    PeakListSelectionMode.specificList => PeakListSelectionSummary(
      chips:
          [
            for (final peakListId in selectedPeakListIds)
              PeakListSelectionChip.list(
                peakListId: peakListId,
                label: labelsById[peakListId] ?? 'List #$peakListId',
              ),
          ]..sort((left, right) {
            return left.label.toLowerCase().compareTo(
              right.label.toLowerCase(),
            );
          }),
    ),
  };
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
  const PeakListSelectionChip._({required this.label, this.peakListId});

  const PeakListSelectionChip.allPeaks() : this._(label: 'All Peaks');

  const PeakListSelectionChip.none() : this._(label: 'None');

  const PeakListSelectionChip.list({
    required int peakListId,
    required String label,
  }) : this._(label: label, peakListId: peakListId);

  final String label;
  final int? peakListId;

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
