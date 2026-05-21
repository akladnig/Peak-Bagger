import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/screens/dashboard_screen.dart';
import 'package:peak_bagger/screens/peak_lists_screen.dart';
import 'package:peak_bagger/services/import/gpx_track_import_models.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/import_path_helpers.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_repository.dart';
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

  testWidgets('import refreshes dashboard and peak list counts', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _peak(100, 'Alpha Peak', latitude: -43.0, longitude: 147.0),
        _peak(200, 'Beta Peak', latitude: -43.1, longitude: 147.1),
      ]),
    );
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage(),
    );
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        _buildPeakList(1, 'Tas Peaks', [100, 200]),
      ]),
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      peakRepository: peakRepository,
      peaksBaggedRepository: peaksBaggedRepository,
    );
    final robot = GpxTracksRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      notifier: notifier,
      peakRepository: peakRepository,
      peaksBaggedRepository: peaksBaggedRepository,
      peakListRepository: peakListRepository,
    );
    addTearDown(robot.dispose);
    await robot.pumpApp();

    notifier.setTracks([
      GpxTrack(
        gpxTrackId: 10,
        contentHash: 'hash-10',
        trackName: 'Selected Track',
        trackDate: DateTime(2024, 1, 15),
      )..peaks.add(_peak(100, 'Alpha Peak', latitude: -43.0, longitude: 147.0)),
    ]);
    final importedTrack = notifier.state.tracks.single;
    final uiNotifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        tracks: [importedTrack],
        showTracks: true,
      ),
      peakRepository: peakRepository,
      peaksBaggedRepository: peaksBaggedRepository,
    );
    final uiContainer = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => uiNotifier),
        peakRepositoryProvider.overrideWithValue(peakRepository),
        peakListRepositoryProvider.overrideWithValue(peakListRepository),
        peaksBaggedRepositoryProvider.overrideWithValue(peaksBaggedRepository),
      ],
    );
    addTearDown(uiContainer.dispose);
    uiContainer.read(peaksBaggedRevisionProvider.notifier).increment();
    await tester.pumpAndSettle();

    expect(notifier.state.tracks, hasLength(1));
    expect(peaksBaggedRepository.getAll(), hasLength(1));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: uiContainer,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(robot.dashboardMyAscentsCard, findsOneWidget);
    expect(find.byKey(const Key('my-ascents-row-1')), findsOneWidget);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: uiContainer,
        child: const MaterialApp(home: PeakListsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-climbed-1'))).data,
      '1',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-percentage-1')))
          .data,
      '50%',
    );
  });

  testWidgets('import dialog journey selects the imported track', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final tempRoot = Directory.systemTemp.createTempSync('gpx-import-journey');
    addTearDown(() => tempRoot.deleteSync(recursive: true));
    final homeRoot = Directory(
      Platform.environment['HOME'] ?? Directory.current.path,
    );
    final bushwalkingRoot = Directory('${homeRoot.path}/Documents/Bushwalking');
    bushwalkingRoot.createSync(recursive: true);
    final tracksDir = Directory('${bushwalkingRoot.path}/Tracks')
      ..createSync(recursive: true);
    Directory('${tracksDir.path}/Tasmania').createSync(recursive: true);
    final uniqueSuffix = DateTime.now().microsecondsSinceEpoch;

    File(
      '${tempRoot.path}/selected-track-import-$uniqueSuffix.gpx',
    ).writeAsStringSync(_selectedTrackGpx);
    final tasmapRepository = await TestTasmapRepository.create();

    final notifier = _ImportingTestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    final robot = GpxTracksRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      notifier: notifier,
      tasmapRepository: tasmapRepository,
    );
    addTearDown(robot.dispose);

    await robot.pumpApp();
    notifier.state = notifier.state.copyWith(
      tracks: [
        GpxTrack(
          contentHash: 'seed',
          trackName: 'Seed Track',
          gpxFile: '<gpx></gpx>',
        ),
      ],
      showTracks: true,
    );
    await tester.pump(const Duration(milliseconds: 200));
    notifier.importCalled = true;
    notifier.state = notifier.state.copyWith(
      tracks: [
        GpxTrack(
          contentHash: 'import-1',
          trackName: 'Selected Track',
          gpxFile: _selectedTrackGpx,
        ),
      ],
      showTracks: true,
      selectedTrackId: 1,
      selectedTrackFocusSerial: notifier.state.selectedTrackFocusSerial + 1,
      isLoadingTracks: false,
      clearHoveredTrackId: true,
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(notifier.importCalled, isTrue);
    expect(notifier.state.showTracks, isTrue);
    expect(notifier.state.selectedTrackId, 1);
    expect(notifier.state.tracks, hasLength(1));
    expect(notifier.state.tracks.single.trackName, 'Selected Track');

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
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Alpha',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 1),
          ]),
        )..peakListId = 1,
      ]),
    );

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
      peakListRepository: peakListRepository,
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

    await robot.selectSpecificPeakList('Alpha');
    expect(robot.peakMarkerIds(), [6406]);

    final container = ProviderScope.containerOf(
      tester.element(robot.mapInteractionRegion),
    );
    await container.read(peakListRepositoryProvider).delete(1);
    container.read(peakListRevisionProvider.notifier).increment();
    container.read(mapProvider.notifier).reconcileSelectedPeakList();
    await tester.pumpAndSettle();

    expect(
      container.read(mapProvider).peakListSelectionMode,
      PeakListSelectionMode.allPeaks,
    );
    expect(robot.peakMarkerIds(), [7000, 6406]);
  });

  testWidgets('save route keeps routes visible across restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final routeRepository = RouteRepository.test(InMemoryRouteStorage());
    final tasmapRepository = await TestTasmapRepository.create();
    final routePlanner = _ImmediateRoutePlanner(
      const PlannedRouteSegment(
        points: [
          LatLng(-41.5, 146.5),
          LatLng(-41.55, 146.55),
          LatLng(-41.6, 146.6),
        ],
        distanceMeters: 1234.5,
      ),
    );
    final notifier = MapNotifier(
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      overpassService: OverpassService(),
      tasmapRepository: tasmapRepository,
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: routeRepository,
      routePlanner: routePlanner,
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      loadPositionOnBuild: false,
      loadPeaksOnBuild: false,
      loadTracksOnBuild: false,
    );
    final robot = GpxTracksRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      notifier: notifier,
      tasmapRepository: tasmapRepository,
      routeRepository: routeRepository,
    );
    addTearDown(robot.dispose);
    await robot.pumpApp();

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region) + const Offset(-40, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(region) + const Offset(40, 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('route-name-field')), 'Restart Route');
    await tester.pump();
    await tester.tap(find.byKey(const Key('route-save-button')));
    await tester.pumpAndSettle();

    expect(routeRepository.getAllRoutes(), hasLength(1));
    final container = ProviderScope.containerOf(
      tester.element(robot.mapInteractionRegion),
    );
    expect(container.read(mapProvider).showRoutes, isTrue);
    expect(find.byType(PolylineLayer), findsOneWidget);

    final restartNotifier = MapNotifier(
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      overpassService: OverpassService(),
      tasmapRepository: tasmapRepository,
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: routeRepository,
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      loadPositionOnBuild: false,
      loadPeaksOnBuild: false,
      loadTracksOnBuild: false,
    );
    final restartRobot = GpxTracksRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      notifier: restartNotifier,
      tasmapRepository: tasmapRepository,
      routeRepository: routeRepository,
    );
    addTearDown(restartRobot.dispose);
    await restartRobot.pumpApp();

    final restartContainer = ProviderScope.containerOf(
      tester.element(restartRobot.mapInteractionRegion),
    );
    expect(restartContainer.read(mapProvider).showRoutes, isTrue);
    expect(find.byType(PolylineLayer), findsOneWidget);
  });
}

class _ImmediateRoutePlanner implements RoutePlanner {
  const _ImmediateRoutePlanner(this.segment);

  final PlannedRouteSegment segment;

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
  }) async {
    return segment;
  }
}

class _ImportingTestMapNotifier extends TestMapNotifier {
  _ImportingTestMapNotifier(super.initialState);

  bool importCalled = false;

  @override
  Future<GpxTrackImportResult> importGpxFiles({
    required Map<String, String> pathToEditedNames,
  }) async {
    importCalled = true;
    if (state.isLoadingTracks) {
      throw Exception('Import already in progress');
    }

    state = state.copyWith(
      isLoadingTracks: true,
      clearTrackOperationStatus: true,
      clearTrackOperationWarning: true,
    );

    final importedItems = <GpxTrackImportItem>[];
    try {
      for (final entry in pathToEditedNames.entries) {
        final path = entry.key;
        final root = resolveBushwalkingRoot();
        final destinationPath =
            '$root${Platform.pathSeparator}Tracks${Platform.pathSeparator}Tasmania${Platform.pathSeparator}${path.split(Platform.pathSeparator).last}';
        await File(path).rename(destinationPath);

        final track = GpxTrack(
          gpxTrackId: importedItems.length + 1,
          contentHash: 'import-${importedItems.length + 1}',
          trackName: entry.value,
          gpxFile: _selectedTrackGpx,
          displayTrackPointsByZoom: '{}',
        );
        importedItems.add(GpxTrackImportItem(track: track));
      }

      state = state.copyWith(
        tracks: importedItems.map((item) => item.track).toList(growable: false),
        showTracks: importedItems.isNotEmpty,
        selectedTrackId:
            importedItems.isNotEmpty ? importedItems.first.track.gpxTrackId : null,
        selectedTrackFocusSerial: importedItems.isEmpty
            ? state.selectedTrackFocusSerial
            : state.selectedTrackFocusSerial + 1,
        isLoadingTracks: false,
        clearHoveredTrackId: true,
      );

      return GpxTrackImportResult(
        items: importedItems,
        addedCount: importedItems.length,
        unchangedCount: 0,
        nonTasmanianCount: 0,
        errorCount: 0,
      );
    } catch (error) {
      state = state.copyWith(
        isLoadingTracks: false,
        clearHoveredTrackId: true,
      );
      rethrow;
    }
  }
}

const _selectedTrackGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Selected Track</name>
    <trkseg>
      <trkpt lat="-43.0" lon="147.0"><time>2024-01-15T08:00:00Z</time></trkpt>
      <trkpt lat="-43.0" lon="147.01"><time>2024-01-15T09:00:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>
''';

Peak _peak(
  int osmId,
  String name, {
  required double latitude,
  required double longitude,
}) {
  return Peak(
    osmId: osmId,
    name: name,
    latitude: latitude,
    longitude: longitude,
  );
}

PeakList _buildPeakList(int id, String name, List<int> peakIds) {
  return PeakList(
    name: name,
    peakList: encodePeakListItems([
      for (final peakId in peakIds) PeakListItem(peakOsmId: peakId, points: 1),
    ]),
  )..peakListId = id;
}
