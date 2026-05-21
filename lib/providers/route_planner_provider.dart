import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/services/route_planner.dart';

final routePlannerProvider = Provider<RoutePlanner>((ref) {
  return TripRoutingRoutePlanner(
    client: LocalFileTripRoutingClient(
      routeGraphStore: ref.read(routeGraphStoreProvider),
    ),
  );
});
