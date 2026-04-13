import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

import 'gpx_tracks_robot.dart';

void main() {
  testWidgets('import happy path then toggle hides and shows tracks', (
    tester,
  ) async {
    final robot = GpxTracksRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        tracks: [
          GpxTrack(
            contentHash: 'hash',
            trackName: 'Mt Anne',
            trackDate: DateTime(2024, 1, 15),
            gpxFile: '<gpx></gpx>',
            displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
              [
                const LatLng(-42.1234, 146.1234),
                const LatLng(-42.2234, 146.2234),
              ],
            ]),
          ),
        ],
      ),
    );
    await robot.pumpApp();

    robot.expectTracksImportedAndVisible();

    await robot.toggleTracks();
    robot.expectTracksHidden();

    await robot.toggleTracks();
    robot.expectTracksShown();
  });
}
