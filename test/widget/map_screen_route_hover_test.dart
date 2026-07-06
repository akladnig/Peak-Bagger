import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  testWidgets(
    'route drafting hovers draft markers and suppresses route hover',
    (tester) async {
      SharedPreferences.setMockInitialValues({'show_routes': true});
      final route = app_route.Route(
        id: 1,
        name: 'Visible Route',
        gpxRoute: const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
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
    },
  );

  testWidgets('route drafting only hovers a draft marker within the marker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'show_routes': true});
    final routeRepository = RouteRepository.test(InMemoryRouteStorage());
    final tasmapRepository = await TestTasmapRepository.create();
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
            point: LatLng(-41.5, 146.47),
            kind: RouteDraftEndpointKind.tapped,
          ),
          RouteDraftControlEndpoint(
            id: '1',
            point: LatLng(-41.5, 146.53),
            kind: RouteDraftEndpointKind.tapped,
          ),
          RouteDraftControlEndpoint(
            id: '2',
            point: LatLng(-41.5, 146.57),
            kind: RouteDraftEndpointKind.tapped,
          ),
        ],
        routeDraftDisplayMarkers: const [
          RouteDraftDisplayMarker(
            id: '0',
            point: LatLng(-41.5, 146.47),
            kind: RouteMarkerKind.circle,
          ),
          RouteDraftDisplayMarker(
            id: '1',
            point: LatLng(-41.5, 146.53),
            kind: RouteMarkerKind.numbered,
            number: 1,
          ),
          RouteDraftDisplayMarker(
            id: '2',
            point: LatLng(-41.5, 146.57),
            kind: RouteMarkerKind.target,
          ),
        ],
        routeDraftMarkers: const [
          LatLng(-41.5, 146.47),
          LatLng(-41.5, 146.53),
          LatLng(-41.5, 146.57),
        ],
        routeDraftCommittedPoints: const [
          LatLng(-41.5, 146.47),
          LatLng(-41.5, 146.53),
          LatLng(-41.5, 146.57),
        ],
        routeDraftProvisionalPoints: const [],
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
    final markerHitbox = find.byKey(const Key('route-draft-marker-hitbox-0'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() async {
      await gesture.removePointer();
    });

    await gesture.addPointer(
      location: tester.getTopLeft(mapRegion) - const Offset(20, 20),
    );
    await tester.pump();
    await gesture.moveTo(tester.getCenter(markerHitbox));
    await tester.pump();

    final container = ProviderScope.containerOf(tester.element(mapRegion));
    expect(container.read(mapProvider).hoveredRouteDraftMarkerId, '0');

    await gesture.moveTo(tester.getCenter(markerHitbox) + const Offset(0, 15));
    await tester.pump();

    expect(container.read(mapProvider).hoveredRouteDraftMarkerId, isNull);
    expect(find.byKey(const Key('route-draft-marker-hover-0')), findsNothing);
  });

  testWidgets('normal map hover still selects a visible route', (tester) async {
    SharedPreferences.setMockInitialValues({'show_routes': true});
    final route = app_route.Route(
      id: 1,
      name: 'Visible Route',
      gpxRoute: const [LatLng(-41.5, 146.49), LatLng(-41.5, 146.51)],
      distance2d: 17450,
    );
    final routeRepository = RouteRepository.test(InMemoryRouteStorage([route]));
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

  testWidgets(
    'clicking a draft marker opens the delete popup without adding a point',
    (tester) async {
      SharedPreferences.setMockInitialValues({'show_routes': true});
      final routeRepository = RouteRepository.test(InMemoryRouteStorage());
      final tasmapRepository = await TestTasmapRepository.create();
      final notifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          isRouteDrafting: true,
          routeDraftStage: RouteDraftStage.awaitingNextPoint,
          routeDraftMode: RouteMode.straightLine,
          routeDraftNextMarkerId: 1,
          routeDraftControlEndpoints: const [
            RouteDraftControlEndpoint(
              id: '0',
              point: LatLng(-41.5, 146.5),
              kind: RouteDraftEndpointKind.tapped,
            ),
          ],
          routeDraftDisplayMarkers: const [
            RouteDraftDisplayMarker(
              id: '0',
              point: LatLng(-41.5, 146.5),
              kind: RouteMarkerKind.circle,
            ),
          ],
          routeDraftMarkers: const [LatLng(-41.5, 146.5)],
          routeDraftCommittedPoints: const [LatLng(-41.5, 146.5)],
        ),
        routeRepository: routeRepository,
      );

      await _pumpMapScreen(
        tester,
        notifier,
        routeRepository,
        tasmapRepository: tasmapRepository,
      );

      await tester.tap(find.byKey(const Key('route-draft-marker-hitbox-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );
      expect(find.byKey(const Key('route-draft-delete-popup')), findsOneWidget);
      expect(
        find.byKey(const Key('route-draft-delete-action')),
        findsOneWidget,
      );
      expect(container.read(mapProvider).routeDraftMarkers, const [
        LatLng(-41.5, 146.5),
      ]);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byKey(const Key('route-draft-delete-popup')), findsNothing);
      expect(container.read(mapProvider).routeDraftMarkers, const [
        LatLng(-41.5, 146.5),
      ]);
    },
  );

  testWidgets('delete popup action removes the selected draft marker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'show_routes': true});
    final routeRepository = RouteRepository.test(InMemoryRouteStorage());
    final tasmapRepository = await TestTasmapRepository.create();
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        isRouteDrafting: true,
        routeDraftStage: RouteDraftStage.awaitingNextPoint,
        routeDraftMode: RouteMode.straightLine,
        routeDraftNextMarkerId: 1,
        routeDraftControlEndpoints: const [
          RouteDraftControlEndpoint(
            id: '0',
            point: LatLng(-41.5, 146.5),
            kind: RouteDraftEndpointKind.tapped,
          ),
        ],
        routeDraftDisplayMarkers: const [
          RouteDraftDisplayMarker(
            id: '0',
            point: LatLng(-41.5, 146.5),
            kind: RouteMarkerKind.circle,
          ),
        ],
        routeDraftMarkers: const [LatLng(-41.5, 146.5)],
        routeDraftCommittedPoints: const [LatLng(-41.5, 146.5)],
      ),
      routeRepository: routeRepository,
    );

    await _pumpMapScreen(
      tester,
      notifier,
      routeRepository,
      tasmapRepository: tasmapRepository,
    );

    await tester.tap(find.byKey(const Key('route-draft-marker-hitbox-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('route-draft-delete-action')));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    expect(find.byKey(const Key('route-draft-delete-popup')), findsNothing);
    expect(container.read(mapProvider).routeDraftMarkers, isEmpty);
    expect(
      container.read(mapProvider).routeDraftStage,
      RouteDraftStage.awaitingStart,
    );
  });

  testWidgets(
    'dragging a draft marker moves it without opening the delete popup',
    (tester) async {
      SharedPreferences.setMockInitialValues({'show_routes': true});
      final routeRepository = RouteRepository.test(InMemoryRouteStorage());
      final tasmapRepository = await TestTasmapRepository.create();
      final notifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          isRouteDrafting: true,
          routeDraftStage: RouteDraftStage.awaitingNextPoint,
          routeDraftMode: RouteMode.straightLine,
          routeDraftNextMarkerId: 2,
          routeDraftControlEndpoints: const [
            RouteDraftControlEndpoint(
              id: '0',
              point: LatLng(-41.5, 146.5),
              kind: RouteDraftEndpointKind.tapped,
            ),
            RouteDraftControlEndpoint(
              id: '1',
              point: LatLng(-41.5, 146.53),
              kind: RouteDraftEndpointKind.tapped,
            ),
          ],
          routeDraftDisplayMarkers: const [
            RouteDraftDisplayMarker(
              id: '0',
              point: LatLng(-41.5, 146.5),
              kind: RouteMarkerKind.circle,
            ),
            RouteDraftDisplayMarker(
              id: '1',
              point: LatLng(-41.5, 146.53),
              kind: RouteMarkerKind.target,
            ),
          ],
          routeDraftMarkers: const [
            LatLng(-41.5, 146.5),
            LatLng(-41.5, 146.53),
          ],
          routeDraftCommittedPoints: const [
            LatLng(-41.5, 146.5),
            LatLng(-41.5, 146.53),
          ],
        ),
        routeRepository: routeRepository,
      );

      await _pumpMapScreen(
        tester,
        notifier,
        routeRepository,
        tasmapRepository: tasmapRepository,
      );

      final markerHitbox = find.byKey(const Key('route-draft-marker-hitbox-1'));
      final markerShell = find.byKey(const Key('route-draft-marker-1'));
      final originalCenter = tester.getCenter(markerShell);
      final gesture = await tester.startGesture(tester.getCenter(markerHitbox));
      await gesture.moveBy(const Offset(30, 0));
      await tester.pump();

      final draggedCenter = tester.getCenter(markerShell);
      expect(draggedCenter.dx, closeTo(originalCenter.dx + 30, 1));
      expect(draggedCenter.dy, closeTo(originalCenter.dy, 1));

      await gesture.up();
      await tester.pump();
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('map-interaction-region'))),
      );
      expect(find.byKey(const Key('route-draft-delete-popup')), findsNothing);
      expect(
        container.read(mapProvider).routeDraftMarkers[1],
        isNot(const LatLng(-41.5, 146.53)),
      );
    },
  );

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
    expect(
      find.byKey(const Key('route-draft-segment-hover-0')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<MouseRegion>(find.byKey(const Key('map-interaction-region')))
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
    expect(
      afterCommit.routeDraftDisplayMarkers[1].kind,
      RouteMarkerKind.numbered,
    );
    expect(afterCommit.routeDraftDisplayMarkers[1].number, 1);
    expect(
      afterCommit.routeDraftDisplayMarkers[2].kind,
      RouteMarkerKind.numbered,
    );
    expect(afterCommit.routeDraftDisplayMarkers[2].number, 2);
    expect(
      afterCommit.routeDraftDisplayMarkers[3].kind,
      RouteMarkerKind.target,
    );
    expect(find.byKey(const Key('route-draft-segment-hover-0')), findsNothing);
  });

  testWidgets(
    'route drafting allows dragging directly from hovered segment circle',
    (tester) async {
      SharedPreferences.setMockInitialValues({'show_routes': true});
      const a = LatLng(-41.51, 146.47);
      const b = LatLng(-41.5, 146.5);
      const c = LatLng(-41.51, 146.53);
      final routeRepository = RouteRepository.test(InMemoryRouteStorage());
      final notifier = TestMapNotifier(
        MapState(
          center: b,
          zoom: 15,
          basemap: Basemap.tracestrack,
          showRoutes: true,
          isRouteDrafting: true,
          routeDraftMode: RouteMode.straightLine,
          routeDraftStage: RouteDraftStage.awaitingNextPoint,
          routeDraftNextMarkerId: 2,
          routeDraftControlEndpoints: const [
            RouteDraftControlEndpoint(
              id: '0',
              point: a,
              kind: RouteDraftEndpointKind.tapped,
            ),
            RouteDraftControlEndpoint(
              id: '1',
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
              point: c,
              kind: RouteMarkerKind.target,
            ),
          ],
          routeDraftMarkers: const [a, c],
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
      final hoverGesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(() async {
        await hoverGesture.removePointer();
      });
      await hoverGesture.addPointer(
        location: tester.getTopLeft(mapRegion) - const Offset(20, 20),
      );
      await tester.pump();
      await hoverGesture.moveTo(tester.getCenter(mapRegion));
      await tester.pump();

      expect(
        find.byKey(const Key('route-draft-segment-hitbox-0')),
        findsOneWidget,
      );

      final dragGesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('route-draft-segment-hitbox-0'))),
      );
      await dragGesture.moveBy(const Offset(30, -10));
      await tester.pump();

      final container = ProviderScope.containerOf(tester.element(mapRegion));
      final liveState = container.read(mapProvider);
      expect(liveState.routeDraftDisplayMarkers, hasLength(3));
      expect(
        liveState.routeDraftDisplayMarkers[1].kind,
        RouteMarkerKind.numbered,
      );
      expect(liveState.routeDraftDisplayMarkers[1].point, isNot(b));
      expect(
        liveState.routeDraftCommittedPoints,
        contains(liveState.routeDraftDisplayMarkers[1].point),
      );

      await dragGesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('route drafting previews along the committed route path', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'show_routes': true});
    const a = LatLng(-41.51, 146.47);
    const b = LatLng(-41.5, 146.5);
    const c = LatLng(-41.51, 146.53);
    final routeRepository = RouteRepository.test(InMemoryRouteStorage());
    final notifier = TestMapNotifier(
      MapState(
        center: b,
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        isRouteDrafting: true,
        routeDraftStage: RouteDraftStage.awaitingNextPoint,
        routeDraftNextMarkerId: 2,
        routeDraftControlEndpoints: const [
          RouteDraftControlEndpoint(
            id: '0',
            point: a,
            kind: RouteDraftEndpointKind.tapped,
          ),
          RouteDraftControlEndpoint(
            id: '1',
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
            point: c,
            kind: RouteMarkerKind.target,
          ),
        ],
        routeDraftMarkers: const [a, c],
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
    final hoveredPoint = container
        .read(mapProvider)
        .hoveredRouteDraftSegmentPoint;

    expect(container.read(mapProvider).hoveredRouteDraftSegmentIndex, 0);
    expect(
      find.byKey(const Key('route-draft-segment-hover-0')),
      findsOneWidget,
    );
    expect(hoveredPoint, isNotNull);
    expect(hoveredPoint!.latitude, closeTo(b.latitude, 0.0002));
    expect(hoveredPoint.longitude, closeTo(b.longitude, 0.0002));
  });

  testWidgets(
    'route drafting does not preview a segment near a peak target endpoint',
    (tester) async {
      SharedPreferences.setMockInitialValues({'show_routes': true});
      const start = LatLng(-41.5, 146.47);
      const peak = LatLng(-41.5, 146.5);
      final routeRepository = RouteRepository.test(InMemoryRouteStorage());
      final notifier = TestMapNotifier(
        MapState(
          center: peak,
          zoom: 15,
          basemap: Basemap.tracestrack,
          showRoutes: true,
          isRouteDrafting: true,
          routeDraftStage: RouteDraftStage.awaitingNextPoint,
          routeDraftNextMarkerId: 2,
          routeDraftControlEndpoints: const [
            RouteDraftControlEndpoint(
              id: '0',
              point: start,
              kind: RouteDraftEndpointKind.tapped,
            ),
            RouteDraftControlEndpoint(
              id: '1',
              point: peak,
              kind: RouteDraftEndpointKind.peakTarget,
            ),
          ],
          routeDraftDisplayMarkers: const [
            RouteDraftDisplayMarker(
              id: '0',
              point: start,
              kind: RouteMarkerKind.circle,
            ),
            RouteDraftDisplayMarker(
              id: '1',
              point: peak,
              kind: RouteMarkerKind.target,
            ),
          ],
          routeDraftMarkers: const [start, peak],
          routeDraftCommittedPoints: const [start, peak],
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
      await gesture.moveTo(tester.getCenter(mapRegion) + const Offset(-11, 0));
      await tester.pump();

      final container = ProviderScope.containerOf(tester.element(mapRegion));
      expect(container.read(mapProvider).hoveredRouteDraftMarkerId, isNull);
      expect(container.read(mapProvider).hoveredRouteDraftSegmentIndex, isNull);
      expect(
        find.byKey(const Key('route-draft-segment-hover-0')),
        findsNothing,
      );
    },
  );
}

Future<void> _pumpMapScreen(
  WidgetTester tester,
  TestMapNotifier notifier,
  RouteRepository routeRepository, {
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
      child: MaterialApp(theme: MyTheme.dark, home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

class _ReadyRouteGraphStore implements RouteGraphStore {
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
