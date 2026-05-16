import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/elevation_summary_service.dart';

void main() {
  group('ElevationSummaryService', () {
    test('builds available daily week buckets and sums ascent', () {
      final service = ElevationSummaryService();
      final now = DateTime(2026, 5, 15, 12);

      final timeline = service.buildTimeline(
        tracks: [
          _track(10, DateTime(2026, 5, 15, 9), ascent: 120),
          _track(20, DateTime(2026, 5, 13, 9), ascent: 80),
          _track(21, DateTime(2026, 5, 13, 17), ascent: 20),
          _track(30, null, ascent: 50),
          _track(40, DateTime(2026, 5, 14, 9), ascent: null),
        ],
        period: ElevationPeriodPreset.week,
        now: now,
      );

      expect(timeline.buckets, hasLength(3));
      expect(timeline.buckets.last.label, 'Fri');
      expect(timeline.buckets.last.roundedAscentMetres, 120);
      expect(timeline.buckets.first.label, 'Wed');
      expect(timeline.buckets.first.roundedAscentMetres, 100);
      expect(timeline.totalMetres, 220);
      expect(timeline.averageMetres, 73);
    });

    test('builds month buckets with zero buckets included in average', () {
      final service = ElevationSummaryService();
      final now = DateTime(2026, 5, 15, 12);

      final timeline = service.buildTimeline(
        tracks: [
          _track(10, DateTime(2026, 5, 1, 9), ascent: 100),
          _track(20, DateTime(2026, 5, 3, 9), ascent: 50),
        ],
        period: ElevationPeriodPreset.month,
        now: now,
      );

      expect(timeline.buckets, hasLength(31));
      expect(timeline.buckets.first.label, '1');
      expect(timeline.buckets.last.label, '31');
      expect(timeline.buckets[2].roundedAscentMetres, 50);
      expect(timeline.totalMetres, 150);
      expect(timeline.averageMetres, 5);
    });

    test(
      'builds weekly buckets for the 3 month window with repeated month labels',
      () {
        final service = ElevationSummaryService();
        final now = DateTime(2026, 5, 15, 12);

        final timeline = service.buildTimeline(
          tracks: [
            _track(10, DateTime(2026, 3, 4, 9), ascent: 100),
            _track(20, DateTime(2026, 4, 20, 9), ascent: 50),
          ],
          period: ElevationPeriodPreset.last3Months,
          now: now,
        );

        expect(timeline.buckets, hasLength(11));
        expect(
          timeline.buckets.where((bucket) => bucket.label == 'Mar'),
          isNotEmpty,
        );
        expect(
          timeline.buckets.where((bucket) => bucket.label == 'Apr'),
          isNotEmpty,
        );
        expect(timeline.totalMetres, 150);
      },
    );

    test('builds 26 weekly buckets for the 6 month window', () {
      final service = ElevationSummaryService();
      final now = DateTime(2026, 5, 15, 12);

      final timeline = service.buildTimeline(
        tracks: [
          _track(10, DateTime(2026, 1, 10, 9), ascent: 100),
          _track(20, DateTime(2026, 4, 20, 9), ascent: 50),
        ],
        period: ElevationPeriodPreset.last6Months,
        now: now,
      );

      expect(timeline.buckets, hasLength(20));
      expect(
        timeline.buckets.where((bucket) => bucket.label == 'Jan'),
        isNotEmpty,
      );
      expect(
        timeline.buckets.where((bucket) => bucket.label == 'Apr'),
        isNotEmpty,
      );
      expect(timeline.totalMetres, 150);
    });

    test('builds yearly buckets for all time', () {
      final service = ElevationSummaryService();
      final now = DateTime(2026, 5, 15, 12);

      final timeline = service.buildTimeline(
        tracks: [
          _track(10, DateTime(2024, 6, 1, 9), ascent: 100),
          _track(20, DateTime(2026, 5, 1, 9), ascent: 50),
        ],
        period: ElevationPeriodPreset.allTime,
        now: now,
      );

      expect(
        timeline.buckets.map((bucket) => bucket.label),
        containsAll(['2024', '2025', '2026']),
      );
      expect(timeline.totalMetres, 150);
    });

    test('shifts window start by half the visible range and clamps', () {
      final service = ElevationSummaryService();

      expect(
        service.shiftWindowStartIndex(
          currentStartIndex: 10,
          visibleBucketCount: 6,
          bucketCount: 20,
          forward: true,
        ),
        13,
      );
      expect(
        service.shiftWindowStartIndex(
          currentStartIndex: 2,
          visibleBucketCount: 6,
          bucketCount: 20,
          forward: false,
        ),
        0,
      );
      expect(
        service.visibleAverageMetres([
          ElevationBucket(
            start: DateTime(2026),
            endExclusive: DateTime(2026, 1, 2),
            label: 'A',
            ascentMetres: 1,
            trackCount: 0,
          ),
          ElevationBucket(
            start: DateTime(2026, 1, 2),
            endExclusive: DateTime(2026, 1, 3),
            label: 'B',
            ascentMetres: 2,
            trackCount: 0,
          ),
        ]),
        2,
      );
      expect(
        service.visibleAverageMetresForPeriod(
          period: ElevationPeriodPreset.month,
          buckets: [
            ElevationBucket(
              start: DateTime(2026, 5, 1),
              endExclusive: DateTime(2026, 5, 2),
              label: '1',
              ascentMetres: 70,
              trackCount: 0,
            ),
            ElevationBucket(
              start: DateTime(2026, 5, 2),
              endExclusive: DateTime(2026, 5, 3),
              label: '2',
              ascentMetres: 35,
              trackCount: 0,
            ),
            ElevationBucket(
              start: DateTime(2026, 5, 8),
              endExclusive: DateTime(2026, 5, 9),
              label: '8',
              ascentMetres: 105,
              trackCount: 0,
            ),
          ],
        ),
        105,
      );
      expect(
        service.visibleAverageMetresForPeriod(
          period: ElevationPeriodPreset.last3Months,
          buckets: [
            ElevationBucket(
              start: DateTime(2026, 3, 1),
              endExclusive: DateTime(2026, 3, 8),
              label: 'Mar',
              ascentMetres: 100,
              trackCount: 0,
            ),
            ElevationBucket(
              start: DateTime(2026, 3, 8),
              endExclusive: DateTime(2026, 3, 15),
              label: 'Mar',
              ascentMetres: 50,
              trackCount: 0,
            ),
            ElevationBucket(
              start: DateTime(2026, 4, 1),
              endExclusive: DateTime(2026, 4, 8),
              label: 'Apr',
              ascentMetres: 250,
              trackCount: 0,
            ),
          ],
        ),
        200,
      );
    });
  });
}

GpxTrack _track(int id, DateTime? trackDate, {double? ascent}) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
    ascent: ascent,
  );
}
