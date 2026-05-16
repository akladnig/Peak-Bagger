import 'dart:math' as math;

import 'package:peak_bagger/models/gpx_track.dart';

enum ElevationPeriodPreset {
  week,
  month,
  last3Months,
  last6Months,
  last12Months,
  allTime,
}

extension ElevationPeriodPresetLabel on ElevationPeriodPreset {
  String get label => switch (this) {
    ElevationPeriodPreset.week => 'Week',
    ElevationPeriodPreset.month => 'Month',
    ElevationPeriodPreset.last3Months => 'Last 3 Months',
    ElevationPeriodPreset.last6Months => 'Last 6 Months',
    ElevationPeriodPreset.last12Months => 'Last 12 Months',
    ElevationPeriodPreset.allTime => 'All Time',
  };
}

class ElevationBucket {
  const ElevationBucket({
    required this.start,
    required this.endExclusive,
    required this.label,
    required this.ascentMetres,
    required this.trackCount,
  });

  final DateTime start;
  final DateTime endExclusive;
  final String label;
  final double ascentMetres;
  final int trackCount;

  int get roundedAscentMetres => ascentMetres.round();
}

class ElevationTimeline {
  const ElevationTimeline({
    required this.period,
    required this.windowStart,
    required this.windowEndExclusive,
    required this.buckets,
  });

  const ElevationTimeline.empty({required this.period})
    : windowStart = null,
      windowEndExclusive = null,
      buckets = const [];

  final ElevationPeriodPreset period;
  final DateTime? windowStart;
  final DateTime? windowEndExclusive;
  final List<ElevationBucket> buckets;

  bool get isEmpty => buckets.isEmpty;

  double get totalAscentMetres =>
      buckets.fold<double>(0, (sum, bucket) => sum + bucket.ascentMetres);

  int get totalMetres => totalAscentMetres.round();

  int get averageMetres => _visibleAverageMetres(buckets);
}

class ElevationSummaryService {
  const ElevationSummaryService();

  ElevationTimeline buildTimeline({
    required Iterable<GpxTrack> tracks,
    required ElevationPeriodPreset period,
    DateTime? now,
  }) {
    final usableTracks = tracks
        .where((track) => track.trackDate != null && track.ascent != null)
        .toList(growable: false);
    if (usableTracks.isEmpty) {
      return ElevationTimeline.empty(period: period);
    }

    final referenceDate = _startOfDay((now ?? DateTime.now()).toLocal());
    final windowStart = _timelineStart(period, usableTracks);
    final windowEndExclusive = switch (period) {
      ElevationPeriodPreset.month => _nextMonth(_startOfMonth(referenceDate)),
      _ => _startOfDay(referenceDate.add(const Duration(days: 1))),
    };
    final buckets = _buildBuckets(
      tracks: usableTracks,
      period: period,
      windowStart: windowStart,
      windowEndExclusive: windowEndExclusive,
    );

    return ElevationTimeline(
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

  int visibleAverageMetres(Iterable<ElevationBucket> buckets) =>
      _visibleAverageMetres(buckets);

  int visibleAverageMetresForPeriod({
    required ElevationPeriodPreset period,
    required Iterable<ElevationBucket> buckets,
  }) {
    return switch (period) {
      ElevationPeriodPreset.week ||
      ElevationPeriodPreset.last12Months ||
      ElevationPeriodPreset.allTime => _visibleAverageMetres(buckets),
      ElevationPeriodPreset.month => _averageByWeek(buckets),
      ElevationPeriodPreset.last3Months ||
      ElevationPeriodPreset.last6Months => _averageByMonth(buckets),
    };
  }

  int visibleTotalMetres(Iterable<ElevationBucket> buckets) {
    final bucketList = buckets.toList(growable: false);
    if (bucketList.isEmpty) {
      return 0;
    }

    final total = bucketList.fold<double>(
      0,
      (sum, bucket) => sum + bucket.ascentMetres,
    );
    return total.round();
  }
}

int _visibleAverageMetres(Iterable<ElevationBucket> buckets) {
  final bucketList = buckets.toList(growable: false);
  if (bucketList.isEmpty) {
    return 0;
  }

  final total = bucketList.fold<double>(
    0,
    (sum, bucket) => sum + bucket.ascentMetres,
  );
  return (total / bucketList.length).round();
}

int _averageByWeek(Iterable<ElevationBucket> buckets) {
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
      (value) => value + bucket.ascentMetres,
      ifAbsent: () => bucket.ascentMetres,
    );
  }

  final total = weeklyTotals.values.fold<double>(
    0,
    (sum, value) => sum + value,
  );
  return (total / weeklyTotals.length).round();
}

int _averageByMonth(Iterable<ElevationBucket> buckets) {
  final bucketList = buckets.toList(growable: false);
  if (bucketList.isEmpty) {
    return 0;
  }

  final monthlyTotals = <DateTime, double>{};
  for (final bucket in bucketList) {
    final monthStart = DateTime(bucket.start.year, bucket.start.month);
    monthlyTotals.update(
      monthStart,
      (value) => value + bucket.ascentMetres,
      ifAbsent: () => bucket.ascentMetres,
    );
  }

  final total = monthlyTotals.values.fold<double>(
    0,
    (sum, value) => sum + value,
  );
  return (total / monthlyTotals.length).round();
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
  ElevationPeriodPreset period,
  List<GpxTrack> usableTracks,
) {
  final earliestDate = _earliestTrackDate(usableTracks);

  return switch (period) {
    ElevationPeriodPreset.week => earliestDate,
    ElevationPeriodPreset.month ||
    ElevationPeriodPreset.last3Months ||
    ElevationPeriodPreset.last6Months ||
    ElevationPeriodPreset.last12Months => _startOfMonth(earliestDate),
    ElevationPeriodPreset.allTime => _startOfYear(earliestDate),
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

List<ElevationBucket> _buildBuckets({
  required List<GpxTrack> tracks,
  required ElevationPeriodPreset period,
  required DateTime windowStart,
  required DateTime windowEndExclusive,
}) {
  final buckets = <_BucketBuilder>[];
  var cursor = windowStart;

  while (cursor.isBefore(windowEndExclusive)) {
    final next = switch (period) {
      ElevationPeriodPreset.week ||
      ElevationPeriodPreset.month => _nextDay(cursor),
      ElevationPeriodPreset.last3Months ||
      ElevationPeriodPreset.last6Months => _nextWeek(cursor),
      ElevationPeriodPreset.last12Months => _nextMonth(cursor),
      ElevationPeriodPreset.allTime => _nextYear(cursor),
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
      totals[index] += track.ascent!;
      counts[index] += 1;
      break;
    }
  }

  return [
    for (var index = 0; index < buckets.length; index++)
      ElevationBucket(
        start: buckets[index].start,
        endExclusive: buckets[index].endExclusive,
        label: buckets[index].label,
        ascentMetres: totals[index],
        trackCount: counts[index],
      ),
  ];
}

String _labelFor(ElevationPeriodPreset period, DateTime date) {
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
    ElevationPeriodPreset.week => weekdays[date.weekday - 1],
    ElevationPeriodPreset.month => date.day.toString(),
    ElevationPeriodPreset.last3Months ||
    ElevationPeriodPreset.last6Months => months[date.month - 1],
    ElevationPeriodPreset.last12Months => months[date.month - 1],
    ElevationPeriodPreset.allTime => date.year.toString(),
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
