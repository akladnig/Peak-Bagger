import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';
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

  test('shows empty when newest track has no usable geometry', () {
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
      ),
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
        ascent: null,
      ),
    ]);

    expect(summary.dateText, formatTrackDate(DateTime.utc(2026, 1, 7, 23, 30)));
    expect(summary.distanceText, '12.4 km');
    expect(summary.ascentText, 'Unknown');
  });
}

GpxTrack _track(
  int id,
  DateTime? startDateTime, {
  List<List<LatLng>> segments = const [],
  double distance2d = 12400,
  double? ascent = 638,
}) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: startDateTime,
    startDateTime: startDateTime,
    distance2d: distance2d,
    ascent: ascent,
    gpxFile: segments.isEmpty ? '' : '<gpx></gpx>',
    displayTrackPointsByZoom: segments.isEmpty
        ? '{}'
        : TrackDisplayCacheBuilder.buildJson(segments),
  );
}
