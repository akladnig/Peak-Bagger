import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/route_planner.dart';

final routePlannerProvider = Provider<RoutePlanner>((ref) {
  return TripRoutingRoutePlanner();
});
