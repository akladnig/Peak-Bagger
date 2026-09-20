import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';

final peakListDetailsMetadataFilterProvider =
    NotifierProvider<
      PeakListDetailsMetadataFilterNotifier,
      PeakListDetailsMetadataFilterState
    >(PeakListDetailsMetadataFilterNotifier.new);

class PeakListDetailsMetadataFilterState {
  const PeakListDetailsMetadataFilterState({
    this.isPopupVisible = false,
    this.ratingFilter = PeakRatingFilterOption.any,
    this.difficultyFilter,
    this.durationFilter = PeakDurationFilterOption.any,
  });

  final bool isPopupVisible;
  final PeakRatingFilterOption ratingFilter;
  final PeakDifficultyFilterOption? difficultyFilter;
  final PeakDurationFilterOption durationFilter;

  int get activeFilterCount {
    var count = 0;
    if (ratingFilter != PeakRatingFilterOption.any) {
      count += 1;
    }
    if (difficultyFilter != null) {
      count += 1;
    }
    if (durationFilter != PeakDurationFilterOption.any) {
      count += 1;
    }
    return count;
  }

  bool get hasActiveFilters => activeFilterCount > 0;

  bool matchesPeak(Peak peak) {
    return peakMatchesRatingFilter(peak, ratingFilter) &&
        peakMatchesDifficultyFilter(peak, difficultyFilter) &&
        peakMatchesDurationFilter(peak, durationFilter);
  }

  List<PeakDifficultyFilterOption> difficultyOptionsFor(Iterable<Peak> peaks) {
    return buildPeakDifficultyFilterOptions(peaks);
  }

  PeakListDetailsMetadataFilterState copyWith({
    bool? isPopupVisible,
    PeakRatingFilterOption? ratingFilter,
    PeakDifficultyFilterOption? difficultyFilter,
    bool clearDifficultyFilter = false,
    PeakDurationFilterOption? durationFilter,
  }) {
    return PeakListDetailsMetadataFilterState(
      isPopupVisible: isPopupVisible ?? this.isPopupVisible,
      ratingFilter: ratingFilter ?? this.ratingFilter,
      difficultyFilter: clearDifficultyFilter
          ? null
          : (difficultyFilter ?? this.difficultyFilter),
      durationFilter: durationFilter ?? this.durationFilter,
    );
  }
}

class PeakListDetailsMetadataFilterNotifier
    extends Notifier<PeakListDetailsMetadataFilterState> {
  @override
  PeakListDetailsMetadataFilterState build() {
    return const PeakListDetailsMetadataFilterState();
  }

  void togglePopup() {
    state = state.copyWith(isPopupVisible: !state.isPopupVisible);
  }

  void openPopup() {
    state = state.copyWith(isPopupVisible: true);
  }

  void closePopup() {
    state = state.copyWith(isPopupVisible: false);
  }

  void setRatingFilter(PeakRatingFilterOption filter) {
    state = state.copyWith(ratingFilter: filter);
  }

  void setDifficultyFilter(PeakDifficultyFilterOption? filter) {
    state = state.copyWith(
      difficultyFilter: filter,
      clearDifficultyFilter: filter == null,
    );
  }

  void setDurationFilter(PeakDurationFilterOption filter) {
    state = state.copyWith(durationFilter: filter);
  }

  void clearFilters() {
    state = state.copyWith(
      ratingFilter: PeakRatingFilterOption.any,
      clearDifficultyFilter: true,
      durationFilter: PeakDurationFilterOption.any,
    );
  }
}
