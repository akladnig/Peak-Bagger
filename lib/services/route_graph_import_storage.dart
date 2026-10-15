import 'dart:convert';
import '../models/route_graph_chunk.dart';
import '../models/route_graph_manifest.dart';
import '../models/route_graph_trail_display_chunk.dart';
import '../models/route_graph_way_index.dart';

const defaultRouteGraphCoverageKey = 'legacy';

({int nodes, int ways}) routeGraphPayloadCounts(Iterable<String> payloads) {
  final nodes = <int>{};
  final ways = <int>{};
  for (final text in payloads) {
    final payload = jsonDecode(text);
    if (payload is! Map || payload['elements'] is! List) {
      throw const FormatException('Invalid persisted route graph payload.');
    }
    for (final element in payload['elements'] as List) {
      if (element is! Map ||
          element['id'] is! int ||
          (element['id'] as int) <= 0) {
        throw const FormatException('Invalid persisted graph identity.');
      }
      if (element['type'] == 'node') nodes.add(element['id'] as int);
      if (element['type'] == 'way') ways.add(element['id'] as int);
    }
  }
  return (nodes: nodes.length, ways: ways.length);
}

class RouteGraphPreparedGeneration {
  const RouteGraphPreparedGeneration({
    required this.generation,
    required this.sourceHash,
    required this.schemaVersion,
    required this.importedAt,
    required this.chunkCount,
    required this.nodeCount,
    required this.edgeCount,
    required this.chunks,
    required this.wayIndexRows,
    this.trailDisplayChunks = const [],
  });
  final int generation;
  final String sourceHash;
  final String schemaVersion;
  final DateTime importedAt;
  final int chunkCount;
  final int nodeCount;
  final int edgeCount;
  final List<RouteGraphChunk> chunks;
  final List<RouteGraphWayIndex> wayIndexRows;
  final List<RouteGraphTrailDisplayChunk> trailDisplayChunks;
  int get elementCount => nodeCount + edgeCount;
}

abstract interface class RouteGraphImportStorage {
  RouteGraphManifest? get manifest;
  RouteGraphManifest? manifestForCoverage(String key);
  List<RouteGraphTrailDisplayChunk> activeTrailDisplayChunks([
    String coverage = defaultRouteGraphCoverageKey,
  ]);
  Future<void> ensureMultiCoverageMigration();
  Future<int> reserveGeneration();
  Future<void> writePreparedGeneration(
    RouteGraphPreparedGeneration generation, {
    String routingCoverageKey = defaultRouteGraphCoverageKey,
    List<String> sourceRegionKeys = const [],
    List<RouteGraphFootprintBound> unavailableFootprint = const [],
    required bool pruneStaleGenerations,
  });
  Future<void> markImportFailure({
    required String routingCoverageKey,
    required String sourceHash,
    required String schemaVersion,
    required String error,
    List<String> sourceRegionKeys = const [],
    List<RouteGraphFootprintBound> unavailableFootprint = const [],
  });
}
