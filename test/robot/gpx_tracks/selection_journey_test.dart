import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
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
    robot.expectTrackInfoPanelVisible('Hover Track');

    await robot.closeTrackInfoPanel();
    robot.expectNoSelectedTrack();
    robot.expectNoTrackInfoPanel();

    await robot.hoverTrack();
    await robot.clickHoveredTrack();
    robot.expectSelectedTrack(7);
    robot.expectTrackInfoPanelVisible('Hover Track');

    await robot.zoomMapWithTrackpad();
    robot.expectSelectedTrack(7);
    robot.expectTrackInfoPanelVisible('Hover Track');

    await robot.clickMapBackground();
    expect(robot.mapTapActionPopup, findsOneWidget);
    robot.expectSelectedTrack(7);
    robot.expectNoHoveredTrack();
    robot.expectTrackInfoPanelVisible('Hover Track');

    await robot.hoverTrack();
    await robot.clickHoveredTrack();
    robot.expectSelectedTrack(7);
    robot.expectTrackInfoPanelVisible('Hover Track');

    await robot.toggleTracks();
    robot.expectTracksHidden();
    robot.expectNoSelectedTrack();
    robot.expectNoTrackInfoPanel();
  });

  testWidgets('background click does not select a merely nearby track', (
    tester,
  ) async {
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

    robot.expectNoSelectedTrack();
    await robot.moveMouseAway();
    robot.expectNoHoveredTrack();

    await robot.clickMapBackground();

    robot.expectNoSelectedTrack();
    robot.expectNoHoveredTrack();
    robot.expectNoTrackInfoPanel();
  });

  testWidgets(
    'selected track recalculation keeps its panel open with refreshed peaks',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final initialTrack = _trackFixture();
      final refreshedTrack = _trackFixture()
        ..peaks.add(
          Peak(
            osmId: 101,
            name: 'Refreshed Correlation Peak',
            latitude: -41.5,
            longitude: 146.5,
            elevation: 1000,
          ),
        );
      refreshedTrack.peakCorrelationProcessed = true;
      final notifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          showTracks: true,
          tracks: [initialTrack],
        ),
        selectedTrackRecalcTracks: [refreshedTrack],
      );
      final robot = GpxTracksRobot(
        tester,
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          showTracks: true,
          tracks: [initialTrack],
        ),
        notifier: notifier,
      );
      addTearDown(robot.dispose);
      await robot.pumpApp();

      await robot.hoverTrack();
      await robot.clickHoveredTrack();
      robot.expectSelectedTrack(7);
      robot.expectTrackInfoPanelVisible('Selected Track');
      expect(find.text('None'), findsOneWidget);

      await robot.requestSelectedTrackStatisticsRecalculation();
      expect(robot.selectedTrackRecalculateConfirm, findsOneWidget);
      await robot.confirmSelectedTrackStatisticsRecalculation();

      expect(notifier.selectedTrackRecalculationCallCount, 1);
      robot.expectSelectedTrackRecalculationSuccess();
      robot.expectTrackInfoPanelVisible('Selected Track');
      robot.expectTrackPeakCorrelation('Refreshed Correlation Peak');
    },
  );
}

GpxTrack _trackFixture() {
  return GpxTrack(
    gpxTrackId: 7,
    contentHash: 'selected-track',
    trackName: 'Selected Track',
    gpxFile: '<gpx></gpx>',
    displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
      [const LatLng(-41.5, 146.49), const LatLng(-41.5, 146.51)],
    ]),
  );
}
