import 'package:latlong2/latlong.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

class PlannedRouteSegment {
  const PlannedRouteSegment({
    required this.points,
    required this.distanceMeters,
  });

  final List<LatLng> points;
  final double distanceMeters;
}

class RoutePlanningException implements Exception {
  const RoutePlanningException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class RoutePlanner {
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
  });
}

abstract class TripRoutingClient {
  Future<trip_routing.Trip> findTotalTrip(
    List<LatLng> waypoints, {
    bool preferWalkingPaths = true,
    bool replaceWaypointsWithBuildingEntrances = false,
    bool forceIncludeWaypoints = false,
    double duplicationPenalty = 0.0,
  });
}

class TripRoutingServiceClient implements TripRoutingClient {
  TripRoutingServiceClient({trip_routing.TripService? tripService})
    : _tripService = tripService ?? trip_routing.TripService();

  final trip_routing.TripService _tripService;

  @override
  Future<trip_routing.Trip> findTotalTrip(
    List<LatLng> waypoints, {
    bool preferWalkingPaths = true,
    bool replaceWaypointsWithBuildingEntrances = false,
    bool forceIncludeWaypoints = false,
    double duplicationPenalty = 0.0,
  }) {
    return _tripService.findTotalTrip(
      waypoints,
      preferWalkingPaths: preferWalkingPaths,
      replaceWaypointsWithBuildingEntrances:
          replaceWaypointsWithBuildingEntrances,
      forceIncludeWaypoints: forceIncludeWaypoints,
      duplicationPenalty: duplicationPenalty,
    );
  }
}

class TripRoutingRoutePlanner implements RoutePlanner {
  TripRoutingRoutePlanner({TripRoutingClient? client})
    : _client = client ?? TripRoutingServiceClient();

  final TripRoutingClient _client;

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
  }) async {
    final trip = await _client.findTotalTrip(
      [start, end],
      preferWalkingPaths: true,
    );
    if (trip.errors.isNotEmpty) {
      throw RoutePlanningException(trip.errors.join('\n'));
    }
    if (trip.route.length < 2) {
      throw const RoutePlanningException('Routing returned no usable segment.');
    }
    if (!trip.distance.isFinite || trip.distance <= 0) {
      throw const RoutePlanningException('Routing returned an invalid distance.');
    }
    return PlannedRouteSegment(
      points: List<LatLng>.from(trip.route, growable: false),
      distanceMeters: trip.distance,
    );
  }
}
