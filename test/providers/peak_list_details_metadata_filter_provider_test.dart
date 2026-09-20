import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/peak_list_details_metadata_filter_provider.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';

void main() {
  test(
    'metadata filter state owns popup visibility and selection semantics',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        peakListDetailsMetadataFilterProvider.notifier,
      );

      notifier.openPopup();
      notifier.setRatingFilter(PeakRatingFilterOption.atLeast4_5);
      notifier.setDifficultyFilter(
        const PeakDifficultyFilterOption(region: 'fvg', difficulty: 'T'),
      );
      notifier.setDurationFilter(PeakDurationFilterOption.upTo4Hours);

      final activeState = container.read(peakListDetailsMetadataFilterProvider);
      expect(activeState.isPopupVisible, isTrue);
      expect(activeState.activeFilterCount, 3);
      expect(activeState.hasActiveFilters, isTrue);
      expect(
        activeState.matchesPeak(
          Peak(
            osmId: 1,
            name: 'Match',
            latitude: 46.2,
            longitude: 13.2,
            rating: 4.8,
            difficulty: 'T',
            durationMinutes: 180,
            region: 'fvg',
          ),
        ),
        isTrue,
      );
      expect(
        activeState.matchesPeak(
          Peak(
            osmId: 2,
            name: 'Does not match',
            latitude: 46.3,
            longitude: 13.3,
            rating: 4.2,
            difficulty: 'T',
            durationMinutes: 180,
            region: 'fvg',
          ),
        ),
        isFalse,
      );

      notifier.clearFilters();

      final clearedState = container.read(
        peakListDetailsMetadataFilterProvider,
      );
      expect(clearedState.isPopupVisible, isTrue);
      expect(clearedState.activeFilterCount, 0);
      expect(clearedState.hasActiveFilters, isFalse);
    },
  );

  test('difficulty options reuse the selected peaks metadata contract', () {
    const state = PeakListDetailsMetadataFilterState();

    expect(
      state.difficultyOptionsFor([
        Peak(
          osmId: 1,
          name: 'FVG T',
          latitude: 46.2,
          longitude: 13.2,
          difficulty: 'T',
          region: 'fvg',
        ),
        Peak(
          osmId: 2,
          name: 'Tas Hard',
          latitude: -42.0,
          longitude: 146.0,
          difficulty: 'Hard',
          region: 'tasmania',
        ),
      ]),
      const [
        PeakDifficultyFilterOption(region: 'fvg', difficulty: 'T'),
        PeakDifficultyFilterOption(region: 'tasmania', difficulty: 'Hard'),
      ],
    );
  });
}
