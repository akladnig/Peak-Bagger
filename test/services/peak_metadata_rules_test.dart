import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';

void main() {
  group('parsePeakDuration', () {
    test('parses exact clock values and preserves labels', () {
      expect(parsePeakDuration('0:15')?.durationMinutes, 15);
      expect(parsePeakDuration('4:15')?.durationMinutes, 255);
      expect(parsePeakDuration('4:15')?.durationLabel, '4:15');
    });

    test('parses hour and day ranges using the upper bound', () {
      expect(parsePeakDuration('4-5 hours')?.durationMinutes, 300);
      expect(parsePeakDuration('1-1 hour')?.durationMinutes, 60);
      expect(parsePeakDuration('2-3 days')?.durationMinutes, 4320);
      expect(parsePeakDuration('20-20 days')?.durationMinutes, 28800);
    });

    test('treats blank values as missing duration', () {
      expect(parsePeakDuration(''), isNull);
      expect(parsePeakDuration('   '), isNull);
    });

    test('rejects invalid duration text', () {
      expect(() => parsePeakDuration('04:15'), throwsFormatException);
      expect(() => parsePeakDuration('4 hours'), throwsFormatException);
      expect(() => parsePeakDuration('5-4 hours'), throwsFormatException);
      expect(() => parsePeakDuration('about 2 days'), throwsFormatException);
    });
  });

  group('formatPeakDurationMinutes', () {
    test('formats missing, hour, and day durations', () {
      expect(formatPeakDurationMinutes(null), '');
      expect(formatPeakDurationMinutes(15), '0:15');
      expect(formatPeakDurationMinutes(255), '4:15');
      expect(formatPeakDurationMinutes(2880), '2 days');
    });

    test('uses a stored label before a numeric fallback', () {
      expect(
        peakDurationDisplayLabel(
          Peak(
            name: 'Mount Anne',
            latitude: -41.5,
            longitude: 146.5,
            durationMinutes: 300,
            durationLabel: '4-5 hours',
          ),
        ),
        '4-5 hours',
      );
      expect(
        peakDurationDisplayLabel(
          Peak(
            name: 'Mount Anne',
            latitude: -41.5,
            longitude: 146.5,
            durationMinutes: 300,
          ),
        ),
        '5:00',
      );
    });
  });

  group('roundPeakRatingForDisplay', () {
    test('rounds to the nearest half star without changing nulls', () {
      expect(roundPeakRatingForDisplay(null), isNull);
      expect(roundPeakRatingForDisplay(4.24), 4.0);
      expect(roundPeakRatingForDisplay(4.25), 4.5);
      expect(roundPeakRatingForDisplay(4.74), 4.5);
      expect(roundPeakRatingForDisplay(4.75), 5.0);
    });
  });

  group('peakMatchesRatingFilter', () {
    test('uses inclusive threshold matching and excludes missing ratings', () {
      final ratedPeak = Peak(
        name: 'Rated Peak',
        latitude: -41.5,
        longitude: 146.5,
        rating: 4.2,
      );
      final lowRatedPeak = Peak(
        name: 'Low Rated Peak',
        latitude: -41.5,
        longitude: 146.5,
        rating: 3.9,
      );
      final unratedPeak = Peak(
        name: 'Unrated Peak',
        latitude: -41.5,
        longitude: 146.5,
      );

      expect(
        peakMatchesRatingFilter(unratedPeak, PeakRatingFilterOption.any),
        isTrue,
      );
      expect(
        peakMatchesRatingFilter(ratedPeak, PeakRatingFilterOption.atLeast4),
        isTrue,
      );
      expect(
        peakMatchesRatingFilter(lowRatedPeak, PeakRatingFilterOption.atLeast4),
        isFalse,
      );
      expect(
        peakMatchesRatingFilter(unratedPeak, PeakRatingFilterOption.atLeast4),
        isFalse,
      );
    });
  });

  group('peakMatchesDurationFilter', () {
    test('supports the fixed duration thresholds and excludes missing values', () {
      final fourHourPeak = Peak(
        name: 'Four Hour Peak',
        latitude: -41.5,
        longitude: 146.5,
        durationMinutes: 240,
      );
      final longPeak = Peak(
        name: 'Long Peak',
        latitude: -41.5,
        longitude: 146.5,
        durationMinutes: 3000,
      );
      final missingPeak = Peak(
        name: 'Missing Peak',
        latitude: -41.5,
        longitude: 146.5,
      );

      expect(
        peakMatchesDurationFilter(missingPeak, PeakDurationFilterOption.any),
        isTrue,
      );
      expect(
        peakMatchesDurationFilter(
          fourHourPeak,
          PeakDurationFilterOption.upTo4Hours,
        ),
        isTrue,
      );
      expect(
        peakMatchesDurationFilter(longPeak, PeakDurationFilterOption.upTo4Hours),
        isFalse,
      );
      expect(
        peakMatchesDurationFilter(longPeak, PeakDurationFilterOption.atLeast2Days),
        isTrue,
      );
      expect(
        peakMatchesDurationFilter(
          missingPeak,
          PeakDurationFilterOption.atLeast2Days,
        ),
        isFalse,
      );
    });
  });

  group('difficulty ordering and filtering', () {
    test('keeps configured ladders region-aware and falls back alphabetically', () {
      final tasmaniaPeaks = [
        Peak(
          name: 'Hard Peak',
          latitude: -41.5,
          longitude: 146.5,
          region: 'tasmania',
          difficulty: 'Hard',
        ),
        Peak(
          name: 'Easy Peak',
          latitude: -41.5,
          longitude: 146.5,
          region: 'tasmania',
          difficulty: 'Easy',
        ),
      ]..sort(comparePeaksByDifficulty);

      final fallbackPeaks = [
        Peak(
          name: 'Beta Peak',
          latitude: -41.5,
          longitude: 146.5,
          region: 'andes',
          difficulty: 'Beta',
        ),
        Peak(
          name: 'Alpha Peak',
          latitude: -41.5,
          longitude: 146.5,
          region: 'andes',
          difficulty: 'Alpha',
        ),
      ]..sort(comparePeaksByDifficulty);

      expect(tasmaniaPeaks.map((peak) => peak.difficulty), ['Easy', 'Hard']);
      expect(fallbackPeaks.map((peak) => peak.difficulty), ['Alpha', 'Beta']);
    });

    test('sorts mixed regions by region, difficulty, then name', () {
      final peaks = [
        Peak(
          name: 'Tasmania Hard',
          latitude: -41.5,
          longitude: 146.5,
          region: 'tasmania',
          difficulty: 'Hard',
        ),
        Peak(
          name: 'Croatia T2',
          latitude: 45.0,
          longitude: 15.0,
          region: 'croatia',
          difficulty: 'T2',
        ),
        Peak(
          name: 'Tasmania Easy',
          latitude: -41.5,
          longitude: 146.5,
          region: 'tasmania',
          difficulty: 'Easy',
        ),
        Peak(
          name: 'FVG T',
          latitude: 46.2,
          longitude: 13.2,
          region: 'fvg',
          difficulty: 'T',
        ),
      ]..sort(comparePeaksByDifficulty);

      expect(
        peaks.map((peak) => '${peak.region}:${peak.difficulty}:${peak.name}'),
        [
          'croatia:T2:Croatia T2',
          'fvg:T:FVG T',
          'tasmania:Easy:Tasmania Easy',
          'tasmania:Hard:Tasmania Hard',
        ],
      );
    });

    test('builds exact region+difficulty filter options and matches one pair', () {
      final peaks = [
        Peak(
          name: 'FVG Peak',
          latitude: 46.2,
          longitude: 13.2,
          region: 'fvg',
          difficulty: 'EE',
        ),
        Peak(
          name: 'Veneto Peak',
          latitude: 45.8,
          longitude: 11.8,
          region: 'veneto',
          difficulty: 'EE',
        ),
        Peak(
          name: 'Slovenia Peak',
          latitude: 46.4,
          longitude: 14.5,
          region: 'slovenia',
          difficulty: 'T4',
        ),
        Peak(
          name: 'Blank Peak',
          latitude: -41.5,
          longitude: 146.5,
          region: 'tasmania',
        ),
      ];

      final options = buildPeakDifficultyFilterOptions(peaks);
      final fvgOption = options.firstWhere(
        (option) => option.region == 'fvg' && option.difficulty == 'EE',
      );

      expect(
        options,
        containsAll([
          const PeakDifficultyFilterOption(region: 'fvg', difficulty: 'EE'),
          const PeakDifficultyFilterOption(region: 'slovenia', difficulty: 'T4'),
          const PeakDifficultyFilterOption(region: 'veneto', difficulty: 'EE'),
        ]),
      );
      expect(peakMatchesDifficultyFilter(peaks[0], fvgOption), isTrue);
      expect(peakMatchesDifficultyFilter(peaks[1], fvgOption), isFalse);
      expect(peakMatchesDifficultyFilter(peaks[3], fvgOption), isFalse);
    });
  });
}
