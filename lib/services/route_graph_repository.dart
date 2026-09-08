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
  List<RouteGraphManifest> manifests() => _manifestBox.getAll();

  @override
  List<RouteGraphChunk> activeChunks(String routingCoverageKey) {
    final manifest = manifestForCoverage(routingCoverageKey);
    if (manifest?.hasActiveGeneration != true) return const [];
    return _rowsForGeneration(
      _chunkBox,
      RouteGraphChunk_.generation,
      manifest!.activeGeneration,
    );
  }

  @override
  List<RouteGraphWayIndex> activeWayIndexRows(String routingCoverageKey) {
    final manifest = manifestForCoverage(routingCoverageKey);
    if (manifest?.hasActiveGeneration != true) return const [];
    return _rowsForGeneration(
      _wayIndexBox,
      RouteGraphWayIndex_.generation,
      manifest!.activeGeneration,
    );
  }

  @override
  List<RouteGraphTrailDisplayChunk> activeTrailDisplayChunks(
    String routingCoverageKey,
  ) {
    final manifest = manifestForCoverage(routingCoverageKey);
    if (manifest?.hasActiveGeneration != true) return const [];
    return _rowsForGeneration(
      _trailDisplayChunkBox,
      RouteGraphTrailDisplayChunk_.generation,
      manifest!.activeGeneration,
    );
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
      if (metadata.multiCoverageMigrationComplete) return;

      final legacy = _manifestBox.get(RouteGraphManifest.manifestId);
      if (legacy != null && legacy.routingCoverageKey.isEmpty) {
        _manifestBox.remove(RouteGraphManifest.manifestId);
        _chunkBox.removeAll();
        _wayIndexBox.removeAll();
        _trailDisplayChunkBox.removeAll();
      }
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
      final previousGeneration = previous?.activeGeneration;
      if (pruneStaleGenerations &&
          previousGeneration != null &&
          previousGeneration > 0 &&
          previousGeneration != manifest.activeGeneration) {
        _removeGenerationRows(previousGeneration);
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

  List<T> _rowsForGeneration<T>(
    Box<T> box,
    QueryIntegerProperty<T> property,
    int generation,
  ) {
    final query = box.query(property.equals(generation)).build();
    final rows = query.find();
    query.close();
    return rows;
  }

  void _removeGenerationRows(int generation) {
    _removeRowsForGeneration(
      _chunkBox,
      RouteGraphChunk_.generation,
      generation,
    );
    _removeRowsForGeneration(
      _wayIndexBox,
      RouteGraphWayIndex_.generation,
      generation,
    );
    _removeRowsForGeneration(
      _trailDisplayChunkBox,
      RouteGraphTrailDisplayChunk_.generation,
      generation,
    );
  }

  void _removeRowsForGeneration<T>(
    Box<T> box,
    QueryIntegerProperty<T> property,
    int generation,
  ) {
    final query = box.query(property.equals(generation)).build();
    final ids = query.findIds();
    query.close();
    if (ids.isNotEmpty) box.removeMany(ids);
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
  }) : _manifests = {
         for (final entry in [if (manifest != null) manifest, ...manifests])
           entry.routingCoverageKey.isEmpty
               ? defaultRouteGraphCoverageKey
               : entry.routingCoverageKey: entry.routingCoverageKey.isEmpty
               ? entry.copyWith(
                   routingCoverageKey: defaultRouteGraphCoverageKey,
                 )
               : entry,
       },
       _metadata = metadata ?? RouteGraphImportMetadata(),
       _chunks = List.of(chunks),
       _wayIndexRows = List.of(wayIndexRows),
       _trailDisplayChunks = List.of(trailDisplayChunks);

  final Map<String, RouteGraphManifest> _manifests;
  RouteGraphImportMetadata _metadata;
  List<RouteGraphChunk> _chunks;
  List<RouteGraphWayIndex> _wayIndexRows;
  List<RouteGraphTrailDisplayChunk> _trailDisplayChunks;

  @override
  RouteGraphManifest? manifestForCoverage(String routingCoverageKey) =>
      _manifests[routingCoverageKey];

  @override
  List<RouteGraphManifest> manifests() => List.unmodifiable(_manifests.values);

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
    if (_metadata.multiCoverageMigrationComplete) return;
    final legacy = _manifests[defaultRouteGraphCoverageKey];
    if (legacy != null && legacy.id == RouteGraphManifest.manifestId) {
      _manifests.remove(defaultRouteGraphCoverageKey);
      _chunks = [];
      _wayIndexRows = [];
      _trailDisplayChunks = [];
    }
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
    final coverage = manifest.routingCoverageKey.isEmpty
        ? defaultRouteGraphCoverageKey
        : manifest.routingCoverageKey;
    final nextManifest = manifest.routingCoverageKey == coverage
        ? manifest
        : manifest.copyWith(routingCoverageKey: coverage);
    final previous = _manifests[coverage];
    _manifests[coverage] = nextManifest;
    _chunks = [..._chunks, ...chunks];
    _wayIndexRows = [..._wayIndexRows, ...wayIndexRows];
    _trailDisplayChunks = [..._trailDisplayChunks, ...trailDisplayChunks];
    final previousGeneration = previous?.activeGeneration;
    if (pruneStaleGenerations &&
        previousGeneration != null &&
        previousGeneration > 0 &&
        previousGeneration != nextManifest.activeGeneration) {
      _chunks.removeWhere((row) => row.generation == previousGeneration);
      _wayIndexRows.removeWhere((row) => row.generation == previousGeneration);
      _trailDisplayChunks.removeWhere(
        (row) => row.generation == previousGeneration,
      );
    }
  }

  @override
  Future<void> markFailure(RouteGraphManifest manifest) async {
    final coverage = manifest.routingCoverageKey.isEmpty
        ? defaultRouteGraphCoverageKey
        : manifest.routingCoverageKey;
    _manifests[coverage] = manifest.routingCoverageKey == coverage
        ? manifest
        : manifest.copyWith(routingCoverageKey: coverage);
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
        .where((row) => generationOf(row) == manifest!.activeGeneration)
        .toList(growable: false);
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
  bool hasUsableActiveGenerationFor(String coverage) =>
      manifestForCoverage(coverage)?.hasActiveGeneration ?? false;
  bool get hasUsableActiveGeneration =>
      hasUsableActiveGenerationFor(defaultRouteGraphCoverageKey);
  int activeGenerationFor(String coverage) =>
      manifestForCoverage(coverage)?.activeGeneration ?? 0;
  int get activeGeneration => activeGenerationFor(defaultRouteGraphCoverageKey);

  List<RouteGraphChunk> activeChunks([
    String coverage = defaultRouteGraphCoverageKey,
  ]) => _cacheFor(coverage).chunks ??= _storage.activeChunks(coverage);
  List<RouteGraphWayIndex> activeWayIndexRows([
    String coverage = defaultRouteGraphCoverageKey,
  ]) => _cacheFor(coverage).wayIndexRows ??= _storage.activeWayIndexRows(
    coverage,
  );
  List<RouteGraphTrailDisplayChunk> activeTrailDisplayChunks([
    String coverage = defaultRouteGraphCoverageKey,
  ]) => _cacheFor(coverage).trailDisplayChunks ??= _storage
      .activeTrailDisplayChunks(coverage);

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
    final manifest = RouteGraphManifest(
      routingCoverageKey: routingCoverageKey,
      sourceHash: generation.sourceHash,
      schemaVersion: generation.schemaVersion,
      activeGeneration: generation.generation,
      importedAt: generation.importedAt,
      chunkCount: generation.chunkCount,
      nodeCount: generation.nodeCount,
      edgeCount: generation.edgeCount,
      readinessState: RouteGraphManifest.readinessReady,
      sourceRegionKeysJson: jsonEncode(sourceRegionKeys),
      unavailableFootprintJson: RouteGraphFootprintBound.encodeList(
        unavailableFootprint,
      ),
    );
    await _storage.replaceGeneration(
      manifest: manifest,
      chunks: generation.chunks,
      wayIndexRows: generation.wayIndexRows,
      trailDisplayChunks: generation.trailDisplayChunks,
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
        sourceHash: sourceHash,
        schemaVersion: schemaVersion,
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
    }
    return cache;
  }

  void _invalidateCache(String coverage) => _caches.remove(coverage);
}

class _RouteGraphCoverageCache {
  int? generation;
  List<RouteGraphChunk>? chunks;
  List<RouteGraphWayIndex>? wayIndexRows;
  List<RouteGraphTrailDisplayChunk>? trailDisplayChunks;
}
