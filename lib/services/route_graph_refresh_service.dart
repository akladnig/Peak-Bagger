import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/services/route_graph_import_coordinator.dart';
import 'route_graph_store.dart';

class RouteGraphRefreshResult {
  const RouteGraphRefreshResult({this.batchResult, this.elementCount = 0});

  final RouteGraphImportBatchResult? batchResult;
  final int elementCount;
}

class RouteGraphRefreshService {
  RouteGraphRefreshService(
    this._store, {
    RouteGraphImportCoordinator? coordinator,
  }) : _coordinator = coordinator;

  final RouteGraphStore _store;
  final RouteGraphImportCoordinator? _coordinator;

  Future<RouteGraphRefreshResult> refreshRouteGraph() async {
    try {
      final coordinator = _coordinator;
      if (coordinator != null) {
        return RouteGraphRefreshResult(
          batchResult: await coordinator.refreshAll(),
        );
      }
      await _store.reload();
      final repository = _store is RouteGraphRepositoryProvider
          ? (_store as RouteGraphRepositoryProvider).repository
          : null;
      final manifest = repository?.manifest;
      return RouteGraphRefreshResult(
        elementCount: (manifest?.nodeCount ?? 0) + (manifest?.edgeCount ?? 0),
      );
    } catch (error) {
      throw RouteGraphLoadException('Failed to refresh route graph: $error');
    }
  }
}

final routeGraphRefreshServiceProvider = Provider<RouteGraphRefreshService>((
  ref,
) {
  final store = ref.read(routeGraphStoreProvider);
  final coordinator = store is ObjectBoxRouteGraphStore
      ? store.importCoordinator
      : null;
  return RouteGraphRefreshService(store, coordinator: coordinator);
});
