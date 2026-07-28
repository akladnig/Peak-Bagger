import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/services/route_graph_store.dart';

void main() {
  test('starts preloading', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(routeGraphReadinessProvider);
    expect(state.status, RouteGraphReadinessStatus.preloading);
    expect(state.error, isNull);
  });

  test('can still be marked failed and recovered', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(routeGraphReadinessProvider).status,
      RouteGraphReadinessStatus.preloading,
    );

    container.read(routeGraphReadinessProvider.notifier).markFailed('boom');
    final failedState = container.read(routeGraphReadinessProvider);
    expect(failedState.status, RouteGraphReadinessStatus.failed);
    expect(failedState.error, 'boom');

    container.read(routeGraphReadinessProvider.notifier).markReady();
    final recoveredState = container.read(routeGraphReadinessProvider);
    expect(recoveredState.status, RouteGraphReadinessStatus.ready);
    expect(recoveredState.error, isNull);
  });

  test(
    'bootstrap marks readiness ready after store bootstrap completes',
    () async {
      final store = _CompletingRouteGraphStore();
      final container = ProviderContainer(
        overrides: [routeGraphStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      final future = container.read(routeGraphBootstrapProvider.future);

      expect(
        container.read(routeGraphReadinessProvider).status,
        RouteGraphReadinessStatus.preloading,
      );
      expect(store.bootstrapCallCount, 1);

      store.completeBootstrap();
      await future;

      final state = container.read(routeGraphReadinessProvider);
      expect(state.status, RouteGraphReadinessStatus.ready);
      expect(state.error, isNull);
    },
  );

  test(
    'bootstrap marks readiness failed when store bootstrap throws',
    () async {
      final container = ProviderContainer(
        overrides: [
          routeGraphStoreProvider.overrideWithValue(
            _FailingRouteGraphStore('broken store'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(routeGraphBootstrapProvider.future),
        completes,
      );

      final state = container.read(routeGraphReadinessProvider);
      expect(state.status, RouteGraphReadinessStatus.failed);
      expect(state.error, 'broken store');
    },
  );
}

class _CompletingRouteGraphStore extends RouteGraphStore {
  final Completer<void> _bootstrapCompleter = Completer<void>();
  int bootstrapCallCount = 0;

  @override
  Future<void> bootstrapData() {
    bootstrapCallCount += 1;
    return _bootstrapCompleter.future;
  }

  void completeBootstrap() {
    if (!_bootstrapCompleter.isCompleted) {
      _bootstrapCompleter.complete();
    }
  }
}

class _FailingRouteGraphStore extends RouteGraphStore {
  _FailingRouteGraphStore(this.message);

  final String message;

  @override
  Future<void> bootstrapData() async {
    throw message;
  }
}
