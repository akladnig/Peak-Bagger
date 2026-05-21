import 'dart:ui' show PointerDeviceKind;

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
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';

import '../../harness/test_map_notifier.dart';

class RouteInfoRobot {
  RouteInfoRobot(
    this.tester,
    this.initialState, {
    required this.routeRepository,
    this.surfaceSize = const Size(1600, 900),
  });

  final WidgetTester tester;
  final MapState initialState;
  final RouteRepository routeRepository;
  final Size surfaceSize;

  TestGesture? _mouseGesture;
  bool _mouseAdded = false;

  Finder get mapInteractionRegion =>
      find.byKey(const Key('map-interaction-region'));
  Finder get routeInfoPanel => find.byKey(const Key('track-info-panel'));
  Finder get routeInfoPanelClose =>
      find.byKey(const Key('track-info-panel-close'));

  Future<void> pumpApp() async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => TestMapNotifier(initialState, routeRepository: routeRepository)),
          routeRepositoryProvider.overrideWithValue(routeRepository),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          gpxTrackRepositoryProvider.overrideWithValue(
            GpxTrackRepository.test(InMemoryGpxTrackStorage()),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> hoverRoute() async {
    final point = tester.getCenter(mapInteractionRegion);
    await _ensureMouse(point);
    await _mouseGesture!.moveTo(point);
    await tester.pump();
  }

  Future<void> clickRoute() async {
    final point = tester.getCenter(mapInteractionRegion);
    await _ensureMouse(point);
    await _mouseGesture!.moveTo(point);
    await tester.pump();
    await _mouseGesture!.down(point);
    await tester.pump();
    await _mouseGesture!.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> closeRoutePanel() async {
    await tester.tap(routeInfoPanelClose);
    await tester.pumpAndSettle();
  }

  Future<void> deleteRouteAndRefresh(int routeId) async {
    routeRepository.deleteRoute(routeId);
    container().read(routeRevisionProvider.notifier).increment();
    await tester.pumpAndSettle();
  }

  void expectRoutePanelVisible(String routeName) {
    expect(routeInfoPanel, findsOneWidget);
    expect(routeInfoPanelClose, findsOneWidget);
    expect(find.text(routeName), findsOneWidget);
  }

  void expectRoutePanelHidden() {
    expect(routeInfoPanel, findsNothing);
    expect(
      container().read(mapProvider).selectedRouteId,
      isNull,
    );
  }

  void expectSelectedRoute(int routeId) {
    expect(container().read(mapProvider).selectedRouteId, routeId);
  }

  ProviderContainer container() {
    return ProviderScope.containerOf(tester.element(mapInteractionRegion));
  }

  Future<void> dispose() async {
    if (_mouseGesture != null && _mouseAdded) {
      await _mouseGesture!.removePointer();
      _mouseAdded = false;
    }
  }

  Future<void> _ensureMouse(Offset location) async {
    _mouseGesture ??= await tester.createGesture(kind: PointerDeviceKind.mouse);
    if (_mouseAdded) {
      return;
    }
    await _mouseGesture!.addPointer(location: location);
    await tester.pump();
    _mouseAdded = true;
  }
}

app_route.Route routeFixture({
  int id = 1,
  String? name,
}) {
  return app_route.Route(
    id: id,
    name: name ?? 'Route $id',
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
}
