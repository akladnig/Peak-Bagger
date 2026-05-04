import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../harness/test_map_notifier.dart';
import 'gpx_tracks_robot.dart';

void main() {
  testWidgets('clicking a hovered track selects and clears it', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final robot = GpxTracksRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        tracks: [
          GpxTrack(
            gpxTrackId: 7,
            contentHash: 'hash',
            trackName: 'Hover Track',
            gpxFile: '<gpx></gpx>',
            displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
              [const LatLng(-41.5, 146.49), const LatLng(-41.5, 146.51)],
            ]),
          ),
        ],
      ),
      notifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          showTracks: true,
          tracks: [
            GpxTrack(
              gpxTrackId: 7,
              contentHash: 'hash',
              trackName: 'Hover Track',
              gpxFile: '<gpx></gpx>',
              displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
                [const LatLng(-41.5, 146.49), const LatLng(-41.5, 146.51)],
              ]),
            ),
          ],
        ),
      ),
    );
    addTearDown(robot.dispose);
    await robot.pumpApp();

    await robot.hoverTrack();
    robot.expectHoveredTrack(7);

    await robot.clickHoveredTrack();
    robot.expectSelectedTrack(7);

    await robot.zoomMapWithTrackpad();
    robot.expectSelectedTrack(7);

    await robot.clickMapBackground();
    robot.expectNoSelectedTrack();
    robot.expectNoHoveredTrack();

    await robot.hoverTrack();
    await robot.clickHoveredTrack();
    robot.expectSelectedTrack(7);

    await robot.toggleTracks();
    robot.expectTracksHidden();
    robot.expectNoSelectedTrack();
  });
}
