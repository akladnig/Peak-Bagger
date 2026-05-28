import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/models/route_marker_display.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';
import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('route drafting hovers draft markers and suppresses route hover', (
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
    final routeRepository = RouteRepository.test(
      InMemoryRouteStorage([route]),
    );
    final tasmapRepository = await TestTasmapRepository.create();
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
      ),
      routeRepository: routeRepository,
    );

    await _pumpMapScreen(
      tester,
      notifier,
      routeRepository,
      tasmapRepository: tasmapRepository,
    );

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final mapRegion = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(mapRegion));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    final container = ProviderScope.containerOf(tester.element(mapRegion));
    expect(container.read(mapProvider).isRouteDrafting, isTrue);
    container.read(mapProvider.notifier).setHoveredRouteDraftMarkerId('0');
    await tester.pump();

    expect(container.read(mapProvider).hoveredRouteDraftMarkerId, '0');
    expect(container.read(mapProvider).hoveredRouteId, isNull);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() async {
      await gesture.removePointer();
    });
    await gesture.addPointer(
      location: tester.getTopLeft(mapRegion) - const Offset(20, 20),
    );
    await tester.pump();
    await gesture.moveTo(tester.getCenter(mapRegion));
    await tester.pump();

    expect(container.read(mapProvider).hoveredRouteId, isNull);

    await gesture.moveTo(tester.getTopLeft(mapRegion) - const Offset(20, 20));
    await tester.pump();

    expect(container.read(mapProvider).hoveredRouteDraftMarkerId, isNull);
    expect(find.byKey(const Key('route-draft-marker-hover-0')), findsNothing);
  });

  testWidgets('normal map hover still selects a visible route', (tester) async {
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
    final routeRepository = RouteRepository.test(
      InMemoryRouteStorage([route]),
    );
    final tasmapRepository = await TestTasmapRepository.create();
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
      ),
      routeRepository: routeRepository,
    );

    await _pumpMapScreen(
      tester,
      notifier,
      routeRepository,
      tasmapRepository: tasmapRepository,
    );

    final mapRegion = find.byKey(const Key('map-interaction-region'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() async {
      await gesture.removePointer();
    });
    await gesture.addPointer(
      location: tester.getTopLeft(mapRegion) - const Offset(20, 20),
    );
    await tester.pump();
    await gesture.moveTo(tester.getCenter(mapRegion));
    await tester.pump();

    final container = ProviderScope.containerOf(tester.element(mapRegion));
    expect(container.read(mapProvider).hoveredRouteId, 1);
  });

  testWidgets('route drafting previews a segment and inserts on click', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'show_routes': true});
    const a = LatLng(-41.5, 146.47);
    const b = LatLng(-41.5, 146.53);
    const c = LatLng(-41.5, 146.57);
    final routeRepository = RouteRepository.test(InMemoryRouteStorage());
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        isRouteDrafting: true,
        routeDraftStage: RouteDraftStage.awaitingNextPoint,
        routeDraftNextMarkerId: 3,
        routeDraftControlEndpoints: const [
          RouteDraftControlEndpoint(
            id: '0',
            point: a,
            kind: RouteDraftEndpointKind.tapped,
          ),
          RouteDraftControlEndpoint(
            id: '1',
            point: b,
            kind: RouteDraftEndpointKind.tapped,
          ),
          RouteDraftControlEndpoint(
            id: '2',
            point: c,
            kind: RouteDraftEndpointKind.tapped,
          ),
        ],
        routeDraftDisplayMarkers: const [
          RouteDraftDisplayMarker(
            id: '0',
            point: a,
            kind: RouteMarkerKind.circle,
          ),
          RouteDraftDisplayMarker(
            id: '1',
            point: b,
            kind: RouteMarkerKind.numbered,
            number: 1,
          ),
          RouteDraftDisplayMarker(
            id: '2',
            point: c,
            kind: RouteMarkerKind.target,
          ),
        ],
        routeDraftMarkers: const [a, b, c],
        routeDraftCommittedPoints: const [a, b, c],
        routeDraftProvisionalPoints: const [],
      ),
      routeRepository: routeRepository,
    );

    await _pumpMapScreen(
      tester,
      notifier,
      routeRepository,
      tasmapRepository: await TestTasmapRepository.create(),
    );

    final mapRegion = find.byKey(const Key('map-interaction-region'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() async {
      await gesture.removePointer();
    });
    await gesture.addPointer(
      location: tester.getTopLeft(mapRegion) - const Offset(20, 20),
    );
    await tester.pump();
    await gesture.moveTo(tester.getCenter(mapRegion));
    await tester.pump();

    final container = ProviderScope.containerOf(tester.element(mapRegion));
    expect(container.read(mapProvider).hoveredRouteDraftSegmentIndex, 0);
    expect(find.byKey(const Key('route-draft-segment-hover-0')), findsOneWidget);
    expect(
      tester.widget<MouseRegion>(find.byKey(const Key('map-interaction-region')))
          .cursor,
      SystemMouseCursors.click,
    );

    await tester.tapAt(tester.getCenter(mapRegion));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final afterCommit = container.read(mapProvider);
    expect(afterCommit.hoveredRouteDraftSegmentIndex, isNull);
    expect(afterCommit.routeDraftControlEndpoints, hasLength(4));
    expect(afterCommit.routeDraftDisplayMarkers, hasLength(4));
    expect(afterCommit.routeDraftDisplayMarkers[1].kind, RouteMarkerKind.target);
    expect(afterCommit.routeDraftDisplayMarkers[3].kind, RouteMarkerKind.target);
    expect(find.byKey(const Key('route-draft-segment-hover-0')), findsNothing);
  });
}

Future<void> _pumpMapScreen(
  WidgetTester tester,
  TestMapNotifier notifier,
  RouteRepository routeRepository,
  {
  required TestTasmapRepository tasmapRepository,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        routeRepositoryProvider.overrideWithValue(routeRepository),
        routeGraphStoreProvider.overrideWithValue(_ReadyRouteGraphStore()),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
        gpxTrackRepositoryProvider.overrideWithValue(
          GpxTrackRepository.test(InMemoryGpxTrackStorage()),
        ),
      ],
      child: MaterialApp(theme: CatppuccinColors.dark, home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

class _ReadyRouteGraphStore implements RouteGraphStore {
  @override
  Future<trip_routing.TripService> preload() async => trip_routing.TripService();

  @override
  Future<trip_routing.TripService> reload() async => trip_routing.TripService();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}
