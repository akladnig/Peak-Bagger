import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/route_graph_store.dart';

final routeGraphQueryServiceProvider = Provider<RouteGraphQueryService?>((ref) {
  final store = ref.read(routeGraphStoreProvider);
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
  return TripRoutingRoutePlanner(
    client: LocalFileTripRoutingClient(
      routeGraphStore: ref.read(routeGraphStoreProvider),
      routeGraphQueryService: ref.read(routeGraphQueryServiceProvider),
    ),
  );
});
