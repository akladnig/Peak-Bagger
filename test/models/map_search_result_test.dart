import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/map_search_result.dart';

void main() {
  test('track result renders the canonical track date in local time', () {
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Arthurs Peak',
      trackDate: DateTime.utc(2026, 7, 22, 14),
      startDateTime: DateTime.utc(2026, 7, 22, 23, 39, 42),
    );

    final result = MapSearchResult.track(
      id: '173',
      title: track.trackName,
      subtitle: '',
      anchor: const LatLng(-43, 147),
      track: track,
    );

    expect(result.displayDate, track.trackDate!.toLocal());
  });
}
