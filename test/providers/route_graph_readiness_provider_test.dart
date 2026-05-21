import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

void main() {
  test('bootstraps from preloading to ready', () async {
    final completer = Completer<trip_routing.TripService>();
    final store = _DeferredRouteGraphStore(completer.future);
    final container = ProviderContainer(
      overrides: [routeGraphStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(routeGraphReadinessProvider).status,
      RouteGraphReadinessStatus.preloading,
    );

    completer.complete(trip_routing.TripService());
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(routeGraphReadinessProvider).status,
      RouteGraphReadinessStatus.ready,
    );
  });

  test('bootstraps failure and can be marked ready after recovery', () async {
    final completer = Completer<trip_routing.TripService>();
    final store = _DeferredRouteGraphStore(completer.future);
    final container = ProviderContainer(
      overrides: [routeGraphStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(routeGraphReadinessProvider).status,
      RouteGraphReadinessStatus.preloading,
    );

    completer.completeError(
      const RouteGraphLoadException('boom'),
      StackTrace.empty,
    );
    await Future<void>.delayed(Duration.zero);

    final failedState = container.read(routeGraphReadinessProvider);
    expect(failedState.status, RouteGraphReadinessStatus.failed);
    expect(failedState.error, contains('boom'));

    container.read(routeGraphReadinessProvider.notifier).markReady();
    expect(
      container.read(routeGraphReadinessProvider).status,
      RouteGraphReadinessStatus.ready,
    );
  });
}

class _DeferredRouteGraphStore implements RouteGraphStore {
  _DeferredRouteGraphStore(this.future);

  final Future<trip_routing.TripService> future;

  @override
  Future<trip_routing.TripService> preload() => future;

  @override
  Future<trip_routing.TripService> reload() => future;

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}
