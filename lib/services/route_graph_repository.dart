import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import 'route_graph_errors.dart';

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
  RouteGraphManifest? activeManifest();

  List<RouteGraphChunk> activeChunks();

  List<RouteGraphWayIndex> activeWayIndexRows();

  List<RouteGraphTrailDisplayChunk> activeTrailDisplayChunks();

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
      _chunkBox = store.box<RouteGraphChunk>(),
      _wayIndexBox = store.box<RouteGraphWayIndex>();

  final Store _store;
  final Box<RouteGraphManifest> _manifestBox;
  final Box<RouteGraphChunk> _chunkBox;
  final Box<RouteGraphWayIndex> _wayIndexBox;

  @override
  RouteGraphManifest? activeManifest() {
    return _manifestBox.get(RouteGraphManifest.manifestId);
  }

  @override
  List<RouteGraphChunk> activeChunks() {
    final manifest = activeManifest();
    if (manifest == null || !manifest.hasActiveGeneration) {
      return const [];
    }

    final query = _chunkBox
        .query(RouteGraphChunk_.generation.equals(manifest.activeGeneration))
        .build();
    final chunks = query.find();
    query.close();
    return chunks;
  }

  @override
  List<RouteGraphWayIndex> activeWayIndexRows() {
    final manifest = activeManifest();
    if (manifest == null || !manifest.hasActiveGeneration) {
      return const [];
    }

    final query = _wayIndexBox
        .query(RouteGraphWayIndex_.generation.equals(manifest.activeGeneration))
        .build();
    final rows = query.find();
    query.close();
    return rows;
  }

  @override
  List<RouteGraphTrailDisplayChunk> activeTrailDisplayChunks() {
    return const [];
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
      _manifestBox.put(manifest);
      if (pruneStaleGenerations) {
        final staleQuery = _chunkBox
            .query(RouteGraphChunk_.generation.notEquals(manifest.activeGeneration))
            .build();
        final staleIds = staleQuery.findIds();
        staleQuery.close();
        if (staleIds.isNotEmpty) {
          _chunkBox.removeMany(staleIds);
        }

        final staleWayQuery = _wayIndexBox
            .query(RouteGraphWayIndex_.generation.notEquals(manifest.activeGeneration))
            .build();
        final staleWayIds = staleWayQuery.findIds();
        staleWayQuery.close();
        if (staleWayIds.isNotEmpty) {
          _wayIndexBox.removeMany(staleWayIds);
        }
      }
      if (chunks.isNotEmpty) {
        _chunkBox.putMany(chunks);
      }
      if (wayIndexRows.isNotEmpty) {
        _wayIndexBox.putMany(wayIndexRows);
      }
    });
  }

  @override
  Future<void> markFailure(RouteGraphManifest manifest) async {
    _store.runInTransaction(TxMode.write, () {
      _manifestBox.put(manifest);
    });
  }

  @override
  Future<void> clearAll() async {
    _chunkBox.removeAll();
    _wayIndexBox.removeAll();
    _manifestBox.remove(RouteGraphManifest.manifestId);
  }
}

class InMemoryRouteGraphStorage implements RouteGraphStorage {
  InMemoryRouteGraphStorage({
    RouteGraphManifest? manifest,
    List<RouteGraphChunk> chunks = const [],
    List<RouteGraphWayIndex> wayIndexRows = const [],
    List<RouteGraphTrailDisplayChunk> trailDisplayChunks = const [],
  })
    : _manifest = manifest,
      _chunks = List<RouteGraphChunk>.from(chunks),
      _wayIndexRows = List<RouteGraphWayIndex>.from(wayIndexRows),
      _trailDisplayChunks = List<RouteGraphTrailDisplayChunk>.from(
        trailDisplayChunks,
      );

  RouteGraphManifest? _manifest;
  List<RouteGraphChunk> _chunks;
  List<RouteGraphWayIndex> _wayIndexRows;
  List<RouteGraphTrailDisplayChunk> _trailDisplayChunks;

  @override
  RouteGraphManifest? activeManifest() => _manifest;

  @override
  List<RouteGraphChunk> activeChunks() {
    final manifest = _manifest;
    if (manifest == null || !manifest.hasActiveGeneration) {
      return const [];
    }
    return _chunks
        .where((chunk) => chunk.generation == manifest.activeGeneration)
        .toList(growable: false);
  }

  @override
  List<RouteGraphWayIndex> activeWayIndexRows() {
    final manifest = _manifest;
    if (manifest == null || !manifest.hasActiveGeneration) {
      return const [];
    }
    return _wayIndexRows
        .where((row) => row.generation == manifest.activeGeneration)
        .toList(growable: false);
  }

  @override
  List<RouteGraphTrailDisplayChunk> activeTrailDisplayChunks() {
    final manifest = _manifest;
    if (manifest == null || !manifest.hasActiveGeneration) {
      return const [];
    }
    return _trailDisplayChunks
        .where((row) => row.generation == manifest.activeGeneration)
        .toList(growable: false);
  }

  @override
  Future<void> replaceGeneration({
    required RouteGraphManifest manifest,
    required List<RouteGraphChunk> chunks,
    required List<RouteGraphWayIndex> wayIndexRows,
    required List<RouteGraphTrailDisplayChunk> trailDisplayChunks,
    required bool pruneStaleGenerations,
  }) async {
    _manifest = manifest;
    if (pruneStaleGenerations) {
      _chunks = chunks.where((chunk) => chunk.generation == manifest.activeGeneration).toList(growable: false);
      _wayIndexRows = wayIndexRows
          .where((row) => row.generation == manifest.activeGeneration)
          .toList(growable: false);
      _trailDisplayChunks = trailDisplayChunks
          .where((row) => row.generation == manifest.activeGeneration)
          .toList(growable: false);
    } else {
      _chunks = [..._chunks, ...chunks];
      _wayIndexRows = [..._wayIndexRows, ...wayIndexRows];
      _trailDisplayChunks = [..._trailDisplayChunks, ...trailDisplayChunks];
    }
  }

  @override
  Future<void> markFailure(RouteGraphManifest manifest) async {
    _manifest = manifest;
  }

  @override
  Future<void> clearAll() async {
    _manifest = null;
    _chunks = [];
    _wayIndexRows = [];
    _trailDisplayChunks = [];
  }
}

class RouteGraphRepository {
  RouteGraphRepository(RouteGraphStorage storage) : _storage = storage;

  RouteGraphRepository.objectBox(Store store)
    : _storage = ObjectBoxRouteGraphStorage(store);

  RouteGraphRepository.test(RouteGraphStorage storage) : _storage = storage;

  final RouteGraphStorage _storage;

  RouteGraphManifest? get manifest => _storage.activeManifest();

  bool get hasUsableActiveGeneration {
    return manifest?.hasActiveGeneration ?? false;
  }

  bool get hasBootstrapFailure {
    final manifest = this.manifest;
    return manifest != null && manifest.isFailed && manifest.activeGeneration == 0;
  }

  int get activeGeneration => manifest?.activeGeneration ?? 0;

  List<RouteGraphChunk> activeChunks() => _storage.activeChunks();

  List<RouteGraphWayIndex> activeWayIndexRows() => _storage.activeWayIndexRows();

  List<RouteGraphTrailDisplayChunk> activeTrailDisplayChunks() {
    return _storage.activeTrailDisplayChunks();
  }

  Future<void> writePreparedGeneration(
    RouteGraphPreparedGeneration generation, {
    required bool pruneStaleGenerations,
  }) async {
    final manifest = RouteGraphManifest(
      sourceHash: generation.sourceHash,
      schemaVersion: generation.schemaVersion,
      activeGeneration: generation.generation,
      importedAt: generation.importedAt,
      chunkCount: generation.chunkCount,
      nodeCount: generation.nodeCount,
      edgeCount: generation.edgeCount,
      readinessState: RouteGraphManifest.readinessReady,
      lastError: null,
    );
    await _storage.replaceGeneration(
      manifest: manifest,
      chunks: generation.chunks,
      wayIndexRows: generation.wayIndexRows,
      trailDisplayChunks: generation.trailDisplayChunks,
      pruneStaleGenerations: pruneStaleGenerations,
    );
  }

  Future<void> markBootstrapFailure({
    required String sourceHash,
    required String schemaVersion,
    required String error,
  }) async {
    final manifest = RouteGraphManifest(
      sourceHash: sourceHash,
      schemaVersion: schemaVersion,
      activeGeneration: 0,
      importedAt: DateTime.now().toUtc(),
      chunkCount: 0,
      nodeCount: 0,
      edgeCount: 0,
      readinessState: RouteGraphManifest.readinessFailed,
      lastError: error,
    );
    await _storage.markFailure(manifest);
  }

  Future<trip_routing.TripService> buildTripServiceForActiveGeneration() async {
    final manifest = this.manifest;
    if (manifest == null || !manifest.hasActiveGeneration) {
      throw const RouteGraphLoadException('No usable route graph generation is active.');
    }

    final payloads = activeChunks().map((chunk) => chunk.decodePayload()).toList(growable: false);
    if (payloads.isEmpty) {
      throw const RouteGraphLoadException('No usable route graph chunks are active.');
    }

    final service = trip_routing.TripService();
    await service.loadOverpassTilePayloads(
      payloads,
      preferWalkingPaths: true,
      source: 'objectbox://route_graph/${manifest.activeGeneration}',
    );
    return service;
  }

  Future<void> clearAll() => _storage.clearAll();
}
