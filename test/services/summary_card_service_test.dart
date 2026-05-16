import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/widgets/dashboard/distance_card.dart';

void main() {
  group('SummaryCardService', () {
    const service = SummaryCardService();

    test('builds available daily week buckets for distance metric', () {
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

      expect(timeline.buckets, hasLength(3));
      expect(timeline.buckets.last.label, 'Fri');
      expect(timeline.buckets.last.roundedValue, 1200);
      expect(timeline.buckets.first.label, 'Wed');
      expect(timeline.buckets.first.roundedValue, 1000);
      expect(timeline.roundedTotalValue, 2200);
      expect(timeline.roundedAverageValue, 733);
    });

    test('builds month buckets with zero buckets included in average', () {
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
