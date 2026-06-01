import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';

import 'route_graph_errors.dart';
import 'route_graph_repository.dart';

class RouteGraphQueryService {
  RouteGraphQueryService(
    RouteGraphRepository repository, {
    this.bufferMeters = 1000.0,
  }) : _repository = repository;

  final RouteGraphRepository _repository;
  final double bufferMeters;
  int? _trailDisplayIndexGeneration;
  Map<int, Map<String, RouteGraphTrailDisplayChunk>>? _trailDisplayIndex;

  List<RouteGraphWayIndex> queryWays(RouteGraphWayQuery query) {
    final rows = _repository.activeWayIndexRows();
    return rows
        .where((row) => _matchesWayQuery(row, query))
        .toList(growable: false);
  }

  List<RouteGraphWayIndex> queryTrailWays() {
    return _repository
        .activeWayIndexRows()
        .where(_isTrailWayRow)
        .toList(growable: false);
  }

  List<String> chunkKeysForWays(RouteGraphWayQuery query) {
    final keys = <String>{};
    for (final row in queryWays(query)) {
      keys.add(row.chunkKey);
    }
    return keys.toList(growable: false);
  }

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

    return _repository
        .activeChunks()
        .where(expanded.intersects)
        .toList(growable: false);
  }

  List<RouteGraphChunk> queryTrailChunksForBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    double? extraBufferMeters,
  }) {
    final trailChunkKeys = queryTrailWays().map((row) => row.chunkKey).toSet();
    if (trailChunkKeys.isEmpty) {
      return const [];
    }

    return queryChunksForBounds(
          minLat: minLat,
          minLon: minLon,
          maxLat: maxLat,
          maxLon: maxLon,
          extraBufferMeters: extraBufferMeters,
        )
        .where((chunk) => trailChunkKeys.contains(chunk.chunkKey))
        .toList(growable: false);
  }

  List<RouteGraphTrailDisplayChunk> queryTrailDisplayChunksForBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    required double zoom,
    double? extraBufferMeters,
  }) {
    final visibleChunkKeys = queryChunksForBounds(
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
      extraBufferMeters: extraBufferMeters,
    ).map((chunk) => chunk.chunkKey).toSet();
    if (visibleChunkKeys.isEmpty) {
      return const [];
    }

    final cacheZoom = zoom.round().clamp(
      MapConstants.trackMinZoom,
      MapConstants.trackMaxZoom,
    );
    final rowsByChunkKey = _trailDisplayRowsForZoom(cacheZoom);
    if (rowsByChunkKey.isEmpty) {
      return const [];
    }

    final rows = <RouteGraphTrailDisplayChunk>[];
    for (final chunkKey in visibleChunkKeys) {
      final row = rowsByChunkKey[chunkKey];
      if (row != null) {
        rows.add(row);
      }
    }
    return rows;
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

  List<Map<String, dynamic>> queryTrailMergedPayloadsForBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    double? extraBufferMeters,
  }) {
    final chunks = queryTrailChunksForBounds(
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

  bool _matchesWayQuery(RouteGraphWayIndex row, RouteGraphWayQuery query) {
    if (query.include.any((filter) => !_matchesTagFilter(row, filter))) {
      return false;
    }

    if (query.exclude.any((filter) => _matchesTagFilter(row, filter))) {
      return false;
    }

    final nameContains = query.nameContains;
    if (nameContains != null && nameContains.isNotEmpty) {
      final normalizedName = row.normalizedName;
      if (normalizedName == null ||
          !normalizedName.contains(nameContains.toLowerCase())) {
        return false;
      }
    }

    final minLengthMeters = query.minLengthMeters;
    if (minLengthMeters != null && row.lengthMeters < minLengthMeters) {
      return false;
    }

    final maxLengthMeters = query.maxLengthMeters;
    if (maxLengthMeters != null && row.lengthMeters > maxLengthMeters) {
      return false;
    }

    final minTagCount = query.minTagCount;
    if (minTagCount != null && row.tagCount < minTagCount) {
      return false;
    }

    return true;
  }

  bool _matchesTagFilter(RouteGraphWayIndex row, TagFilter filter) {
    final value = switch (filter.key) {
      'highway' => row.highway,
      'surface' => row.surface,
      'footway' => row.footway,
      'foot' => row.foot,
      'route' => row.route,
      'access' => row.access,
      'name' => row.name,
      _ => throw RouteGraphLoadException(
        'Unsupported route way tag filter: ${filter.key}',
      ),
    };

    return value == filter.value;
  }

  bool _isTrailWayRow(RouteGraphWayIndex row) {
    return isRouteGraphTrailWayMetadata(
      highway: row.highway,
      surface: row.surface,
      footway: row.footway,
      foot: row.foot,
      route: row.route,
      access: row.access,
      lengthMeters: row.lengthMeters,
      tagCount: row.tagCount,
    );
  }

  Map<String, RouteGraphTrailDisplayChunk> _trailDisplayRowsForZoom(int zoom) {
    final generation = _repository.activeGeneration;
    if (_trailDisplayIndexGeneration != generation ||
        _trailDisplayIndex == null) {
      final nextIndex = <int, Map<String, RouteGraphTrailDisplayChunk>>{};
      for (final row in _repository.activeTrailDisplayChunks()) {
        (nextIndex[row.cacheZoom] ??=
                <String, RouteGraphTrailDisplayChunk>{})[row.chunkKey] =
            row;
      }
      _trailDisplayIndexGeneration = generation;
      _trailDisplayIndex = nextIndex;
    }

    return _trailDisplayIndex?[zoom] ?? const {};
  }
}

bool isRouteGraphTrailWayMetadata({
  required String? highway,
  required String? surface,
  required String? footway,
  required String? foot,
  required String? route,
  required String? access,
  required int lengthMeters,
  required int tagCount,
}) {
  if (access == 'private' ||
      <String>{
        'concrete',
        'asphalt',
        'paved',
        'paving_stones',
      }.contains(surface) ||
      footway == 'sidewalk' ||
      foot == 'no' ||
      route == 'mtb') {
    return false;
  }

  if (highway == 'path') {
    return true;
  }

  if (highway == 'track' && surface == 'earth') {
    return true;
  }

  return highway == 'footway' && lengthMeters > 500 && tagCount > 1;
}

class TagFilter {
  const TagFilter({required this.key, required this.value});

  final String key;
  final String value;
}

class RouteGraphWayQuery {
  const RouteGraphWayQuery({
    this.include = const [],
    this.exclude = const [],
    this.nameContains,
    this.minLengthMeters,
    this.maxLengthMeters,
    this.minTagCount,
  });

  final List<TagFilter> include;
  final List<TagFilter> exclude;
  final String? nameContains;
  final int? minLengthMeters;
  final int? maxLengthMeters;
  final int? minTagCount;
}

Map<String, dynamic> _mergeChunksIntoPayload(List<RouteGraphChunk> chunks) {
  final uniqueElements = <String, Map<String, dynamic>>{};

  for (final chunk in chunks) {
    final payload = chunk.decodePayload();
    final elements = payload['elements'];
    if (elements is! List) {
      throw const RouteGraphLoadException(
        'Route graph chunk payload missing elements.',
      );
    }

    for (final element in elements) {
      if (element is! Map) {
        continue;
      }

      final typed = Map<String, dynamic>.from(element);
      final type = typed['type'];
      final id = typed['id'];
      if (type is! String || id is! int) {
        throw const RouteGraphLoadException(
          'Route graph chunk element is missing OSM identity.',
        );
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
  final denominator = math.max(
    111320.0 * (cosLat < 1e-6 ? 1e-6 : cosLat),
    1e-6,
  );
  return meters / denominator;
}
