import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/route_graph_refresh_service.dart';

import '../../harness/test_peak_notifier.dart';
import '../../harness/test_tasmap_repository.dart';
import 'route_graph_refresh_robot.dart';

void main() {
  testWidgets('refresh route graph flow returns success', (tester) async {
    final repository = await TestTasmapRepository.create();
    final robot = RouteGraphRefreshRobot(
      tester,
      repository,
      TestPeakNotifier(_baseState()),
      _TestRouteGraphRefreshService(
        () async => const RouteGraphRefreshResult(elementCount: 3),
      ),
    );

    await robot.pumpApp();
    await robot.openRefreshDialog();
    robot.expectConfirmDialogVisible();

    await robot.confirmRefresh();
    robot.expectResultVisible();

    router.go('/map');
    await robot.tester.pumpAndSettle();

    final button = robot.tester.widget<FloatingActionButton>(
      find.byKey(const Key('create-route-fab')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('refresh route graph flow shows failure dialog', (tester) async {
    final repository = await TestTasmapRepository.create();
    final robot = RouteGraphRefreshRobot(
      tester,
      repository,
      TestPeakNotifier(_baseState()),
      _TestRouteGraphRefreshService(
        () async {
          throw StateError('boom');
        },
      ),
    );

    await robot.pumpApp();
    await robot.openRefreshDialog();
    robot.expectConfirmDialogVisible();

    await robot.confirmRefresh();
    robot.expectFailureVisible('boom');
  });
}

MapState _baseState() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
  );
}

class _TestRouteGraphRefreshService extends RouteGraphRefreshService {
  _TestRouteGraphRefreshService(this._handler) : super(ReadyRouteGraphStore());

  final Future<RouteGraphRefreshResult> Function() _handler;

  @override
  Future<RouteGraphRefreshResult> refreshRouteGraph() => _handler();
}
