import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('click overlap opens chooser with stable ordering', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'show_tracks': true,
      'show_routes': true,
    });

    final tracks = [
      GpxTrack(
        gpxTrackId: 11,
        contentHash: 'hash-11',
        trackName: 'New Track',
        trackDate: DateTime.utc(2026, 1, 7),
        totalTimeMillis: 2 * 60 * 60 * 1000,
        distance2d: 6800,
        gpxFile: '<gpx></gpx>',
        displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
          const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
        ]),
      ),
      GpxTrack(
        gpxTrackId: 12,
        contentHash: 'hash-12',
        trackName: 'Old Track',
        trackDate: DateTime.utc(2025, 12, 31),
        totalTimeMillis: 90 * 60 * 1000,
        distance2d: 7200,
        gpxFile: '<gpx></gpx>',
        displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
          const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
        ]),
      ),
      GpxTrack(
        gpxTrackId: 13,
        contentHash: 'hash-13',
        trackName: 'Hidden Track',
        visible: false,
        trackDate: DateTime.utc(2026, 1, 8),
        totalTimeMillis: 30 * 60 * 1000,
        distance2d: 5400,
        gpxFile: '<gpx></gpx>',
        displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
          const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
        ]),
      ),
    ];
    final routes = [
      app_route.Route(
        id: 21,
        name: 'Beta Route',
        distance2d: 7400,
        gpxRoute: const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
      ),
      app_route.Route(
        id: 22,
        name: 'Alpha Route',
        distance2d: 7500,
        gpxRoute: const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
      ),
      app_route.Route(
        id: 23,
        name: 'Hidden Route',
        visible: false,
        distance2d: 7600,
        gpxRoute: const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
      ),
    ];
    final routeRepository = RouteRepository.test(InMemoryRouteStorage(routes));
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        showTracks: true,
        tracks: tracks,
      ),
      routeRepository: routeRepository,
    );

    await _pumpRawMapScreen(
      tester,
      notifier,
      routeRepository,
      tracks,
      size: const Size(1600, 900),
    );

    final mapRegion = find.byKey(const Key('map-interaction-region'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() async {
      await gesture.removePointer();
    });
    await gesture.addPointer(location: tester.getCenter(mapRegion));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(mapRegion));
    await tester.pump();

    expect(find.byKey(const Key('track-route-chooser-popup')), findsNothing);

    await gesture.down(tester.getCenter(mapRegion));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('track-route-chooser-popup')), findsOneWidget);
    expect(
      find.byKey(const Key('track-route-chooser-row-track-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('track-route-chooser-row-track-12')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('track-route-chooser-row-route-21')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('track-route-chooser-row-route-22')),
      findsOneWidget,
    );
    expect(find.text('Hidden Track'), findsNothing);
    expect(find.text('Hidden Route'), findsNothing);

    final track11Top = tester
        .getTopLeft(find.byKey(const Key('track-route-chooser-row-track-11')))
        .dy;
    final track12Top = tester
        .getTopLeft(find.byKey(const Key('track-route-chooser-row-track-12')))
        .dy;
    final route22Top = tester
        .getTopLeft(find.byKey(const Key('track-route-chooser-row-route-22')))
        .dy;
    final route21Top = tester
        .getTopLeft(find.byKey(const Key('track-route-chooser-row-route-21')))
        .dy;

    expect(track11Top, lessThan(track12Top));
    expect(track12Top, lessThan(route22Top));
    expect(route22Top, lessThan(route21Top));
    expect(
      find.text('Track • 6.8 km • Wed, 7 Jan 2026 • 2h 0m'),
      findsOneWidget,
    );
    expect(
      find.text('Track • 7.2 km • Wed, 31 Dec 2025 • 1h 30m'),
      findsOneWidget,
    );
    expect(find.textContaining('Route • 7.5 km'), findsOneWidget);
    expect(find.textContaining('Route • 7.4 km'), findsOneWidget);
  });

  testWidgets('choosing a chooser row opens the shared info panel', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'show_tracks': true,
      'show_routes': true,
    });

    final tracks = [
      GpxTrack(
        gpxTrackId: 11,
        contentHash: 'hash-11',
        trackName: 'New Track',
        trackDate: DateTime.utc(2026, 1, 7),
        totalTimeMillis: 2 * 60 * 60 * 1000,
        distance2d: 6800,
        gpxFile: '<gpx></gpx>',
        displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
          const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
        ]),
      ),
    ];
    final routes = [
      app_route.Route(
        id: 21,
        name: 'Beta Route',
        distance2d: 7400,
        gpxRoute: const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
      ),
    ];
    final routeRepository = RouteRepository.test(InMemoryRouteStorage(routes));
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        showTracks: true,
        tracks: tracks,
      ),
      routeRepository: routeRepository,
    );

    await _pumpRawMapScreen(
      tester,
      notifier,
      routeRepository,
      tracks,
      size: const Size(1600, 900),
    );

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
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('track-route-chooser-row-track-11')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('track-route-chooser-popup')), findsNothing);
    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(find.text('New Track'), findsOneWidget);
    expect(notifier.state.selectedTrackId, 11);
    expect(notifier.state.selectedRouteId, isNull);
  });

  testWidgets('chooser disables peak hover while open', (tester) async {
    SharedPreferences.setMockInitialValues({
      'show_tracks': true,
      'show_routes': true,
    });
    final tracks = [
      GpxTrack(
        gpxTrackId: 11,
        contentHash: 'hash-11',
        trackName: 'New Track',
        trackDate: DateTime.utc(2026, 1, 7),
        totalTimeMillis: 2 * 60 * 60 * 1000,
        distance2d: 6800,
        gpxFile: '<gpx></gpx>',
        displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
          const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
        ]),
      ),
    ];
    final routes = [
      app_route.Route(
        id: 21,
        name: 'Beta Route',
        distance2d: 7400,
        gpxRoute: const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
      ),
    ];
    final routeRepository = RouteRepository.test(InMemoryRouteStorage(routes));
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        showTracks: true,
        tracks: tracks,
      ),
      routeRepository: routeRepository,
    );

    await _pumpRawMapScreen(
      tester,
      notifier,
      routeRepository,
      tracks,
      size: const Size(1600, 900),
    );

    final mapRegion = find.byKey(const Key('map-interaction-region'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() async {
      await gesture.removePointer();
    });

    final overlapPoint = tester.getCenter(mapRegion);

    await gesture.moveTo(overlapPoint);
    await tester.pump();
    await gesture.down(overlapPoint);
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('track-route-chooser-popup')), findsOneWidget);

    final peakPoint = tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera
        .latLngToScreenOffset(const LatLng(-41.48, 146.52));

    notifier.state = notifier.state.copyWith(
      peakListSelectionMode: PeakListSelectionMode.allPeaks,
      peaks: [
        Peak(
          osmId: 6406,
          name: 'Near Peak',
          latitude: -41.48,
          longitude: 146.52,
        ),
      ],
    );
    await tester.pump();

    await gesture.moveTo(peakPoint);
    await tester.pump();

    expect(notifier.state.hoveredPeakId, isNull);
    expect(find.byKey(const Key('track-route-chooser-popup')), findsOneWidget);
  });

  testWidgets('escape and outside tap dismiss chooser', (tester) async {
    SharedPreferences.setMockInitialValues({
      'show_tracks': true,
      'show_routes': true,
    });

    final tracks = [
      GpxTrack(
        gpxTrackId: 11,
        contentHash: 'hash-11',
        trackName: 'New Track',
        trackDate: DateTime.utc(2026, 1, 7),
        totalTimeMillis: 2 * 60 * 60 * 1000,
        distance2d: 6800,
        gpxFile: '<gpx></gpx>',
        displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
          const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
        ]),
      ),
      GpxTrack(
        gpxTrackId: 12,
        contentHash: 'hash-12',
        trackName: 'Old Track',
        trackDate: DateTime.utc(2025, 12, 31),
        totalTimeMillis: 90 * 60 * 1000,
        distance2d: 7200,
        gpxFile: '<gpx></gpx>',
        displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
          const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
        ]),
      ),
    ];
    final routes = [
      app_route.Route(
        id: 21,
        name: 'Beta Route',
        distance2d: 7400,
        gpxRoute: const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
      ),
    ];
    final routeRepository = RouteRepository.test(InMemoryRouteStorage(routes));
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        showTracks: true,
        tracks: tracks,
      ),
      routeRepository: routeRepository,
    );

    await _pumpRawMapScreen(
      tester,
      notifier,
      routeRepository,
      tracks,
      size: const Size(1600, 900),
    );

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
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('track-route-chooser-popup')), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(const Key('track-route-chooser-popup')), findsNothing);

    await gesture.moveTo(const Offset(20, 20));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(mapRegion));
    await tester.pump();
    expect(find.byKey(const Key('track-route-chooser-popup')), findsNothing);

    await gesture.down(tester.getCenter(mapRegion));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('track-route-chooser-popup')), findsOneWidget);

    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('track-route-chooser-popup')), findsNothing);
    expect(notifier.state.selectedTrackId, isNull);
    expect(notifier.state.selectedRouteId, isNull);
  });
}

Future<void> _pumpRawMapScreen(
  WidgetTester tester,
  TestMapNotifier notifier,
  RouteRepository routeRepository,
  List<GpxTrack> tracks, {
  required Size size,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        routeRepositoryProvider.overrideWithValue(routeRepository),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        gpxTrackRepositoryProvider.overrideWithValue(
          GpxTrackRepository.test(InMemoryGpxTrackStorage(tracks)),
        ),
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}
