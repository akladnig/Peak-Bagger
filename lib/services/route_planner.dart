import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
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

const _routeGraphPathDefine = 'PEAK_BAGGER_ROUTE_GRAPH_PATH';
const _bundledRouteGraphAsset = 'assets/highway.json';

class LocalFileTripRoutingClient implements TripRoutingClient {
  LocalFileTripRoutingClient({
    trip_routing.TripService? tripService,
    String? graphFilePath,
  }) : _tripService = tripService,
       graphFilePath =
           graphFilePath ??
           const String.fromEnvironment(_routeGraphPathDefine);

  final trip_routing.TripService? _tripService;
  final String graphFilePath;
  Future<trip_routing.TripService>? _serviceFuture;

  @override
  Future<trip_routing.Trip> findTotalTrip(
    List<LatLng> waypoints, {
    bool preferWalkingPaths = true,
    bool replaceWaypointsWithBuildingEntrances = false,
    bool forceIncludeWaypoints = false,
    double duplicationPenalty = 0.0,
  }) async {
    final resolvedGraphPath = graphFilePath.trim();

    try {
      final tripService = await (_serviceFuture ??= _loadService(resolvedGraphPath));
      return tripService.findTotalTrip(
        waypoints,
        preferWalkingPaths: preferWalkingPaths,
        replaceWaypointsWithBuildingEntrances:
            replaceWaypointsWithBuildingEntrances,
        forceIncludeWaypoints: forceIncludeWaypoints,
        duplicationPenalty: duplicationPenalty,
      );
    } catch (error) {
      return trip_routing.Trip(
        route: const [],
        distance: 0,
        errors: ['Failed to load local route graph: $error'],
      );
    }
  }

  Future<trip_routing.TripService> _loadService(String graphPath) async {
    final useLocalFile = graphPath.isNotEmpty;
    final rawJson = useLocalFile
        ? await File(graphPath).readAsString()
        : await rootBundle.loadString(_bundledRouteGraphAsset);
    final decodedJson = jsonDecode(rawJson);
    if (decodedJson is! Map<String, dynamic>) {
      throw const FormatException('Expected decoded Overpass JSON object.');
    }

    final tripService = _tripService ?? trip_routing.TripService();
    await tripService.loadOverpassJson(
      decodedJson,
      preferWalkingPaths: true,
      source: useLocalFile ? graphPath : _bundledRouteGraphAsset,
    );
    return tripService;
  }
}

class OverpassRoutePlannerFallback implements RoutePlannerFallback {
  OverpassRoutePlannerFallback({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  static const _overpassEndpoints = [
    'https://lz4.overpass-api.de/api/interpreter',
    'https://z.overpass-api.de/api/interpreter',
    'https://overpass-api.de/api/interpreter',
  ];

  @override
  Future<PlannedRouteSegment?> tryPlanSegment({
    required LatLng start,
    required LatLng end,
  }) async {
    final elements = await _fetchWalkingElements(start: start, end: end);
    if (elements.isEmpty) {
      return null;
    }

    final graph = _buildGraph(elements);
    if (graph.nodes.length < 2) {
      return null;
    }

    final nodeIds = _findClosestNodes(graph, [start, end]);
    if (nodeIds.length != 2) {
      return null;
    }

    final routed = _shortestPath(
      graph: graph,
      startId: nodeIds.first,
      targetId: nodeIds.last,
    );
    if (routed == null || routed.points.length < 2 || routed.distanceMeters <= 0) {
      return null;
    }

    return _attachEndpoints(start: start, end: end, segment: routed);
  }

  Future<List<Map<String, dynamic>>> _fetchWalkingElements({
    required LatLng start,
    required LatLng end,
  }) async {
    final bounds = _buildBounds(start: start, end: end);
    final query = '''
      [out:json];
      (
        way["highway"]["area"!~"yes"]["place"!~"square"](${bounds.minLat}, ${bounds.minLon}, ${bounds.maxLat}, ${bounds.maxLon});
      );
      out body;
      >;
      out skel qt;
      ''';

    final encodedBody = 'data=${Uri.encodeQueryComponent(query)}';

    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await _httpClient.post(
          Uri.parse(endpoint),
          headers: const {
            HttpHeaders.contentTypeHeader:
                'application/x-www-form-urlencoded; charset=UTF-8',
            HttpHeaders.acceptHeader: 'application/json',
            HttpHeaders.userAgentHeader: 'peak-bagger/route-planner',
          },
          body: encodedBody,
        );
        if (response.statusCode != 200) {
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = decoded['elements'];
        if (elements is! List || elements.isEmpty) {
          continue;
        }

        return elements
            .whereType<Map>()
            .map((element) => Map<String, dynamic>.from(element))
            .toList(growable: false);
      } catch (error, stackTrace) {
        developer.log(
          'Fallback route fetch failed for $endpoint',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return const [];
  }

  trip_routing.Graph _buildGraph(List<Map<String, dynamic>> elements) {
    final graph = trip_routing.Graph();

    for (final element in elements) {
      if (element['type'] != 'node') {
        continue;
      }
      final id = element['id'];
      final lat = element['lat'];
      final lon = element['lon'];
      if (id is! int || lat is! num || lon is! num) {
        continue;
      }
      graph.addNode(
        trip_routing.Node(
          id,
          lat.toDouble(),
          lon.toDouble(),
          false,
        ),
      );
    }

    for (final element in elements) {
      if (element['type'] != 'way') {
        continue;
      }
      final nodes = element['nodes'];
      if (nodes is! List) {
        continue;
      }

      for (var index = 0; index < nodes.length - 1; index++) {
        final startId = nodes[index];
        final endId = nodes[index + 1];
        if (startId is! int || endId is! int) {
          continue;
        }

        final startNode = graph.nodes[startId];
        final endNode = graph.nodes[endId];
        if (startNode == null || endNode == null) {
          continue;
        }

        final distance = trip_routing.haversineDistance(
          startNode.lat,
          startNode.lon,
          endNode.lat,
          endNode.lon,
        );
        if (!distance.isFinite || distance <= 0) {
          continue;
        }

        graph.addEdge(trip_routing.Edge(startId, endId, distance));
      }
    }

    return graph;
  }

  List<int> _findClosestNodes(
    trip_routing.Graph graph,
    List<LatLng> positions,
  ) {
    final allNodes = graph.nodes.values.toList(growable: false);
    if (allNodes.isEmpty) {
      return const [];
    }

    return positions.map((position) {
      var closestNode = allNodes.first;
      var minDistance = double.infinity;
      for (final node in allNodes) {
        final distance = trip_routing.haversineDistance(
          position.latitude,
          position.longitude,
          node.lat,
          node.lon,
        );
        if (distance < minDistance) {
          minDistance = distance;
          closestNode = node;
        }
      }
      return closestNode.id;
    }).toList(growable: false);
  }

  PlannedRouteSegment? _shortestPath({
    required trip_routing.Graph graph,
    required int startId,
    required int targetId,
  }) {
    if (!graph.nodes.containsKey(startId) || !graph.nodes.containsKey(targetId)) {
      return null;
    }

    final distances = <int, double>{
      for (final nodeId in graph.nodes.keys) nodeId: double.infinity,
    };
    final previous = <int, int>{};
    final visited = <int>{};
    distances[startId] = 0;

    while (visited.length < graph.nodes.length) {
      int? currentId;
      var currentDistance = double.infinity;
      for (final entry in distances.entries) {
        if (visited.contains(entry.key)) {
          continue;
        }
        if (entry.value < currentDistance) {
          currentDistance = entry.value;
          currentId = entry.key;
        }
      }

      if (currentId == null || currentDistance == double.infinity) {
        break;
      }
      if (currentId == targetId) {
        break;
      }

      visited.add(currentId);
      for (final edge in graph.adjacencyList[currentId] ?? const []) {
        final nextDistance = currentDistance + edge.weight;
        if (nextDistance < (distances[edge.to] ?? double.infinity)) {
          distances[edge.to] = nextDistance;
          previous[edge.to] = currentId;
        }
      }
    }

    final totalDistance = distances[targetId];
    if (totalDistance == null || !totalDistance.isFinite) {
      return null;
    }

    final path = <int>[targetId];
    var current = targetId;
    while (previous.containsKey(current)) {
      current = previous[current]!;
      path.add(current);
    }
    if (path.last != startId) {
      return null;
    }

    final points = path
        .reversed
        .map((nodeId) => graph.nodes[nodeId])
        .whereType<trip_routing.Node>()
        .map((node) => LatLng(node.lat, node.lon))
        .toList(growable: false);

    return PlannedRouteSegment(
      points: points,
      distanceMeters: totalDistance,
    );
  }

  PlannedRouteSegment _attachEndpoints({
    required LatLng start,
    required LatLng end,
    required PlannedRouteSegment segment,
  }) {
    final points = List<LatLng>.from(segment.points, growable: true);
    var distanceMeters = segment.distanceMeters;

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

  _Bounds _buildBounds({required LatLng start, required LatLng end}) {
    final minLat = start.latitude < end.latitude ? start.latitude : end.latitude;
    final maxLat = start.latitude > end.latitude ? start.latitude : end.latitude;
    final minLon = start.longitude < end.longitude ? start.longitude : end.longitude;
    final maxLon = start.longitude > end.longitude ? start.longitude : end.longitude;

    final latPadding = ((maxLat - minLat) * 0.3).abs();
    final lonPadding = ((maxLon - minLon) * 0.3).abs();

    return _Bounds(
      minLat: minLat - (latPadding < 0.01 ? 0.01 : latPadding),
      minLon: minLon - (lonPadding < 0.01 ? 0.01 : lonPadding),
      maxLat: maxLat + (latPadding < 0.01 ? 0.01 : latPadding),
      maxLon: maxLon + (lonPadding < 0.01 ? 0.01 : lonPadding),
    );
  }
}

class TripRoutingRoutePlanner implements RoutePlanner {
  TripRoutingRoutePlanner({
    TripRoutingClient? client,
    RoutePlannerFallback? fallback,
  }) : _client = client ?? TripRoutingServiceClient(),
       _fallback = fallback ?? OverpassRoutePlannerFallback();

  final TripRoutingClient _client;
  final RoutePlannerFallback _fallback;

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
      if (_shouldTryFallback(trip.errors)) {
        final fallbackSegment = await _fallback.tryPlanSegment(
          start: start,
          end: end,
        );
        if (fallbackSegment != null) {
          return fallbackSegment;
        }
      }
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

  bool _shouldTryFallback(List<String> errors) {
    return errors.any(
      (error) =>
          error == 'Graph data unavailable' || error == 'No path found.',
    );
  }
}

class _Bounds {
  const _Bounds({
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
  });

  final double minLat;
  final double minLon;
  final double maxLat;
  final double maxLon;
}
