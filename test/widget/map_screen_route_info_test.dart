import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/gpx_export_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';
import 'package:peak_bagger/services/gpx_export_service.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('hidden selected route still shows the shared panel', (
    tester,
  ) async {
    final route = app_route.Route(
      id: 1,
      name: 'Hidden Route',
      visible: false,
      gpxRoute: const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
    );
    final routeRepository = RouteRepository.test(InMemoryRouteStorage([route]));
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        selectedRouteId: 1,
      ),
      routeRepository: routeRepository,
    );

    await _pumpRawMapScreen(
      tester,
      notifier,
      routeRepository,
      size: const Size(1600, 900),
    );

    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(find.text('Hidden Route'), findsOneWidget);
  });

  testWidgets('route selection opens shared panel and close clears route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'show_routes': true});
    final route = app_route.Route(
      id: 1,
      name: 'Visible Route',
      gpxRoute: [const LatLng(-41.5, 146.2), const LatLng(-41.5, 146.8)],
      distance2d: 17450,
      ascent: 912,
      descent: 456,
      startElevation: 100,
      endElevation: 250,
      highestElevation: 320,
      lowestElevation: 90,
    );
    final routeRepository = RouteRepository.test(InMemoryRouteStorage([route]));
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
      ),
      routeRepository: routeRepository,
    );

    await _pumpRawMapScreen(
      tester,
      notifier,
      routeRepository,
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

    expect(
      ProviderScope.containerOf(
        tester.element(mapRegion),
      ).read(mapProvider).hoveredRouteId,
      1,
    );

    await gesture.down(tester.getCenter(mapRegion));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(mapRegion));
    expect(container.read(mapProvider).selectedRouteId, 1);
    expect(container.read(mapProvider).selectedTrackId, isNull);
    expect(container.read(mapProvider).selectedRouteFocusSerial, 1);
    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(find.text('Visible Route'), findsOneWidget);
    expect(find.text('Speed'), findsNothing);
    expect(find.byKey(const Key('map-mgrs-readout')), findsNothing);
    expect(find.byKey(const Key('map-zoom-readout')), findsNothing);
    expect(container.read(mapProvider).center.longitude, lessThan(146.5));

    await tester.tap(find.byKey(const Key('track-info-panel-close')));
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).selectedRouteId, isNull);
    expect(find.byKey(const Key('track-info-panel')), findsNothing);
  });

  testWidgets('track chooser selection replaces an existing route selection', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'show_routes': true});
    final route = app_route.Route(
      id: 1,
      name: 'Visible Route',
      gpxRoute: const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
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
    final routeRepository = RouteRepository.test(InMemoryRouteStorage([route]));
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

    await _pumpRawMapScreen(
      tester,
      notifier,
      routeRepository,
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
    expect(
      find.byKey(const Key('track-route-chooser-row-track-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('track-route-chooser-row-route-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('track-route-chooser-row-track-2')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(tester.element(mapRegion));
    expect(container.read(mapProvider).selectedTrackId, 2);
    expect(container.read(mapProvider).selectedRouteId, isNull);
    expect(find.text('Visible Track'), findsOneWidget);
  });

  testWidgets('shared route panel shows metrics and omits time', (
    tester,
  ) async {
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

  testWidgets('route export success snackbar shows nested Routes path', (
    tester,
  ) async {
    final route = app_route.Route(
      id: 1,
      name: 'Visible Route',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
    );
    final routeRepository = RouteRepository.test(InMemoryRouteStorage([route]));
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        selectedRouteId: 1,
      ),
      routeRepository: routeRepository,
    );
    final exportService = _FakeRouteInfoExportService();

    await _pumpRawMapScreen(
      tester,
      notifier,
      routeRepository,
      size: const Size(1600, 900),
      exportService: exportService,
    );

    await tester.tap(find.byKey(const Key('track-info-panel-export-button')));
    await tester.pumpAndSettle();

    expect(
      exportService.lastWrittenPath,
      '/fake/Routes/Australia/Tasmania/Visible-Route.gpx',
    );
    expect(
      find.textContaining(
        'Exported to /fake/Routes/Australia/Tasmania/Visible-Route.gpx',
      ),
      findsOneWidget,
    );
  });

  testWidgets('route export failure shows unsupported location message', (
    tester,
  ) async {
    final route = app_route.Route(
      id: 1,
      name: 'Melbourne Route',
      gpxRoute: const [LatLng(-37.8136, 144.9631)],
    );
    final routeRepository = RouteRepository.test(InMemoryRouteStorage([route]));
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-37.8136, 144.9631),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        selectedRouteId: 1,
      ),
      routeRepository: routeRepository,
    );
    final exportService = _FailingRouteInfoExportService();

    await _pumpRawMapScreen(
      tester,
      notifier,
      routeRepository,
      size: const Size(1600, 900),
      exportService: exportService,
    );

    await tester.tap(find.byKey(const Key('track-info-panel-export-button')));
    await tester.pumpAndSettle();

    expect(exportService.writeAttempted, isFalse);
    expect(
      find.textContaining(
        'Export failed: Route export location is unsupported.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpRawMapScreen(
  WidgetTester tester,
  TestMapNotifier notifier,
  RouteRepository routeRepository, {
  required Size size,
  GpxExportService? exportService,
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

final class _FakeRouteInfoExportService extends GpxExportService {
  _FakeRouteInfoExportService()
    : super(routeExportsDirectoryResolver: () => Directory('/fake/Routes'));

  String? lastWrittenPath;

  @override
  bool fileExists(GpxExportPlan plan) => false;

  @override
  Future<String> writeExport(GpxExportPlan plan) async {
    lastWrittenPath = plan.path;
    return plan.path;
  }
}

final class _FailingRouteInfoExportService extends GpxExportService {
  _FailingRouteInfoExportService()
    : super(routeExportsDirectoryResolver: () => Directory('/fake/Routes'));

  bool writeAttempted = false;

  @override
  Future<GpxExportPlan> planRouteExport(app_route.Route route) async {
    throw const GpxExportException('Route export location is unsupported.');
  }

  @override
  Future<String> writeExport(GpxExportPlan plan) async {
    writeAttempted = true;
    return plan.path;
  }
}
