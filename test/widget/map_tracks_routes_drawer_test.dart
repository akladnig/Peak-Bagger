import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/gpx_export_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/services/gpx_export_service.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/widgets/map_tracks_routes_drawer.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('whole-row tap toggles tracks and routes when available', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        tracks: [
          GpxTrack(contentHash: 'hash', trackName: 'Track 1', gpxFile: '<gpx></gpx>'),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          routeRepositoryProvider.overrideWithValue(
            RouteRepository.test(
              InMemoryRouteStorage([app_route.Route(name: 'Route 1')]),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MapTracksRoutesDrawer()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Show Tracks'));
    await tester.pump();
    expect(notifier.state.showTracks, isTrue);

    await tester.tap(find.text('Show Routes'));
    await tester.pump();
    expect(notifier.state.showRoutes, isTrue);
  });

  testWidgets('disabled switches keep stored values and show helper text', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        showTracks: true,
        showRoutes: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          routeRepositoryProvider.overrideWithValue(
            RouteRepository.test(InMemoryRouteStorage()),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MapTracksRoutesDrawer()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No tracks loaded'), findsOneWidget);
    expect(find.text('No routes available'), findsOneWidget);

    final tracksSwitch = tester.widget<Switch>(
      find.byKey(const Key('show-tracks-switch')),
    );
    final routesSwitch = tester.widget<Switch>(
      find.byKey(const Key('show-routes-switch')),
    );
    expect(tracksSwitch.value, isTrue);
    expect(tracksSwitch.onChanged, isNull);
    expect(routesSwitch.value, isTrue);
    expect(routesSwitch.onChanged, isNull);
  });

  testWidgets('export button disables when selection cannot resolve', (
    tester,
  ) async {
    final exportService = FakeGpxExportService();
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        showTracks: true,
        selectedTrackId: 1,
        tracks: [
          GpxTrack(
            gpxTrackId: 1,
            contentHash: 'hash',
            trackName: 'Track 1',
            gpxFile: '<gpx></gpx>',
          ),
        ],
      ),
    );

    await _pumpDrawer(
      tester,
      notifier: notifier,
      exportService: exportService,
      trackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('tracks-routes-export-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('track export writes gpx and shows snackbar', (tester) async {
    final exportService = FakeGpxExportService();
    final track = GpxTrack(
      gpxTrackId: 1,
      contentHash: 'hash',
      trackName: 'Track 1',
      gpxFile: '<gpx><trk></trk></gpx>',
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        showTracks: true,
        selectedTrackId: 1,
        tracks: [track],
      ),
    );

    await _pumpDrawer(
      tester,
      notifier: notifier,
      exportService: exportService,
      trackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage([track])),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
    );

    await tester.tap(find.byKey(const Key('tracks-routes-export-button')));
    await tester.pumpAndSettle();

    expect(exportService.writeCallCount, 1);
    expect(exportService.lastPlan?.path, '/fake/track/Track-1.gpx');
    expect(find.textContaining('Exported to /fake/track/Track-1.gpx'), findsOneWidget);
  });

  testWidgets('route export confirms overwrite and writes file', (tester) async {
    final exportService = FakeGpxExportService(routeExists: true);
    final route = app_route.Route(
      id: 1,
      name: 'Route 1',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        selectedRouteId: 1,
      ),
    );
    final routeRepository = RouteRepository.test(InMemoryRouteStorage([route]));

    await _pumpDrawer(
      tester,
      notifier: notifier,
      exportService: exportService,
      trackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: routeRepository,
    );

    await tester.tap(find.byKey(const Key('tracks-routes-export-button')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.byKey(const Key('tracks-routes-export-confirm')));
    await tester.pumpAndSettle();

    expect(exportService.writeCallCount, 1);
    expect(exportService.lastPlan?.path, '/fake/route/Route-1.gpx');
    expect(find.textContaining('Exported to /fake/route/Route-1.gpx'), findsOneWidget);
  });

  testWidgets('route export cancel leaves existing file untouched', (
    tester,
  ) async {
    final exportService = FakeGpxExportService(routeExists: true);
    final route = app_route.Route(
      id: 1,
      name: 'Route 2',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        selectedRouteId: 1,
      ),
    );
    final routeRepository = RouteRepository.test(InMemoryRouteStorage([route]));

    await _pumpDrawer(
      tester,
      notifier: notifier,
      exportService: exportService,
      trackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: routeRepository,
    );

    await tester.tap(find.byKey(const Key('tracks-routes-export-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tracks-routes-export-cancel')));
    await tester.pumpAndSettle();

    expect(exportService.writeCallCount, 0);
    expect(find.textContaining('Exported to'), findsNothing);
  });

  testWidgets('track export failure shows snackbar', (tester) async {
    final exportService = FakeGpxExportService(failTrackPlan: true);
    final track = GpxTrack(
      gpxTrackId: 1,
      contentHash: 'hash',
      trackName: 'Broken Track',
      gpxFile: '',
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        showTracks: true,
        selectedTrackId: 1,
        tracks: [track],
      ),
    );

    await _pumpDrawer(
      tester,
      notifier: notifier,
      exportService: exportService,
      trackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage([track])),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
    );

    await tester.tap(find.byKey(const Key('tracks-routes-export-button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Export failed:'), findsOneWidget);
  });
}

final class FakeGpxExportService extends GpxExportService {
  FakeGpxExportService({
    this.routeExists = false,
    this.failTrackPlan = false,
  }) : super(
         trackDownloadsDirectoryResolver: () => Directory('/fake/track'),
         routeExportsDirectoryResolver: () => Directory('/fake/route'),
       );

  final bool routeExists;
  final bool failTrackPlan;
  int writeCallCount = 0;
  GpxExportPlan? lastPlan;

  @override
  GpxExportPlan planTrackExport(GpxTrack track) {
    if (failTrackPlan) {
      throw const GpxExportException('Track GPX payload is empty.');
    }
    return GpxExportPlan(
      path: '/fake/track/Track-1.gpx',
      contents: track.gpxFile,
    );
  }

  @override
  GpxExportPlan planRouteExport(app_route.Route route) {
    return GpxExportPlan(
      path: '/fake/route/${route.name.replaceAll(' ', '-')}.gpx',
      contents: '<route>${route.name}</route>',
    );
  }

  @override
  bool fileExists(GpxExportPlan plan) {
    lastPlan = plan;
    return routeExists && plan.path.startsWith('/fake/route/');
  }

  @override
  Future<String> writeExport(GpxExportPlan plan) async {
    lastPlan = plan;
    writeCallCount += 1;
    return plan.path;
  }
}

Future<void> _pumpDrawer(
  WidgetTester tester, {
  required TestMapNotifier notifier,
  required GpxExportService exportService,
  required GpxTrackRepository trackRepository,
  required RouteRepository routeRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        gpxTrackRepositoryProvider.overrideWithValue(trackRepository),
        routeRepositoryProvider.overrideWithValue(routeRepository),
        gpxExportServiceProvider.overrideWithValue(exportService),
      ],
      child: const MaterialApp(
        home: Scaffold(body: MapTracksRoutesDrawer()),
      ),
    ),
  );
  await tester.pump();
}
