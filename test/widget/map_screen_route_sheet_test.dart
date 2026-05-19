import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';

import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';
import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('create route opens draft sheet and clears selection state', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        selectedLocation: const LatLng(-41.6, 146.6),
        showTracks: true,
        tracks: [_track(10)],
        selectedTrackId: 10,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final container = _container(tester);
    final state = container.read(mapProvider);
    expect(state.isRouteDrafting, isTrue);
    expect(state.routeDraftMode, RouteMode.snapToTrail);
    expect(state.routeDraftName, isEmpty);
    expect(state.routeDraftMarkers, isEmpty);
    expect(state.selectedLocation, isNull);
    expect(state.selectedTrackId, isNull);

    expect(find.byKey(const Key('route-bottom-sheet')), findsOneWidget);
    expect(find.byKey(const Key('route-name-field')), findsOneWidget);
    expect(find.byKey(const Key('route-mode-snap-to-trail')), findsOneWidget);
    expect(find.byKey(const Key('route-mode-straight-line')), findsOneWidget);
    expect(find.byKey(const Key('route-elevation-placeholder')), findsOneWidget);
  });

  testWidgets('route sheet accepts name input and closes on cancel', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('route-name-field')), 'Ridge Loop');
    await tester.pump();

    expect(_container(tester).read(mapProvider).routeDraftName, 'Ridge Loop');

    await tester.tap(find.byKey(const Key('route-cancel-button')));
    await tester.pumpAndSettle();

    final state = _container(tester).read(mapProvider);
    expect(state.isRouteDrafting, isFalse);
    expect(state.routeDraftName, isEmpty);
    expect(state.routeDraftMarkers, isEmpty);
    expect(find.byKey(const Key('route-bottom-sheet')), findsNothing);
  });

  testWidgets('route taps append temporary markers and stay isolated', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final state = _container(tester).read(mapProvider);
    expect(state.routeDraftMarkers, hasLength(1));
    expect(state.routeDraftMarkers.first.latitude, closeTo(-41.5, 0.000001));
    expect(state.routeDraftMarkers.first.longitude, closeTo(146.5, 0.000001));
    expect(state.selectedLocation, isNull);
    expect(state.selectedTrackId, isNull);
    expect(find.byKey(const Key('route-draft-marker-layer')), findsOneWidget);
    expect(find.byKey(const Key('route-draft-marker-0')), findsOneWidget);
    final markerContainer = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const Key('route-draft-marker-0')),
        matching: find.byType(Container),
      ),
    );
    final decoration = markerContainer.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFFF0000));
  });

  testWidgets('blank route name shows inline error and save stays disabled', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    expect(find.text('A Route name must be entered'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('route-save-button')),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('valid route save persists routed geometry and closes sheet', (tester) async {
    final routeRepository = RouteRepository.test(InMemoryRouteStorage());
    final tasmapRepository = await TestTasmapRepository.create();
    final routePlanner = _CompletingRoutePlanner();
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
    await _pumpMap(
      tester,
      notifier,
      routeRepository: routeRepository,
      tasmapRepository: tasmapRepository,
    );

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region) + const Offset(-40, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(region) + const Offset(40, 0));
    await tester.pump();

    expect(find.byKey(const Key('route-loading-text')), findsOneWidget);

    routePlanner.complete(
      const PlannedRouteSegment(
        points: [
          LatLng(-41.5, 146.5),
          LatLng(-41.55, 146.55),
          LatLng(-41.6, 146.6),
        ],
        distanceMeters: 1234.5,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-distance-text')), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('route-name-field')), 'Ridge Loop');
    await tester.pump();

    await tester.tap(find.byKey(const Key('route-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-bottom-sheet')), findsNothing);
    final savedRoutes = routeRepository.getAllRoutes();
    expect(savedRoutes, hasLength(1));
    expect(savedRoutes.single.name, 'Ridge Loop');
    expect(savedRoutes.single.colour, 0xFFFF0000);
    expect(savedRoutes.single.gpxRoute, hasLength(3));
    expect(savedRoutes.single.distance2d, 1234.5);
    expect(savedRoutes.single.displayRoutePointsByZoom, isNot('{}'));
    expect(_container(tester).read(mapProvider).showRoutes, isTrue);
  });

  testWidgets('route save failure shows snackbar and keeps sheet open', (
    tester,
  ) async {
    final routeRepository = RouteRepository.test(_FailingRouteStorage());
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
    await _pumpMap(
      tester,
      notifier,
      routeRepository: routeRepository,
      tasmapRepository: tasmapRepository,
    );

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region) + const Offset(-40, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(region) + const Offset(40, 0));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('route-name-field')), 'Failure Route');
    await tester.pump();

    await tester.tap(find.byKey(const Key('route-save-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-bottom-sheet')), findsOneWidget);
    expect(find.textContaining('Failed to save route'), findsOneWidget);
  });

  testWidgets('routing failure shows inline error and save stays disabled', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final notifier = MapNotifier(
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      overpassService: OverpassService(),
      tasmapRepository: tasmapRepository,
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
      routePlanner: const _FailingRoutePlanner('No path found.'),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      loadPositionOnBuild: false,
      loadPeaksOnBuild: false,
      loadTracksOnBuild: false,
    );
    await _pumpMap(
      tester,
      notifier,
      tasmapRepository: tasmapRepository,
    );

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region) + const Offset(-40, 0));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(region) + const Offset(40, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-error-text')), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const Key('route-save-button')),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('create route hides the entry button while drafting', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    final fab = find.byKey(const Key('create-route-fab'));
    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-bottom-sheet')), findsOneWidget);
    expect(fab, findsNothing);
  });
}

class _CompletingRoutePlanner implements RoutePlanner {
  final _completer = Completer<PlannedRouteSegment>();

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
  }) {
    return _completer.future;
  }

  void complete(PlannedRouteSegment segment) {
    if (!_completer.isCompleted) {
      _completer.complete(segment);
    }
  }
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

class _FailingRoutePlanner implements RoutePlanner {
  const _FailingRoutePlanner(this.message);

  final String message;

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
  }) async {
    throw RoutePlanningException(message);
  }
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byKey(const Key('map-interaction-region'))),
  );
}

Future<void> _pumpMap(
  WidgetTester tester,
  MapNotifier notifier, {
  RouteRepository? routeRepository,
  TasmapRepository? tasmapRepository,
}
) async {
  final effectiveTasmapRepository = tasmapRepository ?? await TestTasmapRepository.create();
  final effectiveRouteRepository = routeRepository ??
      RouteRepository.test(InMemoryRouteStorage());
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        routeRepositoryProvider.overrideWithValue(effectiveRouteRepository),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        tasmapRepositoryProvider.overrideWithValue(effectiveTasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(effectiveTasmapRepository),
        ),
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

GpxTrack _track(int id) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    gpxFile: '<gpx></gpx>',
  );
}

class _FailingRouteStorage implements RouteStorage {
  @override
  bool delete(int id) => false;

  @override
  List<app_route.Route> getAll() => const [];

  @override
  app_route.Route? getById(int id) => null;

  @override
  int save(app_route.Route route) {
    throw Exception('write failed');
  }
}
