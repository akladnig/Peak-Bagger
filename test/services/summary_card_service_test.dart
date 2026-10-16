import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/track_date_status.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/widgets/dashboard/distance_card.dart';

void main() {
  group('SummaryCardService', () {
    const service = SummaryCardService();

    test('Monday week includes both sides of a year boundary', () {
      final timeline = service.buildTimeline(
        tracks: [
          _track(1, DateTime.utc(2025, 12, 31), distance2d: 70, ascent: 70)
            ..trackDateStatus = TrackDateStatus.resolved,
        ],
        period: SummaryPeriodPreset.week,
        metric: DistanceCard.metric,
        now: DateTime(2026, 1, 1),
      );
      expect(timeline.windowStart, DateTime(2025, 12, 29));
      expect(timeline.windowEndExclusive, DateTime(2026, 1, 5));
      expect(timeline.buckets, hasLength(7));
      expect(timeline.buckets[2].value, 70);
      expect(timeline.buckets[3].start, DateTime(2026, 1, 1));
    });

    for (final fixture in [
      (2023, 2, 28),
      (2024, 2, 29),
      (2026, 4, 30),
      (2026, 10, 31),
    ]) {
      test(
        'complete month ${fixture.$1}-${fixture.$2} has ${fixture.$3} days',
        () {
          final day = DateTime(fixture.$1, fixture.$2, 1);
          final page = service.calendarPage(
            period: SummaryPeriodPreset.month,
            day: day,
          );
          final timeline = service.buildTimeline(
            tracks: [_track(1, day, distance2d: 100, ascent: 10)],
            period: SummaryPeriodPreset.month,
            metric: DistanceCard.metric,
            now: DateTime(2026, 10, 15),
            page: page,
          );
          expect(timeline.buckets, hasLength(fixture.$3));
          expect(timeline.buckets.first.start, day);
          expect(
            timeline.buckets.last.endExclusive,
            DateTime(fixture.$1, fixture.$2 + 1),
          );
          expect(timeline.buckets.map((b) => b.start.day).toSet(), {
            for (var d = 1; d <= fixture.$3; d++) d,
          });
        },
      );
    }

    for (final fixture in [(4, 5, 11, 10), (10, 4, 10, 11)]) {
      test(
        'Hobart DST ${fixture.$1} retains every day in its week and month',
        () {
          final month = fixture.$1;
          final transition = fixture.$2;
          // Independent 2026 Hobart offset expectations, not the page algorithm.
          expect(
            DateTime(2026, month, transition - 1, 12).timeZoneOffset,
            Duration(hours: fixture.$3),
          );
          expect(
            DateTime(2026, month, transition, 12).timeZoneOffset,
            Duration(hours: fixture.$4),
          );
          final tracks = [
            for (var d = 1; d <= 31; d++)
              if (DateTime(2026, month, d).month == month)
                _track(
                  d,
                  DateTime.utc(2026, month, d),
                  distance2d: d.toDouble(),
                  ascent: d.toDouble(),
                )..trackDateStatus = TrackDateStatus.resolved,
          ];
          for (final period in [
            SummaryPeriodPreset.week,
            SummaryPeriodPreset.month,
          ]) {
            final page = service.calendarPage(
              period: period,
              day: DateTime(2026, month, transition),
            );
            final timeline = service.buildTimeline(
              tracks: tracks,
              period: period,
              metric: DistanceCard.metric,
              now: DateTime(2026, 12, 31),
              page: page,
            );
            expect(
              timeline.buckets,
              hasLength(
                period == SummaryPeriodPreset.week
                    ? 7
                    : DateTime(2026, month + 1, 0).day,
              ),
            );
            expect(
              timeline.buckets.map((b) => b.start).toSet().length,
              timeline.buckets.length,
            );
            for (final bucket in timeline.buckets) {
              expect(
                bucket.endExclusive,
                DateTime(
                  bucket.start.year,
                  bucket.start.month,
                  bucket.start.day + 1,
                ),
              );
              expect(
                bucket.value,
                bucket.start.month == month ? bucket.start.day : 0,
              );
              expect(bucket.trackCount, bucket.start.month == month ? 1 : 0);
            }
          }
        },
      );
    }

    test(
      'full history endpoints, consecutive gaps, primary eligibility and cutoff',
      () {
        final tracks = [
          _track(1, DateTime(2020, 2, 29), distance2d: 10, ascent: 1),
          _track(2, DateTime(2026, 8, 15), distance2d: 20, ascent: 2),
          _track(3, DateTime(2026, 10, 16), distance2d: 9999, ascent: 9999),
        ];
        final nav = service.pageNavigation(
          tracks: tracks,
          metric: DistanceCard.metric,
          period: SummaryPeriodPreset.month,
          now: DateTime(2026, 10, 15),
        )!;
        expect(nav.selected.start, DateTime(2026, 10));
        expect(nav.first.start, DateTime(2020, 2));
        expect(nav.last.start, DateTime(2026, 8));
        expect(nav.canNext, isFalse);
        expect(nav.canLast, isTrue);
        final latest = service.pageNavigation(
          tracks: tracks,
          metric: DistanceCard.metric,
          period: SummaryPeriodPreset.month,
          now: DateTime(2026, 10, 15),
          selectedDay: nav.last.start,
        )!;
        expect(latest.canLast, isFalse);
        expect(latest.canNext, isTrue);
        expect(latest.adjacent(true).start, DateTime(2026, 9));
        final gap = service.buildTimeline(
          tracks: tracks,
          period: SummaryPeriodPreset.month,
          metric: DistanceCard.metric,
          now: DateTime(2026, 10, 15),
          page: latest.adjacent(true),
        );
        expect(gap.isEmpty, isFalse);
        expect(gap.buckets, hasLength(30));
        expect(gap.totalValue, 0);
        expect(
          service.visibleAverageValueForPeriod(
            period: gap.period,
            buckets: gap.buckets,
          ),
          0,
        );
        final noSecondary = service.buildTimeline(
          tracks: tracks,
          period: SummaryPeriodPreset.month,
          metric: const SummaryMetricDefinition(valueOf: _noValue),
          now: DateTime(2026, 10, 15),
          page: nav.first,
        );
        expect(
          noSecondary.buckets.map((b) => b.start),
          List.generate(29, (i) => DateTime(2020, 2, i + 1)),
        );
        expect(noSecondary.totalValue, 0);
      },
    );

    test(
      'single historical page still allows forward navigation and future-only is empty',
      () {
        final old = _track(
          1,
          DateTime(2026, 8, 15),
          distance2d: 70,
          ascent: 70,
        );
        for (final period in [
          SummaryPeriodPreset.week,
          SummaryPeriodPreset.month,
        ]) {
          final nav = service.pageNavigation(
            tracks: [old],
            metric: DistanceCard.metric,
            period: period,
            now: DateTime(2026, 10, 15),
            selectedDay: old.trackDate,
          )!;
          expect(nav.canFirst, isFalse);
          expect(nav.canLast, isFalse);
          expect(nav.canPrevious, isFalse);
          expect(nav.canNext, isTrue);
          final onlyCurrent = service.pageNavigation(
            tracks: [old],
            metric: DistanceCard.metric,
            period: period,
            now: DateTime(2026, 8, 15),
          )!;
          expect([
            onlyCurrent.canFirst,
            onlyCurrent.canPrevious,
            onlyCurrent.canNext,
            onlyCurrent.canLast,
          ], everyElement(isFalse));
          final future = _track(
            2,
            DateTime.utc(2026, 10, 16),
            distance2d: 700,
            ascent: 700,
          )..trackDateStatus = TrackDateStatus.resolved;
          expect(
            service
                .buildTimeline(
                  tracks: [future],
                  period: period,
                  metric: DistanceCard.metric,
                  now: DateTime(2026, 10, 15),
                )
                .isEmpty,
            isTrue,
          );
          expect(
            service.pageNavigation(
              tracks: [future],
              metric: DistanceCard.metric,
              period: period,
              now: DateTime(2026, 10, 15),
            ),
            isNull,
          );
          final current = service.buildTimeline(
            tracks: [old, future],
            period: period,
            metric: DistanceCard.metric,
            now: DateTime(2026, 10, 15),
          );
          expect(current.totalValue, 0);
          expect(
            current.buckets.where((b) => b.start.day == 16).single.value,
            0,
          );
          expect(
            service
                .buildTimeline(
                  tracks: [old, future],
                  period: period,
                  metric: DistanceCard.metric,
                  now: DateTime(2026, 10, 16),
                )
                .totalValue,
            700,
          );
        }
      },
    );

    test('builds the complete Monday to Sunday week for distance', () {
      final timeline = service.buildTimeline(
        tracks: [
          _track(10, DateTime(2026, 5, 15, 9), distance2d: 1200, ascent: 120),
          _track(20, DateTime(2026, 5, 13, 9), distance2d: 800, ascent: 80),
          _track(21, DateTime(2026, 5, 13, 17), distance2d: 200, ascent: 20),
          _track(30, null, distance2d: 500, ascent: 50),
        ],
        period: SummaryPeriodPreset.week,
        metric: DistanceCard.metric,
        now: DateTime(2026, 5, 15, 12),
      );

      expect(timeline.buckets, hasLength(7));
      expect(timeline.buckets.first.start, DateTime(2026, 5, 11));
      expect(timeline.buckets.last.label, 'Sun');
      expect(timeline.buckets[4].roundedValue, 1200);
      expect(timeline.buckets[2].label, 'Wed');
      expect(timeline.buckets[2].roundedValue, 1000);
      expect(timeline.roundedTotalValue, 2200);
      expect(timeline.roundedAverageValue, 314);
    });

    test(
      'builds current month buckets with zero buckets included in average',
      () {
        final timeline = service.buildTimeline(
          tracks: [
            _track(10, DateTime(2026, 5, 1, 9), distance2d: 100, ascent: 100),
            _track(20, DateTime(2026, 5, 3, 9), distance2d: 50, ascent: 50),
          ],
          period: SummaryPeriodPreset.month,
          metric: const SummaryMetricDefinition(valueOf: _trackAscent),
          now: DateTime(2026, 5, 15, 12),
        );

        expect(timeline.buckets, hasLength(31));
        expect(timeline.buckets.first.label, '1');
        expect(timeline.buckets.last.label, '31');
        expect(timeline.buckets[2].roundedValue, 50);
        expect(timeline.roundedTotalValue, 150);
        expect(timeline.roundedAverageValue, 5);
      },
    );

    test('lists year to date between last 12 months and all time', () {
      expect(SummaryPeriodPreset.values.map((preset) => preset.label), [
        'Week',
        'Month',
        'Last 3 Months',
        'Last 6 Months',
        'Last 12 Months',
        'Year to Date',
        'All Time',
      ]);
    });

    test('builds year to date month buckets from Jan to Dec', () {
      final timeline = service.buildTimeline(
        tracks: [
          _track(10, DateTime(2026, 1, 15, 9), distance2d: 100, ascent: 100),
          _track(21, DateTime(2026, 2, 15, 9), distance2d: 50, ascent: 50),
          _track(22, DateTime(2026, 12, 15, 9), distance2d: 200, ascent: 200),
        ],
        period: SummaryPeriodPreset.yearToDate,
        metric: DistanceCard.metric,
        now: DateTime(2026, 5, 15, 12),
      );

      expect(timeline.buckets, hasLength(12));
      expect(timeline.buckets.first.label, 'Jan');
      expect(timeline.buckets.last.label, 'Dec');
      expect(timeline.buckets.first.roundedValue, 100);
      expect(timeline.buckets.last.roundedValue, 0);
      expect(timeline.roundedTotalValue, 150);
      expect(
        service
            .visibleAverageValueForPeriod(
              period: SummaryPeriodPreset.yearToDate,
              buckets: timeline.buckets,
              referenceDate: DateTime(2026, 5, 15, 12),
            )
            .round(),
        30,
      );
    });

    test('opens the current week even with old tracks', () {
      final timeline = service.buildTimeline(
        tracks: [
          _track(1, DateTime(2021, 1, 1, 9), distance2d: 100, ascent: 10),
          _track(2, DateTime(2026, 5, 15, 9), distance2d: 200, ascent: 20),
        ],
        period: SummaryPeriodPreset.week,
        metric: DistanceCard.metric,
        now: DateTime(2026, 5, 15, 12),
      );

      expect(timeline.buckets, hasLength(7));
      expect(timeline.roundedTotalValue, 200);
    });

    test('visible summary math handles zero totals and period averages', () {
      final buckets = [
        SummaryBucket(
          start: DateTime(2026, 5, 1),
          endExclusive: DateTime(2026, 5, 2),
          label: '1',
          value: 70,
          trackCount: 0,
        ),
        SummaryBucket(
          start: DateTime(2026, 5, 2),
          endExclusive: DateTime(2026, 5, 3),
          label: '2',
          value: 35,
          trackCount: 0,
        ),
        SummaryBucket(
          start: DateTime(2026, 5, 8),
          endExclusive: DateTime(2026, 5, 9),
          label: '8',
          value: 105,
          trackCount: 0,
        ),
      ];

      expect(service.visibleTotalValue(const []), 0);
      expect(service.visibleAverageValue(const []), 0);
      expect(service.visibleAverageValue(buckets).round(), 70);
      expect(
        service
            .visibleAverageValueForPeriod(
              period: SummaryPeriodPreset.month,
              buckets: buckets,
            )
            .round(),
        105,
      );
    });
  });
}

GpxTrack _track(
  int id,
  DateTime? trackDate, {
  required double distance2d,
  required double? ascent,
}) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
    distance2d: distance2d,
    ascent: ascent,
  );
}

double? _trackAscent(GpxTrack track) => track.ascent;
double? _noValue(GpxTrack track) => null;
