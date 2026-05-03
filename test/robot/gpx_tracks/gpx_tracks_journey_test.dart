import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';
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
          startDateTime: DateTime.utc(2024, 1, 15, 8),
          endDateTime: DateTime.utc(2024, 1, 15, 9),
          totalTimeMillis: 3600000,
          movingTime: 3000000,
          restingTime: 300000,
          pausedTime: 300000,
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
      ).read(mapProvider).tracks.first.totalTimeMillis,
      3600000,
    );
    expect(
      ProviderScope.containerOf(
        tester.element(robot.recalcStatsTile),
      ).read(mapProvider).tracks.first.pausedTime,
      300000,
    );
    expect(
      ProviderScope.containerOf(
        tester.element(robot.recalcStatsTile),
      ).read(mapProvider).showTracks,
      isTrue,
    );
  });

  testWidgets('startup warning opens settings and shows mirrored detail', (
    tester,
  ) async {
    final robot = GpxTracksRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        trackImportError:
            'Failed to rebuild bagged peak history from stored tracks.',
      ),
      notifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          trackImportError:
              'Failed to rebuild bagged peak history from stored tracks.',
        ),
        startupBackfillWarningMessage:
            'Bagged history is stale. Open Settings to rebuild it.',
      ),
    );
    addTearDown(robot.dispose);
    await robot.pumpApp();

    await robot.openSettingsFromStartupWarning();

    robot.expectMirroredStartupFailureDetail(
      'Failed to rebuild bagged peak history from stored tracks.',
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
    await ProviderScope.containerOf(
      tester.element(robot.filterSettingsTile),
    ).read(gpxFilterSettingsProvider.notifier).setHampelWindow(9);

    expect(
      ProviderScope.containerOf(
        tester.element(robot.filterSettingsTile),
      ).read(gpxFilterSettingsProvider).value!.hampelWindow,
      9,
    );
  });

  testWidgets('disabled filter selections persist and disable windows', (
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
    await robot.setOutlierFilterNone();
    await robot.setElevationSmootherNone();
    await robot.setPositionSmootherNone();

    expect(
      ProviderScope.containerOf(
        tester.element(robot.filterSettingsTile),
      ).read(gpxFilterSettingsProvider).value!,
      isA<GpxFilterConfig>()
          .having(
            (config) => config.outlierFilter,
            'outlierFilter',
            GpxTrackOutlierFilter.none,
          )
          .having(
            (config) => config.elevationSmoother,
            'elevationSmoother',
            GpxTrackElevationSmoother.none,
          )
          .having(
            (config) => config.positionSmoother,
            'positionSmoother',
            GpxTrackPositionSmoother.none,
          ),
    );

    expect(
      tester.widget<DropdownButtonFormField<int>>(robot.hampelWindowField)
          .onChanged,
      isNull,
    );
    expect(
      tester.widget<DropdownButtonFormField<int>>(robot.elevationWindowField)
          .onChanged,
      isNull,
    );
    expect(
      tester.widget<DropdownButtonFormField<int>>(robot.positionWindowField)
          .onChanged,
      isNull,
    );

    router.go('/map');
    await tester.pumpAndSettle();
    await robot.openSettings();
    await robot.openFilterSettings();

    expect(find.textContaining('Outlier Filter: None'), findsOneWidget);
    expect(
      ProviderScope.containerOf(
        tester.element(robot.filterSettingsTile),
      ).read(gpxFilterSettingsProvider).value!,
      isA<GpxFilterConfig>()
          .having(
            (config) => config.outlierFilter,
            'outlierFilter',
            GpxTrackOutlierFilter.none,
          )
          .having(
            (config) => config.elevationSmoother,
            'elevationSmoother',
            GpxTrackElevationSmoother.none,
          )
          .having(
            (config) => config.positionSmoother,
            'positionSmoother',
            GpxTrackPositionSmoother.none,
          ),
    );
  });

  testWidgets('peak correlation threshold persists from the settings screen', (
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
    await robot.openPeakCorrelationSettings();
    await robot.setPeakCorrelationDistance(70);

    expect(
      robot.currentPeakCorrelationDistance(
        tester.element(robot.peakCorrelationDistanceField),
      ),
      70,
    );
  });

  testWidgets('peak layer toggles and shows correlated markers', (
    tester,
  ) async {
    final robot = GpxTracksRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        showTracks: false,
        peaks: [
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
          Peak(
            osmId: 7000,
            name: 'Other Peak',
            latitude: -42.9,
            longitude: 147.1,
          ),
        ],
        tracks: [
          GpxTrack(
              contentHash: 'hash',
              trackName: 'Correlated Track',
              gpxFile: '<gpx></gpx>',
              displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
                [const LatLng(-43.0, 147.0), const LatLng(-42.9, 147.1)],
              ]),
              peakCorrelationProcessed: true,
            )
            ..peaks.add(
              Peak(
                osmId: 6406,
                name: 'Bonnet Hill',
                latitude: -43.0,
                longitude: 147.0,
              ),
            ),
        ],
      ),
      notifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 12,
          basemap: Basemap.tracestrack,
          showTracks: false,
          peaks: [
            Peak(
              osmId: 6406,
              name: 'Bonnet Hill',
              latitude: -43.0,
              longitude: 147.0,
            ),
            Peak(
              osmId: 7000,
              name: 'Other Peak',
              latitude: -42.9,
              longitude: 147.1,
            ),
          ],
          tracks: [
            GpxTrack(
                contentHash: 'hash',
                trackName: 'Correlated Track',
                gpxFile: '<gpx></gpx>',
                displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
                  [const LatLng(-43.0, 147.0), const LatLng(-42.9, 147.1)],
                ]),
                peakCorrelationProcessed: true,
              )
              ..peaks.add(
                Peak(
                  osmId: 6406,
                  name: 'Bonnet Hill',
                  latitude: -43.0,
                  longitude: 147.0,
                ),
              ),
          ],
        ),
        correlatedPeakIds: {6406},
      ),
    );
    addTearDown(robot.dispose);
    await robot.pumpApp();

    robot.expectPeaksShown();

    final assets = robot.peakMarkerAssetNames();
    expect(assets, contains('SvgAssetLoader(assets/peak_marker_ticked.svg)'));
    expect(assets, contains('SvgAssetLoader(assets/peak_marker.svg)'));

    await robot.toggleTracks();
    robot.expectTracksShown();

    await robot.selectNoPeaks();
    robot.expectPeaksHidden();

    await robot.selectAllPeaks();
    robot.expectPeaksShown();
  });
}
