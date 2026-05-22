import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

void main() {
  test('local file client preloads the graph before routing', () async {
    const start = LatLng(-41.5, 146.5);
    const end = LatLng(-41.6, 146.6);
    const midpoint = LatLng(-41.55, 146.55);
    final service = _FakeTripService(
      trip_routing.Trip(
        route: const [start, midpoint, end],
        distance: 1234.5,
        errors: const [],
      ),
    );
    final store = _FakeRouteGraphStore(service);
    final client = LocalFileTripRoutingClient(routeGraphStore: store);

    final trip = await client.findTotalTrip([start, end]);

    expect(store.preloadCallCount, 1);
    expect(service.recordedWaypoints, const [start, end]);
    expect(trip.route, const [start, midpoint, end]);
    expect(trip.distance, 1234.5);
  });

  test('trip routing adapter attaches off-track endpoints to the returned route', () async {
    const start = LatLng(-41.5, 146.5);
    const end = LatLng(-41.6, 146.6);
    const snappedStart = LatLng(-41.5005, 146.5005);
    const midpoint = LatLng(-41.55, 146.55);
    const snappedEnd = LatLng(-41.5995, 146.5995);
    final service = _FakeTripService(
      trip_routing.Trip(
        route: const [snappedStart, midpoint, snappedEnd],
        distance: 1234.5,
        errors: const [],
      ),
    );
    final store = _FakeRouteGraphStore(service);
    final client = LocalFileTripRoutingClient(routeGraphStore: store);
    final planner = TripRoutingRoutePlanner(client: client);

    final segment = await planner.planSegment(start: start, end: end);

    expect(segment.points, const [start, snappedStart, midpoint, snappedEnd, end]);
    expect(
      segment.distanceMeters,
      closeTo(
        1234.5 +
            trip_routing.haversineDistance(
              start.latitude,
              start.longitude,
              snappedStart.latitude,
              snappedStart.longitude,
            ) +
            trip_routing.haversineDistance(
              snappedEnd.latitude,
              snappedEnd.longitude,
              end.latitude,
              end.longitude,
            ),
        0.001,
      ),
    );
  });

  test('trip routing adapter rejects an unusable trip result', () async {
    const start = LatLng(-41.5, 146.5);
    const end = LatLng(-41.6, 146.6);
    final client = _FakeTripRoutingClient(
      trip_routing.Trip(
        route: const [],
        distance: 0,
        errors: const ['No path found.'],
      ),
    );
    final planner = TripRoutingRoutePlanner(client: client);

    await expectLater(
      () => planner.planSegment(start: start, end: end),
      throwsA(isA<RoutePlanningException>()),
    );
  });

  test('trip routing adapter surfaces route graph load failure', () async {
    const start = LatLng(-41.5, 146.5);
    const end = LatLng(-41.6, 146.6);
    final store = _ThrowingRouteGraphStore();
    final client = LocalFileTripRoutingClient(routeGraphStore: store);
    final planner = TripRoutingRoutePlanner(client: client);

    await expectLater(
      () => planner.planSegment(start: start, end: end),
      throwsA(isA<RouteGraphLoadException>()),
    );
  });
}

class _FakeTripRoutingClient implements TripRoutingClient {
  _FakeTripRoutingClient(this.trip);

  final trip_routing.Trip trip;
  List<LatLng>? recordedWaypoints;

  @override
  Future<trip_routing.Trip> findTotalTrip(
    List<LatLng> waypoints, {
    bool preferWalkingPaths = true,
    bool replaceWaypointsWithBuildingEntrances = false,
    bool forceIncludeWaypoints = false,
    double duplicationPenalty = 0.0,
  }) async {
    recordedWaypoints = List<LatLng>.from(waypoints, growable: false);
    return trip;
  }
}

class _FakeRouteGraphStore implements RouteGraphStore {
  _FakeRouteGraphStore(this.service);

  final _FakeTripService service;
  int preloadCallCount = 0;

  @override
  Future<trip_routing.TripService> preload() async {
    preloadCallCount += 1;
    return service;
  }

  @override
  Future<trip_routing.TripService> reload() async => service;

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}

class _ThrowingRouteGraphStore implements RouteGraphStore {
  @override
  Future<trip_routing.TripService> preload() async {
    throw const RouteGraphLoadException('route graph unavailable');
  }

  @override
  Future<trip_routing.TripService> reload() => preload();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}

class _FakeTripService extends trip_routing.TripService {
  _FakeTripService(this.trip);

  final trip_routing.Trip trip;
  List<LatLng>? recordedWaypoints;

  @override
  Future<trip_routing.Trip> findTotalTrip(
    List<LatLng> waypoints, {
    bool preferWalkingPaths = true,
    bool replaceWaypointsWithBuildingEntrances = false,
    bool forceIncludeWaypoints = false,
    double duplicationPenalty = 0.0,
  }) async {
    recordedWaypoints = List<LatLng>.from(waypoints, growable: false);
    return trip;
  }
}
