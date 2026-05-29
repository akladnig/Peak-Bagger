import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';

void main() {
  test('starts ready', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(routeGraphReadinessProvider);
    expect(state.status, RouteGraphReadinessStatus.ready);
    expect(state.error, isNull);
  });

  test('can still be marked failed and recovered', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(routeGraphReadinessProvider).status,
      RouteGraphReadinessStatus.ready,
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
}
