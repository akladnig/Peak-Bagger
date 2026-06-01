import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/route_graph_refresh_service.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

void main() {
  test('refreshRouteGraph reloads the bundled route graph', () async {
    final store = _FakeRouteGraphStore();
    final service = RouteGraphRefreshService(store);
    final result = await service.refreshRouteGraph();

    expect(result.elementCount, 0);
    expect(store.reloadCallCount, 1);
  });

  test('refreshRouteGraph rejects reload failures', () async {
    final service = RouteGraphRefreshService(_ThrowingRouteGraphStore());

    await expectLater(
      () => service.refreshRouteGraph(),
      throwsA(isA<RouteGraphLoadException>()),
    );
  });
}

class _FakeRouteGraphStore implements RouteGraphStore {
  @override
  Future<void> bootstrapData() async {}

  int reloadCallCount = 0;

  @override
  Future<trip_routing.TripService> preload() async {
    return trip_routing.TripService();
  }

  @override
  Future<trip_routing.TripService> reload() async {
    reloadCallCount += 1;
    return trip_routing.TripService();
  }

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}

class _ThrowingRouteGraphStore implements RouteGraphStore {
  @override
  Future<void> bootstrapData() async {}

  @override
  Future<trip_routing.TripService> preload() async {
    throw const RouteGraphLoadException('failed');
  }

  @override
  Future<trip_routing.TripService> reload() async => preload();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}
