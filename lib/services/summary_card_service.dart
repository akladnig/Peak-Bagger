import 'dart:math' as math;

import 'package:peak_bagger/models/gpx_track.dart';
import 'track_date_calendar_codec.dart';

enum SummaryPeriodPreset {
  week,
  month,
  last3Months,
  last6Months,
  last12Months,
  yearToDate,
  allTime,
}

extension SummaryPeriodPresetLabel on SummaryPeriodPreset {
  int get monthsPerPage => switch (this) {
    SummaryPeriodPreset.last3Months => 3,
    SummaryPeriodPreset.last6Months => 6,
    SummaryPeriodPreset.last12Months => 12,
    _ => 1,
  };

  String get previousTooltip => 'Previous $navigationUnit';
  String get nextTooltip => 'Next $navigationUnit';
  String get navigationUnit => switch (this) {
    SummaryPeriodPreset.week => 'Week',
    SummaryPeriodPreset.month => 'Month',
    SummaryPeriodPreset.last3Months => '3 Months',
    SummaryPeriodPreset.last6Months => '6 Months',
    SummaryPeriodPreset.last12Months => '12 Months',
    SummaryPeriodPreset.yearToDate => 'Year',
    SummaryPeriodPreset.allTime => '12 Years',
  };

  String get label => switch (this) {
    SummaryPeriodPreset.week => 'Week',
    SummaryPeriodPreset.month => 'Month',
    SummaryPeriodPreset.last3Months => 'Last 3 Months',
    SummaryPeriodPreset.last6Months => 'Last 6 Months',
    SummaryPeriodPreset.last12Months => 'Last 12 Months',
    SummaryPeriodPreset.yearToDate => 'Year to Date',
    SummaryPeriodPreset.allTime => 'All Time',
  };

  String get averageLabel => switch (this) {
    SummaryPeriodPreset.week => 'Daily Avg:',
    SummaryPeriodPreset.month => 'Weekly Avg:',
    SummaryPeriodPreset.last3Months ||
    SummaryPeriodPreset.last6Months ||
    SummaryPeriodPreset.last12Months ||
    SummaryPeriodPreset.yearToDate => 'Monthly Avg:',
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

/// Calendar components in the Mac's local zone, with an end-exclusive boundary.
/// Constructing adjacent dates (rather than adding 24h) preserves DST days.
class SummaryCalendarPage {
  const SummaryCalendarPage({required this.start, required this.endExclusive});

  final DateTime start;
  final DateTime endExclusive;
  DateTime get lastDay =>
      DateTime(endExclusive.year, endExclusive.month, endExclusive.day - 1);
}

class SummaryPageNavigation {
  const SummaryPageNavigation({
    required this.period,
    required this.selected,
    required this.first,
    required this.last,
    required this.current,
  });

  final SummaryPeriodPreset period;
  final SummaryCalendarPage selected;
  final SummaryCalendarPage first;
  final SummaryCalendarPage last;
  final SummaryCalendarPage current;

  bool get canFirst => selected.start != first.start;
  bool get canPrevious => selected.start.isAfter(first.start);
  bool get canNext => selected.start.isBefore(current.start);
  bool get canLast => selected.start != last.start;

  SummaryCalendarPage adjacent(bool forward) {
    final direction = forward ? 1 : -1;
    // Use the end year for a potentially shortened oldest All Time page.
    final day = switch (period) {
      SummaryPeriodPreset.week => DateTime(
        selected.start.year,
        selected.start.month,
        selected.start.day + direction * 7,
      ),
      SummaryPeriodPreset.allTime => DateTime(
        selected.endExclusive.year - 1 + direction * 12,
      ),
      SummaryPeriodPreset.yearToDate => DateTime(
        selected.start.year + direction,
      ),
      _ => DateTime(
        selected.start.year,
        selected.start.month + direction * period.monthsPerPage,
      ),
    };
    final destination = const SummaryCardService().calendarPage(
      period: period,
      day: day,
      referenceDate: current.lastDay,
    );
    if (destination.start.isBefore(first.start)) return first;
    if (destination.start.isAfter(current.start)) return current;
    return destination;
  }
}

class SummaryCardService {
  const SummaryCardService();

  SummaryCalendarPage calendarPage({
    required SummaryPeriodPreset period,
    required DateTime day,
    DateTime? referenceDate,
  }) {
    final reference = referenceDate ?? day;
    if (period == SummaryPeriodPreset.week) {
      final start = DateTime(day.year, day.month, day.day - day.weekday + 1);
      return SummaryCalendarPage(start: start, endExclusive: _nextWeek(start));
    }
    if (period == SummaryPeriodPreset.yearToDate) {
      return SummaryCalendarPage(
        start: DateTime(day.year),
        endExclusive: DateTime(day.year + 1),
      );
    }
    if (period == SummaryPeriodPreset.allTime) {
      final pagesBack = ((reference.year - day.year) / 12).floor();
      final endYear = reference.year + 1 - pagesBack * 12;
      return SummaryCalendarPage(
        start: DateTime(endYear - 12),
        endExclusive: DateTime(endYear),
      );
    }
    final months = period.monthsPerPage;
    final monthDelta =
        (reference.year - day.year) * 12 + reference.month - day.month;
    final pagesBack = (monthDelta / months).floor();
    final end = DateTime(
      reference.year,
      reference.month + 1 - pagesBack * months,
    );
    return SummaryCalendarPage(
      start: DateTime(end.year, end.month - months),
      endExclusive: end,
    );
  }

  SummaryPageNavigation? pageNavigation({
    required Iterable<GpxTrack> tracks,
    required SummaryMetricDefinition metric,
    required SummaryPeriodPreset period,
    required DateTime now,
    DateTime? selectedDay,
  }) {
    final reference = _startOfDay(now.toLocal());
    DateTime? earliest;
    DateTime? latest;
    for (final track in tracks) {
      final decoded = TrackDateCalendarCodec.day(track);
      if (decoded == null || metric.valueOf(track) == null) continue;
      final day = _startOfDay(decoded);
      if (day.isAfter(reference)) continue;
      if (earliest == null || day.isBefore(earliest)) earliest = day;
      if (latest == null || day.isAfter(latest)) latest = day;
    }
    final earliestDay = earliest;
    if (earliestDay == null) return null;
    SummaryCalendarPage pageFor(DateTime day) {
      final page = calendarPage(
        period: period,
        day: day.isBefore(earliestDay) ? earliestDay : day,
        referenceDate: reference,
      );
      // Do not invent years before recorded history on the oldest yearly page.
      return period == SummaryPeriodPreset.allTime &&
              page.start.year < earliestDay.year
          ? SummaryCalendarPage(
              start: DateTime(earliestDay.year),
              endExclusive: page.endExclusive,
            )
          : page;
    }

    final first = pageFor(earliestDay);
    final last = pageFor(latest!);
    final current = pageFor(reference);
    var selected = pageFor(selectedDay ?? reference);
    if (selected.start.isBefore(first.start)) selected = first;
    if (selected.start.isAfter(current.start)) selected = current;
    return SummaryPageNavigation(
      period: period,
      selected: selected,
      first: first,
      last: last,
      current: current,
    );
  }

  SummaryTimeline buildTimeline({
    required Iterable<GpxTrack> tracks,
    required SummaryPeriodPreset period,
    required SummaryMetricDefinition metric,
    DateTime? now,
    SummaryCalendarPage? page,
  }) {
    final usableTracks = <_UsableTrack>[];
    final referenceDate = _startOfDay((now ?? DateTime.now()).toLocal());
    DateTime? earliestDate;

    for (final track in tracks) {
      final trackDate = TrackDateCalendarCodec.day(track);
      final value = metric.valueOf(track);
      if (trackDate == null || value == null) {
        continue;
      }

      final day = _startOfDay(trackDate);
      if (day.isAfter(referenceDate)) {
        continue;
      }
      earliestDate = earliestDate == null || day.isBefore(earliestDate)
          ? day
          : earliestDate;
      usableTracks.add(_UsableTrack(date: day, value: value));
    }

    if (usableTracks.isEmpty && page == null) {
      return SummaryTimeline.empty(period: period);
    }

    final selectedPage =
        page ?? calendarPage(period: period, day: referenceDate);
    final windowStart =
        page == null &&
            period == SummaryPeriodPreset.allTime &&
            earliestDate!.isAfter(selectedPage.start)
        ? DateTime(earliestDate.year)
        : selectedPage.start;
    final windowEndExclusive = selectedPage.endExclusive;
    final buckets = _buildBuckets(
      tracks: usableTracks,
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

  double visibleAverageValue(Iterable<SummaryBucket> buckets) =>
      _visibleAverageValue(buckets);

  double visibleAverageValueForPeriod({
    required SummaryPeriodPreset period,
    required Iterable<SummaryBucket> buckets,
    DateTime? referenceDate,
  }) {
    final bucketList = buckets.toList(growable: false);
    return switch (period) {
      SummaryPeriodPreset.week ||
      SummaryPeriodPreset.last12Months ||
      SummaryPeriodPreset.allTime => _visibleAverageValue(buckets),
      SummaryPeriodPreset.month => _averageByWeek(buckets),
      SummaryPeriodPreset.last3Months ||
      SummaryPeriodPreset.last6Months => _averageByMonth(buckets),
      SummaryPeriodPreset.yearToDate => _visibleAverageValue(
        bucketList.where(
          (bucket) =>
              referenceDate == null || !bucket.start.isAfter(referenceDate),
        ),
      ),
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
    final weekStart = DateTime(
      bucket.start.year,
      bucket.start.month,
      bucket.start.day - bucket.start.weekday + 1,
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

  final start = bucketList.first.start;
  final end = bucketList.last.endExclusive;
  final lastDay = DateTime(end.year, end.month, end.day - 1);
  final months =
      (lastDay.year - start.year) * 12 + lastDay.month - start.month + 1;
  return bucketList.fold<double>(0, (sum, bucket) => sum + bucket.value) /
      months;
}

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

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

List<SummaryBucket> _buildBuckets({
  required List<_UsableTrack> tracks,
  required SummaryPeriodPreset period,
  required DateTime windowStart,
  required DateTime windowEndExclusive,
}) {
  final buckets = <_BucketBuilder>[];
  var cursor = windowStart;

  while (cursor.isBefore(windowEndExclusive)) {
    final next = switch (period) {
      SummaryPeriodPreset.week || SummaryPeriodPreset.month => _nextDay(cursor),
      SummaryPeriodPreset.last3Months || SummaryPeriodPreset.last6Months =>
        DateTime(cursor.year, cursor.month, cursor.day + 8 - cursor.weekday),
      SummaryPeriodPreset.last12Months => _nextMonth(cursor),
      SummaryPeriodPreset.yearToDate => _nextMonth(cursor),
      SummaryPeriodPreset.allTime => _nextYear(cursor),
    };

    buckets.add(
      _BucketBuilder(
        start: cursor,
        endExclusive: next.isAfter(windowEndExclusive)
            ? windowEndExclusive
            : next,
        label: _labelFor(period, cursor),
      ),
    );
    cursor = next;
  }

  final totals = List<double>.filled(buckets.length, 0);
  final counts = List<int>.filled(buckets.length, 0);

  for (final track in tracks) {
    if (track.date.isBefore(windowStart) ||
        !track.date.isBefore(windowEndExclusive)) {
      continue;
    }
    final index = _bucketIndexFor(
      period: period,
      windowStart: windowStart,
      trackDate: track.date,
    );
    if (index == null || index < 0 || index >= buckets.length) {
      continue;
    }

    totals[index] += track.value;
    counts[index] += 1;
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

int? _bucketIndexFor({
  required SummaryPeriodPreset period,
  required DateTime windowStart,
  required DateTime trackDate,
}) {
  return switch (period) {
    SummaryPeriodPreset.week || SummaryPeriodPreset.month =>
      _dateOnlyDifferenceInDays(trackDate, windowStart),
    SummaryPeriodPreset.last3Months || SummaryPeriodPreset.last6Months =>
      (_dateOnlyDifferenceInDays(trackDate, windowStart) +
              windowStart.weekday -
              1) ~/
          7,
    SummaryPeriodPreset.last12Months =>
      ((trackDate.year - windowStart.year) * 12) +
          (trackDate.month - windowStart.month),
    SummaryPeriodPreset.yearToDate =>
      ((trackDate.year - windowStart.year) * 12) +
          (trackDate.month - windowStart.month),
    SummaryPeriodPreset.allTime => trackDate.year - windowStart.year,
  };
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
    SummaryPeriodPreset.last12Months ||
    SummaryPeriodPreset.yearToDate => months[date.month - 1],
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

class _UsableTrack {
  const _UsableTrack({required this.date, required this.value});

  final DateTime date;
  final double value;
}

int _dateOnlyDifferenceInDays(DateTime a, DateTime b) {
  final aUtc = DateTime.utc(a.year, a.month, a.day);
  final bUtc = DateTime.utc(b.year, b.month, b.day);
  return aUtc.difference(bUtc).inDays;
}
