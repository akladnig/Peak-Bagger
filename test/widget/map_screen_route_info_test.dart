import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('route selection opens shared panel and close clears route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'show_routes': true});
    final route = app_route.Route(
      id: 1,
      name: 'Visible Route',
      gpxRoute: [
        const LatLng(-41.5, 146.49),
        const LatLng(-41.5, 146.51),
      ],
      distance2d: 17450,
      ascent: 912,
      descent: 456,
      startElevation: 100,
      endElevation: 250,
      highestElevation: 320,
      lowestElevation: 90,
    );
    final routeRepository = RouteRepository.test(
      InMemoryRouteStorage([route]),
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
      ),
      routeRepository: routeRepository,
    );

    await _pumpRawMapScreen(tester, notifier, routeRepository, size: const Size(1600, 900));

    final mapRegion = find.byKey(const Key('map-interaction-region'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() async {
      await gesture.removePointer();
    });
    await gesture.addPointer(location: tester.getCenter(mapRegion));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(mapRegion));
    await tester.pump();

    expect(
      ProviderScope.containerOf(tester.element(mapRegion)).read(mapProvider).hoveredRouteId,
      1,
    );

    await gesture.down(tester.getCenter(mapRegion));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(mapRegion));
    expect(container.read(mapProvider).selectedRouteId, 1);
    expect(container.read(mapProvider).selectedTrackId, isNull);
    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(find.text('Visible Route'), findsOneWidget);

    await tester.tap(find.byKey(const Key('track-info-panel-close')));
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).selectedRouteId, isNull);
    expect(find.byKey(const Key('track-info-panel')), findsNothing);
  });

  testWidgets('track click replaces an existing route selection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'show_routes': true});
    final route = app_route.Route(
      id: 1,
      name: 'Visible Route',
      gpxRoute: const [
        LatLng(-41.5, 146.49),
        LatLng(-41.5, 146.51),
      ],
      distance2d: 17450,
    );
    final track = GpxTrack(
      gpxTrackId: 2,
      contentHash: 'hash-track',
      trackName: 'Visible Track',
      gpxFile: '<gpx></gpx>',
      displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
        const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
      ]),
    );
    final routeRepository = RouteRepository.test(
      InMemoryRouteStorage([route]),
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        showRoutes: true,
        tracks: [track],
        selectedRouteId: 1,
      ),
      routeRepository: routeRepository,
    );

    await _pumpRawMapScreen(tester, notifier, routeRepository, size: const Size(1600, 900));

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
    expect(container.read(mapProvider).selectedTrackId, 2);
    expect(container.read(mapProvider).selectedRouteId, isNull);
    expect(find.text('Visible Track'), findsOneWidget);
  });

  testWidgets('shared route panel shows metrics and omits time', (tester) async {
    final route = app_route.Route(
      id: 1,
      name: '',
      distance2d: 17500,
      ascent: 900,
      descent: 450,
      startElevation: 100,
      endElevation: 250,
      highestElevation: 320,
      lowestElevation: 90,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CatppuccinColors.dark,
        home: Scaffold(
          body: MapTrackInfoPanel(route: route, onClose: () {}),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Unnamed Route'), findsOneWidget);
    expect(find.text('17.5 km'), findsOneWidget);
    expect(find.text('900 m'), findsNWidgets(2));
    expect(find.text('450 m'), findsOneWidget);
    expect(find.text('Time'), findsNothing);
    expect(find.text('Peaks Climbed'), findsNothing);
    expect(find.text('Elevation'), findsOneWidget);
    expect(find.text('Start Elevation'), findsOneWidget);
    expect(find.text('End Elevation'), findsOneWidget);
  });
}

Future<void> _pumpRawMapScreen(
  WidgetTester tester,
  TestMapNotifier notifier,
  RouteRepository routeRepository, {
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
          GpxTrackRepository.test(InMemoryGpxTrackStorage()),
        ),
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}
