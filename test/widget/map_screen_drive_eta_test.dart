import 'dart:async';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/drive_eta_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/live_location_service.dart';
import 'package:peak_bagger/services/open_route_service.dart';
import 'package:peak_bagger/services/route_graph_drive_eta_hit_service.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/theme.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('valid qualifying road click shows loading then success ETA popup', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final routeGraphStore = _DriveEtaRouteGraphStore();
    final locationService = _FakeLiveLocationService(
      const LatLng(-41.6, 146.6),
    );
    final routeSummaryCompleter = Completer<OpenRouteServiceSummary>();
    final openRouteService = _FakeOpenRouteService(routeSummaryCompleter.future);
    final hitService = _FakeDriveEtaHitService(
      const RouteGraphDriveEtaHitResult.hit(
        snappedPoint: LatLng(-41.5, 146.5),
        matchedWayId: 10,
        wayName: 'Forestry Road',
      ),
    );

    await _pumpMapScreen(
      tester,
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      ),
      tasmapRepository: tasmapRepository,
      routeGraphStore: routeGraphStore,
      locationService: locationService,
      openRouteService: openRouteService,
      hitService: hitService,
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    await _mouseClickMapCenter(tester);

    expect(container.read(mapProvider).driveEtaPopup, isNotNull);
    expect(find.byKey(const Key('drive-eta-popup-root')), findsOneWidget);
    expect(find.byKey(const Key('drive-eta-popup-loading')), findsOneWidget);
    expect(find.byKey(const Key('drive-eta-popup-duration-row')), findsNothing);
    expect(find.byKey(const Key('drive-eta-popup-distance-row')), findsNothing);

    routeSummaryCompleter.complete(
      const OpenRouteServiceSummary(
        distanceMeters: 12000,
        durationSeconds: 3900,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('drive-eta-popup-loading')), findsNothing);
    expect(find.byKey(const Key('drive-eta-popup-duration-row')), findsOneWidget);
    expect(find.byKey(const Key('drive-eta-popup-distance-row')), findsOneWidget);
    expect(
      tester
          .widget<RichText>(
            find.descendant(
              of: find.byKey(const Key('drive-eta-popup-duration-row')),
              matching: find.byType(RichText),
            ),
          )
          .text
          .toPlainText(),
      contains('1h 5m'),
    );
    expect(
      tester
          .widget<RichText>(
            find.descendant(
              of: find.byKey(const Key('drive-eta-popup-distance-row')),
              matching: find.byType(RichText),
            ),
          )
          .text
          .toPlainText(),
      contains('12.0 km'),
    );
  });

  testWidgets('GPS failure keeps ETA popup anchored with inline error', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();

    await _pumpMapScreen(
      tester,
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      ),
      tasmapRepository: tasmapRepository,
      routeGraphStore: _DriveEtaRouteGraphStore(),
      locationService: _ThrowingLiveLocationService(
        const LiveLocationException('Location permission denied'),
      ),
      openRouteService: _FakeOpenRouteService(
        Future.value(
          const OpenRouteServiceSummary(
            distanceMeters: 1000,
            durationSeconds: 600,
          ),
        ),
      ),
      hitService: _FakeDriveEtaHitService(
        const RouteGraphDriveEtaHitResult.hit(
          snappedPoint: LatLng(-41.5, 146.5),
          matchedWayId: 10,
          wayName: 'Forestry Road',
        ),
      ),
    );

    await _mouseClickMapCenter(tester);

    expect(find.byKey(const Key('drive-eta-popup-root')), findsOneWidget);
    expect(find.byKey(const Key('drive-eta-popup-error')), findsOneWidget);
    expect(find.text('Location permission denied'), findsOneWidget);
  });

  testWidgets('ORS failure keeps ETA popup anchored with inline error', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();

    await _pumpMapScreen(
      tester,
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      ),
      tasmapRepository: tasmapRepository,
      routeGraphStore: _DriveEtaRouteGraphStore(),
      locationService: _FakeLiveLocationService(
        const LatLng(-41.6, 146.6),
      ),
      openRouteService: _ThrowingOpenRouteService(
        const OpenRouteServiceException('OpenRouteService request failed (429)'),
      ),
      hitService: _FakeDriveEtaHitService(
        const RouteGraphDriveEtaHitResult.hit(
          snappedPoint: LatLng(-41.5, 146.5),
          matchedWayId: 10,
          wayName: 'Forestry Road',
        ),
      ),
    );

    await _mouseClickMapCenter(tester);

    expect(find.byKey(const Key('drive-eta-popup-root')), findsOneWidget);
    expect(find.byKey(const Key('drive-eta-popup-error')), findsOneWidget);
    expect(
      find.text('OpenRouteService request failed (429)'),
      findsOneWidget,
    );
  });

  testWidgets('missing ORS key renders an inline ETA error', (tester) async {
    final tasmapRepository = await TestTasmapRepository.create();

    await _pumpMapScreen(
      tester,
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      ),
      tasmapRepository: tasmapRepository,
      routeGraphStore: _DriveEtaRouteGraphStore(),
      locationService: _FakeLiveLocationService(
        const LatLng(-41.6, 146.6),
      ),
      openRouteService: HttpOpenRouteService(apiKey: ''),
      hitService: _FakeDriveEtaHitService(
        const RouteGraphDriveEtaHitResult.hit(
          snappedPoint: LatLng(-41.5, 146.5),
          matchedWayId: 10,
          wayName: 'Forestry Road',
        ),
      ),
    );

    await _mouseClickMapCenter(tester);

    expect(find.byKey(const Key('drive-eta-popup-error')), findsOneWidget);
    expect(find.text('OpenRouteService API key is missing'), findsOneWidget);
  });

  testWidgets('route graph unavailable renders an inline ETA error', (tester) async {
    final tasmapRepository = await TestTasmapRepository.create();

    await _pumpMapScreen(
      tester,
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      ),
      tasmapRepository: tasmapRepository,
      routeGraphStore: _DriveEtaRouteGraphStore(),
      locationService: _FakeLiveLocationService(const LatLng(-41.6, 146.6)),
      openRouteService: _FakeOpenRouteService(
        Future.value(
          const OpenRouteServiceSummary(
            distanceMeters: 1000,
            durationSeconds: 600,
          ),
        ),
      ),
      hitService: _FakeDriveEtaHitService(const RouteGraphDriveEtaHitResult.noHit()),
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    container.read(mapProvider.notifier).openDriveEtaPopupError(
      requestId: 1,
      anchor: const LatLng(-41.5, 146.5),
      title: 'Drive ETA',
      message: 'Route graph unavailable',
    );
    await tester.pump();

    expect(find.byKey(const Key('drive-eta-popup-error')), findsOneWidget);
    expect(find.text('Route graph unavailable'), findsOneWidget);
  });
  testWidgets('no hit stays silent for ETA', (tester) async {
    final tasmapRepository = await TestTasmapRepository.create();

    await _pumpMapScreen(
      tester,
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      ),
      tasmapRepository: tasmapRepository,
      routeGraphStore: _DriveEtaRouteGraphStore(),
      locationService: _FakeLiveLocationService(
        const LatLng(-41.6, 146.6),
      ),
      openRouteService: _FakeOpenRouteService(
        Future.value(
          const OpenRouteServiceSummary(
            distanceMeters: 1000,
            durationSeconds: 600,
          ),
        ),
      ),
      hitService: _FakeDriveEtaHitService(const RouteGraphDriveEtaHitResult.noHit()),
    );

    await _mouseClickMapCenter(tester);

    expect(find.byKey(const Key('drive-eta-popup-root')), findsNothing);
  });

  testWidgets('second valid click suppresses stale first ETA result', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final firstSummary = Completer<OpenRouteServiceSummary>();
    final secondSummary = Completer<OpenRouteServiceSummary>();

    await _pumpMapScreen(
      tester,
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      ),
      tasmapRepository: tasmapRepository,
      routeGraphStore: _DriveEtaRouteGraphStore(),
      locationService: _FakeLiveLocationService(
        const LatLng(-41.6, 146.6),
      ),
      openRouteService: _QueueOpenRouteService([
        firstSummary.future,
        secondSummary.future,
      ]),
      hitService: _FakeDriveEtaHitService(
        const RouteGraphDriveEtaHitResult.hit(
          snappedPoint: LatLng(-41.5, 146.5),
          matchedWayId: 10,
          wayName: 'Forestry Road',
        ),
      ),
    );

    await _mouseClickMapCenter(tester);
    await _mouseClickMapCenter(tester);

    secondSummary.complete(
      const OpenRouteServiceSummary(
        distanceMeters: 2400,
        durationSeconds: 900,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('drive-eta-popup-distance-row')), findsOneWidget);
    expect(
      tester
          .widget<RichText>(
            find.descendant(
              of: find.byKey(const Key('drive-eta-popup-distance-row')),
              matching: find.byType(RichText),
            ),
          )
          .text
          .toPlainText(),
      contains('2.4 km'),
    );

    firstSummary.complete(
      const OpenRouteServiceSummary(
        distanceMeters: 9900,
        durationSeconds: 3600,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester
          .widget<RichText>(
            find.descendant(
              of: find.byKey(const Key('drive-eta-popup-distance-row')),
              matching: find.byType(RichText),
            ),
          )
          .text
          .toPlainText(),
      contains('2.4 km'),
    );
  });

  testWidgets('background click dismisses an open ETA popup', (tester) async {
    final tasmapRepository = await TestTasmapRepository.create();

    await _pumpMapScreen(
      tester,
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      ),
      tasmapRepository: tasmapRepository,
      routeGraphStore: _DriveEtaRouteGraphStore(),
      locationService: _FakeLiveLocationService(
        const LatLng(-41.6, 146.6),
      ),
      openRouteService: _FakeOpenRouteService(
        Future.value(
          const OpenRouteServiceSummary(
            distanceMeters: 12000,
            durationSeconds: 3900,
          ),
        ),
      ),
      hitService: _QueueDriveEtaHitService([
        const RouteGraphDriveEtaHitResult.hit(
          snappedPoint: LatLng(-41.5, 146.5),
          matchedWayId: 10,
          wayName: 'Forestry Road',
        ),
        const RouteGraphDriveEtaHitResult.noHit(),
      ]),
    );

    await _mouseClickMapCenter(tester);
    expect(find.byKey(const Key('drive-eta-popup-root')), findsOneWidget);

    await _mouseClickMapCenter(tester);

    expect(find.byKey(const Key('drive-eta-popup-root')), findsNothing);
  });

  testWidgets('opening a peak popup closes an ETA popup', (tester) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final peak = Peak(
      osmId: 5,
      name: 'Test Peak',
      latitude: -41.5,
      longitude: 146.5,
    );

    await _pumpMapScreen(
      tester,
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          peaks: [peak],
        ),
      ),
      tasmapRepository: tasmapRepository,
      routeGraphStore: _DriveEtaRouteGraphStore(),
      locationService: _FakeLiveLocationService(
        const LatLng(-41.6, 146.6),
      ),
      openRouteService: _FakeOpenRouteService(
        Future.value(
          const OpenRouteServiceSummary(
            distanceMeters: 12000,
            durationSeconds: 3900,
          ),
        ),
      ),
      hitService: _FakeDriveEtaHitService(const RouteGraphDriveEtaHitResult.noHit()),
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    container.read(mapProvider.notifier).showDriveEtaPopupLoading(
      requestId: 1,
      anchor: const LatLng(-41.5, 146.5),
      title: 'Drive ETA',
    );
    await tester.pump();
    expect(find.byKey(const Key('drive-eta-popup-root')), findsOneWidget);

    container.read(mapProvider.notifier).openPeakInfoPopup(peak);
    await tester.pump();

    expect(find.byKey(const Key('drive-eta-popup-root')), findsNothing);
    expect(find.byKey(const Key('peak-info-popup')), findsOneWidget);
  });

  testWidgets('opening an ETA popup clears existing peak popup state', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final peak = Peak(
      osmId: 5,
      name: 'Test Peak',
      latitude: -41.5,
      longitude: 146.5,
    );

    await _pumpMapScreen(
      tester,
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          peaks: [peak],
        ),
      ),
      tasmapRepository: tasmapRepository,
      routeGraphStore: _DriveEtaRouteGraphStore(),
      locationService: _FakeLiveLocationService(
        const LatLng(-41.6, 146.6),
      ),
      openRouteService: _FakeOpenRouteService(
        Future.value(
          const OpenRouteServiceSummary(
            distanceMeters: 12000,
            durationSeconds: 3900,
          ),
        ),
      ),
      hitService: _FakeDriveEtaHitService(
        const RouteGraphDriveEtaHitResult.hit(
          snappedPoint: LatLng(-41.5, 146.5),
          matchedWayId: 10,
          wayName: 'Forestry Road',
        ),
      ),
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    container.read(mapProvider.notifier).openPeakInfoPopup(peak);
    await tester.pump();
    expect(container.read(mapProvider).peakInfoPeak?.osmId, peak.osmId);

    container.read(mapProvider.notifier).showDriveEtaPopupLoading(
      requestId: 1,
      anchor: const LatLng(-41.5, 146.5),
      title: 'Drive ETA',
    );
    await tester.pump();

    expect(container.read(mapProvider).peakInfoPeak, isNull);
    expect(find.byKey(const Key('drive-eta-popup-root')), findsOneWidget);
  });

  testWidgets('unanchorable ETA popup closes on the next frame', (tester) async {
    final tasmapRepository = await TestTasmapRepository.create();

    await _pumpMapScreen(
      tester,
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      ),
      tasmapRepository: tasmapRepository,
      routeGraphStore: _DriveEtaRouteGraphStore(),
      locationService: _FakeLiveLocationService(
        const LatLng(-41.6, 146.6),
      ),
      openRouteService: _FakeOpenRouteService(
        Future.value(
          const OpenRouteServiceSummary(
            distanceMeters: 12000,
            durationSeconds: 3900,
          ),
        ),
      ),
      hitService: _FakeDriveEtaHitService(
        const RouteGraphDriveEtaHitResult.hit(
          snappedPoint: LatLng(-41.5, 146.5),
          matchedWayId: 10,
          wayName: 'Forestry Road',
        ),
      ),
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    container.read(mapProvider.notifier).showDriveEtaPopupLoading(
      requestId: 1,
      anchor: const LatLng(-30.0, 120.0),
      title: 'Drive ETA',
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('drive-eta-popup-root')), findsNothing);
    expect(container.read(mapProvider).driveEtaPopup, isNull);
  });
}

Future<void> _pumpMapScreen(
  WidgetTester tester, {
  required TestMapNotifier mapNotifier,
  required TestTasmapRepository tasmapRepository,
  required RouteGraphStore routeGraphStore,
  required LiveLocationService locationService,
  required OpenRouteService openRouteService,
  required RouteGraphDriveEtaHitService hitService,
  RouteRepository? routeRepository,
  GpxTrackRepository? gpxTrackRepository,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => mapNotifier),
        routeGraphStoreProvider.overrideWithValue(routeGraphStore),
        routeRepositoryProvider.overrideWithValue(
          routeRepository ?? RouteRepository.test(InMemoryRouteStorage()),
        ),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
        gpxTrackRepositoryProvider.overrideWithValue(
          gpxTrackRepository ??
              GpxTrackRepository.test(InMemoryGpxTrackStorage()),
        ),
        liveLocationServiceProvider.overrideWithValue(locationService),
        openRouteServiceProvider.overrideWithValue(openRouteService),
        routeGraphDriveEtaHitServiceProvider.overrideWithValue(hitService),
      ],
      child: MaterialApp(theme: CatppuccinColors.dark, home: const MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _mouseClickMapCenter(WidgetTester tester) async {
  final region = find.byKey(const Key('map-interaction-region'));
  final center = tester.getCenter(region);
  final gesture = await tester.startGesture(
    center,
    kind: PointerDeviceKind.mouse,
  );
  await tester.pump();
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

class _DriveEtaRouteGraphStore
    implements RouteGraphStore, RouteGraphRepositoryProvider {
  _DriveEtaRouteGraphStore()
    : repository = RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: RouteGraphManifest(
            activeGeneration: 1,
            readinessState: RouteGraphManifest.readinessReady,
          ),
          chunks: [
            RouteGraphChunk(
              recordKey: '1|0_0',
              chunkKey: '0_0',
              generation: 1,
              minLat: -42.0,
              minLon: 146.0,
              maxLat: -41.0,
              maxLon: 147.0,
              elementCount: 3,
              payloadJson:
                  '{"elements":[{"type":"node","id":1,"lat":-41.5,"lon":146.49},{"type":"node","id":2,"lat":-41.5,"lon":146.51},{"type":"way","id":10,"nodes":[1,2],"tags":{"highway":"service","name":"Forestry Road"}}]}',
            ),
          ],
          wayIndexRows: [
            RouteGraphWayIndex(
              recordKey: '1|0_0|10',
              generation: 1,
              chunkKey: '0_0',
              osmWayId: 10,
              highway: 'service',
              access: 'public',
              name: 'Forestry Road',
              normalizedName: 'forestry road',
              lengthMeters: 200,
              tagCount: 2,
              tagsJson: '{}',
            ),
          ],
        ),
      );

  @override
  final RouteGraphRepository repository;

  @override
  Future<void> bootstrapData() async {}

  @override
  Future<trip_routing.TripService> preload() async => trip_routing.TripService();

  @override
  Future<trip_routing.TripService> reload() async => trip_routing.TripService();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}

class _FakeLiveLocationService implements LiveLocationService {
  const _FakeLiveLocationService(this.location);

  final LatLng location;

  @override
  Future<LatLng> getCurrentLocation() async => location;
}

class _FakeOpenRouteService implements OpenRouteService {
  _FakeOpenRouteService(this.summaryFuture);

  final Future<OpenRouteServiceSummary> summaryFuture;

  @override
  Future<OpenRouteServiceSummary> fetchDrivingSummary({
    required LatLng origin,
    required LatLng destination,
  }) {
    return summaryFuture;
  }
}

class _ThrowingOpenRouteService implements OpenRouteService {
  const _ThrowingOpenRouteService(this.error);

  final OpenRouteServiceException error;

  @override
  Future<OpenRouteServiceSummary> fetchDrivingSummary({
    required LatLng origin,
    required LatLng destination,
  }) {
    throw error;
  }
}

class _ThrowingLiveLocationService implements LiveLocationService {
  const _ThrowingLiveLocationService(this.error);

  final LiveLocationException error;

  @override
  Future<LatLng> getCurrentLocation() async {
    throw error;
  }
}

class _FakeDriveEtaHitService extends RouteGraphDriveEtaHitService {
  _FakeDriveEtaHitService(this.result)
    : super(
        RouteGraphQueryService(
          RouteGraphRepository.test(InMemoryRouteGraphStorage()),
        ),
      );

  final RouteGraphDriveEtaHitResult result;

  @override
  RouteGraphDriveEtaHitResult hitTest({
    required Offset pointerPosition,
    required MapCamera camera,
    required LatLng tappedLocation,
  }) {
    return result;
  }
}

class _QueueDriveEtaHitService extends RouteGraphDriveEtaHitService {
  _QueueDriveEtaHitService(this._results)
    : super(
        RouteGraphQueryService(
          RouteGraphRepository.test(InMemoryRouteGraphStorage()),
        ),
      );

  final List<RouteGraphDriveEtaHitResult> _results;
  var _index = 0;

  @override
  RouteGraphDriveEtaHitResult hitTest({
    required Offset pointerPosition,
    required MapCamera camera,
    required LatLng tappedLocation,
  }) {
    final result = _results[_index];
    if (_index < _results.length - 1) {
      _index += 1;
    }
    return result;
  }
}

class _QueueOpenRouteService implements OpenRouteService {
  _QueueOpenRouteService(this._summaries);

  final List<Future<OpenRouteServiceSummary>> _summaries;
  var _index = 0;

  @override
  Future<OpenRouteServiceSummary> fetchDrivingSummary({
    required LatLng origin,
    required LatLng destination,
  }) {
    final summary = _summaries[_index];
    if (_index < _summaries.length - 1) {
      _index += 1;
    }
    return summary;
  }
}
