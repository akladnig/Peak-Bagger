import 'dart:math' as math;

import 'package:peak_bagger/models/gpx_track.dart';

enum SummaryPeriodPreset {
  week,
  month,
  last3Months,
  last6Months,
  last12Months,
  allTime,
}

extension SummaryPeriodPresetLabel on SummaryPeriodPreset {
  String get label => switch (this) {
    SummaryPeriodPreset.week => 'Week',
    SummaryPeriodPreset.month => 'Month',
    SummaryPeriodPreset.last3Months => 'Last 3 Months',
    SummaryPeriodPreset.last6Months => 'Last 6 Months',
    SummaryPeriodPreset.last12Months => 'Last 12 Months',
    SummaryPeriodPreset.allTime => 'All Time',
  };

  String get averageLabel => switch (this) {
    SummaryPeriodPreset.week => 'Daily Avg:',
    SummaryPeriodPreset.month => 'Weekly Avg:',
    SummaryPeriodPreset.last3Months ||
    SummaryPeriodPreset.last6Months ||
    SummaryPeriodPreset.last12Months => 'Monthly Avg:',
    SummaryPeriodPreset.allTime => 'Annual Avg:',
  };
}

class SummaryBucket {
  const SummaryBucket({
    required this.start,
    required this.endExclusive,
    required this.label,
    required this.value,
    required this.trackCount,
  });

  final DateTime start;
  final DateTime endExclusive;
  final String label;
  final double value;
  final int trackCount;

  int get roundedValue => value.round();
}

class SummaryTimeline {
  const SummaryTimeline({
    required this.period,
    required this.windowStart,
    required this.windowEndExclusive,
    required this.buckets,
  });

  const SummaryTimeline.empty({required this.period})
    : windowStart = null,
      windowEndExclusive = null,
      buckets = const [];

  final SummaryPeriodPreset period;
  final DateTime? windowStart;
  final DateTime? windowEndExclusive;
  final List<SummaryBucket> buckets;

  bool get isEmpty => buckets.isEmpty;

  double get totalValue =>
      buckets.fold<double>(0, (sum, bucket) => sum + bucket.value);

  int get roundedTotalValue => totalValue.round();

  double get averageValue => _visibleAverageValue(buckets);

  int get roundedAverageValue => averageValue.round();
}

class SummaryMetricDefinition {
  const SummaryMetricDefinition({required this.valueOf});

  final double? Function(GpxTrack track) valueOf;
}

class SummaryCardService {
  const SummaryCardService();

  SummaryTimeline buildTimeline({
    required Iterable<GpxTrack> tracks,
    required SummaryPeriodPreset period,
    required SummaryMetricDefinition metric,
    DateTime? now,
  }) {
    final usableTracks = tracks
        .where(
          (track) => track.trackDate != null && metric.valueOf(track) != null,
        )
        .toList(growable: false);
    if (usableTracks.isEmpty) {
      return SummaryTimeline.empty(period: period);
    }

    final referenceDate = _startOfDay((now ?? DateTime.now()).toLocal());
    final windowStart = _timelineStart(period, usableTracks);
    final windowEndExclusive = switch (period) {
      SummaryPeriodPreset.month => _nextMonth(_startOfMonth(referenceDate)),
      _ => _startOfDay(referenceDate.add(const Duration(days: 1))),
    };
    final buckets = _buildBuckets(
      tracks: usableTracks,
      metric: metric,
      period: period,
      windowStart: windowStart,
      windowEndExclusive: windowEndExclusive,
    );

    return SummaryTimeline(
      period: period,
      windowStart: windowStart,
      windowEndExclusive: windowEndExclusive,
      buckets: buckets,
    );
  }

  int shiftWindowStartIndex({
    required int currentStartIndex,
    required int visibleBucketCount,
    required int bucketCount,
    required bool forward,
  }) {
    if (bucketCount <= 0) {
      return 0;
    }

    final safeVisibleCount = math.max(1, visibleBucketCount);
    final maxStartIndex = math.max(0, bucketCount - safeVisibleCount);
    final delta = math.max(1, (safeVisibleCount / 2).round());
    final next = forward
        ? currentStartIndex + delta
        : currentStartIndex - delta;
    return next.clamp(0, maxStartIndex);
  }

  double shiftScrollOffset({
    required double currentOffset,
    required double viewportWidth,
    required double maxScrollExtent,
    required bool forward,
  }) {
    final delta = math.max(1.0, viewportWidth / 2);
    final next = forward ? currentOffset + delta : currentOffset - delta;
    return next.clamp(0.0, maxScrollExtent);
  }

  double visibleAverageValue(Iterable<SummaryBucket> buckets) =>
      _visibleAverageValue(buckets);

  double visibleAverageValueForPeriod({
    required SummaryPeriodPreset period,
    required Iterable<SummaryBucket> buckets,
  }) {
    return switch (period) {
      SummaryPeriodPreset.week ||
      SummaryPeriodPreset.last12Months ||
      SummaryPeriodPreset.allTime => _visibleAverageValue(buckets),
      SummaryPeriodPreset.month => _averageByWeek(buckets),
      SummaryPeriodPreset.last3Months ||
      SummaryPeriodPreset.last6Months => _averageByMonth(buckets),
    };
  }

  double visibleTotalValue(Iterable<SummaryBucket> buckets) {
    final bucketList = buckets.toList(growable: false);
    if (bucketList.isEmpty) {
      return 0;
    }

    return bucketList.fold<double>(0, (sum, bucket) => sum + bucket.value);
  }
}

double _visibleAverageValue(Iterable<SummaryBucket> buckets) {
  final bucketList = buckets.toList(growable: false);
  if (bucketList.isEmpty) {
    return 0;
  }

  final total = bucketList.fold<double>(0, (sum, bucket) => sum + bucket.value);
  return total / bucketList.length;
}

double _averageByWeek(Iterable<SummaryBucket> buckets) {
  final bucketList = buckets.toList(growable: false);
  if (bucketList.isEmpty) {
    return 0;
  }

  final weeklyTotals = <DateTime, double>{};
  for (final bucket in bucketList) {
    final weekStart = _startOfDay(
      bucket.start.subtract(Duration(days: bucket.start.weekday - 1)),
    );
    weeklyTotals.update(
      weekStart,
      (value) => value + bucket.value,
      ifAbsent: () => bucket.value,
    );
  }

  final total = weeklyTotals.values.fold<double>(
    0,
    (sum, value) => sum + value,
  );
  return total / weeklyTotals.length;
}

double _averageByMonth(Iterable<SummaryBucket> buckets) {
  final bucketList = buckets.toList(growable: false);
  if (bucketList.isEmpty) {
    return 0;
  }

  final monthlyTotals = <DateTime, double>{};
  for (final bucket in bucketList) {
    final monthStart = DateTime(bucket.start.year, bucket.start.month);
    monthlyTotals.update(
      monthStart,
      (value) => value + bucket.value,
      ifAbsent: () => bucket.value,
    );
  }

  final total = monthlyTotals.values.fold<double>(
    0,
    (sum, value) => sum + value,
  );
  return total / monthlyTotals.length;
}

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime _startOfMonth(DateTime date) => DateTime(date.year, date.month);

DateTime _startOfYear(DateTime date) => DateTime(date.year);

DateTime _addMonthsClamped(DateTime date, int months) {
  final totalMonths = (date.year * 12) + (date.month - 1) + months;
  final year = totalMonths ~/ 12;
  final month = (totalMonths % 12) + 1;
  final day = math.min(date.day, _daysInMonth(year, month));
  return DateTime(year, month, day);
}

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime _nextDay(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);

DateTime _nextWeek(DateTime date) =>
    DateTime(date.year, date.month, date.day + 7);

DateTime _nextMonth(DateTime date) => _addMonthsClamped(date, 1);

DateTime _nextYear(DateTime date) => DateTime(date.year + 1);

DateTime _timelineStart(
  SummaryPeriodPreset period,
  List<GpxTrack> usableTracks,
) {
  final earliestDate = _earliestTrackDate(usableTracks);

  return switch (period) {
    SummaryPeriodPreset.week => earliestDate,
    SummaryPeriodPreset.month ||
    SummaryPeriodPreset.last3Months ||
    SummaryPeriodPreset.last6Months ||
    SummaryPeriodPreset.last12Months => _startOfMonth(earliestDate),
    SummaryPeriodPreset.allTime => _startOfYear(earliestDate),
  };
}

DateTime _earliestTrackDate(List<GpxTrack> tracks) {
  final dates = tracks
      .map((track) => track.trackDate!.toLocal())
      .map(_startOfDay)
      .toList(growable: false);
  dates.sort();
  return dates.first;
}

List<SummaryBucket> _buildBuckets({
  required List<GpxTrack> tracks,
  required SummaryMetricDefinition metric,
  required SummaryPeriodPreset period,
  required DateTime windowStart,
  required DateTime windowEndExclusive,
}) {
  final buckets = <_BucketBuilder>[];
  var cursor = windowStart;

  while (cursor.isBefore(windowEndExclusive)) {
    final next = switch (period) {
      SummaryPeriodPreset.week || SummaryPeriodPreset.month => _nextDay(cursor),
      SummaryPeriodPreset.last3Months ||
      SummaryPeriodPreset.last6Months => _nextWeek(cursor),
      SummaryPeriodPreset.last12Months => _nextMonth(cursor),
      SummaryPeriodPreset.allTime => _nextYear(cursor),
    };

    buckets.add(
      _BucketBuilder(
        start: cursor,
        endExclusive: next,
        label: _labelFor(period, cursor),
      ),
    );
    cursor = next;
  }

  final totals = List<double>.filled(buckets.length, 0);
  final counts = List<int>.filled(buckets.length, 0);

  for (final track in tracks) {
    final trackDate = _startOfDay(track.trackDate!.toLocal());
    for (var index = 0; index < buckets.length; index++) {
      final bucket = buckets[index];
      final inRange =
          !trackDate.isBefore(bucket.start) &&
          trackDate.isBefore(bucket.endExclusive);
      if (!inRange) {
        continue;
      }
      totals[index] += metric.valueOf(track)!;
      counts[index] += 1;
      break;
    }
  }

  return [
    for (var index = 0; index < buckets.length; index++)
      SummaryBucket(
        start: buckets[index].start,
        endExclusive: buckets[index].endExclusive,
        label: buckets[index].label,
        value: totals[index],
        trackCount: counts[index],
      ),
  ];
}

String _labelFor(SummaryPeriodPreset period, DateTime date) {
  const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return switch (period) {
    SummaryPeriodPreset.week => weekdays[date.weekday - 1],
    SummaryPeriodPreset.month => date.day.toString(),
    SummaryPeriodPreset.last3Months ||
    SummaryPeriodPreset.last6Months ||
    SummaryPeriodPreset.last12Months => months[date.month - 1],
    SummaryPeriodPreset.allTime => date.year.toString(),
  };
}

class _BucketBuilder {
  const _BucketBuilder({
    required this.start,
    required this.endExclusive,
    required this.label,
  });

  final DateTime start;
  final DateTime endExclusive;
  final String label;
}
