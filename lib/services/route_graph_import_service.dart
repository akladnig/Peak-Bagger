import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';

import 'route_graph_errors.dart';
import 'route_graph_repository.dart';

typedef RouteGraphAssetLoader = Future<String> Function(String assetPath);
typedef RouteGraphGenerationPreparer = Future<Map<String, Object?>> Function(
  String rawJson,
  String schemaVersion,
  int generation,
);

const _gridSizeMeters = 5000.0;
const _overlapMeters = 1000.0;
const _earthRadiusMeters = 6378137.0;

class RouteGraphImportOutcome {
  const RouteGraphImportOutcome._({
    required this.imported,
    required this.reusedExisting,
    required this.generation,
    required this.sourceHash,
    required this.chunkCount,
    required this.nodeCount,
    required this.edgeCount,
  });

  factory RouteGraphImportOutcome.imported({
    required int generation,
    required String sourceHash,
    required int chunkCount,
    required int nodeCount,
    required int edgeCount,
  }) {
    return RouteGraphImportOutcome._(
      imported: true,
      reusedExisting: false,
      generation: generation,
      sourceHash: sourceHash,
      chunkCount: chunkCount,
      nodeCount: nodeCount,
      edgeCount: edgeCount,
    );
  }

  factory RouteGraphImportOutcome.reused(RouteGraphManifest manifest) {
    return RouteGraphImportOutcome._(
      imported: false,
      reusedExisting: true,
      generation: manifest.activeGeneration,
      sourceHash: manifest.sourceHash,
      chunkCount: manifest.chunkCount,
      nodeCount: manifest.nodeCount,
      edgeCount: manifest.edgeCount,
    );
  }

  final bool imported;
  final bool reusedExisting;
  final int generation;
  final String sourceHash;
  final int chunkCount;
  final int nodeCount;
  final int edgeCount;

  int get elementCount => nodeCount + edgeCount;
}

class RouteGraphImportService {
  RouteGraphImportService(
    this._repository, {
    RouteGraphAssetLoader? assetLoader,
    RouteGraphGenerationPreparer? generationPreparer,
    this.assetPath = _bundledRouteGraphAsset,
    this.schemaVersion = _schemaVersion,
  }) : _assetLoader = assetLoader ?? rootBundle.loadString,
        _generationPreparer =
            generationPreparer ?? _prepareGenerationInBackground;

  static const _bundledRouteGraphAsset = 'assets/highway.json';
  static const _schemaVersion = 'route-graph-v1';

  final RouteGraphRepository _repository;
  final RouteGraphAssetLoader _assetLoader;
  final RouteGraphGenerationPreparer _generationPreparer;
  final String assetPath;
  final String schemaVersion;

  Future<RouteGraphImportOutcome> bootstrapIfNeeded() async {
    final manifest = _repository.manifest;
    if (manifest?.hasActiveGeneration == true) {
      return RouteGraphImportOutcome.reused(manifest!);
    }

    if (_repository.hasBootstrapFailure) {
      throw RouteGraphLoadException(
        'Route graph bootstrap previously failed. Refresh Route Graph from Settings.',
      );
    }

    final rawJson = await _assetLoader(assetPath);
    return importRawJson(rawJson, bootstrap: true);
  }

  Future<RouteGraphImportOutcome> refreshFromBundledAsset() async {
    final rawJson = await _assetLoader(assetPath);
    return importRawJson(rawJson, bootstrap: false);
  }

  Future<RouteGraphImportOutcome> importRawJson(
    String rawJson, {
    required bool bootstrap,
  }) async {
    final hadUsableActiveGeneration = _repository.hasUsableActiveGeneration;
    final sourceHash = sha256.convert(utf8.encode(rawJson)).toString();

    try {
      final nextGeneration = _repository.activeGeneration + 1;
      final preparedMap = await _generationPreparer(
        rawJson,
        schemaVersion,
        nextGeneration,
      );
      final prepared = _preparedGenerationFromMap(preparedMap);
      await _repository.writePreparedGeneration(
        prepared,
        pruneStaleGenerations: true,
      );
      return RouteGraphImportOutcome.imported(
        generation: prepared.generation,
        sourceHash: prepared.sourceHash,
        chunkCount: prepared.chunkCount,
        nodeCount: prepared.nodeCount,
        edgeCount: prepared.edgeCount,
      );
    } catch (error) {
      if (!hadUsableActiveGeneration) {
        await _repository.markBootstrapFailure(
          sourceHash: sourceHash,
          schemaVersion: schemaVersion,
          error: '$error',
        );
      }
      throw RouteGraphLoadException('Failed to import route graph: $error');
    }
  }
}

Future<Map<String, Object?>> _prepareGenerationInBackground(
  String rawJson,
  String schemaVersion,
  int generation,
) async {
  return Isolate.run(() => _prepareGeneration(rawJson, schemaVersion, generation));
}

Map<String, Object?> _prepareGeneration(
  String rawJson,
  String schemaVersion,
  int generation,
) {
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map<String, dynamic>) {
    throw const RouteGraphLoadException('Expected top-level route graph object.');
  }

  final elements = decoded['elements'];
  if (elements is! List) {
    throw const RouteGraphLoadException('Expected top-level "elements" list.');
  }

  final nodeMap = <int, Map<String, dynamic>>{};
  final wayMaps = <Map<String, dynamic>>[];
  var nodeCount = 0;
  var edgeCount = 0;

  for (final element in elements) {
    if (element is! Map) {
      continue;
    }

    final typed = Map<String, dynamic>.from(element);
    switch (typed['type']) {
      case 'node':
        final id = _readInt(typed['id']);
        final lat = _readDouble(typed['lat']);
        final lon = _readDouble(typed['lon']);
        if (id == null || lat == null || lon == null) {
          continue;
        }
        nodeMap[id] = Map<String, dynamic>.from(typed)
          ..['id'] = id
          ..['lat'] = lat
          ..['lon'] = lon;
        nodeCount += 1;
        break;
      case 'way':
        final tags = typed['tags'];
        if (tags is Map && tags['highway'] != null && tags['area'] != 'yes' && tags['place'] != 'square') {
          wayMaps.add(typed);
          edgeCount += 1;
        }
        break;
    }
  }

  final chunks = _buildChunks(nodeMap, wayMaps, generation);

  return {
    'generation': generation,
    'sourceHash': sha256.convert(utf8.encode(rawJson)).toString(),
    'schemaVersion': schemaVersion,
    'importedAtMillis': DateTime.now().toUtc().millisecondsSinceEpoch,
    'chunkCount': chunks.length,
    'nodeCount': nodeCount,
    'edgeCount': edgeCount,
    'chunks': chunks,
  };
}

RouteGraphPreparedGeneration _preparedGenerationFromMap(Map<String, Object?> map) {
  final chunksRaw = map['chunks'];
  if (chunksRaw is! List) {
    throw const RouteGraphLoadException('Prepared route graph missing chunks.');
  }

  final chunks = chunksRaw.map((entry) {
    if (entry is! Map) {
      throw const RouteGraphLoadException('Prepared chunk payload must be a map.');
    }

    final typed = Map<String, Object?>.from(entry);
    return RouteGraphChunk(
      recordKey: typed['recordKey'] as String,
      chunkKey: typed['chunkKey'] as String,
      generation: typed['generation'] as int,
      minLat: (typed['minLat'] as num).toDouble(),
      minLon: (typed['minLon'] as num).toDouble(),
      maxLat: (typed['maxLat'] as num).toDouble(),
      maxLon: (typed['maxLon'] as num).toDouble(),
      elementCount: typed['elementCount'] as int,
      payloadJson: typed['payloadJson'] as String,
    );
  }).toList(growable: false);

  return RouteGraphPreparedGeneration(
    generation: map['generation'] as int,
    sourceHash: map['sourceHash'] as String,
    schemaVersion: map['schemaVersion'] as String,
    importedAt: DateTime.fromMillisecondsSinceEpoch(
      map['importedAtMillis'] as int,
      isUtc: true,
    ),
    chunkCount: map['chunkCount'] as int,
    nodeCount: map['nodeCount'] as int,
    edgeCount: map['edgeCount'] as int,
    chunks: chunks,
  );
}

List<Map<String, Object?>> _buildChunks(
  Map<int, Map<String, dynamic>> nodeMap,
  List<Map<String, dynamic>> ways,
  int generation,
) {
  final builders = <String, _ChunkBuilder>{};

  for (final way in ways) {
    final nodeIds = _readNodeIds(way['nodes']);
    final nodes = nodeIds
        .map(nodeMap.tryGet)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    if (nodes.isEmpty) {
      continue;
    }

    final bounds = _geometryBounds(nodes);
    final minCellX = _cellIndex(bounds.minX - _overlapMeters);
    final maxCellX = _cellIndex(bounds.maxX + _overlapMeters);
    final minCellY = _cellIndex(bounds.minY - _overlapMeters);
    final maxCellY = _cellIndex(bounds.maxY + _overlapMeters);

    for (var cellX = minCellX; cellX <= maxCellX; cellX++) {
      for (var cellY = minCellY; cellY <= maxCellY; cellY++) {
        final chunkKey = '${cellX}_$cellY';
        final builder = builders.putIfAbsent(
          chunkKey,
          () => _ChunkBuilder(
            chunkKey: chunkKey,
            generation: generation,
            minX: cellX * _gridSizeMeters - _overlapMeters,
            minY: cellY * _gridSizeMeters - _overlapMeters,
            maxX: (cellX + 1) * _gridSizeMeters + _overlapMeters,
            maxY: (cellY + 1) * _gridSizeMeters + _overlapMeters,
          ),
        );
        builder.addWay(way, nodeMap, nodeIds);
      }
    }
  }

  return builders.values
      .map((builder) => builder.toMap())
      .toList(growable: false);
}

int _cellIndex(double meters) => (meters / _gridSizeMeters).floor();

_ProjectedBounds _geometryBounds(List<Map<String, dynamic>> nodes) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;

  for (final node in nodes) {
    final lat = node['lat'] as double;
    final lon = node['lon'] as double;
    final projected = _project(lat, lon);
    minX = math.min(minX, projected.x);
    minY = math.min(minY, projected.y);
    maxX = math.max(maxX, projected.x);
    maxY = math.max(maxY, projected.y);
  }

  return _ProjectedBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

({double x, double y}) _project(double lat, double lon) {
  final x = _earthRadiusMeters * lon * math.pi / 180.0;
  final y = _earthRadiusMeters * math.log(
    math.tan(math.pi / 4.0 + lat * math.pi / 360.0),
  );
  return (x: x, y: y);
}

List<int> _readNodeIds(dynamic nodes) {
  if (nodes is! List) {
    return const [];
  }
  return nodes.map(_readInt).whereType<int>().toList(growable: false);
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

double? _readDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

class _ProjectedBounds {
  const _ProjectedBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
}

class _ChunkBuilder {
  _ChunkBuilder({
    required this.chunkKey,
    required this.generation,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final String chunkKey;
  final int generation;
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
  final Map<int, Map<String, dynamic>> _nodes = {};
  final Map<int, Map<String, dynamic>> _ways = {};

  void addWay(
    Map<String, dynamic> way,
    Map<int, Map<String, dynamic>> nodeMap,
    List<int> nodeIds,
  ) {
    final wayId = _readInt(way['id']);
    if (wayId != null) {
      _ways.putIfAbsent(wayId, () => way);
    }

    for (final nodeId in nodeIds) {
      final node = nodeMap[nodeId];
      if (node != null) {
        _nodes.putIfAbsent(nodeId, () => node);
      }
    }
  }

  Map<String, Object?> toMap() {
    final elements = <Map<String, dynamic>>[
      ..._nodes.values.map((node) => Map<String, dynamic>.from(node)),
      ..._ways.values.map((way) {
        final cloned = Map<String, dynamic>.from(way);
        cloned.remove('__nodesById');
        return cloned;
      }),
    ];
    final payload = <String, dynamic>{'elements': elements};
    return {
      'recordKey': '$generation|$chunkKey',
      'chunkKey': chunkKey,
      'generation': generation,
      'minLat': _unprojectY(minY),
      'minLon': _unprojectX(minX),
      'maxLat': _unprojectY(maxY),
      'maxLon': _unprojectX(maxX),
      'elementCount': elements.length,
      'payloadJson': jsonEncode(payload),
    };
  }
}

double _unprojectX(double x) => x * 180.0 / (_earthRadiusMeters * math.pi);

double _unprojectY(double y) =>
    (2.0 * math.atan(math.exp(y / _earthRadiusMeters)) - math.pi / 2.0) *
    180.0 /
    math.pi;

extension<T> on Map<int, T> {
  T? tryGet(int key) => containsKey(key) ? this[key] : null;
}
