import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/route_repository.dart';

import '../../harness/test_tasmap_repository.dart';

class MapRouteRobot {
  MapRouteRobot(
    this.tester,
    this.initialState, {
    required this.routePlanningOutcomes,
    RouteRepository? routeRepository,
  }) : routeRepository =
           routeRepository ?? RouteRepository.test(InMemoryRouteStorage());

  final WidgetTester tester;
  final MapState initialState;
  final List<Object> routePlanningOutcomes;
  final RouteRepository routeRepository;

  late final TestTasmapRepository _tasmapRepository;
  late final MapNotifier _mapNotifier;

  Finder get mapInteractionRegion =>
      find.byKey(const Key('map-interaction-region'));
  Finder get createRouteFab => find.byKey(const Key('create-route-fab'));
  Finder get routeSaveButton => find.byKey(const Key('route-save-button'));
  Finder get routeDistanceText => find.byKey(const Key('route-distance-text'));
  Finder get routeBottomSheet => find.byKey(const Key('route-bottom-sheet'));

  Future<void> pumpApp() async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    _tasmapRepository = await TestTasmapRepository.create();
    _mapNotifier = MapNotifier(
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      overpassService: OverpassService(),
      tasmapRepository: _tasmapRepository,
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: routeRepository,
      routePlanner: _QueueRoutePlanner(routePlanningOutcomes),
      peaksBaggedRepository: PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage(),
      ),
      loadPositionOnBuild: false,
      loadPeaksOnBuild: false,
      loadTracksOnBuild: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => _mapNotifier),
          routeRepositoryProvider.overrideWithValue(routeRepository),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
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

  Future<void> enterRouteMode() async {
    await tester.tap(createRouteFab);
    await tester.pumpAndSettle();
  }

  Future<void> tapRoutePoint(Offset offset) async {
    await tester.tapAt(tester.getCenter(mapInteractionRegion) + offset);
    await tester.pumpAndSettle();
  }

  Future<void> enterRouteName(String value) async {
    container().read(mapProvider.notifier).setRouteDraftName(value);
    await tester.pump();
  }

  Future<void> saveRoute() async {
    container().read(mapProvider.notifier).saveRouteDraft();
    await tester.pumpAndSettle();
  }

  ProviderContainer container() {
    return ProviderScope.containerOf(tester.element(mapInteractionRegion));
  }

  List<app_route.Route> savedRoutes() => routeRepository.getAllRoutes();

  Future<void> dispose() async {
    await tester.binding.setSurfaceSize(null);
    await _tasmapRepository.dispose();
  }
}

class _QueueRoutePlanner implements RoutePlanner {
  _QueueRoutePlanner(this._outcomes);

  final List<Object> _outcomes;
  var _index = 0;

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
  }) async {
    final outcome = _outcomes[_index++];
    if (outcome is PlannedRouteSegment) {
      return outcome;
    }
    if (outcome is RoutePlanningException) {
      throw outcome;
    }
    if (outcome is String) {
      throw RoutePlanningException(outcome);
    }
    throw const RoutePlanningException('Unexpected queued route outcome.');
  }
}
