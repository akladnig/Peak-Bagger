import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/route_graph_store.dart';

final routeGraphQueryServiceProvider = Provider<RouteGraphQueryService?>((ref) {
  RouteGraphStore store;
  try {
    store = ref.read(routeGraphStoreProvider);
  } catch (_) {
    return null;
  }
  if (store is! RouteGraphRepositoryProvider) {
    return null;
  }
  final repository = (store as RouteGraphRepositoryProvider).repository;
  if (repository == null) {
    return null;
  }
  return RouteGraphQueryService(repository);
});

final routePlannerProvider = Provider<RoutePlanner>((ref) {
  RouteGraphStore store;
  try {
    store = ref.read(routeGraphStoreProvider);
  } catch (_) {
    store = _UnavailableRouteGraphStore();
  }
  return TripRoutingRoutePlanner(
    client: LocalFileTripRoutingClient(
      routeGraphStore: store,
      routeGraphQueryService: ref.read(routeGraphQueryServiceProvider),
    ),
  );
});

class _UnavailableRouteGraphStore extends RouteGraphStore {
  @override
  Future<trip_routing.TripService> preload() async {
    throw const RouteGraphLoadException('Route graph store is unavailable.');
  }

  @override
  Future<trip_routing.TripService> reload() async {
    throw const RouteGraphLoadException('Route graph store is unavailable.');
  }

  @override
  Future<void> replaceSnapshot(String rawJson) async {
    throw const RouteGraphLoadException('Route graph store is unavailable.');
  }

  @override
  Future<io.File> snapshotFile() async {
    throw const RouteGraphLoadException('Route graph store is unavailable.');
  }
}
