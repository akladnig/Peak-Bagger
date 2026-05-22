import 'dart:io';

import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

class TestReadyRouteGraphStore implements RouteGraphStore {
  @override
  Future<trip_routing.TripService> preload() async => trip_routing.TripService();

  @override
  Future<trip_routing.TripService> reload() async => trip_routing.TripService();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}
