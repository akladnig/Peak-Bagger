import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

void main() {
  test('preload seeds the bundled snapshot and caches the service', () async {
    final supportDir = await Directory.systemTemp.createTemp('route-graph-store');
    addTearDown(() => supportDir.delete(recursive: true));

    final service = _FakeTripService();
    final store = BundledRouteGraphStore(
      supportDirectoryLoader: () async => supportDir,
      assetLoader: (_) async => '{"elements": [{"type": "node", "id": 1}]}',
      tripServiceFactory: () => service,
    );

    final loadedService = await store.preload();

    expect(identical(loadedService, service), isTrue);
    expect(service.loadCallCount, 1);

    final snapshot = await store.snapshotFile();
    expect(await snapshot.exists(), isTrue);
    expect(await snapshot.readAsString(), contains('elements'));
  });

  test('replaceSnapshot validates before writing', () async {
    final supportDir = await Directory.systemTemp.createTemp('route-graph-store');
    addTearDown(() => supportDir.delete(recursive: true));

    final service = _FakeTripService();
    final store = BundledRouteGraphStore(
      supportDirectoryLoader: () async => supportDir,
      assetLoader: (_) async => '{"elements": [{"type": "node", "id": 1}]}',
      tripServiceFactory: () => service,
    );

    final snapshot = await store.snapshotFile();
    await snapshot.writeAsString('{"elements": [{"type": "node", "id": 1}]}');

    await expectLater(
      () => store.replaceSnapshot('not-json'),
      throwsA(isA<RouteGraphLoadException>()),
    );

    expect(await snapshot.readAsString(), contains('"id": 1'));
  });

  test('reload keeps the previous cache when the snapshot breaks', () async {
    final supportDir = await Directory.systemTemp.createTemp('route-graph-store');
    addTearDown(() => supportDir.delete(recursive: true));

    final service = _FakeTripService();
    final store = BundledRouteGraphStore(
      supportDirectoryLoader: () async => supportDir,
      assetLoader: (_) async => '{"elements": [{"type": "node", "id": 1}]}',
      tripServiceFactory: () => service,
    );

    final firstService = await store.preload();
    final snapshot = await store.snapshotFile();
    await snapshot.writeAsString('{"elements": [{"type": "node", "id": 1}]}');

    await snapshot.writeAsString('not-json');

    await expectLater(
      () => store.reload(),
      throwsA(isA<RouteGraphLoadException>()),
    );

    final secondService = await store.preload();
    expect(identical(firstService, secondService), isTrue);
    expect(service.loadCallCount, 1);
  });
}

class _FakeTripService extends trip_routing.TripService {
  int loadCallCount = 0;

  @override
  Future<void> loadOverpassJson(
    Map<String, dynamic> json, {
    bool preferWalkingPaths = true,
    int minIslandSize = 0,
    String source = 'custom',
  }) async {
    loadCallCount += 1;
  }
}
