import 'dart:async';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/providers/drive_eta_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/live_location_service.dart';
import 'package:peak_bagger/services/open_route_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/route_graph_drive_eta_hit_service.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class DriveEtaRobot {
  DriveEtaRobot(
    this.tester,
    this.initialState, {
    RouteRepository? routeRepository,
    GpxTrackRepository? gpxTrackRepository,
  }) : _routeRepository =
           routeRepository ?? RouteRepository.test(InMemoryRouteStorage()),
       _gpxTrackRepository =
           gpxTrackRepository ??
           GpxTrackRepository.test(InMemoryGpxTrackStorage());

  final WidgetTester tester;
  final MapState initialState;
  final RouteRepository _routeRepository;
  final GpxTrackRepository _gpxTrackRepository;

  final _summaryCompleter = Completer<OpenRouteServiceSummary>();
  late final TestTasmapRepository _tasmapRepository;
  TestGesture? _mouseGesture;
  bool _mouseAdded = false;

  Finder get mapInteractionRegion =>
      find.byKey(const Key('map-interaction-region'));
  Finder get popupRoot => find.byKey(const Key('drive-eta-popup-root'));
  Finder get loadingState => find.byKey(const Key('drive-eta-popup-loading'));
  Finder get durationRow =>
      find.byKey(const Key('drive-eta-popup-duration-row'));
  Finder get distanceRow =>
      find.byKey(const Key('drive-eta-popup-distance-row'));

  Future<void> pumpApp() async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    _tasmapRepository = await TestTasmapRepository.create();
    router = createRouter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              initialState,
              routeRepository: _routeRepository,
              gpxTrackRepository: _gpxTrackRepository,
            ),
          ),
          routeGraphReadinessProvider.overrideWith(
            () => _ReadyRouteGraphReadinessNotifier(),
          ),
          routeGraphStoreProvider.overrideWithValue(_DriveEtaRouteGraphStore()),
          routeRepositoryProvider.overrideWithValue(_routeRepository),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          tasmapRepositoryProvider.overrideWithValue(_tasmapRepository),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(_tasmapRepository),
          ),
          gpxTrackRepositoryProvider.overrideWithValue(_gpxTrackRepository),
          liveLocationServiceProvider.overrideWithValue(
            const _FakeLiveLocationService(LatLng(-41.6, 146.6)),
          ),
          openRouteServiceProvider.overrideWithValue(
            _RobotOpenRouteService(_summaryCompleter.future),
          ),
          routeGraphDriveEtaHitServiceProvider.overrideWithValue(
            _FakeDriveEtaHitService(
              const RouteGraphDriveEtaHitResult.hit(
                snappedPoint: LatLng(-41.5, 146.5),
                matchedWayId: 10,
                wayName: 'Forestry Road',
              ),
            ),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
  }

  Future<void> openMap() async {
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> clickEtaTarget() async {
    final center = tester.getCenter(mapInteractionRegion);
    final gesture = await _ensureMouse(center);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final driveHomeAction = find.byKey(const Key('map-tap-action-drive-home'));
    if (driveHomeAction.evaluate().isNotEmpty) {
      await tester.tap(driveHomeAction);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  void completeRoute({
    required double distanceMeters,
    required int durationSeconds,
  }) {
    _summaryCompleter.complete(
      OpenRouteServiceSummary(
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
      ),
    );
  }

  Future<void> pumpAfterAsync() async {
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  void expectLoadingVisible() {
    expect(popupRoot, findsOneWidget);
    expect(loadingState, findsOneWidget);
  }

  void expectSuccessVisible() {
    expect(popupRoot, findsOneWidget);
    expect(durationRow, findsOneWidget);
    expect(distanceRow, findsOneWidget);
  }

  void expectSelectedLocation(LatLng location) {
    expect(container().read(mapProvider).selectedLocation, location);
  }

  void expectSelectedRoute(int routeId) {
    expect(container().read(mapProvider).selectedRouteId, routeId);
  }

  void expectSelectedTrack(int trackId) {
    expect(container().read(mapProvider).selectedTrackId, trackId);
  }

  ProviderContainer container() {
    return ProviderScope.containerOf(tester.element(mapInteractionRegion));
  }

  Future<TestGesture> _ensureMouse(Offset location) async {
    _mouseGesture ??= await tester.startGesture(
      location,
      kind: PointerDeviceKind.mouse,
    );
    if (_mouseAdded) {
      return _mouseGesture!;
    }
    _mouseAdded = true;
    return _mouseGesture!;
  }
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
  Future<trip_routing.TripService> preload() async =>
      trip_routing.TripService();

  @override
  Future<trip_routing.TripService> reload() async => trip_routing.TripService();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}

class _ReadyRouteGraphReadinessNotifier extends RouteGraphReadinessNotifier {
  @override
  RouteGraphReadinessState build() {
    return const RouteGraphReadinessState.ready();
  }
}

class _FakeLiveLocationService implements LiveLocationService {
  const _FakeLiveLocationService(this.location);

  final LatLng location;

  @override
  Future<LatLng> getCurrentLocation() async => location;
}

class _RobotOpenRouteService implements OpenRouteService {
  _RobotOpenRouteService(this.summaryFuture);

  final Future<OpenRouteServiceSummary> summaryFuture;

  @override
  Future<OpenRouteServiceSummary> fetchDrivingSummary({
    required LatLng origin,
    required LatLng destination,
  }) {
    return summaryFuture;
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
