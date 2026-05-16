import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/year_to_date_summary_service.dart';

void main() {
  group('YearToDateSummaryService', () {
    const service = YearToDateSummaryService();

    test('derives the selected year and yearly totals', () {
      final summary = service.buildSummary(
        tracks: [
          _track(
            10,
            DateTime.utc(2025, 12, 31, 12),
            distance2d: 4000,
            ascent: 70,
            peakIds: [1, 2],
          ),
          _track(
            20,
            DateTime.utc(2026, 1, 1, 12),
            distance2d: 1000,
            ascent: null,
            peakIds: [2, 2, 3],
          ),
          _track(
            30,
            DateTime.utc(2026, 6, 15, 12),
            distance2d: 2000,
            ascent: 50,
            peakIds: [3, 4],
          ),
          _track(
            40,
            DateTime.utc(2026, 6, 15, 15),
            distance2d: 3000,
            ascent: 75,
            peakIds: [5],
          ),
          _track(
            50,
            DateTime.utc(2027, 1, 1, 12),
            distance2d: 6000,
            ascent: 90,
            peakIds: [1],
          ),
          _track(60, null, distance2d: 9000, ascent: 100, peakIds: [6]),
        ],
        year: 2026,
      );

      expect(summary.year, 2026);
      expect(summary.distance2d, 6000);
      expect(summary.ascentMetres, 125);
      expect(summary.walkCount, 3);
      expect(summary.peaksClimbed, 4);
      expect(summary.newPeaksClimbed, 3);
    });

    test('returns zero totals for an empty year and shifts year locally', () {
      expect(service.initialYear(now: DateTime(2026, 5, 15, 12)), 2026);
      expect(service.shiftYear(year: 2026, forward: false), 2025);
      expect(service.shiftYear(year: 2025, forward: true), 2026);

      final summary = service.buildSummary(
        tracks: [
          _track(
            10,
            DateTime.utc(2026, 1, 1, 12),
            distance2d: 1000,
            ascent: 10,
            peakIds: [1],
          ),
        ],
        year: 2024,
      );

      expect(summary.distance2d, 0);
      expect(summary.ascentMetres, 0);
      expect(summary.walkCount, 0);
      expect(summary.peaksClimbed, 0);
      expect(summary.newPeaksClimbed, 0);
    });
  });
}

GpxTrack _track(
  int id,
  DateTime? trackDate, {
  required double distance2d,
  required List<int> peakIds,
  double? ascent,
}) {
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
    distance2d: distance2d,
    ascent: ascent,
  );
  track.peaks.addAll(
    peakIds.map(
      (peakId) => Peak(
        osmId: peakId,
        name: 'Peak $peakId',
        latitude: -42,
        longitude: 146,
      ),
    ),
  );
  return track;
}
