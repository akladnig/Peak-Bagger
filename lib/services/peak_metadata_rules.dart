import '../models/peak.dart';

class ParsedPeakDuration {
  const ParsedPeakDuration({
    required this.durationMinutes,
    required this.durationLabel,
  });

  final int durationMinutes;
  final String durationLabel;
}

enum PeakRatingFilterOption {
  any(label: 'Any'),
  atLeast3(threshold: 3.0, label: '3.0'),
  atLeast3_5(threshold: 3.5, label: '3.5'),
  atLeast4(threshold: 4.0, label: '4.0'),
  atLeast4_5(threshold: 4.5, label: '4.5');

  const PeakRatingFilterOption({this.threshold, required this.label});

  final double? threshold;
  final String label;
}

enum PeakDurationFilterOption {
  any(label: 'Any'),
  upTo4Hours(thresholdMinutes: 240, label: '4h'),
  upTo8Hours(thresholdMinutes: 480, label: '8h'),
  upTo12Hours(thresholdMinutes: 720, label: '12h'),
  upTo2Days(thresholdMinutes: 2880, label: '2d'),
  upTo5Days(thresholdMinutes: 7200, label: '5d'),
  upTo10Days(thresholdMinutes: 14400, label: '10d'),
  atLeast2Days(thresholdMinutes: 2880, label: '2d+');

  const PeakDurationFilterOption({this.thresholdMinutes, required this.label});

  final int? thresholdMinutes;
  final String label;
}

class PeakDifficultyFilterOption {
  const PeakDifficultyFilterOption({
    required this.region,
    required this.difficulty,
  });

  final String region;
  final String difficulty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PeakDifficultyFilterOption &&
        other.region == region &&
        other.difficulty == difficulty;
  }

  @override
  int get hashCode => Object.hash(region, difficulty);
}

ParsedPeakDuration? parsePeakDuration(String rawValue) {
  final trimmedValue = rawValue.trim();
  if (trimmedValue.isEmpty) {
    return null;
  }

  final clockMatch = _clockDurationPattern.firstMatch(trimmedValue);
  if (clockMatch != null) {
    final hours = int.parse(clockMatch.group(1)!);
    final minutes = int.parse(clockMatch.group(2)!);
    return ParsedPeakDuration(
      durationMinutes: (hours * 60) + minutes,
      durationLabel: trimmedValue,
    );
  }

  final hourRangeMatch = _hourRangeDurationPattern.firstMatch(trimmedValue);
  if (hourRangeMatch != null) {
    return _parseDurationRange(
      match: hourRangeMatch,
      rawValue: trimmedValue,
      minutesPerUnit: Duration.minutesPerHour,
    );
  }

  final dayRangeMatch = _dayRangeDurationPattern.firstMatch(trimmedValue);
  if (dayRangeMatch != null) {
    return _parseDurationRange(
      match: dayRangeMatch,
      rawValue: trimmedValue,
      minutesPerUnit: Duration.minutesPerDay,
    );
  }

  final exactDayMatch = _exactDayDurationPattern.firstMatch(trimmedValue);
  if (exactDayMatch != null) {
    return _parseExactDayDuration(match: exactDayMatch, rawValue: trimmedValue);
  }

  throw FormatException(_invalidPeakDurationMessage(trimmedValue));
}

String formatPeakDurationMinutes(int? durationMinutes) {
  if (durationMinutes == null) {
    return '';
  }

  if (durationMinutes >= Duration.minutesPerDay &&
      durationMinutes % Duration.minutesPerDay == 0) {
    final dayCount = durationMinutes ~/ Duration.minutesPerDay;
    final unit = dayCount == 1 ? 'day' : 'days';
    return '$dayCount $unit';
  }

  final hours = durationMinutes ~/ Duration.minutesPerHour;
  final minutes = durationMinutes % Duration.minutesPerHour;
  return '$hours:${minutes.toString().padLeft(2, '0')}';
}

String peakDurationDisplayLabel(Peak peak) {
  final trimmedLabel = peak.durationLabel.trim();
  if (trimmedLabel.isNotEmpty) {
    return trimmedLabel;
  }

  return formatPeakDurationMinutes(peak.durationMinutes);
}

double? roundPeakRatingForDisplay(double? rating) {
  if (rating == null) {
    return null;
  }

  return (rating * 2).round() / 2;
}

bool peakMatchesRatingFilter(Peak peak, PeakRatingFilterOption filter) {
  if (filter == PeakRatingFilterOption.any) {
    return true;
  }

  final rating = peak.rating;
  return rating != null && rating >= filter.threshold!;
}

bool peakMatchesDurationFilter(Peak peak, PeakDurationFilterOption filter) {
  if (filter == PeakDurationFilterOption.any) {
    return true;
  }

  final durationMinutes = peak.durationMinutes;
  if (durationMinutes == null) {
    return false;
  }

  return switch (filter) {
    PeakDurationFilterOption.atLeast2Days =>
      durationMinutes >= filter.thresholdMinutes!,
    PeakDurationFilterOption.any => true,
    _ => durationMinutes <= filter.thresholdMinutes!,
  };
}

int comparePeaksByDifficulty(Peak left, Peak right) {
  final regionComparison = _compareRegionKeys(left.region, right.region);
  if (regionComparison != 0) {
    return regionComparison;
  }

  final difficultyComparison = _compareDifficultyValues(
    region: _normalizeRegion(left.region),
    left: left.difficulty,
    right: right.difficulty,
  );
  if (difficultyComparison != 0) {
    return difficultyComparison;
  }

  return _compareText(left.name, right.name);
}

List<PeakDifficultyFilterOption> buildPeakDifficultyFilterOptions(
  Iterable<Peak> peaks,
) {
  final difficultiesByRegion = <String, Set<String>>{};
  for (final peak in peaks) {
    final region = _normalizeRegion(peak.region);
    final difficulty = peak.difficulty.trim();
    if (difficulty.isEmpty) {
      continue;
    }
    difficultiesByRegion.putIfAbsent(region, () => <String>{}).add(difficulty);
  }

  final regions = difficultiesByRegion.keys.toList(growable: false)
    ..sort(_compareNormalizedRegionKeys);

  final options = <PeakDifficultyFilterOption>[];
  for (final region in regions) {
    final difficulties = difficultiesByRegion[region]!.toList(growable: false)
      ..sort((left, right) {
        return _compareDifficultyValues(
          region: region,
          left: left,
          right: right,
        );
      });
    options.addAll(
      difficulties.map(
        (difficulty) =>
            PeakDifficultyFilterOption(region: region, difficulty: difficulty),
      ),
    );
  }

  return options;
}

bool peakMatchesDifficultyFilter(
  Peak peak,
  PeakDifficultyFilterOption? filter,
) {
  if (filter == null) {
    return true;
  }

  return _normalizeRegion(peak.region) == filter.region &&
      peak.difficulty.trim() == filter.difficulty;
}

ParsedPeakDuration _parseDurationRange({
  required RegExpMatch match,
  required String rawValue,
  required int minutesPerUnit,
}) {
  final lowerBound = int.parse(match.group(1)!);
  final upperBound = int.parse(match.group(2)!);
  if (upperBound < lowerBound) {
    throw FormatException(
      'Invalid peak duration "$rawValue". Expected the upper bound to be '
      'greater than or equal to the lower bound.',
    );
  }

  return ParsedPeakDuration(
    durationMinutes: upperBound * minutesPerUnit,
    durationLabel: rawValue,
  );
}

ParsedPeakDuration _parseExactDayDuration({
  required RegExpMatch match,
  required String rawValue,
}) {
  final dayCount = int.parse(match.group(1)!);
  final unit = match.group(2)!;
  final isValidSingular = dayCount == 1 && unit == 'day';
  final isValidPlural = dayCount > 1 && unit == 'days';
  if (!isValidSingular && !isValidPlural) {
    throw FormatException(_invalidPeakDurationMessage(rawValue));
  }

  return ParsedPeakDuration(
    durationMinutes: dayCount * Duration.minutesPerDay,
    durationLabel: rawValue,
  );
}

int _compareRegionKeys(String? left, String? right) {
  return _compareNormalizedRegionKeys(
    _normalizeRegion(left),
    _normalizeRegion(right),
  );
}

int _compareNormalizedRegionKeys(String left, String right) {
  if (left.isEmpty && right.isEmpty) {
    return 0;
  }
  if (left.isEmpty) {
    return 1;
  }
  if (right.isEmpty) {
    return -1;
  }
  return left.compareTo(right);
}

int _compareDifficultyValues({
  required String region,
  required String left,
  required String right,
}) {
  final trimmedLeft = left.trim();
  final trimmedRight = right.trim();

  if (trimmedLeft.isEmpty && trimmedRight.isEmpty) {
    return 0;
  }
  if (trimmedLeft.isEmpty) {
    return 1;
  }
  if (trimmedRight.isEmpty) {
    return -1;
  }

  final ladder = _difficultyLadders[region];
  if (ladder != null) {
    final leftIndex = ladder.indexOf(trimmedLeft.toLowerCase());
    final rightIndex = ladder.indexOf(trimmedRight.toLowerCase());
    if (leftIndex >= 0 && rightIndex >= 0) {
      return leftIndex.compareTo(rightIndex);
    }
    if (leftIndex >= 0) {
      return -1;
    }
    if (rightIndex >= 0) {
      return 1;
    }
  }

  return _compareText(trimmedLeft, trimmedRight);
}

int _compareText(String left, String right) {
  final leftLower = left.toLowerCase();
  final rightLower = right.toLowerCase();
  final comparison = leftLower.compareTo(rightLower);
  if (comparison != 0) {
    return comparison;
  }
  return left.compareTo(right);
}

String _normalizeRegion(String? region) {
  return region?.trim().toLowerCase() ?? '';
}

String _invalidPeakDurationMessage(String rawValue) {
  return 'Invalid peak duration "$rawValue". Expected H:MM, '
      '<int>-<int> hour(s), <int>-<int> day(s), 1 day, or <int> days.';
}

final _clockDurationPattern = RegExp(r'^(0|[1-9]\d*):([0-5]\d)$');
final _hourRangeDurationPattern = RegExp(r'^(\d+)-(\d+) hours?$');
final _dayRangeDurationPattern = RegExp(r'^(\d+)-(\d+) days?$');
final _exactDayDurationPattern = RegExp(r'^(\d+) (day|days)$');

final _difficultyLadders = <String, List<String>>{
  'tasmania': ['easy', 'medium', 'hard', 'very hard'],
  'fvg': ['t', 'e', 'ee', 'eea', 'eai'],
  'veneto': ['t', 'e', 'ee', 'eea', 'eai'],
  'friuli venezia giulia': ['t', 'e', 'ee', 'eea', 'eai'],
  'slovenia': ['t1', 't2', 't3', 't4', 't5', 't6'],
  'croatia': ['t1', 't2', 't3', 't4', 't5', 't6'],
};
