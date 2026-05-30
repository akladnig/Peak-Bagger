import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'route_graph_store.dart';

class RouteGraphRefreshResult {
  const RouteGraphRefreshResult({required this.elementCount});

  final int elementCount;
}

class RouteGraphRefreshService {
  RouteGraphRefreshService(this._store);

  final RouteGraphStore _store;

  Future<RouteGraphRefreshResult> refreshRouteGraph() async {
    try {
      await _store.reload();
      final repository = _store is RouteGraphRepositoryProvider
          ? (_store as RouteGraphRepositoryProvider).repository
          : null;
      final manifest = repository?.manifest;
      return RouteGraphRefreshResult(
        elementCount: (manifest?.nodeCount ?? 0) + (manifest?.edgeCount ?? 0),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Route graph refresh failed.',
        error: error,
        stackTrace: stackTrace,
      );
      throw RouteGraphLoadException('Failed to refresh route graph: $error');
    }
  }
}

final routeGraphRefreshServiceProvider = Provider<RouteGraphRefreshService>((ref) {
  return RouteGraphRefreshService(ref.read(routeGraphStoreProvider));
});
