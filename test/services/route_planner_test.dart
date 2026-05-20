import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

void main() {
  test(
    'trip routing adapter plans a segment with ordered waypoints',
    () async {
      const start = LatLng(-41.5, 146.5);
      const end = LatLng(-41.6, 146.6);
      const midpoint = LatLng(-41.55, 146.55);
      final client = _FakeTripRoutingClient(
        trip_routing.Trip(
          route: const [start, midpoint, end],
          distance: 1234.5,
          errors: const [],
        ),
      );
      final planner = TripRoutingRoutePlanner(client: client);

      final segment = await planner.planSegment(start: start, end: end);

      expect(client.recordedWaypoints, const [start, end]);
      expect(segment.points, const [start, midpoint, end]);
      expect(segment.distanceMeters, 1234.5);
    },
  );

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
    final planner = TripRoutingRoutePlanner(
      client: client,
      fallback: const _NullFallbackRoutePlanner(),
    );

    await expectLater(
      () => planner.planSegment(start: start, end: end),
      throwsA(isA<RoutePlanningException>()),
    );
  });

  test('trip routing adapter falls back when package graph is unavailable', () async {
    const start = LatLng(-41.5, 146.5);
    const end = LatLng(-41.6, 146.6);
    final client = _FakeTripRoutingClient(
      trip_routing.Trip(
        route: const [],
        distance: 0,
        errors: const ['Graph data unavailable'],
      ),
    );
    final planner = TripRoutingRoutePlanner(
      client: client,
      fallback: const _FallbackRoutePlanner(
        PlannedRouteSegment(
          points: [start, LatLng(-41.55, 146.55), end],
          distanceMeters: 1234.5,
        ),
      ),
    );

    final segment = await planner.planSegment(start: start, end: end);

    expect(segment.points, const [start, LatLng(-41.55, 146.55), end]);
    expect(segment.distanceMeters, 1234.5);
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

class _FallbackRoutePlanner implements RoutePlannerFallback {
  const _FallbackRoutePlanner(this.segment);

  final PlannedRouteSegment segment;

  @override
  Future<PlannedRouteSegment?> tryPlanSegment({
    required LatLng start,
    required LatLng end,
  }) async {
    return segment;
  }
}

class _NullFallbackRoutePlanner implements RoutePlannerFallback {
  const _NullFallbackRoutePlanner();

  @override
  Future<PlannedRouteSegment?> tryPlanSegment({
    required LatLng start,
    required LatLng end,
  }) async {
    return null;
  }
}
