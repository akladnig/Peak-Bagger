import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/date_formatters.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/latest_walk_summary.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

void main() {
  test('selects newest track by startDateTime', () {
    final summary = LatestWalkSummary.fromTracks([
      _track(
        10,
        DateTime.utc(2026, 5, 14, 10),
        segments: [
          [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
        ],
      ),
      _track(
        20,
        DateTime.utc(2026, 5, 15, 10),
        segments: [
          [const LatLng(-41.6, 146.6), const LatLng(-41.7, 146.7)],
        ],
      ),
    ]);

    expect(summary.track?.gpxTrackId, 20);
    expect(summary.title, 'Track 20');
  });

  test('ignores tracks without startDateTime', () {
    final summary = LatestWalkSummary.fromTracks([
      _track(
        10,
        null,
        segments: [
          [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
        ],
      ),
      _track(
        20,
        DateTime.utc(2026, 5, 15, 10),
        segments: [
          [const LatLng(-41.6, 146.6), const LatLng(-41.7, 146.7)],
        ],
      ),
    ]);

    expect(summary.track?.gpxTrackId, 20);
  });

  test('breaks ties with highest track id', () {
    final sharedStart = DateTime.utc(2026, 5, 15, 10);
    final summary = LatestWalkSummary.fromTracks([
      _track(
        10,
        sharedStart,
        segments: [
          [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
        ],
      ),
      _track(
        20,
        sharedStart,
        segments: [
          [const LatLng(-41.6, 146.6), const LatLng(-41.7, 146.7)],
        ],
      ),
    ]);

    expect(summary.track?.gpxTrackId, 20);
  });

  test('orders tracks newest first and exposes paging bounds', () {
    final ordered = LatestWalkSummary.orderedTracks([
      _track(
        10,
        DateTime.utc(2026, 5, 14, 10),
        segments: [
          [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
        ],
      ),
      _track(
        20,
        DateTime.utc(2026, 5, 15, 10),
        segments: [
          [const LatLng(-41.6, 146.6), const LatLng(-41.7, 146.7)],
        ],
      ),
      _track(
        30,
        DateTime.utc(2026, 5, 13, 10),
        segments: [
          [const LatLng(-41.8, 146.8), const LatLng(-41.9, 146.9)],
        ],
      ),
      _track(40, null),
    ]);

    expect(ordered.map((track) => track.gpxTrackId), [20, 10, 30]);
    expect(LatestWalkSummary.indexOfTrackId(ordered, 20), 0);
    expect(LatestWalkSummary.indexOfTrackId(ordered, 10), 1);
    expect(LatestWalkSummary.previousTrack(ordered, 0), isNull);
    expect(LatestWalkSummary.nextTrack(ordered, 0)?.gpxTrackId, 10);
    expect(LatestWalkSummary.nextTrack(ordered, 2), isNull);
  });

  test('shows empty when newest track has no usable geometry', () {
    final summary = LatestWalkSummary.fromTracks([
      _track(
        10,
        DateTime.utc(2026, 5, 14, 10),
        segments: [
          [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
        ],
      ),
      _track(20, DateTime.utc(2026, 5, 15, 10)),
    ]);

    expect(summary.isEmpty, isTrue);
    expect(summary.track, isNull);
  });

  test('formats date distance and ascent from selected track', () {
    final summary = LatestWalkSummary.fromTracks([
      _track(
        10,
        DateTime.utc(2026, 1, 7, 23, 30),
        segments: [
          [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
        ],
        distance2d: 12400,
        distance3d: 12700,
        ascent: null,
      ),
    ]);

    expect(summary.dateText, 'Thu, 8 Jan 2026');
    expect(summary.distanceText, '12.4 km / 12.7 km');
    expect(summary.ascentText, 'Unknown');
  });

  test('uses unknown date fallback for a track without a start date', () {
    final summary = LatestWalkSummary.fromTrack(
      _track(
        10,
        null,
        segments: [
          [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
        ],
      ),
    );

    expect(summary.isEmpty, isFalse);
    expect(summary.dateText, 'Unknown');
    expect(formatTrackDateShortMonth(null), 'Unknown');
  });

  for (final (start, expectedDate) in [
    (DateTime.utc(2026, 10, 14, 23, 30), 'Thu, 15 Oct 2026'),
    (DateTime.utc(2026, 12, 31, 23, 30), 'Fri, 1 Jan 2027'),
  ]) {
    test('displays $start in Hobart without changing Track data', () {
      expect(start.toLocal().timeZoneOffset, const Duration(hours: 11));
      // Also check standard time so a fixed UTC+11 runner cannot pass.
      expect(
        DateTime.utc(2026, 7, 1).toLocal().timeZoneOffset,
        const Duration(hours: 10),
      );
      final track =
          _track(
              10,
              start,
              segments: [
                [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
              ],
            )
            ..trackDate = DateTime.utc(2020, 12, 31)
            ..endDateTime = start.add(const Duration(hours: 2));
      final before = track.toMap();

      final summary = LatestWalkSummary.fromTracks([track]);

      expect(summary.dateText, expectedDate);
      expect(summary.track, same(track));
      expect(track.toMap(), before);
      expect(formatTrackDate(track.trackDate), 'Thu, 31 December 2020');
      expect(formatTrackDateShortMonth(track.trackDate), 'Thu, 31 Dec 2020');
    });
  }

  test('formats mixed-unit combined distance from selected track', () {
    final summary = LatestWalkSummary.fromTracks([
      _track(
        10,
        DateTime.utc(2026, 1, 7, 23, 30),
        segments: [
          [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
        ],
        distance2d: 850,
        distance3d: 900,
      ),
    ]);

    expect(summary.distanceText, '850 m / 900 m');
  });
}

GpxTrack _track(
  int id,
  DateTime? startDateTime, {
  List<List<LatLng>> segments = const [],
  double distance2d = 12400,
  double distance3d = 12400,
  double? ascent = 638,
}) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: startDateTime,
    startDateTime: startDateTime,
    distance2d: distance2d,
    distance3d: distance3d,
    ascent: ascent,
    gpxFile: segments.isEmpty ? '' : '<gpx></gpx>',
    displayTrackPointsByZoom: segments.isEmpty
        ? '{}'
        : TrackDisplayCacheBuilder.buildJson(segments),
  );
}
