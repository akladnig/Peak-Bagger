import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

class PlannedRouteSegment {
  const PlannedRouteSegment({
    required this.points,
    required this.distanceMeters,
  });

  final List<LatLng> points;
  final double distanceMeters;
}

enum RouteEndpointAnchorType { raw, node, edgeProjection }

class RouteEndpointAnchor {
  const RouteEndpointAnchor({
    required this.point,
    required this.type,
    this.nodeId,
    this.originalSegmentId,
  });

  final LatLng point;
  final RouteEndpointAnchorType type;
  final int? nodeId;
  final String? originalSegmentId;
}

enum RoutePlanningStatus { routed, offTrack, noPath, failed }

enum RoutePlanningFailureKind { generic, routeGraphLoad }

class RoutePlanningResult {
  const RoutePlanningResult({
    required this.status,
    required this.points,
    required this.distanceMeters,
    required this.startAnchor,
    required this.endAnchor,
    this.errorMessage,
    this.failureKind = RoutePlanningFailureKind.generic,
  });

  final RoutePlanningStatus status;
  final List<LatLng> points;
  final double distanceMeters;
  final RouteEndpointAnchor? startAnchor;
  final RouteEndpointAnchor? endAnchor;
  final String? errorMessage;
  final RoutePlanningFailureKind failureKind;

  bool get isRouted => status == RoutePlanningStatus.routed;
}

class RouteEndpointProbeResult {
  const RouteEndpointProbeResult({
    required this.isOnTrack,
    this.anchor,
    this.errorMessage,
    this.failureKind = RoutePlanningFailureKind.generic,
  });

  final bool isOnTrack;
  final RouteEndpointAnchor? anchor;
  final String? errorMessage;
  final RoutePlanningFailureKind failureKind;
}

class RoutePlanningException implements Exception {
  const RoutePlanningException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class RoutePlanner {
  Future<RoutePlanningResult> planSegmentResult({
    required LatLng start,
    required LatLng end,
  });

  Future<RouteEndpointProbeResult> probeEndpoint({
    required LatLng point,
  });

  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
  });
}

abstract class TripRoutingClient {
  Future<trip_routing.AnchoredSegmentResult> findAnchoredSegment({
    required LatLng start,
    required LatLng end,
    required double maxSnapDistanceMeters,
  });

  Future<trip_routing.EndpointProbeResult> probeEndpointAnchor({
    required LatLng point,
    required double maxSnapDistanceMeters,
  });
}

abstract class RoutePlannerFallback {
  Future<PlannedRouteSegment?> tryPlanSegment({
    required LatLng start,
    required LatLng end,
  });
}

class NoopRoutePlannerFallback implements RoutePlannerFallback {
  const NoopRoutePlannerFallback();

  @override
  Future<PlannedRouteSegment?> tryPlanSegment({
    required LatLng start,
    required LatLng end,
  }) async => null;
}

class TripRoutingServiceClient implements TripRoutingClient {
  TripRoutingServiceClient({trip_routing.TripService? tripService})
    : _tripService = tripService ?? trip_routing.TripService();

  final trip_routing.TripService _tripService;

  @override
  Future<trip_routing.AnchoredSegmentResult> findAnchoredSegment({
    required LatLng start,
    required LatLng end,
    required double maxSnapDistanceMeters,
  }) {
    return _tripService.findAnchoredSegment(
      start: start,
      end: end,
      maxSnapDistanceMeters: maxSnapDistanceMeters,
    );
  }

  @override
  Future<trip_routing.EndpointProbeResult> probeEndpointAnchor({
    required LatLng point,
    required double maxSnapDistanceMeters,
  }) {
    return _tripService.probeEndpointAnchor(
      point: point,
      maxSnapDistanceMeters: maxSnapDistanceMeters,
    );
  }
}

class LocalFileTripRoutingClient implements TripRoutingClient {
  LocalFileTripRoutingClient({
    RouteGraphStore? routeGraphStore,
    RouteGraphQueryService? routeGraphQueryService,
  })  : _routeGraphStore =
            routeGraphStore ??
            (throw UnimplementedError('routeGraphStore is required')),
        _injectedRouteGraphQueryService = routeGraphQueryService;

  final RouteGraphStore _routeGraphStore;
  final RouteGraphQueryService? _injectedRouteGraphQueryService;
  RouteGraphQueryService? _queryService;

  RouteGraphQueryService? get _routeGraphQueryService {
    final injected = _injectedRouteGraphQueryService;
    if (injected != null) {
      return injected;
    }

    final repository = _repositoryForStore(_routeGraphStore);
    if (repository == null) {
      return null;
    }
    return _queryService ??= RouteGraphQueryService(repository);
  }

  RouteGraphRepository? _repositoryForStore(RouteGraphStore store) {
    final provider =
        store is RouteGraphRepositoryProvider ? store as RouteGraphRepositoryProvider : null;
    return provider?.repository;
  }

  Future<trip_routing.TripService> _tripServiceForRoute({
    required LatLng start,
    required LatLng end,
  }) {
    final queryService = _routeGraphQueryService;
    if (queryService != null) {
      return queryService.buildTripServiceForRoute(start: start, end: end);
    }
    return _routeGraphStore.preload();
  }

  Future<trip_routing.TripService> _tripServiceForPoint({
    required LatLng point,
  }) {
    final queryService = _routeGraphQueryService;
    if (queryService != null) {
      return queryService.buildTripServiceForPoint(point: point);
    }
    return _routeGraphStore.preload();
  }

  @override
  Future<trip_routing.AnchoredSegmentResult> findAnchoredSegment({
    required LatLng start,
    required LatLng end,
    required double maxSnapDistanceMeters,
  }) async {
    final tripService = await _tripServiceForRoute(start: start, end: end);
    return tripService.findAnchoredSegment(
      start: start,
      end: end,
      maxSnapDistanceMeters: maxSnapDistanceMeters,
    );
  }

  @override
  Future<trip_routing.EndpointProbeResult> probeEndpointAnchor({
    required LatLng point,
    required double maxSnapDistanceMeters,
  }) async {
    final tripService = await _tripServiceForPoint(point: point);
    return tripService.probeEndpointAnchor(
      point: point,
      maxSnapDistanceMeters: maxSnapDistanceMeters,
    );
  }
}

class OverpassRoutePlannerFallback implements RoutePlannerFallback {
  const OverpassRoutePlannerFallback();

  @override
  Future<PlannedRouteSegment?> tryPlanSegment({
    required LatLng start,
    required LatLng end,
  }) async => null;
}

class TripRoutingRoutePlanner implements RoutePlanner {
  TripRoutingRoutePlanner({
    TripRoutingClient? client,
  }) : _client = client ?? TripRoutingServiceClient();

  final TripRoutingClient _client;

  static const _maxSnapDistanceMeters = RouteConstants.maxSnapDistanceMeters;

  RouteEndpointAnchor? _mapAnchor(trip_routing.EndpointAnchor? anchor) {
    if (anchor == null) {
      return null;
    }
    return RouteEndpointAnchor(
      point: anchor.point,
      type: switch (anchor.type) {
        trip_routing.EndpointAnchorType.raw => RouteEndpointAnchorType.raw,
        trip_routing.EndpointAnchorType.node => RouteEndpointAnchorType.node,
        trip_routing.EndpointAnchorType.edgeProjection =>
          RouteEndpointAnchorType.edgeProjection,
      },
      nodeId: anchor.nodeId,
      originalSegmentId: anchor.originalSegmentId,
    );
  }

  RoutePlanningResult _mapSegmentResult(
    trip_routing.AnchoredSegmentResult result,
  ) {
    final startAnchor = _mapAnchor(result.startAnchor);
    final endAnchor = _mapAnchor(result.endAnchor);
    return switch (result.status) {
      trip_routing.AnchoredSegmentStatus.routed =>
        result.route.length < 2 ||
                !result.distance.isFinite ||
                result.distance <= 0
            ? RoutePlanningResult(
                status: RoutePlanningStatus.failed,
                points: const [],
                distanceMeters: 0,
                startAnchor: startAnchor,
                endAnchor: endAnchor,
                errorMessage: 'Routing returned no usable segment.',
              )
            : RoutePlanningResult(
                status: RoutePlanningStatus.routed,
                points: List<LatLng>.unmodifiable(result.route),
                distanceMeters: result.distance,
                startAnchor: startAnchor,
                endAnchor: endAnchor,
              ),
      trip_routing.AnchoredSegmentStatus.offTrack => RoutePlanningResult(
          status: RoutePlanningStatus.offTrack,
          points: const [],
          distanceMeters: 0,
          startAnchor: startAnchor,
          endAnchor: endAnchor,
        ),
      trip_routing.AnchoredSegmentStatus.noPath => RoutePlanningResult(
          status: RoutePlanningStatus.noPath,
          points: const [],
          distanceMeters: 0,
          startAnchor: startAnchor,
          endAnchor: endAnchor,
        ),
      trip_routing.AnchoredSegmentStatus.failed => RoutePlanningResult(
          status: RoutePlanningStatus.failed,
          points: const [],
          distanceMeters: 0,
          startAnchor: startAnchor,
          endAnchor: endAnchor,
          errorMessage: result.errors.join('\n'),
        ),
    };
  }

  @override
  Future<RoutePlanningResult> planSegmentResult({
    required LatLng start,
    required LatLng end,
  }) async {
    try {
      final result = await _client.findAnchoredSegment(
        start: start,
        end: end,
        maxSnapDistanceMeters: _maxSnapDistanceMeters,
      );
      return _mapSegmentResult(result);
    } on RouteGraphLoadException catch (error) {
      return RoutePlanningResult(
        status: RoutePlanningStatus.failed,
        points: const [],
        distanceMeters: 0,
        startAnchor: null,
        endAnchor: null,
        errorMessage: '$error',
        failureKind: RoutePlanningFailureKind.routeGraphLoad,
      );
    } catch (error) {
      return RoutePlanningResult(
        status: RoutePlanningStatus.failed,
        points: const [],
        distanceMeters: 0,
        startAnchor: null,
        endAnchor: null,
        errorMessage: '$error',
      );
    }
  }

  @override
  Future<RouteEndpointProbeResult> probeEndpoint({required LatLng point}) async {
    try {
      final result = await _client.probeEndpointAnchor(
        point: point,
        maxSnapDistanceMeters: _maxSnapDistanceMeters,
      );
      return RouteEndpointProbeResult(
        isOnTrack: result.isOnTrack,
        anchor: _mapAnchor(result.anchor),
        errorMessage: result.errors.isEmpty ? null : result.errors.join('\n'),
      );
    } catch (error) {
      return RouteEndpointProbeResult(
        isOnTrack: false,
        errorMessage: '$error',
        failureKind: error is RouteGraphLoadException
            ? RoutePlanningFailureKind.routeGraphLoad
            : RoutePlanningFailureKind.generic,
      );
    }
  }

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
  }) async {
    final result = await planSegmentResult(start: start, end: end);
    if (result.status != RoutePlanningStatus.routed) {
      throw RoutePlanningException(
        result.errorMessage ?? 'Routing returned no usable segment.',
      );
    }

    final segment = _attachEndpoints(
      start: start,
      end: end,
      route: result.points,
      distanceMeters: result.distanceMeters,
    );
    return segment;

  }

  PlannedRouteSegment _attachEndpoints({
    required LatLng start,
    required LatLng end,
    required List<LatLng> route,
    required double distanceMeters,
  }) {
    final points = List<LatLng>.from(route, growable: true);

    if (points.first != start) {
      distanceMeters += trip_routing.haversineDistance(
        start.latitude,
        start.longitude,
        points.first.latitude,
        points.first.longitude,
      );
      points.insert(0, start);
    }

    if (points.last != end) {
      distanceMeters += trip_routing.haversineDistance(
        points.last.latitude,
        points.last.longitude,
        end.latitude,
        end.longitude,
      );
      points.add(end);
    }

    return PlannedRouteSegment(
      points: List<LatLng>.unmodifiable(points),
      distanceMeters: distanceMeters,
    );
  }
}
