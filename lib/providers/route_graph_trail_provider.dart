import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:peak_bagger/providers/route_planner_provider.dart';
import 'package:peak_bagger/services/route_graph_trail_service.dart';

final routeGraphTrailServiceProvider = Provider<RouteGraphTrailService?>((ref) {
  final queryService = ref.read(routeGraphQueryServiceProvider);
  if (queryService == null) {
    return null;
  }

  return RouteGraphTrailService(queryService);
});
