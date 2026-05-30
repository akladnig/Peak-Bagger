import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import 'package:peak_bagger/models/route_graph_chunk.dart';

import 'route_graph_errors.dart';
import 'route_graph_repository.dart';

class RouteGraphQueryService {
  RouteGraphQueryService(
    RouteGraphRepository repository, {
    this.bufferMeters = 1000.0,
  }) : _repository = repository;

  final RouteGraphRepository _repository;
  final double bufferMeters;

  List<RouteGraphChunk> queryChunksForBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    double? extraBufferMeters,
  }) {
    final expanded = _RouteGraphBounds(
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
    ).expand(extraBufferMeters ?? bufferMeters);

    return _repository.activeChunks().where(expanded.intersects).toList(growable: false);
  }

  List<RouteGraphChunk> queryChunksForRoute({
    required LatLng start,
    required LatLng end,
    double? extraBufferMeters,
  }) {
    final bounds = _RouteGraphBounds.fromPoints(start, end);
    return queryChunksForBounds(
      minLat: bounds.minLat,
      minLon: bounds.minLon,
      maxLat: bounds.maxLat,
      maxLon: bounds.maxLon,
      extraBufferMeters: extraBufferMeters,
    );
  }

  List<RouteGraphChunk> queryChunksForPoint({
    required LatLng point,
    double? extraBufferMeters,
  }) {
    return queryChunksForBounds(
      minLat: point.latitude,
      minLon: point.longitude,
      maxLat: point.latitude,
      maxLon: point.longitude,
      extraBufferMeters: extraBufferMeters,
    );
  }

  List<Map<String, dynamic>> queryMergedPayloadsForBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    double? extraBufferMeters,
  }) {
    final chunks = queryChunksForBounds(
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
      extraBufferMeters: extraBufferMeters,
    );
    if (chunks.isEmpty) {
      return const [];
    }

    return [_mergeChunksIntoPayload(chunks)];
  }

  Future<void> prefetchBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    double? extraBufferMeters,
  }) async {
    queryMergedPayloadsForBounds(
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
      extraBufferMeters: extraBufferMeters,
    );
  }

  List<Map<String, dynamic>> queryMergedPayloadsForRoute({
    required LatLng start,
    required LatLng end,
    double? extraBufferMeters,
  }) {
    final chunks = queryChunksForRoute(
      start: start,
      end: end,
      extraBufferMeters: extraBufferMeters,
    );
    if (chunks.isEmpty) {
      return const [];
    }

    return [_mergeChunksIntoPayload(chunks)];
  }

  List<Map<String, dynamic>> queryMergedPayloadsForPoint({
    required LatLng point,
    double? extraBufferMeters,
  }) {
    final chunks = queryChunksForPoint(
      point: point,
      extraBufferMeters: extraBufferMeters,
    );
    if (chunks.isEmpty) {
      return const [];
    }

    return [_mergeChunksIntoPayload(chunks)];
  }

  Future<trip_routing.TripService> buildTripServiceForRoute({
    required LatLng start,
    required LatLng end,
    double? extraBufferMeters,
  }) async {
    final payloads = queryMergedPayloadsForRoute(
      start: start,
      end: end,
      extraBufferMeters: extraBufferMeters,
    );
    return _loadTripService(
      payloads,
      message: 'No usable route graph coverage for requested route.',
    );
  }

  Future<trip_routing.TripService> buildTripServiceForPoint({
    required LatLng point,
    double? extraBufferMeters,
  }) async {
    final payloads = queryMergedPayloadsForPoint(
      point: point,
      extraBufferMeters: extraBufferMeters,
    );
    return _loadTripService(
      payloads,
      message: 'No usable route graph coverage for requested point.',
    );
  }

  Future<trip_routing.TripService> buildTripServiceForBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    double? extraBufferMeters,
  }) async {
    final payloads = queryMergedPayloadsForBounds(
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
      extraBufferMeters: extraBufferMeters,
    );
    return _loadTripService(
      payloads,
      message: 'No usable route graph coverage for requested area.',
    );
  }

  Future<trip_routing.TripService> _loadTripService(
    List<Map<String, dynamic>> payloads, {
    required String message,
  }) async {
    if (payloads.isEmpty) {
      throw RouteGraphLoadException(message);
    }

    final service = trip_routing.TripService();
    await service.loadOverpassTilePayloads(
      payloads,
      preferWalkingPaths: true,
      source: 'objectbox://route_graph/${_repository.activeGeneration}',
    );
    return service;
  }
}

Map<String, dynamic> _mergeChunksIntoPayload(List<RouteGraphChunk> chunks) {
  final uniqueElements = <String, Map<String, dynamic>>{};

  for (final chunk in chunks) {
    final payload = chunk.decodePayload();
    final elements = payload['elements'];
    if (elements is! List) {
      throw const RouteGraphLoadException('Route graph chunk payload missing elements.');
    }

    for (final element in elements) {
      if (element is! Map) {
        continue;
      }

      final typed = Map<String, dynamic>.from(element);
      final type = typed['type'];
      final id = typed['id'];
      if (type is! String || id is! int) {
        throw const RouteGraphLoadException('Route graph chunk element is missing OSM identity.');
      }

      uniqueElements.putIfAbsent('$type:$id', () => typed);
    }
  }

  return {'elements': uniqueElements.values.toList(growable: false)};
}

class _RouteGraphBounds {
  const _RouteGraphBounds({
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
  });

  factory _RouteGraphBounds.fromPoints(LatLng start, LatLng end) {
    return _RouteGraphBounds(
      minLat: math.min(start.latitude, end.latitude),
      minLon: math.min(start.longitude, end.longitude),
      maxLat: math.max(start.latitude, end.latitude),
      maxLon: math.max(start.longitude, end.longitude),
    );
  }

  final double minLat;
  final double minLon;
  final double maxLat;
  final double maxLon;

  _RouteGraphBounds expand(double meters) {
    final latitudePadding = _metersToLatitudeDegrees(meters);
    final centerLat = (minLat + maxLat) / 2.0;
    final longitudePadding = _metersToLongitudeDegrees(meters, centerLat);
    return _RouteGraphBounds(
      minLat: minLat - latitudePadding,
      minLon: minLon - longitudePadding,
      maxLat: maxLat + latitudePadding,
      maxLon: maxLon + longitudePadding,
    );
  }

  bool intersects(RouteGraphChunk chunk) {
    return chunk.maxLat >= minLat &&
        chunk.minLat <= maxLat &&
        chunk.maxLon >= minLon &&
        chunk.minLon <= maxLon;
  }
}

double _metersToLatitudeDegrees(double meters) => meters / 111320.0;

double _metersToLongitudeDegrees(double meters, double latitude) {
  final cosLat = math.cos(latitude * math.pi / 180.0).abs();
  final denominator = math.max(111320.0 * (cosLat < 1e-6 ? 1e-6 : cosLat), 1e-6);
  return meters / denominator;
}
