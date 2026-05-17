import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_repository.dart';
import 'dashboard_robot.dart';

void main() {
  testWidgets('dashboard journey reorders cards and restores layout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final robot = DashboardRobot(tester);

    final firstContainer = await _createContainer(
      notifier: TestMapNotifier(
        const MapState(
          center: LatLng(-41.5, 146.5),
          zoom: 12,
          basemap: Basemap.tracestrack,
        ),
      ),
    );
    addTearDown(firstContainer.dispose);
    await robot.pumpApp(container: firstContainer);
    await robot.openDashboard();

    expect(robot.board, findsOneWidget);
    expect(robot.card('distance'), findsOneWidget);
    expect(robot.card('peaks-bagged'), findsOneWidget);
    expect(robot.card('year-to-date'), findsOneWidget);
    expect(robot.dragHandle('distance'), findsOneWidget);
    expect(robot.latestWalkEmptyState, findsOneWidget);

    await robot.container
        .read(dashboardLayoutProvider.notifier)
        .moveCard('distance', 'peaks-bagged');
    final savedOrder = [
      'elevation',
      'latest-walk',
      'distance',
      'peaks-bagged',
      'year-to-date',
      'my-lists',
      'my-ascents',
    ];
    robot.expectOrder(savedOrder);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(dashboardCardOrderStorageKey), savedOrder);

    SharedPreferences.setMockInitialValues({
      dashboardCardOrderStorageKey: savedOrder,
    });

    final secondContainer = await _createContainer(
      notifier: TestMapNotifier(
        const MapState(
          center: LatLng(-41.5, 146.5),
          zoom: 12,
          basemap: Basemap.tracestrack,
        ),
      ),
    );
    addTearDown(secondContainer.dispose);
    await robot.pumpApp(container: secondContainer);
    await robot.openDashboard();

    expect(robot.board, findsOneWidget);
    expect(robot.card('distance'), findsOneWidget);
    expect(robot.dragHandle('distance'), findsOneWidget);
    expect(robot.card('year-to-date'), findsOneWidget);
  });

  testWidgets('dashboard journey exposes scoped distance controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final robot = DashboardRobot(tester);
    final notifier = TestMapNotifier(
      const MapState(
        center: LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
    );

    final container = await _createContainer(
      notifier: notifier,
    );
    addTearDown(container.dispose);

    await robot.pumpApp(container: container);
    await robot.openDashboard();

    notifier.setTracks([
      _track(
        10,
        DateTime.utc(2026, 5, 15, 10),
        segments: [
          [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
        ],
      ),
    ]);
    await tester.pumpAndSettle();

    expect(
      robot.summaryControl('distance', 'summary-period-dropdown'),
      findsOneWidget,
    );
    expect(
      robot.summaryControl('distance', 'summary-prev-window'),
      findsOneWidget,
    );
    expect(
      robot.summaryControl('distance', 'summary-next-window'),
      findsOneWidget,
    );
    expect(
      robot.summaryControl('distance', 'summary-mode-fab'),
      findsOneWidget,
    );
  });

  testWidgets(
    'dashboard journey refreshes latest walk card after track update',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      final robot = DashboardRobot(tester);
      final notifier = TestMapNotifier(
        const MapState(
          center: LatLng(-41.5, 146.5),
          zoom: 12,
          basemap: Basemap.tracestrack,
        ),
      );

    final container = await _createContainer(notifier: notifier);
      addTearDown(container.dispose);

      await robot.pumpApp(container: container);
      await robot.openDashboard();

      expect(robot.latestWalkEmptyState, findsOneWidget);

      notifier.setTracks([
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
      await tester.pumpAndSettle();

      expect(find.text('Track 20'), findsOneWidget);
      expect(robot.latestWalkCard, findsOneWidget);
    },
  );

  testWidgets('dashboard journey pages latest walk tracks', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final robot = DashboardRobot(tester);
    final notifier = TestMapNotifier(
      const MapState(
        center: LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
    );

    final container = await _createContainer(
      notifier: notifier,
    );
    addTearDown(container.dispose);

    await robot.pumpApp(container: container);
    await robot.openDashboard();

    notifier.setTracks([
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
    ]);
    await tester.pumpAndSettle();

    expect(robot.latestWalkTitle, findsOneWidget);
    expect(find.text('Track 20'), findsOneWidget);
    expect(
      tester.widget<IconButton>(robot.latestWalkNextTrack).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(robot.latestWalkPrevTrack).onPressed,
      isNotNull,
    );

    await robot.tapLatestWalkPrev();
    expect(find.text('Track 10'), findsOneWidget);

    await robot.tapLatestWalkNext();
    expect(find.text('Track 20'), findsOneWidget);
  });

  testWidgets('dashboard journey keeps year selection stable across reorder', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final robot = DashboardRobot(tester);
    final notifier = TestMapNotifier(
      const MapState(
        center: LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
    );

    final container = await _createContainer(
      notifier: notifier,
    );
    addTearDown(container.dispose);

    await robot.pumpApp(container: container);
    await robot.openDashboard();

    notifier.setTracks([
      _track(
        10,
        DateTime.utc(2025, 5, 14, 10),
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
        DateTime.utc(2027, 5, 13, 10),
        segments: [
          [const LatLng(-41.8, 146.8), const LatLng(-41.9, 146.9)],
        ],
      ),
    ]);
    await tester.pumpAndSettle();

    expect(robot.yearToDateCard, findsOneWidget);
    expect(robot.yearToDateTitle, findsOneWidget);
    expect(find.text('My Walks in 2026'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('year-to-date-distance-value')))
          .data,
      '12 km',
    );

    await tester.tap(robot.yearToDateControl('year-to-date-prev-year'));
    await tester.pumpAndSettle();

    expect(find.text('My Walks in 2025'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('year-to-date-distance-value')))
          .data,
      '12 km',
    );

    await robot.container
        .read(dashboardLayoutProvider.notifier)
        .moveCard('year-to-date', 'distance');
    await tester.pumpAndSettle();

    expect(find.text('My Walks in 2025'), findsOneWidget);
    expect(
      tester
      .widget<Text>(find.byKey(const Key('year-to-date-distance-value')))
          .data,
      '12 km',
    );
  });

  testWidgets('dashboard journey shows My Lists rows and migrates layout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      dashboardCardOrderStorageKey: [
        'elevation',
        'distance',
        'latest-walk',
        'peaks-bagged',
        'year-to-date',
        'top-5-highest',
        'my-ascents',
      ],
    });

    final robot = DashboardRobot(tester);
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        tracks: [
          _trackWithPeaks(10, [1, 2]),
          _trackWithPeaks(20, [1, 3]),
        ],
      ),
    );

    final container = await _createContainer(
      notifier: notifier,
      peakLists: [
        _peakList(1, 'Alpha', [1, 2]),
        _peakList(2, 'Beta', [1, 3]),
      ],
    );
    addTearDown(container.dispose);

    await robot.pumpApp(container: container);
    await robot.openDashboard();

    robot.expectOrder([
      'elevation',
      'distance',
      'latest-walk',
      'peaks-bagged',
      'year-to-date',
      'my-lists',
      'my-ascents',
    ]);
    expect(robot.myListsCard, findsOneWidget);
    expect(robot.myListsTable, findsOneWidget);
    expect(robot.myListsRow(1), findsOneWidget);
    expect(robot.myListsRow(2), findsOneWidget);
    expect(
      find.descendant(of: robot.myListsRow(1), matching: find.text('Alpha')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: robot.myListsRow(2), matching: find.text('Beta')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: robot.myListsRow(1), matching: find.text('100%')),
      findsOneWidget,
    );
  });
}

Future<ProviderContainer> _createContainer({
  required TestMapNotifier notifier,
  List<PeakList> peakLists = const [],
}) async {
  final peaksBaggedRepository = PeaksBaggedRepository.test(
    InMemoryPeaksBaggedStorage(),
  );
  if (notifier.initialState.tracks.isNotEmpty) {
    await peaksBaggedRepository.rebuildFromTracks(notifier.initialState.tracks);
  }

  return ProviderContainer(
    overrides: [
      mapProvider.overrideWith(() => notifier),
      peakListRepositoryProvider.overrideWithValue(
        PeakListRepository.test(InMemoryPeakListStorage(peakLists)),
      ),
      peaksBaggedRepositoryProvider.overrideWithValue(peaksBaggedRepository),
      tasmapRepositoryProvider.overrideWithValue(
        await TestTasmapRepository.create(),
      ),
    ],
  );
}

PeakList _peakList(int id, String name, List<int> peakIds) {
  return PeakList(
    peakListId: id,
    name: name,
    peakList: encodePeakListItems(
      peakIds
          .map((peakId) => PeakListItem(peakOsmId: peakId, points: 1))
          .toList(growable: false),
    ),
  );
}

GpxTrack _trackWithPeaks(int id, List<int> peakIds) {
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: DateTime.utc(2026, 5, 15, 10),
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

GpxTrack _track(
  int id,
  DateTime? startDateTime, {
  List<List<LatLng>> segments = const [],
}) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: startDateTime,
    startDateTime: startDateTime,
    distance2d: 12400,
    ascent: 638,
    gpxFile: segments.isEmpty ? '' : '<gpx></gpx>',
    displayTrackPointsByZoom: segments.isEmpty
        ? '{}'
        : TrackDisplayCacheBuilder.buildJson(segments),
  );
}
