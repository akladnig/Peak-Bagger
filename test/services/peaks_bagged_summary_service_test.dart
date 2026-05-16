import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peaks_bagged_summary_service.dart';

void main() {
  group('PeaksBaggedSummaryService', () {
    const service = PeaksBaggedSummaryService();

    test('counts unique peaks per track and skips null dates', () {
      final trackLate = _track(
        20,
        DateTime.utc(2026, 5, 15, 10),
        peakIds: [11, 11, 22],
      );
      final trackEarly = _track(
        10,
        DateTime.utc(2026, 5, 15, 10),
        peakIds: [11, 33],
      );
      final trackIgnored = _track(
        30,
        null,
        peakIds: [44],
      );

      final series = service.buildSeries([trackLate, trackEarly, trackIgnored]);

      expect(series.totalCountsByTrackId, {
        10: 2,
        20: 2,
      });
      expect(series.newCountsByTrackId, {
        10: 2,
        20: 1,
      });
      expect(series.totalValueOf(trackEarly), 2);
      expect(series.newValueOf(trackLate), 1);
      expect(series.totalValueOf(trackIgnored), isNull);
    });

    test('assigns new peaks by chronological first occurrence', () {
      final trackRight = _track(
        20,
        DateTime.utc(2026, 5, 15, 10),
        peakIds: [11, 22],
      );
      final trackLeft = _track(
        10,
        DateTime.utc(2026, 5, 15, 10),
        peakIds: [11, 33],
      );

      final series = service.buildSeries([trackRight, trackLeft]);

      expect(series.totalCountsByTrackId, {
        10: 2,
        20: 2,
      });
      expect(series.newCountsByTrackId, {
        10: 2,
        20: 1,
      });
    });
  });
}

GpxTrack _track(
  int id,
  DateTime? trackDate, {
  required List<int> peakIds,
}) {
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
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
