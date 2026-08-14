import 'dart:async';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/gpx_export_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';
import 'package:peak_bagger/services/gpx_export_service.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/gpx_track_statistics_calculator.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/theme.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('hidden selected track still shows the shared panel', (
    tester,
  ) async {
    final track = GpxTrack(
      gpxTrackId: 10,
      contentHash: 'hash-10',
      trackName: 'Hidden Track',
      visible: false,
      gpxFile: '<gpx></gpx>',
    );
    final state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      showTracks: true,
      tracks: [track],
      selectedTrackId: 10,
    );

    await _pumpRawMapScreen(tester, state, size: const Size(1600, 900));

    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(find.text('Hidden Track'), findsOneWidget);
  });

  testWidgets('selected track renders panel at desktop width', (tester) async {
    final track = GpxTrack(
      gpxTrackId: 10,
      contentHash: 'hash-10',
      trackName: 'Ridge Walk',
      gpxFile: '<gpx></gpx>',
    );
    final state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      showTracks: true,
      tracks: [track],
      selectedTrackId: 10,
    );

    await _pumpRawMapScreen(tester, state, size: const Size(1600, 900));

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    expect(container.read(mapProvider).selectedTrackId, 10);
    expect(container.read(mapProvider).tracks.single.gpxTrackId, 10);
    expect(
      tester.getSize(find.byType(MapScreen)).width,
      greaterThanOrEqualTo(1024),
    );

    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(find.text('Ridge Walk'), findsOneWidget);
    expect(find.byKey(const Key('map-mgrs-readout')), findsNothing);
    expect(find.byKey(const Key('map-zoom-readout')), findsNothing);
  });

  testWidgets('track click selects and refits into the visible map lane', (
    tester,
  ) async {
    final track = GpxTrack(
      gpxTrackId: 10,
      contentHash: 'hash-10',
      trackName: 'Ridge Walk',
      gpxFile: '<gpx></gpx>',
      displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
        const [LatLng(-41.5, 146.2), LatLng(-41.5, 146.8)],
      ]),
    );
    final state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      showTracks: true,
      tracks: [track],
    );

    await _pumpRawMapScreen(tester, state, size: const Size(1600, 900));

    final mapRegion = find.byKey(const Key('map-interaction-region'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() async {
      await gesture.removePointer();
    });
    await gesture.addPointer(location: tester.getCenter(mapRegion));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(mapRegion));
    await tester.pump();

    await gesture.down(tester.getCenter(mapRegion));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(mapRegion));
    expect(container.read(mapProvider).selectedTrackId, 10);
    expect(container.read(mapProvider).selectedTrackFocusSerial, 1);
    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(container.read(mapProvider).center.longitude, lessThan(146.5));
  });

  testWidgets('close button clears selected track and hides panel', (
    tester,
  ) async {
    final state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      showTracks: true,
      tracks: [
        GpxTrack(
          gpxTrackId: 10,
          contentHash: 'hash-10',
          trackName: 'Ridge Walk',
          gpxFile: '<gpx></gpx>',
        ),
      ],
      selectedTrackId: 10,
    );

    await _pumpRawMapScreen(tester, state, size: const Size(1600, 900));

    await tester.tap(find.byKey(const Key('track-info-panel-close')));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    expect(container.read(mapProvider).selectedTrackId, isNull);
    expect(find.byKey(const Key('track-info-panel')), findsNothing);
  });

  testWidgets(
    'selected track recalculation confirms and cancel makes no changes',
    (tester) async {
      final state = _selectedTrackState();
      late TestMapNotifier notifier;
      await _pumpRawMapScreen(
        tester,
        state,
        size: const Size(1600, 900),
        mapNotifierBuilder: (initialState) =>
            notifier = TestMapNotifier(initialState),
      );

      final recalculateButton = find.byKey(
        const Key('track-info-panel-recalculate-button'),
      );
      await tester.ensureVisible(recalculateButton);
      await tester.tap(recalculateButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Recalculate Track Statistics?'), findsOneWidget);
      expect(
        find.text(
          'This will rebuild statistics and peak correlation for this track from stored GPX XML. Do you wish to proceed?',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(
          find.byKey(const Key('selected-track-recalculate-confirm')),
        ),
        isA<FilledButton>(),
      );

      await tester.tap(
        find.byKey(const Key('selected-track-recalculate-cancel')),
      );
      await tester.pumpAndSettle();

      expect(notifier.selectedTrackRecalculationCallCount, 0);
      expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    },
  );

  testWidgets(
    'peak correlation removal confirms and cancel leaves panel intact',
    (tester) async {
      final state = _selectedTrackState();
      state.tracks.single.peaks.add(
        Peak(
          osmId: 42,
          name: 'Bonnet Hill',
          elevation: 1234,
          latitude: -43.0,
          longitude: 147.0,
        ),
      );
      late TestMapNotifier notifier;
      await _pumpRawMapScreen(
        tester,
        state,
        size: const Size(1600, 900),
        mapNotifierBuilder: (initialState) =>
            notifier = TestMapNotifier(initialState),
      );

      final removeControl = find.byKey(
        const Key('map-track-correlation-remove-10-42'),
      );
      await tester.tap(removeControl);
      await tester.pump();

      expect(find.text('Remove Peak Correlation?'), findsOneWidget);
      expect(
        find.text('Remove the correlation between Bonnet Hill and Ridge Walk?'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peak-correlation-remove-cancel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peak-correlation-remove-confirm')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('peak-correlation-remove-cancel')));
      await tester.pumpAndSettle();

      expect(notifier.peakCorrelationRemovalCallCount, 0);
      expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
      expect(removeControl, findsOneWidget);
    },
  );

  testWidgets('peak correlation removal keeps panel open on failure', (
    tester,
  ) async {
    final state = _selectedTrackState();
    state.tracks.single.peaks.add(
      Peak(osmId: 42, name: 'Bonnet Hill', latitude: -43.0, longitude: 147.0),
    );
    final completion = Completer<void>();
    await _pumpRawMapScreen(
      tester,
      state,
      size: const Size(1600, 900),
      mapNotifierBuilder: (initialState) => TestMapNotifier(
        initialState,
        peakCorrelationRemovalCompleter: completion,
        peakCorrelationRemovalError: 'Local storage is unavailable.',
      ),
    );

    final removeControl = find.byKey(
      const Key('map-track-correlation-remove-10-42'),
    );
    await tester.tap(removeControl);
    await tester.pump();
    await tester.tap(find.byKey(const Key('peak-correlation-remove-confirm')));
    await tester.pump();

    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(
      find.byKey(const Key('map-track-correlation-remove-busy-10-42')),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(removeControl).onPressed, isNull);

    completion.complete();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('map-track-correlation-remove-error-10-42')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Failed to remove peak correlation:'),
      findsOneWidget,
    );
    expect(tester.widget<IconButton>(removeControl).onPressed, isNotNull);
  });

  testWidgets('successful peak correlation removal refreshes the open panel', (
    tester,
  ) async {
    final state = _selectedTrackState();
    state.tracks.single.peaks.add(
      Peak(osmId: 42, name: 'Bonnet Hill', latitude: -43.0, longitude: 147.0),
    );
    final refreshedTrack = GpxTrack(
      gpxTrackId: 10,
      contentHash: 'hash-10',
      trackName: 'Ridge Walk',
      gpxFile: '<gpx></gpx>',
    );
    await _pumpRawMapScreen(
      tester,
      state,
      size: const Size(1600, 900),
      mapNotifierBuilder: (initialState) => TestMapNotifier(
        initialState,
        peakCorrelationRemovalTracks: [refreshedTrack],
      ),
    );

    await tester.tap(
      find.byKey(const Key('map-track-correlation-remove-10-42')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('peak-correlation-remove-confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(
      find.byKey(const Key('map-track-correlation-remove-10-42')),
      findsNothing,
    );
    expect(find.text('None'), findsOneWidget);
  });

  testWidgets('selected track recalculation refreshes the open panel', (
    tester,
  ) async {
    final state = _selectedTrackState();
    final refreshedTrack = GpxTrack(
      gpxTrackId: 10,
      contentHash: 'hash-10',
      trackName: 'Recalculated Ridge Walk',
      gpxFile: '<gpx></gpx>',
    );
    await _pumpRawMapScreen(
      tester,
      state,
      size: const Size(1600, 900),
      mapNotifierBuilder: (initialState) => TestMapNotifier(
        initialState,
        selectedTrackRecalcTracks: [refreshedTrack],
      ),
    );

    final recalculateButton = find.byKey(
      const Key('track-info-panel-recalculate-button'),
    );
    await tester.ensureVisible(recalculateButton);
    await tester.tap(recalculateButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('selected-track-recalculate-confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(find.text('Recalculated Ridge Walk'), findsOneWidget);
    expect(find.text('Track Statistics Recalculated'), findsOneWidget);
    expect(
      find.text('Track statistics and peak correlation were refreshed.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('selected-track-recalculate-result-close')),
      findsOneWidget,
    );
  });

  testWidgets('selected track recalculation recovers from failure', (
    tester,
  ) async {
    final state = _selectedTrackState();
    await _pumpRawMapScreen(
      tester,
      state,
      size: const Size(1600, 900),
      mapNotifierBuilder: (initialState) => TestMapNotifier(
        initialState,
        selectedTrackRecalcError: 'Stored GPX XML is unavailable.',
      ),
    );

    final recalculateButton = find.byKey(
      const Key('track-info-panel-recalculate-button'),
    );
    await tester.ensureVisible(recalculateButton);
    await tester.tap(recalculateButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('selected-track-recalculate-confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(find.text('Track Statistics Recalculation Failed'), findsOneWidget);
    expect(find.text('Stored GPX XML is unavailable.'), findsOneWidget);
    expect(tester.widget<FilledButton>(recalculateButton).onPressed, isNotNull);
    expect(
      find.byKey(const Key('selected-track-recalculate-error-close')),
      findsOneWidget,
    );
  });

  testWidgets('selected track recalculation keeps the panel open while busy', (
    tester,
  ) async {
    final completion = Completer<TrackStatisticsRecalcResult?>();
    final state = _selectedTrackState();
    await _pumpRawMapScreen(
      tester,
      state,
      size: const Size(1600, 900),
      mapNotifierBuilder: (initialState) => TestMapNotifier(
        initialState,
        selectedTrackRecalcCompleter: completion,
      ),
    );

    final recalculateButton = find.byKey(
      const Key('track-info-panel-recalculate-button'),
    );
    await tester.ensureVisible(recalculateButton);
    await tester.tap(recalculateButton, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('selected-track-recalculate-confirm')),
    );
    await tester.pump();

    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(
      find.byKey(const Key('track-info-panel-recalculate-busy-indicator')),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(recalculateButton).onPressed, isNull);

    completion.complete(
      const TrackStatisticsRecalcResult(updatedCount: 1, skippedCount: 0),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('panel renders sections and fallback strings', (tester) async {
    final track =
        GpxTrack(
            gpxTrackId: 10,
            contentHash: 'hash-10',
            trackName: '',
            trackDate: DateTime.utc(2026, 1, 7, 23, 30),
            distance2d: 12400,
            distanceToPeak: 840,
            distanceFromPeak: 11560,
            ascent: null,
            startElevation: 100,
            endElevation: 250,
            highestElevation: 300,
            lowestElevation: 90,
            totalTimeMillis: 2 * 60 * 60 * 1000 + 5 * 60 * 1000,
            movingTime: 90 * 60 * 1000,
            restingTime: 15 * 60 * 1000,
            pausedTime: 0,
            averageSpeedKmh: 5.9,
            movingSpeedKmh: 8.3,
            maxSpeedKmh: 12.7,
            peakCorrelationProcessed: true,
            gpxFile: '<gpx></gpx>',
          )
          ..peaks.addAll([
            Peak(
              osmId: 2,
              name: 'beta',
              elevation: 1377,
              latitude: 0,
              longitude: 0,
            ),
            Peak(
              osmId: 1,
              name: '',
              elevation: 1022,
              latitude: 0,
              longitude: 0,
            ),
          ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: MyTheme.dark,
        home: Scaffold(
          body: MapTrackInfoPanel(track: track, onClose: () {}),
        ),
      ),
    );
    await tester.pump();

    final panel = tester.widget<Card>(
      find.byKey(const Key('track-info-panel')),
    );

    expect(find.text('Unnamed Track'), findsOneWidget);
    final headerRow = find
        .ancestor(of: find.text('Unnamed Track'), matching: find.byType(Row))
        .first;
    expect(
      find.descendant(of: headerRow, matching: find.byIcon(Icons.hiking)),
      findsOneWidget,
    );
    expect(find.text('Wed, 7 January 2026'), findsOneWidget);
    expect(find.text('from Unknown to Unknown'), findsOneWidget);
    expect(panel.color, MyTheme.dark.colorScheme.surfaceContainer);
    expect(find.text('Distance (2d/3d)'), findsOneWidget);
    expect(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Distance (2d/3d)'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.text('12.4 km / 0 m'),
      ),
      findsOneWidget,
    );
    expect(find.text('Ascent'), findsOneWidget);
    expect(find.text('Unknown'), findsWidgets);
    expect(find.text('Peaks Climbed'), findsOneWidget);
    expect(find.text('Distance to highest peak'), findsOneWidget);
    final distanceLabel = tester.widget<Text>(
      find.text('Distance to highest peak'),
    );
    expect(distanceLabel.maxLines, 1);
    expect(distanceLabel.softWrap, isFalse);
    expect(distanceLabel.overflow, TextOverflow.clip);
    final highestPeakLabel = tester.widget<Text>(
      find.text('Distance from highest peak'),
    );
    expect(highestPeakLabel.maxLines, 1);
    expect(highestPeakLabel.softWrap, isFalse);
    expect(highestPeakLabel.overflow, TextOverflow.clip);
    expect(find.text('840 m'), findsOneWidget);
    expect(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Distance from highest peak'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.text('11.6 km'),
      ),
      findsOneWidget,
    );
    expect(find.text('Unknown Peak'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('1377 m'), findsOneWidget);
    expect(find.text('1022 m'), findsOneWidget);
    expect(find.text('Elevation'), findsOneWidget);
    expect(find.text('Start Elevation'), findsOneWidget);
    expect(find.text('100 m'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Average Speed'), findsOneWidget);
    expect(find.text('5.9 km/h'), findsOneWidget);
    expect(find.text('Moving Speed'), findsOneWidget);
    expect(find.text('8.3 km/h'), findsOneWidget);
    expect(find.text('Max Speed'), findsOneWidget);
    expect(find.text('12.7 km/h'), findsOneWidget);
    expect(find.text('2h 5m'), findsWidgets);
  });

  testWidgets(
    'panel shows None fallback and pinned close button stays accessible',
    (tester) async {
      final track = GpxTrack(
        gpxTrackId: 11,
        contentHash: 'hash-11',
        trackName: 'Long Content Track',
        trackDate: DateTime(2026, 1, 7),
        gpxFile: '<gpx></gpx>',
        peakCorrelationProcessed: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 320,
              child: MapTrackInfoPanel(track: track, onClose: () {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('None'), findsOneWidget);
      expect(find.byKey(const Key('track-info-panel-close')), findsOneWidget);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pump();

      expect(find.byKey(const Key('track-info-panel-close')), findsOneWidget);
    },
  );

  testWidgets('basemaps drawer coexists with selected track panel', (
    tester,
  ) async {
    final track = GpxTrack(
      gpxTrackId: 10,
      contentHash: 'hash-10',
      trackName: 'Ridge Walk',
      gpxFile: '<gpx></gpx>',
    );
    final state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      showTracks: true,
      tracks: [track],
      selectedTrackId: 10,
    );

    await _pumpRawMapScreen(tester, state, size: const Size(1600, 900));

    final basemapsFab = find.byKey(const Key('show-basemaps-fab'));
    await tester.ensureVisible(basemapsFab);
    await tester.pumpAndSettle();
    await tester.tap(basemapsFab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('basemaps-drawer')), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    expect(container.read(mapProvider).selectedTrackId, 10);
  });

  testWidgets(
    'selecting another visible track updates panel content immediately',
    (tester) async {
      final tracks = [
        GpxTrack(
          gpxTrackId: 10,
          contentHash: 'hash-10',
          trackName: 'First Track',
          gpxFile: '<gpx></gpx>',
        ),
        GpxTrack(
          gpxTrackId: 20,
          contentHash: 'hash-20',
          trackName: 'Second Track',
          gpxFile: '<gpx></gpx>',
        ),
      ];
      final state = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        tracks: tracks,
        selectedTrackId: 10,
      );

      await _pumpRawMapScreen(tester, state, size: const Size(1600, 900));

      expect(find.text('First Track'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );
      container.read(mapProvider.notifier).selectTrack(20);
      await tester.pumpAndSettle();

      expect(find.text('First Track'), findsNothing);
      expect(find.text('Second Track'), findsOneWidget);
    },
  );

  testWidgets('export dialog offers New Version and writes suffixed path', (
    tester,
  ) async {
    final track = GpxTrack(
      gpxTrackId: 10,
      contentHash: 'hash-10',
      trackName: 'Ridge Walk',
      gpxFile: '<gpx></gpx>',
    );
    final state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      showTracks: true,
      tracks: [track],
      selectedTrackId: 10,
    );
    final exportService = _FakeInfoPanelExportService();

    await _pumpRawMapScreen(
      tester,
      state,
      size: const Size(1600, 900),
      exportService: exportService,
    );

    await tester.tap(find.byKey(const Key('track-info-panel-export-button')));
    await tester.pumpAndSettle();

    expect(find.text('New Version'), findsOneWidget);
    expect(
      find.text(
        'This file already exists. Do you want to overwrite it or add a new version?',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<Widget>(
        find.byKey(const Key('tracks-routes-export-new-version')),
      ),
      isA<OutlinedButton>(),
    );
    expect(
      tester.widget<Widget>(
        find.byKey(const Key('tracks-routes-export-confirm')),
      ),
      isA<FilledButton>(),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    final hoverTarget = find.byKey(
      const Key('tracks-routes-export-new-version'),
    );
    await mouse.addPointer(location: tester.getCenter(hoverTarget));
    await tester.pump();
    await mouse.moveTo(tester.getCenter(hoverTarget));
    await tester.pump();

    expect(
      tester.widget<Widget>(
        find.byKey(const Key('tracks-routes-export-new-version')),
      ),
      isA<OutlinedButton>(),
    );
    expect(
      tester.widget<Widget>(
        find.byKey(const Key('tracks-routes-export-confirm')),
      ),
      isA<FilledButton>(),
    );

    await tester.tap(find.byKey(const Key('tracks-routes-export-new-version')));
    await tester.pumpAndSettle();

    expect(exportService.lastWrittenPath, '/fake/track/Ridge-Walk_1.gpx');
    expect(
      find.textContaining('Exported to /fake/track/Ridge-Walk_1.gpx'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpRawMapScreen(
  WidgetTester tester,
  MapState state, {
  required Size size,
  GpxExportService? exportService,
  TestMapNotifier Function(MapState initialState)? mapNotifierBuilder,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final gpxTrackRepository = GpxTrackRepository.test(
    InMemoryGpxTrackStorage(state.tracks),
  );
  final mapNotifier = mapNotifierBuilder?.call(state) ?? TestMapNotifier(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => mapNotifier),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        gpxTrackRepositoryProvider.overrideWithValue(gpxTrackRepository),
        if (exportService != null)
          gpxExportServiceProvider.overrideWithValue(exportService),
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

MapState _selectedTrackState() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    showTracks: true,
    tracks: [
      GpxTrack(
        gpxTrackId: 10,
        contentHash: 'hash-10',
        trackName: 'Ridge Walk',
        gpxFile: '<gpx></gpx>',
      ),
    ],
    selectedTrackId: 10,
  );
}

final class _FakeInfoPanelExportService extends GpxExportService {
  _FakeInfoPanelExportService()
    : super(
        trackDownloadsDirectoryResolver: () => Directory('/fake/track'),
        routeExportsDirectoryResolver: () => Directory('/fake/route'),
      );

  String? lastWrittenPath;

  @override
  bool fileExists(GpxExportPlan plan) => true;

  @override
  Future<String> writeExport(GpxExportPlan plan) async {
    lastWrittenPath = plan.path;
    return plan.path;
  }
}
