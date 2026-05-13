import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/theme.dart';

import '../harness/test_map_notifier.dart';

void main() {
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
            peakCorrelationProcessed: true,
            gpxFile: '<gpx></gpx>',
          )
          ..peaks.addAll([
            Peak(osmId: 2, name: 'beta', latitude: 0, longitude: 0),
            Peak(osmId: 1, name: '', latitude: 0, longitude: 0),
          ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: CatppuccinColors.dark,
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
    expect(find.text('Wed, 7 January 2026'), findsOneWidget);
    expect(find.text('from Unknown to Unknown'), findsOneWidget);
    expect(panel.color, CatppuccinColors.dark.colorScheme.secondary);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('12.4 km'), findsOneWidget);
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
    expect(find.text('11.6 km'), findsOneWidget);
    expect(find.text('Unknown Peak'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('Elevation'), findsOneWidget);
    expect(find.text('Start Elevation'), findsOneWidget);
    expect(find.text('100 m'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('show-basemaps-fab')));
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
}

Future<void> _pumpRawMapScreen(
  WidgetTester tester,
  MapState state, {
  required Size size,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final gpxTrackRepository = GpxTrackRepository.test(
    InMemoryGpxTrackStorage(state.tracks),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => TestMapNotifier(state)),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        gpxTrackRepositoryProvider.overrideWithValue(gpxTrackRepository),
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}
