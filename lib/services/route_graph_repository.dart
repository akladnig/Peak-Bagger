import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_import_metadata.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import 'route_graph_errors.dart';

const defaultRouteGraphCoverageKey = 'legacy';

/// Chunk overlap duplicates geometry; manifest counts describe unique graph
/// nodes and ways, not their repeated occurrences in neighboring chunks.
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

abstract class RouteGraphStorage {
  RouteGraphManifest? manifestForCoverage(String routingCoverageKey);
  List<RouteGraphManifest> manifests();
  List<RouteGraphChunk> activeChunks(String routingCoverageKey);
  List<RouteGraphWayIndex> activeWayIndexRows(String routingCoverageKey);
  List<RouteGraphTrailDisplayChunk> activeTrailDisplayChunks(
    String routingCoverageKey,
  );
  Future<int> reserveGeneration();
  Future<void> ensureMultiCoverageMigration();
  Future<void> replaceGeneration({
    required RouteGraphManifest manifest,
    required List<RouteGraphChunk> chunks,
    required List<RouteGraphWayIndex> wayIndexRows,
    required List<RouteGraphTrailDisplayChunk> trailDisplayChunks,
    required bool pruneStaleGenerations,
  });
  Future<void> markFailure(RouteGraphManifest manifest);
  Future<void> clearAll();
}

class ObjectBoxRouteGraphStorage implements RouteGraphStorage {
  ObjectBoxRouteGraphStorage(Store store)
    : _store = store,
      _manifestBox = store.box<RouteGraphManifest>(),
      _metadataBox = store.box<RouteGraphImportMetadata>(),
      _chunkBox = store.box<RouteGraphChunk>(),
      _wayIndexBox = store.box<RouteGraphWayIndex>(),
      _trailDisplayChunkBox = store.box<RouteGraphTrailDisplayChunk>();

  final Store _store;
  final Box<RouteGraphManifest> _manifestBox;
  final Box<RouteGraphImportMetadata> _metadataBox;
  final Box<RouteGraphChunk> _chunkBox;
  final Box<RouteGraphWayIndex> _wayIndexBox;
  final Box<RouteGraphTrailDisplayChunk> _trailDisplayChunkBox;

  @override
  RouteGraphManifest? manifestForCoverage(String routingCoverageKey) {
    if (routingCoverageKey.isEmpty) return null;
    final query = _manifestBox
        .query(
          RouteGraphManifest_.routingCoverageKey.equals(routingCoverageKey),
        )
        .build();
    final manifest = query.findFirst();
    query.close();
    return manifest;
  }

  @override
  List<RouteGraphManifest> manifests() => _manifestBox
      .getAll()
      .where((manifest) => manifest.routingCoverageKey.isNotEmpty)
      .toList(growable: false);

  @override
  List<RouteGraphChunk> activeChunks(String routingCoverageKey) {
    if (routingCoverageKey.isEmpty) return const [];
    final manifest = manifestForCoverage(routingCoverageKey);
    if (manifest?.hasActiveGeneration != true) return const [];
    return _chunkBox
        .getAll()
        .where(
          (row) =>
              row.routingCoverageKey == routingCoverageKey &&
              row.generation == manifest!.activeGeneration,
        )
        .toList(growable: false);
  }

  @override
  List<RouteGraphWayIndex> activeWayIndexRows(String routingCoverageKey) {
    if (routingCoverageKey.isEmpty) return const [];
    final manifest = manifestForCoverage(routingCoverageKey);
    if (manifest?.hasActiveGeneration != true) return const [];
    return _wayIndexBox
        .getAll()
        .where(
          (row) =>
              row.routingCoverageKey == routingCoverageKey &&
              row.generation == manifest!.activeGeneration,
        )
        .toList(growable: false);
  }

  @override
  List<RouteGraphTrailDisplayChunk> activeTrailDisplayChunks(
    String routingCoverageKey,
  ) {
    if (routingCoverageKey.isEmpty) return const [];
    final manifest = manifestForCoverage(routingCoverageKey);
    if (manifest?.hasActiveGeneration != true) return const [];
    return _trailDisplayChunkBox
        .getAll()
        .where(
          (row) =>
              row.routingCoverageKey == routingCoverageKey &&
              row.generation == manifest!.activeGeneration,
        )
        .toList(growable: false);
  }

  @override
  Future<int> reserveGeneration() async {
    return _store.runInTransaction(TxMode.write, () {
      final metadata =
          _metadataBox.get(RouteGraphImportMetadata.metadataId) ??
          RouteGraphImportMetadata();
      final highestActiveGeneration = _manifestBox.getAll().fold<int>(
        0,
        (highest, manifest) => manifest.activeGeneration > highest
            ? manifest.activeGeneration
            : highest,
      );
      if (metadata.lastReservedGeneration < highestActiveGeneration) {
        metadata.lastReservedGeneration = highestActiveGeneration;
      }
      metadata.lastReservedGeneration += 1;
      _metadataBox.put(metadata);
      return metadata.lastReservedGeneration;
    });
  }

  @override
  Future<void> ensureMultiCoverageMigration() async {
    _store.runInTransaction(TxMode.write, () {
      final metadata =
          _metadataBox.get(RouteGraphImportMetadata.metadataId) ??
          RouteGraphImportMetadata();
      _removeLegacyRows();
      metadata.multiCoverageMigrationComplete = true;
      _metadataBox.put(metadata);
    });
  }

  @override
  Future<void> replaceGeneration({
    required RouteGraphManifest manifest,
    required List<RouteGraphChunk> chunks,
    required List<RouteGraphWayIndex> wayIndexRows,
    required List<RouteGraphTrailDisplayChunk> trailDisplayChunks,
    required bool pruneStaleGenerations,
  }) async {
    _store.runInTransaction(TxMode.write, () {
      _validateGenerationRows(
        manifest,
        chunks,
        wayIndexRows,
        trailDisplayChunks,
      );
      final previous = manifestForCoverage(manifest.routingCoverageKey);
      if (previous != null) {
        manifest.id = previous.id;
      }
      _manifestBox.put(manifest);
      if (chunks.isNotEmpty) _chunkBox.putMany(chunks);
      if (wayIndexRows.isNotEmpty) _wayIndexBox.putMany(wayIndexRows);
      if (trailDisplayChunks.isNotEmpty) {
        _trailDisplayChunkBox.putMany(trailDisplayChunks);
      }
      if (pruneStaleGenerations) {
        _removeStaleGenerationRows(
          manifest.routingCoverageKey,
          manifest.activeGeneration,
        );
      }
    });
  }

  @override
  Future<void> markFailure(RouteGraphManifest manifest) async {
    _store.runInTransaction(TxMode.write, () => _manifestBox.put(manifest));
  }

  @override
  Future<void> clearAll() async {
    _store.runInTransaction(TxMode.write, () {
      _chunkBox.removeAll();
      _wayIndexBox.removeAll();
      _trailDisplayChunkBox.removeAll();
      _manifestBox.removeAll();
      _metadataBox.removeAll();
    });
  }

  void _removeLegacyRows() {
    _manifestBox.removeMany(
      _manifestBox
          .getAll()
          .where((row) => row.routingCoverageKey.isEmpty)
          .map((row) => row.id)
          .toList(growable: false),
    );
    _chunkBox.removeMany(
      _chunkBox
          .getAll()
          .where((row) => row.routingCoverageKey.isEmpty)
          .map((row) => row.id)
          .toList(growable: false),
    );
    _wayIndexBox.removeMany(
      _wayIndexBox
          .getAll()
          .where((row) => row.routingCoverageKey.isEmpty)
          .map((row) => row.id)
          .toList(growable: false),
    );
    _trailDisplayChunkBox.removeMany(
      _trailDisplayChunkBox
          .getAll()
          .where((row) => row.routingCoverageKey.isEmpty)
          .map((row) => row.id)
          .toList(growable: false),
    );
  }

  void _removeStaleGenerationRows(String coverage, int generation) {
    _chunkBox.removeMany(
      _chunkBox
          .getAll()
          .where(
            (row) =>
                row.routingCoverageKey == coverage &&
                row.generation != generation,
          )
          .map((row) => row.id)
          .toList(growable: false),
    );
    _wayIndexBox.removeMany(
      _wayIndexBox
          .getAll()
          .where(
            (row) =>
                row.routingCoverageKey == coverage &&
                row.generation != generation,
          )
          .map((row) => row.id)
          .toList(growable: false),
    );
    _trailDisplayChunkBox.removeMany(
      _trailDisplayChunkBox
          .getAll()
          .where(
            (row) =>
                row.routingCoverageKey == coverage &&
                row.generation != generation,
          )
          .map((row) => row.id)
          .toList(growable: false),
    );
  }

  void _validateGenerationRows(
    RouteGraphManifest manifest,
    List<RouteGraphChunk> chunks,
    List<RouteGraphWayIndex> wayIndexRows,
    List<RouteGraphTrailDisplayChunk> trailDisplayChunks,
  ) {
    final coverage = manifest.routingCoverageKey;
    final generation = manifest.activeGeneration;
    if (coverage.isEmpty ||
        generation <= 0 ||
        chunks.length != manifest.chunkCount ||
        wayIndexRows.length != manifest.wayIndexCount ||
        trailDisplayChunks.length != manifest.trailDisplayChunkCount ||
        chunks.any(
          (row) =>
              row.routingCoverageKey != coverage ||
              row.generation != generation ||
              row.recordKey !=
                  RouteGraphChunk.recordKeyFor(
                    routingCoverageKey: coverage,
                    generation: generation,
                    chunkKey: row.chunkKey,
                  ),
        ) ||
        wayIndexRows.any(
          (row) =>
              row.routingCoverageKey != coverage ||
              row.generation != generation ||
              row.recordKey !=
                  RouteGraphWayIndex.recordKeyFor(
                    routingCoverageKey: coverage,
                    generation: generation,
                    chunkKey: row.chunkKey,
                    osmWayId: row.osmWayId,
                  ),
        ) ||
        trailDisplayChunks.any(
          (row) =>
              row.routingCoverageKey != coverage ||
              row.generation != generation ||
              row.recordKey !=
                  RouteGraphTrailDisplayChunk.recordKeyFor(
                    routingCoverageKey: coverage,
                    generation: generation,
                    cacheZoom: row.cacheZoom,
                    chunkKey: row.chunkKey,
                  ),
        )) {
      throw StateError(
        'Route-graph rows do not match their coverage generation.',
      );
    }
  }
}

class InMemoryRouteGraphStorage implements RouteGraphStorage {
  InMemoryRouteGraphStorage({
    RouteGraphManifest? manifest,
    List<RouteGraphManifest> manifests = const [],
    RouteGraphImportMetadata? metadata,
    List<RouteGraphChunk> chunks = const [],
    List<RouteGraphWayIndex> wayIndexRows = const [],
    List<RouteGraphTrailDisplayChunk> trailDisplayChunks = const [],
  }) : _metadata = metadata ?? RouteGraphImportMetadata() {
    final suppliedManifests = [if (manifest != null) manifest, ...manifests];
    final coverageKeys = suppliedManifests
        .map((entry) => entry.routingCoverageKey)
        .where((key) => key.isNotEmpty)
        .toSet();
    final fixtureCoverage = coverageKeys.length == 1
        ? coverageKeys.single
        : defaultRouteGraphCoverageKey;
    final coverageForGeneration = {
      for (final entry in suppliedManifests)
        if (entry.routingCoverageKey.isNotEmpty)
          entry.activeGeneration: entry.routingCoverageKey,
    };
    _chunks = [
      for (final row in chunks)
        _normalizeChunk(
          row,
          coverageForGeneration[row.generation] ?? fixtureCoverage,
        ),
    ];
    _wayIndexRows = [
      for (final row in wayIndexRows)
        _normalizeWayIndex(
          row,
          coverageForGeneration[row.generation] ?? fixtureCoverage,
        ),
    ];
    _trailDisplayChunks = [
      for (final row in trailDisplayChunks)
        _normalizeTrailDisplayChunk(
          row,
          coverageForGeneration[row.generation] ?? fixtureCoverage,
        ),
    ];
    _manifests = {
      for (final entry in suppliedManifests)
        _normalizeManifest(entry).routingCoverageKey: _normalizeManifest(entry),
    };
  }

  late final Map<String, RouteGraphManifest> _manifests;
  RouteGraphImportMetadata _metadata;
  late List<RouteGraphChunk> _chunks;
  late List<RouteGraphWayIndex> _wayIndexRows;
  late List<RouteGraphTrailDisplayChunk> _trailDisplayChunks;

  @override
  RouteGraphManifest? manifestForCoverage(String routingCoverageKey) =>
      routingCoverageKey.isEmpty ? null : _manifests[routingCoverageKey];

  @override
  List<RouteGraphManifest> manifests() => List.unmodifiable(
    _manifests.values.where(
      (manifest) => manifest.routingCoverageKey.isNotEmpty,
    ),
  );

  @override
  List<RouteGraphChunk> activeChunks([
    String routingCoverageKey = defaultRouteGraphCoverageKey,
  ]) => _activeRows(_chunks, routingCoverageKey, (row) => row.generation);

  @override
  List<RouteGraphWayIndex> activeWayIndexRows([
    String routingCoverageKey = defaultRouteGraphCoverageKey,
  ]) => _activeRows(_wayIndexRows, routingCoverageKey, (row) => row.generation);

  @override
  List<RouteGraphTrailDisplayChunk> activeTrailDisplayChunks([
    String routingCoverageKey = defaultRouteGraphCoverageKey,
  ]) => _activeRows(
    _trailDisplayChunks,
    routingCoverageKey,
    (row) => row.generation,
  );

  @override
  Future<int> reserveGeneration() async {
    final highestActiveGeneration = _manifests.values.fold<int>(
      0,
      (highest, manifest) => manifest.activeGeneration > highest
          ? manifest.activeGeneration
          : highest,
    );
    if (_metadata.lastReservedGeneration < highestActiveGeneration) {
      _metadata.lastReservedGeneration = highestActiveGeneration;
    }
    return ++_metadata.lastReservedGeneration;
  }

  @override
  Future<void> ensureMultiCoverageMigration() async {
    _manifests.removeWhere((key, _) => key.isEmpty);
    _chunks.removeWhere((row) => row.routingCoverageKey.isEmpty);
    _wayIndexRows.removeWhere((row) => row.routingCoverageKey.isEmpty);
    _trailDisplayChunks.removeWhere((row) => row.routingCoverageKey.isEmpty);
    _metadata.multiCoverageMigrationComplete = true;
  }

  @override
  Future<void> replaceGeneration({
    required RouteGraphManifest manifest,
    required List<RouteGraphChunk> chunks,
    required List<RouteGraphWayIndex> wayIndexRows,
    required List<RouteGraphTrailDisplayChunk> trailDisplayChunks,
    required bool pruneStaleGenerations,
  }) async {
    _validateGenerationRows(manifest, chunks, wayIndexRows, trailDisplayChunks);
    final coverage = manifest.routingCoverageKey;
    final nextManifest = manifest;
    _manifests[coverage] = nextManifest;
    _chunks = [..._chunks, ...chunks];
    _wayIndexRows = [..._wayIndexRows, ...wayIndexRows];
    _trailDisplayChunks = [..._trailDisplayChunks, ...trailDisplayChunks];
    if (pruneStaleGenerations) {
      _chunks.removeWhere(
        (row) =>
            row.routingCoverageKey == coverage &&
            row.generation != nextManifest.activeGeneration,
      );
      _wayIndexRows.removeWhere(
        (row) =>
            row.routingCoverageKey == coverage &&
            row.generation != nextManifest.activeGeneration,
      );
      _trailDisplayChunks.removeWhere(
        (row) =>
            row.routingCoverageKey == coverage &&
            row.generation != nextManifest.activeGeneration,
      );
    }
  }

  @override
  Future<void> markFailure(RouteGraphManifest manifest) async {
    _manifests[manifest.routingCoverageKey] = manifest;
  }

  @override
  Future<void> clearAll() async {
    _manifests.clear();
    _metadata = RouteGraphImportMetadata();
    _chunks = [];
    _wayIndexRows = [];
    _trailDisplayChunks = [];
  }

  List<T> _activeRows<T>(
    List<T> rows,
    String coverage,
    int Function(T row) generationOf,
  ) {
    final manifest = _manifests[coverage];
    if (manifest?.hasActiveGeneration != true) return const [];
    return rows
        .where(
          (row) =>
              _routingCoverageOf(row as Object) == coverage &&
              generationOf(row) == manifest!.activeGeneration,
        )
        .toList(growable: false);
  }

  String _routingCoverageOf(Object row) => switch (row) {
    RouteGraphChunk(:final routingCoverageKey) => routingCoverageKey,
    RouteGraphWayIndex(:final routingCoverageKey) => routingCoverageKey,
    RouteGraphTrailDisplayChunk(:final routingCoverageKey) =>
      routingCoverageKey,
    _ => throw ArgumentError.value(row, 'row'),
  };

  RouteGraphManifest _normalizeManifest(RouteGraphManifest manifest) {
    if (manifest.id == RouteGraphManifest.manifestId) {
      return manifest;
    }
    final coverage = manifest.routingCoverageKey.isEmpty
        ? defaultRouteGraphCoverageKey
        : manifest.routingCoverageKey;
    final generation = manifest.activeGeneration;
    // Legacy in-memory snapshots have no recorded source-count contract. Derive
    // their counts from their actual fixture geometry, as for row counts below.
    // Explicit persisted fixtures (id == manifestId) are never normalized.
    ({int nodes, int ways})? fixtureCounts;
    try {
      fixtureCounts = routeGraphPayloadCounts(
        _chunks
            .where(
              (row) =>
                  row.routingCoverageKey == coverage &&
                  row.generation == generation,
            )
            .map((row) => row.payloadJson),
      );
    } on FormatException {
      // Keep corrupt fixtures corrupt so production usability rejects them.
    }
    return manifest.copyWith(
      routingCoverageKey: coverage,
      nodeCount: fixtureCounts?.nodes,
      edgeCount: fixtureCounts?.ways,
      // In-memory fixtures predate coverage-qualified count fields.
      // Production storage never takes this compatibility path.
      chunkCount: _chunks
          .where(
            (row) =>
                row.routingCoverageKey == coverage &&
                row.generation == generation,
          )
          .length,
      wayIndexCount: _wayIndexRows
          .where(
            (row) =>
                row.routingCoverageKey == coverage &&
                row.generation == generation,
          )
          .length,
      trailDisplayChunkCount: _trailDisplayChunks
          .where(
            (row) =>
                row.routingCoverageKey == coverage &&
                row.generation == generation,
          )
          .length,
    );
  }

  RouteGraphChunk _normalizeChunk(RouteGraphChunk row, String coverage) {
    if (row.routingCoverageKey.isNotEmpty) return row;
    return row.copyWith(
      routingCoverageKey: coverage,
      recordKey: RouteGraphChunk.recordKeyFor(
        routingCoverageKey: coverage,
        generation: row.generation,
        chunkKey: row.chunkKey,
      ),
    );
  }

  RouteGraphWayIndex _normalizeWayIndex(
    RouteGraphWayIndex row,
    String coverage,
  ) {
    if (row.routingCoverageKey.isNotEmpty) return row;
    return row.copyWith(
      routingCoverageKey: coverage,
      recordKey: RouteGraphWayIndex.recordKeyFor(
        routingCoverageKey: coverage,
        generation: row.generation,
        chunkKey: row.chunkKey,
        osmWayId: row.osmWayId,
      ),
    );
  }

  RouteGraphTrailDisplayChunk _normalizeTrailDisplayChunk(
    RouteGraphTrailDisplayChunk row,
    String coverage,
  ) {
    if (row.routingCoverageKey.isNotEmpty) return row;
    return row.copyWith(
      routingCoverageKey: coverage,
      recordKey: RouteGraphTrailDisplayChunk.recordKeyFor(
        routingCoverageKey: coverage,
        generation: row.generation,
        cacheZoom: row.cacheZoom,
        chunkKey: row.chunkKey,
      ),
    );
  }

  void _validateGenerationRows(
    RouteGraphManifest manifest,
    List<RouteGraphChunk> chunks,
    List<RouteGraphWayIndex> wayIndexRows,
    List<RouteGraphTrailDisplayChunk> trailDisplayChunks,
  ) {
    final coverage = manifest.routingCoverageKey;
    final generation = manifest.activeGeneration;
    if (coverage.isEmpty ||
        generation <= 0 ||
        chunks.length != manifest.chunkCount ||
        wayIndexRows.length != manifest.wayIndexCount ||
        trailDisplayChunks.length != manifest.trailDisplayChunkCount ||
        chunks.any(
          (row) =>
              row.routingCoverageKey != coverage ||
              row.generation != generation ||
              row.recordKey !=
                  RouteGraphChunk.recordKeyFor(
                    routingCoverageKey: coverage,
                    generation: generation,
                    chunkKey: row.chunkKey,
                  ),
        ) ||
        wayIndexRows.any(
          (row) =>
              row.routingCoverageKey != coverage ||
              row.generation != generation ||
              row.recordKey !=
                  RouteGraphWayIndex.recordKeyFor(
                    routingCoverageKey: coverage,
                    generation: generation,
                    chunkKey: row.chunkKey,
                    osmWayId: row.osmWayId,
                  ),
        ) ||
        trailDisplayChunks.any(
          (row) =>
              row.routingCoverageKey != coverage ||
              row.generation != generation ||
              row.recordKey !=
                  RouteGraphTrailDisplayChunk.recordKeyFor(
                    routingCoverageKey: coverage,
                    generation: generation,
                    cacheZoom: row.cacheZoom,
                    chunkKey: row.chunkKey,
                  ),
        )) {
      throw StateError(
        'Route-graph rows do not match their coverage generation.',
      );
    }
  }
}

class RouteGraphRepository {
  RouteGraphRepository(RouteGraphStorage storage) : _storage = storage;
  RouteGraphRepository.objectBox(Store store)
    : _storage = ObjectBoxRouteGraphStorage(store);
  RouteGraphRepository.test(RouteGraphStorage storage) : _storage = storage;

  final RouteGraphStorage _storage;
  final Map<String, _RouteGraphCoverageCache> _caches = {};

  RouteGraphManifest? get manifest =>
      manifestForCoverage(defaultRouteGraphCoverageKey);
  RouteGraphManifest? manifestForCoverage(String routingCoverageKey) =>
      _storage.manifestForCoverage(routingCoverageKey);
  List<RouteGraphManifest> get manifests => _storage.manifests();
  bool hasUsableActiveGenerationFor(String coverage) {
    final manifest = manifestForCoverage(coverage);
    if (manifest?.hasActiveGeneration != true || coverage.isEmpty) {
      return false;
    }
    final chunks = _storage.activeChunks(coverage);
    final wayIndexRows = _storage.activeWayIndexRows(coverage);
    final trailDisplayChunks = _storage.activeTrailDisplayChunks(coverage);
    if (manifest!.chunkCount <= 0 ||
        manifest.nodeCount <= 0 ||
        manifest.edgeCount <= 0) {
      return false;
    }
    final cache = _cacheFor(coverage);
    final payloads = [for (final row in chunks) row.payloadJson];
    if (cache.countPayloads == null ||
        cache.countPayloads!.length != payloads.length ||
        [
          for (var i = 0; i < payloads.length; i++)
            cache.countPayloads![i] == payloads[i],
        ].any((same) => !same)) {
      try {
        cache.counts = routeGraphPayloadCounts(payloads);
        cache.countPayloads = payloads;
      } on FormatException {
        return false;
      }
    }
    return cache.counts!.nodes == manifest.nodeCount &&
        cache.counts!.ways == manifest.edgeCount &&
        chunks.length == manifest.chunkCount &&
        wayIndexRows.length == manifest.wayIndexCount &&
        trailDisplayChunks.length == manifest.trailDisplayChunkCount &&
        chunks.every(
          (row) =>
              row.routingCoverageKey == coverage &&
              row.generation == manifest.activeGeneration &&
              row.recordKey ==
                  RouteGraphChunk.recordKeyFor(
                    routingCoverageKey: coverage,
                    generation: manifest.activeGeneration,
                    chunkKey: row.chunkKey,
                  ),
        ) &&
        wayIndexRows.every(
          (row) =>
              row.routingCoverageKey == coverage &&
              row.generation == manifest.activeGeneration &&
              row.recordKey ==
                  RouteGraphWayIndex.recordKeyFor(
                    routingCoverageKey: coverage,
                    generation: manifest.activeGeneration,
                    chunkKey: row.chunkKey,
                    osmWayId: row.osmWayId,
                  ),
        ) &&
        trailDisplayChunks.every(
          (row) =>
              row.routingCoverageKey == coverage &&
              row.generation == manifest.activeGeneration &&
              row.recordKey ==
                  RouteGraphTrailDisplayChunk.recordKeyFor(
                    routingCoverageKey: coverage,
                    generation: manifest.activeGeneration,
                    cacheZoom: row.cacheZoom,
                    chunkKey: row.chunkKey,
                  ),
        );
  }

  bool get hasUsableActiveGeneration =>
      hasUsableActiveGenerationFor(defaultRouteGraphCoverageKey);
  int activeGenerationFor(String coverage) =>
      manifestForCoverage(coverage)?.activeGeneration ?? 0;
  int get activeGeneration => activeGenerationFor(defaultRouteGraphCoverageKey);

  List<RouteGraphChunk> activeChunks([
    String coverage = defaultRouteGraphCoverageKey,
  ]) => hasUsableActiveGenerationFor(coverage)
      ? (_cacheFor(coverage).chunks ??= _storage.activeChunks(coverage))
      : const [];
  List<RouteGraphWayIndex> activeWayIndexRows([
    String coverage = defaultRouteGraphCoverageKey,
  ]) => hasUsableActiveGenerationFor(coverage)
      ? (_cacheFor(coverage).wayIndexRows ??= _storage.activeWayIndexRows(
          coverage,
        ))
      : const [];
  List<RouteGraphTrailDisplayChunk> activeTrailDisplayChunks([
    String coverage = defaultRouteGraphCoverageKey,
  ]) => hasUsableActiveGenerationFor(coverage)
      ? (_cacheFor(coverage).trailDisplayChunks ??= _storage
            .activeTrailDisplayChunks(coverage))
      : const [];

  Future<void> ensureMultiCoverageMigration() =>
      _storage.ensureMultiCoverageMigration();
  Future<int> reserveGeneration() => _storage.reserveGeneration();

  Future<void> writePreparedGeneration(
    RouteGraphPreparedGeneration generation, {
    String routingCoverageKey = defaultRouteGraphCoverageKey,
    List<String> sourceRegionKeys = const [],
    List<RouteGraphFootprintBound> unavailableFootprint = const [],
    required bool pruneStaleGenerations,
  }) async {
    _invalidateCache(routingCoverageKey);
    final qualified = _qualifyPreparedGeneration(
      generation,
      routingCoverageKey: routingCoverageKey,
    );
    final manifest = RouteGraphManifest(
      routingCoverageKey: routingCoverageKey,
      sourceHash: qualified.sourceHash,
      schemaVersion: qualified.schemaVersion,
      activeGeneration: qualified.generation,
      importedAt: qualified.importedAt,
      chunkCount: qualified.chunkCount,
      nodeCount: qualified.nodeCount,
      edgeCount: qualified.edgeCount,
      wayIndexCount: qualified.wayIndexRows.length,
      trailDisplayChunkCount: qualified.trailDisplayChunks.length,
      readinessState: RouteGraphManifest.readinessReady,
      sourceRegionKeysJson: jsonEncode(sourceRegionKeys),
      unavailableFootprintJson: RouteGraphFootprintBound.encodeList(
        unavailableFootprint,
      ),
    );
    await _storage.replaceGeneration(
      manifest: manifest,
      chunks: qualified.chunks,
      wayIndexRows: qualified.wayIndexRows,
      trailDisplayChunks: qualified.trailDisplayChunks,
      pruneStaleGenerations: pruneStaleGenerations,
    );
  }

  Future<void> markImportFailure({
    required String routingCoverageKey,
    required String sourceHash,
    required String schemaVersion,
    required String error,
    List<String> sourceRegionKeys = const [],
    List<RouteGraphFootprintBound> unavailableFootprint = const [],
  }) async {
    _invalidateCache(routingCoverageKey);
    final previous = manifestForCoverage(routingCoverageKey);
    final base =
        previous ?? RouteGraphManifest(routingCoverageKey: routingCoverageKey);
    final footprint = previous?.unavailableFootprint ?? unavailableFootprint;
    await _storage.markFailure(
      base.copyWith(
        sourceHash: previous?.hasActiveGeneration == true
            ? previous!.sourceHash
            : sourceHash,
        schemaVersion: previous?.hasActiveGeneration == true
            ? previous!.schemaVersion
            : schemaVersion,
        importedAt: previous?.importedAt ?? DateTime.now().toUtc(),
        readinessState: previous?.hasActiveGeneration == true
            ? RouteGraphManifest.readinessReady
            : RouteGraphManifest.readinessFailed,
        lastError: error,
        sourceRegionKeysJson: sourceRegionKeys.isEmpty
            ? null
            : jsonEncode(sourceRegionKeys),
        unavailableFootprintJson: footprint.isEmpty
            ? null
            : RouteGraphFootprintBound.encodeList(footprint),
      ),
    );
  }

  Future<void> ensureCoverageFootprint({
    required String routingCoverageKey,
    required List<String> sourceRegionKeys,
    required List<RouteGraphFootprintBound> unavailableFootprint,
  }) async {
    if (manifestForCoverage(routingCoverageKey) != null) {
      return;
    }
    await _storage.markFailure(
      RouteGraphManifest(
        routingCoverageKey: routingCoverageKey,
        sourceRegionKeysJson: jsonEncode(sourceRegionKeys),
        unavailableFootprintJson: RouteGraphFootprintBound.encodeList(
          unavailableFootprint,
        ),
      ),
    );
  }

  List<String> activeCoverageKeysContaining(LatLng point) => manifests
      .where((manifest) => manifest.hasActiveGeneration)
      .where(
        (manifest) => activeChunks(manifest.routingCoverageKey).any(
          (chunk) =>
              point.latitude >= chunk.minLat &&
              point.latitude <= chunk.maxLat &&
              point.longitude >= chunk.minLon &&
              point.longitude <= chunk.maxLon,
        ),
      )
      .map((manifest) => manifest.routingCoverageKey)
      .toList(growable: false);

  List<String> unavailableCoverageKeysContaining(LatLng point) => manifests
      .where((manifest) => !manifest.hasActiveGeneration)
      .where(
        (manifest) => manifest.unavailableFootprint.any(
          (bound) => bound.contains(point.latitude, point.longitude),
        ),
      )
      .map((manifest) => manifest.routingCoverageKey)
      .toList(growable: false);

  String? selectExactlyOneActiveCoverage(LatLng point) {
    final matches = activeCoverageKeysContaining(point);
    return matches.length == 1 ? matches.single : null;
  }

  String? selectExactlyOneUnavailableCoverage(LatLng point) {
    final matches = unavailableCoverageKeysContaining(point);
    return matches.length == 1 ? matches.single : null;
  }

  String? selectExactlyOneCoverageForPoint(LatLng point) {
    final active = selectExactlyOneActiveCoverage(point);
    return active ?? selectExactlyOneUnavailableCoverage(point);
  }

  Future<trip_routing.TripService> buildTripServiceForActiveGeneration([
    String coverage = defaultRouteGraphCoverageKey,
  ]) async {
    final manifest = manifestForCoverage(coverage);
    if (manifest?.hasActiveGeneration != true) {
      throw const RouteGraphLoadException(
        'No usable route graph generation is active.',
      );
    }
    final payloads = activeChunks(
      coverage,
    ).map((chunk) => chunk.decodePayload()).toList(growable: false);
    if (payloads.isEmpty) {
      throw const RouteGraphLoadException(
        'No usable route graph chunks are active.',
      );
    }
    final service = trip_routing.TripService();
    await service.loadOverpassTilePayloads(
      payloads,
      preferWalkingPaths: true,
      source: 'objectbox://route_graph/$coverage/${manifest!.activeGeneration}',
    );
    return service;
  }

  Future<void> clearAll() async {
    _caches.clear();
    await _storage.clearAll();
  }

  _RouteGraphCoverageCache _cacheFor(String coverage) {
    final manifest = manifestForCoverage(coverage);
    final cache = _caches.putIfAbsent(coverage, _RouteGraphCoverageCache.new);
    if (cache.generation != manifest?.activeGeneration) {
      cache
        ..generation = manifest?.activeGeneration
        ..chunks = null
        ..wayIndexRows = null
        ..trailDisplayChunks = null;
      cache.countPayloads = null;
      cache.counts = null;
    }
    return cache;
  }

  void _invalidateCache(String coverage) => _caches.remove(coverage);

  RouteGraphPreparedGeneration _qualifyPreparedGeneration(
    RouteGraphPreparedGeneration prepared, {
    required String routingCoverageKey,
  }) {
    if (prepared.chunks.any(
          (row) =>
              row.routingCoverageKey.isNotEmpty &&
              row.routingCoverageKey != routingCoverageKey,
        ) ||
        prepared.wayIndexRows.any(
          (row) =>
              row.routingCoverageKey.isNotEmpty &&
              row.routingCoverageKey != routingCoverageKey,
        ) ||
        prepared.trailDisplayChunks.any(
          (row) =>
              row.routingCoverageKey.isNotEmpty &&
              row.routingCoverageKey != routingCoverageKey,
        )) {
      throw StateError(
        'Route-graph rows do not match their coverage generation.',
      );
    }
    return RouteGraphPreparedGeneration(
      generation: prepared.generation,
      sourceHash: prepared.sourceHash,
      schemaVersion: prepared.schemaVersion,
      importedAt: prepared.importedAt,
      chunkCount: prepared.chunks.length,
      nodeCount: prepared.nodeCount,
      edgeCount: prepared.edgeCount,
      chunks: [
        for (final row in prepared.chunks)
          row.copyWith(
            routingCoverageKey: routingCoverageKey,
            recordKey: RouteGraphChunk.recordKeyFor(
              routingCoverageKey: routingCoverageKey,
              generation: prepared.generation,
              chunkKey: row.chunkKey,
            ),
          ),
      ],
      wayIndexRows: [
        for (final row in prepared.wayIndexRows)
          row.copyWith(
            routingCoverageKey: routingCoverageKey,
            recordKey: RouteGraphWayIndex.recordKeyFor(
              routingCoverageKey: routingCoverageKey,
              generation: prepared.generation,
              chunkKey: row.chunkKey,
              osmWayId: row.osmWayId,
            ),
          ),
      ],
      trailDisplayChunks: [
        for (final row in prepared.trailDisplayChunks)
          row.copyWith(
            routingCoverageKey: routingCoverageKey,
            recordKey: RouteGraphTrailDisplayChunk.recordKeyFor(
              routingCoverageKey: routingCoverageKey,
              generation: prepared.generation,
              cacheZoom: row.cacheZoom,
              chunkKey: row.chunkKey,
            ),
          ),
      ],
    );
  }
}

class _RouteGraphCoverageCache {
  List<String>? countPayloads;
  ({int nodes, int ways})? counts;
  int? generation;
  List<RouteGraphChunk>? chunks;
  List<RouteGraphWayIndex>? wayIndexRows;
  List<RouteGraphTrailDisplayChunk>? trailDisplayChunks;
}
