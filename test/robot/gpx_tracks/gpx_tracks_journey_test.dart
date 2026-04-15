import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../harness/test_map_notifier.dart';
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
    addTearDown(robot.dispose);
    await robot.pumpApp();

    robot.expectTracksImportedAndVisible();

    await robot.toggleTracks();
    robot.expectTracksHidden();

    await robot.toggleTracks();
    robot.expectTracksShown();
  });

  testWidgets('hovering visible track updates hover state then clears', (
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
            gpxTrackId: 7,
            contentHash: 'hash',
            trackName: 'Hover Track',
            trackDate: DateTime(2024, 1, 15),
            gpxFile: '<gpx></gpx>',
            displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
              [const LatLng(-41.5, 146.49), const LatLng(-41.5, 146.51)],
            ]),
          ),
        ],
      ),
    );
    addTearDown(robot.dispose);
    await robot.pumpApp();

    await robot.hoverTrack();
    robot.expectHoveredTrack(7);

    await robot.moveMouseAway();
    robot.expectNoHoveredTrack();
  });

  testWidgets('recalculate track statistics from settings keeps tracks visible', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        tracks: const [],
      ),
      recalcTracks: [
        GpxTrack(
          contentHash: 'hash',
          trackName: 'Mt Anne',
          trackDate: DateTime(2024, 1, 15),
          gpxFile: '<gpx></gpx>',
          distance2d: 1234,
          distance3d: 0,
          distanceToPeak: 234,
          distanceFromPeak: 1000,
          lowestElevation: 100,
          highestElevation: 250,
          ascent: 100,
          descent: 0,
          startElevation: 100,
          endElevation: 250,
          elevationProfile:
              '[{"segmentIndex":0,"pointIndex":0,"distanceMeters":0.0,"elevationMeters":100.0,"timeLocal":null}]',
        ),
      ],
    );
    final robot = GpxTracksRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        tracks: const [],
      ),
      notifier: notifier,
    );
    addTearDown(robot.dispose);
    await robot.pumpApp();

    await robot.openSettings();
    await robot.recalculateTrackStatistics();

    robot.expectTrackStatisticsDialog(updatedCount: 1, skippedCount: 0);
    expect(
      ProviderScope.containerOf(
        tester.element(robot.recalcStatsTile),
      ).read(mapProvider).tracks,
      hasLength(1),
    );
    expect(
      ProviderScope.containerOf(
        tester.element(robot.recalcStatsTile),
      ).read(mapProvider).tracks.first.startElevation,
      100,
    );
    expect(
      ProviderScope.containerOf(
        tester.element(robot.recalcStatsTile),
      ).read(mapProvider).showTracks,
      isTrue,
    );
  });

  testWidgets('filter settings persist from the settings screen', (
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
        tracks: const [],
      ),
    );
    addTearDown(robot.dispose);
    await robot.pumpApp();

    await robot.openSettings();
    await robot.openFilterSettings();
    await robot.setHampelWindow(9);

    expect(
      ProviderScope.containerOf(
        tester.element(robot.filterSettingsTile),
      ).read(gpxFilterSettingsProvider).value!.hampelWindow,
      9,
    );
  });
}
