import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/track_date_status.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/services/time_summary_metrics.dart';

void main() {
  const service = SummaryCardService();
  final reference = DateTime(2026, 10, 15);
  test(
    'duration pairs qualify together, retain zero activity, and never repair records',
    () {
      final pairs = <(int?, int?, bool)>[
        (null, null, false),
        (null, 0, false),
        (0, null, false),
        (-1, 0, false),
        (0, -1, false),
        (-2, -1, false),
        (1, 2, false),
        (0, 0, true),
        (1, 0, true),
        (1, 1, true),
      ];
      for (final (total, moving, expected) in pairs) {
        final track = _track(1, DateTime.utc(2026, 10, 1), total, moving);
        final before = track.toMap();
        expect(TimeSummaryMetrics.isEligible(track), expected);
        expect(track.toMap(), before);
      }
    },
  );

  test(
    'both endpoints and series share duration/date/cutoff eligibility for every preset',
    () {
      final tracks = [
        _track(1, DateTime.utc(1980), 1, null),
        _track(2, DateTime.utc(1990), 1, 2),
        _track(3, DateTime.utc(2020, 2, 29), 0, 0),
        _track(4, DateTime.utc(2024, 12, 31), 100, 0),
        _track(5, DateTime.utc(2026, 10, 16), 100, 90),
        _track(6, null, 100, 90),
        _track(7, DateTime.utc(2026, 10, 15), -1, 0),
      ];
      final before = tracks.map((t) => t.toMap()).toList();
      final eligible = tracks.where(TimeSummaryMetrics.isEligible).toList();
      for (final period in SummaryPeriodPreset.values) {
        final primaryNavigation = service.pageNavigation(
          tracks: eligible,
          metric: TimeSummaryMetrics.total,
          period: period,
          now: reference,
        )!;
        final secondaryNavigation = service.pageNavigation(
          tracks: eligible,
          metric: TimeSummaryMetrics.moving,
          period: period,
          now: reference,
        )!;
        expect(primaryNavigation.first.start, secondaryNavigation.first.start);
        expect(primaryNavigation.last.start, secondaryNavigation.last.start);
        expect(primaryNavigation.first.start.year, greaterThanOrEqualTo(2019));
        expect(primaryNavigation.last.lastDay.year, lessThanOrEqualTo(2026));
        for (final page in [
          primaryNavigation.first,
          primaryNavigation.last,
          primaryNavigation.current,
        ]) {
          SummaryTimeline build(SummaryMetricDefinition metric) =>
              service.buildTimeline(
                tracks: eligible,
                metric: metric,
                period: period,
                now: reference,
                page: page,
              );
          final total = build(TimeSummaryMetrics.total);
          final moving = build(TimeSummaryMetrics.moving);
          expect(
            total.buckets.map((b) => (b.start, b.endExclusive, b.trackCount)),
            moving.buckets.map((b) => (b.start, b.endExclusive, b.trackCount)),
          );
          expect(
            total.buckets.fold<int>(0, (s, b) => s + b.trackCount),
            lessThanOrEqualTo(2),
          );
          expect(moving.totalValue, 0);
        }
      }
      expect(tracks.map((t) => t.toMap()), before);
    },
  );

  test(
    'recorded segments include rest but exclude gaps; no timestamp substitution',
    () {
      final track = _track(1, DateTime.utc(2026, 10, 15), 18000000, 14400000)
        ..restingTime = 3600000
        ..pausedTime = 1800000
        ..startDateTime = DateTime.utc(2026, 10, 15, 1)
        ..endDateTime = DateTime.utc(2026, 10, 15, 6, 30);
      final total = service.buildTimeline(
        tracks: [track],
        period: SummaryPeriodPreset.week,
        metric: TimeSummaryMetrics.total,
        now: reference,
      );
      final moving = service.buildTimeline(
        tracks: [track],
        period: SummaryPeriodPreset.week,
        metric: TimeSummaryMetrics.moving,
        now: reference,
      );
      expect(total.totalValue, 18000000);
      expect(moving.totalValue, 14400000);
      expect(formatDurationMillis(total.totalValue), '0d 5h 0m');
      expect(formatDurationMillis(moving.totalValue), '0d 4h 0m');
    },
  );

  test(
    'sum full milliseconds before formatting or averaging, including zero days',
    () {
      final total = service.buildTimeline(
        tracks: [
          for (var i = 0; i < 14; i++)
            _track(i, DateTime.utc(2026, 10, 15), 30001, 30001),
        ],
        period: SummaryPeriodPreset.week,
        metric: TimeSummaryMetrics.total,
        now: reference,
      );
      expect(total.totalValue, 420014);
      expect(formatDurationMillis(total.totalValue), '0d 0h 7m');
      final average = service.visibleAverageValueForPeriod(
        period: total.period,
        buckets: total.buckets,
      );
      expect(average, 60002);
      expect(formatDurationMillis(average), '0d 0h 1m');
    },
  );

  test(
    'multi-day durations belong entirely to their Track day across Hobart DST',
    () {
      expect(DateTime(2026, 10, 3).timeZoneOffset, const Duration(hours: 10));
      expect(DateTime(2026, 10, 5).timeZoneOffset, const Duration(hours: 11));
      final timeline = service.buildTimeline(
        tracks: [_track(1, DateTime.utc(2026, 10, 3), 191220000, 172800000)],
        period: SummaryPeriodPreset.month,
        metric: TimeSummaryMetrics.total,
        now: reference,
      );
      expect(timeline.buckets[2].value, 191220000);
      expect(timeline.buckets[2].trackCount, 1);
      expect(timeline.buckets.where((b) => b.trackCount > 0), hasLength(1));
      expect(formatDurationMillis(timeline.totalValue), '2d 5h 7m');
    },
  );
}

GpxTrack _track(int id, DateTime? date, int? total, int? moving) => GpxTrack(
  gpxTrackId: id,
  contentHash: '$id',
  trackName: 'Track $id',
  trackDate: date,
  trackDateStatus: TrackDateStatus.resolved,
  totalTimeMillis: total,
  movingTime: moving,
);
