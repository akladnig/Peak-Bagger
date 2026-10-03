import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:peak_bagger/services/manifest_priority.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';

const mappingStoreRootPath = '/Volumes/Services/Mapping';
const _regionManifestPath = 'region_manifest.json';
const _polygonManifestPath = 'Polygons/manifest.json';

typedef MappingStoreTextReader = Future<String> Function(String absolutePath);

final mappingCatalogProvider = Provider<MappingCatalog>((_) {
  throw StateError(
    'MappingCatalog is only available in the ready ProviderScope.',
  );
});

class MappingStoreFailure implements Exception {
  MappingStoreFailure(Iterable<String> paths)
    : paths = List<String>.unmodifiable((paths.toSet().toList()..sort()));

  final List<String> paths;

  @override
  String toString() => 'Mapping data store unavailable: ${paths.join(', ')}';
}

abstract interface class MappingStoreFileSystem {
  Future<String> readText(String absolutePath);
  Future<bool> fileExists(String absolutePath);
  Future<void> checkReadable(String absolutePath);
  Future<String> canonicalize(String absolutePath);
  Future<MappingStoreFileMetadata> metadata(String absolutePath);
}

class MappingStoreFileMetadata {
  const MappingStoreFileMetadata({
    required this.size,
    required this.modifiedMillis,
  });

  final int size;
  final int modifiedMillis;
}

class IoMappingStoreFileSystem implements MappingStoreFileSystem {
  const IoMappingStoreFileSystem();

  @override
  Future<String> readText(String absolutePath) =>
      File(absolutePath).readAsString();

  @override
  Future<bool> fileExists(String absolutePath) async =>
      FileSystemEntity.typeSync(absolutePath, followLinks: true) ==
      FileSystemEntityType.file;

  @override
  Future<void> checkReadable(String absolutePath) async {
    final handle = await File(absolutePath).open(mode: FileMode.read);
    await handle.close();
  }

  @override
  Future<String> canonicalize(String absolutePath) =>
      File(absolutePath).resolveSymbolicLinks();

  @override
  Future<MappingStoreFileMetadata> metadata(String absolutePath) async {
    final stat = await File(absolutePath).stat();
    return MappingStoreFileMetadata(
      size: stat.size,
      modifiedMillis: stat.modified.millisecondsSinceEpoch,
    );
  }
}

class MappingCatalogCacheSource {
  const MappingCatalogCacheSource({
    required this.path,
    required this.size,
    required this.modifiedMillis,
    required this.contentHash,
  });

  final String path;
  final int size;
  final int modifiedMillis;
  final String contentHash;
}

class MappingCatalogCache {
  MappingCatalogCache(this.directoryPath);

  static const schemaVersion = 1;
  static const _fileName = 'mapping_catalog_geometry.json';

  final String directoryPath;

  String get _filePath => p.join(directoryPath, _fileName);

  Future<Map<String, List<LatLng>>> read({
    required String manifestHash,
    required Iterable<MappingCatalogCacheSource> sources,
  }) async {
    try {
      final decoded = jsonDecode(await File(_filePath).readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != schemaVersion ||
          decoded['manifestHash'] != manifestHash ||
          decoded['entries'] is! List) {
        await _discard();
        return const {};
      }
      final expectedByPath = {
        for (final source in sources) source.path: source,
      };
      final polygons = <String, List<LatLng>>{};
      for (final entry in decoded['entries'] as List) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('Cache entry must be an object.');
        }
        final path = entry['path'];
        final source = path is String ? expectedByPath[path] : null;
        if (source == null ||
            entry['size'] != source.size ||
            entry['modifiedMillis'] != source.modifiedMillis ||
            entry['contentHash'] != source.contentHash ||
            entry['vertices'] is! List) {
          continue;
        }
        final vertices = <LatLng>[];
        for (final vertex in entry['vertices'] as List) {
          if (vertex is! List ||
              vertex.length != 2 ||
              vertex[0] is! num ||
              vertex[1] is! num) {
            throw const FormatException('Cache vertex is invalid.');
          }
          vertices.add(
            LatLng(
              (vertex[0] as num).toDouble(),
              (vertex[1] as num).toDouble(),
            ),
          );
        }
        if (vertices.length < 3) {
          throw const FormatException('Cache polygon is incomplete.');
        }
        polygons[path] = List.unmodifiable(vertices);
      }
      return Map.unmodifiable(polygons);
    } on Object {
      await _discard();
      return const {};
    }
  }

  Future<void> replace({
    required String manifestHash,
    required Iterable<MappingCatalogCacheSource> sources,
    required Map<String, List<LatLng>> polygons,
  }) async {
    final entries = [
      for (final source in sources)
        if (polygons[source.path] case final List<LatLng> vertices)
          {
            'path': source.path,
            'size': source.size,
            'modifiedMillis': source.modifiedMillis,
            'contentHash': source.contentHash,
            'vertices': [
              for (final vertex in vertices)
                [vertex.latitude, vertex.longitude],
            ],
          },
    ];
    final temporaryPath =
        '$_filePath.${DateTime.now().microsecondsSinceEpoch}.tmp';
    try {
      await Directory(directoryPath).create(recursive: true);
      await File(temporaryPath).writeAsString(
        jsonEncode({
          'schemaVersion': schemaVersion,
          'manifestHash': manifestHash,
          'entries': entries,
        }),
      );
      await File(temporaryPath).rename(_filePath);
    } on Object {
      try {
        await File(temporaryPath).delete();
      } on Object {
        // Cache cleanup must never make valid source data unavailable.
      }
    }
  }

  Future<void> _discard() async {
    try {
      await File(_filePath).delete();
    } on Object {
      // Cache cleanup must never make valid source data unavailable.
    }
  }
}

typedef MappingCatalogCacheDirectoryResolver = Future<String?> Function();

Future<String?> defaultMappingCatalogCacheDirectory() async {
  try {
    final appSupportDirectory = await getApplicationSupportDirectory();
    return p.join(appSupportDirectory.path, 'MappingCatalogCache');
  } on Object {
    return null;
  }
}

class MappingCatalogBasemap {
  MappingCatalogBasemap({
    required this.key,
    required this.name,
    required this.tileUrl,
    required this.attribution,
    required this.maxZoom,
    required Iterable<String> coveragePolygonPaths,
    required Iterable<List<LatLng>> coveragePolygons,
  }) : coveragePolygonPaths = List.unmodifiable(coveragePolygonPaths),
       coveragePolygons = List.unmodifiable([
         for (final polygon in coveragePolygons)
           List<LatLng>.unmodifiable(polygon),
       ]);

  final String key;
  final String name;
  final String tileUrl;
  final String attribution;
  final int? maxZoom;
  final List<String> coveragePolygonPaths;
  final List<List<LatLng>> coveragePolygons;

  bool isAvailableForPoint(LatLng point) =>
      coveragePolygons.isEmpty ||
      coveragePolygons.any((polygon) => polygonContainsPoint(point, polygon));
}

class MappingCatalogRegion {
  MappingCatalogRegion({
    required this.key,
    required this.name,
    required this.shortName,
    required this.priority,
    required this.showInPeakList,
    required Iterable<String> polyPaths,
    required Iterable<List<LatLng>> polygons,
    required Iterable<String> basemapKeys,
    required Iterable<String> mapSet,
    required Iterable<String> peakListFilterAliases,
    required this.routingCoverage,
    required this.seedOnStartup,
    required this.composite,
    required Iterable<String> peaks,
    required Iterable<String> highways,
    required this.fingerprint,
  }) : polyPaths = List.unmodifiable(polyPaths),
       polygons = List.unmodifiable([
         for (final polygon in polygons) List<LatLng>.unmodifiable(polygon),
       ]),
       basemapKeys = List.unmodifiable(basemapKeys),
       mapSet = List.unmodifiable(mapSet),
       peakListFilterAliases = List.unmodifiable(peakListFilterAliases),
       peaks = List.unmodifiable(peaks),
       highways = List.unmodifiable(highways);

  final String key;
  final String name;
  final String shortName;
  final ManifestPriority priority;
  final bool showInPeakList;
  final List<String> polyPaths;
  final List<List<LatLng>> polygons;
  final List<String> basemapKeys;
  final List<String> mapSet;
  final List<String> peakListFilterAliases;
  final String? routingCoverage;
  final bool seedOnStartup;
  final bool composite;
  final List<String> peaks;
  final List<String> highways;
  final String? fingerprint;

  bool containsPoint(LatLng point) =>
      polygons.any((polygon) => polygonContainsPoint(point, polygon));
}

class MappingCatalog {
  MappingCatalog({
    required this.rootPath,
    required Iterable<MappingCatalogRegion> regions,
    required Iterable<MappingCatalogBasemap> basemaps,
    required this.tasmapCatalogPath,
    required this.naturalFeaturesCatalogPath,
    required Map<String, String> demSources,
    required Map<String, List<String>> routingCoverageRegionKeys,
  }) : regions = List.unmodifiable(regions),
       basemaps = List.unmodifiable(basemaps),
       demSources = Map.unmodifiable(demSources),
       routingCoverageRegionKeys = Map.unmodifiable({
         for (final entry in routingCoverageRegionKeys.entries)
           entry.key: List<String>.unmodifiable(entry.value),
       }),
       _regionsByKey = {for (final region in regions) region.key: region},
       _basemapsByKey = {for (final basemap in basemaps) basemap.key: basemap};

  final String rootPath;
  final List<MappingCatalogRegion> regions;
  final List<MappingCatalogBasemap> basemaps;
  final String tasmapCatalogPath;
  final String naturalFeaturesCatalogPath;
  final Map<String, String> demSources;
  final Map<String, List<String>> routingCoverageRegionKeys;
  final Map<String, MappingCatalogRegion> _regionsByKey;
  final Map<String, MappingCatalogBasemap> _basemapsByKey;

  MappingCatalogRegion? regionByKey(String key) => _regionsByKey[key];
  MappingCatalogBasemap? basemapByKey(String key) => _basemapsByKey[key];

  MappingCatalogRegion? regionByDisplayName(String? displayName) {
    final trimmed = displayName?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    for (final region in regions) {
      if (region.name.trim() == trimmed) {
        return region;
      }
    }
    return null;
  }

  String? regionKeyByDisplayName(String? displayName) =>
      regionByDisplayName(displayName)?.key;

  String? peakListFilterRegionKey(String? regionKey) {
    final normalized = regionKey?.trim().toLowerCase();
    if (normalized == null) {
      return null;
    }
    if (normalized.isEmpty) {
      return 'tasmania';
    }
    for (final region in regions) {
      if (region.peakListFilterAliases.any(
        (alias) => alias.trim().toLowerCase() == normalized,
      )) {
        return region.key;
      }
    }
    return normalized;
  }

  List<MappingCatalogRegion> peakListRegions() =>
      List.unmodifiable(regions.where((region) => region.showInPeakList));

  MappingCatalogRegion? regionForPoint(LatLng point) {
    final matches = regionsForPointByPriority(point);
    return matches.isEmpty ? null : matches.first;
  }

  String? regionKeyForPoint(LatLng point) => regionForPoint(point)?.key;

  List<MappingCatalogRegion> regionsForPointByPriority(LatLng point) {
    final matches =
        [
          for (final region in regions)
            if (region.containsPoint(point)) region,
        ]..sort((left, right) {
          final priority = right.priority.compareTo(left.priority);
          return priority == 0 ? left.key.compareTo(right.key) : priority;
        });
    return List.unmodifiable(matches);
  }

  String? routingCoverageForPoint(LatLng point) {
    final matches = regionsForPointByPriority(point)
        .where((region) => !region.composite && region.routingCoverage != null)
        .toList(growable: false);
    if (matches.isEmpty) {
      return null;
    }
    final highestPriority = matches.first.priority;
    final coverages = {
      for (final region in matches)
        if (region.priority.compareTo(highestPriority) == 0)
          region.routingCoverage!,
    };
    return coverages.length == 1 ? coverages.single : null;
  }
}

class MappingStorePreflight {
  const MappingStorePreflight._({
    required this.root,
    required this._manifest,
    required this.requiredPolygonPaths,
  });

  final String root;
  final _MappingStoreManifest _manifest;
  final Set<String> requiredPolygonPaths;
}

class MappingDataStore {
  MappingDataStore({
    this.rootPath = mappingStoreRootPath,
    MappingStoreFileSystem? fileSystem,
    this.textReader,
    this.cache,
    MappingCatalogCacheDirectoryResolver? cacheDirectoryResolver,
  }) : _fileSystem = fileSystem ?? const IoMappingStoreFileSystem(),
       _cacheDirectoryResolver =
           cacheDirectoryResolver ?? defaultMappingCatalogCacheDirectory;

  final String rootPath;
  final MappingStoreFileSystem _fileSystem;
  final MappingStoreTextReader? textReader;
  final MappingCatalogCache? cache;
  final MappingCatalogCacheDirectoryResolver _cacheDirectoryResolver;

  Future<MappingStorePreflight> preflight() async {
    final failures = <String>[];
    final root = await _canonicalRoot(failures);
    final regionJson = await _readManifest(
      root ?? rootPath,
      _regionManifestPath,
      failures,
    );
    final polygonJson = await _readManifest(
      root ?? rootPath,
      _polygonManifestPath,
      failures,
    );
    if (root == null || regionJson == null || polygonJson == null) {
      throw MappingStoreFailure(failures);
    }

    final parsed = _parseRegionManifest(regionJson, failures);
    final polygonPaths = _parsePolygonManifest(polygonJson, failures);
    if (parsed == null || polygonPaths == null) {
      throw MappingStoreFailure(failures);
    }

    final requiredPolygonPaths = <String>{
      for (final region in parsed.regions) ...region.polyPaths,
      for (final basemap in parsed.basemapsByKey.values)
        ...basemap.coveragePolygonPaths,
    };
    for (final path in requiredPolygonPaths) {
      if (!polygonPaths.contains(path)) {
        failures.add('$_polygonManifestPath#/${_escapePointer(path)}');
      }
    }

    final references = <String>{
      parsed.tasmapCatalogPath,
      parsed.naturalFeaturesCatalogPath,
      ...parsed.demSources.values,
      ...requiredPolygonPaths,
      for (final region in parsed.regions) ...region.peaks,
      for (final region in parsed.regions) ...region.highways,
    };
    for (final path in references) {
      await _checkReferencedPath(root, path, failures);
    }
    if (failures.isNotEmpty) {
      throw MappingStoreFailure(failures);
    }
    return MappingStorePreflight._(
      root: root,
      manifest: parsed,
      requiredPolygonPaths: requiredPolygonPaths,
    );
  }

  Future<String> _readText(String absolutePath) =>
      textReader?.call(absolutePath) ?? _fileSystem.readText(absolutePath);

  Future<MappingCatalog> loadCatalog() async {
    final preflightResult = await preflight();
    return loadCatalogFromPreflight(preflightResult);
  }

  Future<MappingCatalog> loadCatalogFromPreflight(
    MappingStorePreflight preflightResult,
  ) async {
    final failures = <String>[];
    final polygonTextByPath = <String, String>{};
    final cacheSources = <MappingCatalogCacheSource>[];
    for (final path in preflightResult.requiredPolygonPaths) {
      final target = await _resolveReferencedPath(
        preflightResult.root,
        path,
        failures,
      );
      if (target == null) {
        continue;
      }
      try {
        final contents = await _readText(target);
        final metadata = await _fileSystem.metadata(target);
        polygonTextByPath[path] = contents;
        cacheSources.add(
          MappingCatalogCacheSource(
            path: path,
            size: metadata.size,
            modifiedMillis: metadata.modifiedMillis,
            contentHash: _sha256(contents),
          ),
        );
      } on FileSystemException {
        failures.add(path);
      }
    }
    if (failures.isNotEmpty) {
      throw MappingStoreFailure(failures);
    }
    final manifestHash = await _manifestHash(preflightResult.root, failures);
    if (manifestHash == null) {
      throw MappingStoreFailure(failures);
    }
    final resolvedCache = cache ?? await _createDefaultCache();
    final polygonsByPath = <String, List<LatLng>>{};
    if (resolvedCache != null) {
      try {
        polygonsByPath.addAll(
          await resolvedCache.read(
            manifestHash: manifestHash,
            sources: cacheSources,
          ),
        );
      } on Object {
        // Cache failure must not make valid store geometry unavailable.
      }
    }
    for (final entry in polygonTextByPath.entries) {
      if (polygonsByPath.containsKey(entry.key)) {
        continue;
      }
      try {
        final result = parsePolygonText(entry.value);
        if (!result.isSuccess) {
          failures.add(entry.key);
          continue;
        }
        polygonsByPath[entry.key] = result.polygon!.vertices;
      } on FormatException {
        failures.add(entry.key);
      }
    }
    if (failures.isNotEmpty) {
      throw MappingStoreFailure(failures);
    }
    if (resolvedCache != null) {
      try {
        await resolvedCache.replace(
          manifestHash: manifestHash,
          sources: cacheSources,
          polygons: polygonsByPath,
        );
      } on Object {
        // Cache failure must not make valid store geometry unavailable.
      }
    }

    final basemaps = [
      for (final basemap in preflightResult._manifest.basemapsByKey.values)
        MappingCatalogBasemap(
          key: basemap.key,
          name: basemap.name,
          tileUrl: basemap.tileUrl,
          attribution: basemap.attribution,
          maxZoom: basemap.maxZoom,
          coveragePolygonPaths: List.unmodifiable(basemap.coveragePolygonPaths),
          coveragePolygons: List.unmodifiable([
            for (final path in basemap.coveragePolygonPaths)
              polygonsByPath[path]!,
          ]),
        ),
      MappingCatalogBasemap(
        key: 'localTopo',
        name: 'Local Topo',
        tileUrl: localTopoPlaceholderTileUrl,
        attribution: 'OpenStreetMap contributors and State of Tasmania',
        maxZoom: 18,
        coveragePolygonPaths: [],
        coveragePolygons: [],
      ),
    ];
    final regions = [
      for (final region in preflightResult._manifest.regions)
        MappingCatalogRegion(
          key: region.key,
          name: region.name,
          shortName: region.shortName,
          priority: region.priority,
          showInPeakList: region.showInPeakList,
          polyPaths: List.unmodifiable(region.polyPaths),
          polygons: List.unmodifiable([
            for (final path in region.polyPaths) polygonsByPath[path]!,
          ]),
          basemapKeys: List.unmodifiable(region.basemapKeys),
          mapSet: List.unmodifiable(region.mapSet),
          peakListFilterAliases: List.unmodifiable(
            region.peakListFilterAliases,
          ),
          routingCoverage: region.routingCoverage,
          seedOnStartup: region.seedOnStartup,
          composite: region.composite,
          peaks: List.unmodifiable(region.peaks),
          highways: List.unmodifiable(region.highways),
          fingerprint: region.fingerprint,
        ),
    ];
    return MappingCatalog(
      rootPath: preflightResult.root,
      regions: regions,
      basemaps: basemaps,
      tasmapCatalogPath: preflightResult._manifest.tasmapCatalogPath,
      naturalFeaturesCatalogPath:
          preflightResult._manifest.naturalFeaturesCatalogPath,
      demSources: preflightResult._manifest.demSources,
      routingCoverageRegionKeys:
          preflightResult._manifest.routingCoverageRegionKeys,
    );
  }

  Future<MappingCatalogCache?> _createDefaultCache() async {
    try {
      final directory = await _cacheDirectoryResolver();
      return directory == null ? null : MappingCatalogCache(directory);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _manifestHash(String root, List<String> failures) async {
    late final String regionManifest;
    try {
      regionManifest = await _readText(p.join(root, _regionManifestPath));
    } on Object {
      failures.add(_regionManifestPath);
      return null;
    }
    try {
      final polygonManifest = await _readText(
        p.join(root, _polygonManifestPath),
      );
      return _sha256('$regionManifest\u0000$polygonManifest');
    } on Object {
      failures.add(_polygonManifestPath);
      return null;
    }
  }

  Future<String?> _canonicalRoot(List<String> failures) async {
    try {
      return await _fileSystem.canonicalize(rootPath);
    } on Object {
      failures.add('.');
      return null;
    }
  }

  Future<Object?> _readManifest(
    String root,
    String path,
    List<String> failures,
  ) async {
    try {
      return jsonDecode(await _readText(p.join(root, path)));
    } on FormatException {
      failures.add(path);
    } on Object {
      failures.add(path);
    }
    return null;
  }

  Future<void> _checkReferencedPath(
    String root,
    String path,
    List<String> failures,
  ) async {
    final target = await _resolveReferencedPath(root, path, failures);
    if (target == null) {
      return;
    }
    try {
      await _fileSystem.checkReadable(target);
    } on Object {
      failures.add(path);
    }
  }

  Future<String?> _resolveReferencedPath(
    String root,
    String path,
    List<String> failures,
  ) async {
    final candidate = p.join(root, path);
    try {
      if (!await _fileSystem.fileExists(candidate)) {
        failures.add(path);
        return null;
      }
      final canonicalTarget = await _fileSystem.canonicalize(candidate);
      if (!p.isWithin(root, canonicalTarget)) {
        failures.add(path);
        return null;
      }
      return canonicalTarget;
    } on Object {
      failures.add(path);
      return null;
    }
  }
}

_MappingStoreManifest? _parseRegionManifest(
  Object value,
  List<String> failures,
) {
  if (value is! Map<String, dynamic>) {
    failures.add(_regionManifestPath);
    return null;
  }
  final root = value;
  final tasmap = _requiredObject(root, 'tasmap', '/tasmap', failures);
  final naturalFeatures = _requiredObject(
    root,
    'naturalFeatures',
    '/naturalFeatures',
    failures,
  );
  final demSources = _requiredObject(
    root,
    'demSources',
    '/demSources',
    failures,
  );
  final routingCoverages = _requiredObject(
    root,
    'routingCoverages',
    '/routingCoverages',
    failures,
  );
  if (tasmap == null ||
      naturalFeatures == null ||
      demSources == null ||
      routingCoverages == null) {
    return null;
  }
  final tasmapCatalog = _requiredPath(
    tasmap,
    'catalog',
    '/tasmap/catalog',
    failures,
  );
  final naturalFeaturesCatalog = _requiredPath(
    naturalFeatures,
    'catalog',
    '/naturalFeatures/catalog',
    failures,
  );
  final parsedDemSources = <String, String>{};
  _rejectUnknownKeys(tasmap, const {'catalog'}, '/tasmap', failures);
  _rejectUnknownKeys(
    naturalFeatures,
    const {'catalog'},
    '/naturalFeatures',
    failures,
  );
  for (final key in const ['elvisRuntime', 'thelist25m', 'copernicus']) {
    final path = _requiredPath(demSources, key, '/demSources/$key', failures);
    if (path != null) {
      parsedDemSources[key] = path;
    }
  }
  for (final key in demSources.keys) {
    if (!const {'elvisRuntime', 'thelist25m', 'copernicus'}.contains(key)) {
      _error('/demSources/${_escapePointer(key)}', failures);
    }
  }

  final coverageNames = <String, String>{};
  for (final key in const ['tasmania', 'northeast-alps']) {
    final coverage = routingCoverages[key];
    if (coverage is! Map<String, dynamic> ||
        coverage['displayName'] is! String ||
        (coverage['displayName'] as String).trim().isEmpty) {
      _error('/routingCoverages/$key', failures);
      continue;
    }
    coverageNames[key] = (coverage['displayName'] as String).trim();
    _rejectUnknownKeys(
      coverage,
      const {'displayName'},
      '/routingCoverages/$key',
      failures,
    );
  }
  for (final key in routingCoverages.keys) {
    if (!coverageNames.containsKey(key)) {
      _error('/routingCoverages/${_escapePointer(key)}', failures);
    }
  }

  final regions = <_ParsedRegion>[];
  final basemapsByKey = <String, _ParsedBasemap>{};
  final basemapPointers = <String, List<String>>{};
  for (final entry in root.entries) {
    if (const {
      'tasmap',
      'naturalFeatures',
      'demSources',
      'routingCoverages',
    }.contains(entry.key)) {
      continue;
    }
    final region = _parseRegion(entry.key, entry.value, failures);
    if (region == null) {
      continue;
    }
    regions.add(region);
    for (final basemap in region.maps) {
      final pointers = basemapPointers.putIfAbsent(basemap.key, () => []);
      pointers.add(basemap.pointer);
      final existing = basemapsByKey[basemap.key];
      if (existing != null && !existing.sameDescriptor(basemap)) {
        for (final pointer in pointers) {
          _error(pointer, failures);
        }
      } else {
        basemapsByKey.putIfAbsent(basemap.key, () => basemap);
      }
    }
  }
  final coverageRegions = <String, List<String>>{
    for (final key in coverageNames.keys) key: [],
  };
  for (final region in regions) {
    final coverage = region.routingCoverage;
    if (coverage != null) {
      if (!coverageRegions.containsKey(coverage)) {
        _error('/${_escapePointer(region.key)}/routingCoverage', failures);
      } else {
        coverageRegions[coverage]!.add(region.key);
      }
    }
  }
  const expectedCoverageMembers = {
    'tasmania': ['tasmania'],
    'northeast-alps': ['fvg', 'veneto', 'slovenia'],
  };
  for (final entry in expectedCoverageMembers.entries) {
    final actual = (coverageRegions[entry.key] ?? <String>[])..sort();
    final expected = [...entry.value]..sort();
    if (!_sameStrings(actual, expected)) {
      _error('/routingCoverages/${entry.key}', failures);
    }
  }
  if (tasmapCatalog != 'Maps/tasmap50k.csv') {
    _error('/tasmap/catalog', failures);
  }
  if (naturalFeaturesCatalog != 'Features/tasmania_natural_features.json') {
    _error('/naturalFeatures/catalog', failures);
  }
  const expectedDemSources = {
    'elvisRuntime': 'DEM/Elvis/elvis_runtime_10m.tif',
    'thelist25m': 'DEM/tasmania_dem_25m.tif',
    'copernicus': 'DEM/cop30_hh.tif',
  };
  for (final entry in expectedDemSources.entries) {
    if (parsedDemSources[entry.key] != entry.value) {
      _error('/demSources/${entry.key}', failures);
    }
  }
  if (tasmapCatalog == null ||
      naturalFeaturesCatalog == null ||
      parsedDemSources.length != expectedDemSources.length) {
    return null;
  }
  return _MappingStoreManifest(
    tasmapCatalogPath: tasmapCatalog,
    naturalFeaturesCatalogPath: naturalFeaturesCatalog,
    demSources: parsedDemSources,
    regions: List.unmodifiable(regions),
    basemapsByKey: Map.unmodifiable(basemapsByKey),
    routingCoverageRegionKeys: Map.unmodifiable({
      for (final entry in coverageRegions.entries)
        entry.key: List<String>.unmodifiable(entry.value),
    }),
  );
}

Set<String>? _parsePolygonManifest(Object value, List<String> failures) {
  if (value is! List) {
    failures.add(_polygonManifestPath);
    return null;
  }
  final paths = <String>{};
  for (var index = 0; index < value.length; index++) {
    final path = value[index];
    if (path is! String || !_isSafePath(path) || !path.endsWith('.poly')) {
      _error('/$index', failures, manifestPath: _polygonManifestPath);
      continue;
    }
    if (!paths.add(path)) {
      _error('/$index', failures, manifestPath: _polygonManifestPath);
    }
  }
  return paths;
}

_ParsedRegion? _parseRegion(String key, Object? value, List<String> failures) {
  final pointer = '/${_escapePointer(key)}';
  if (value is! Map<String, dynamic>) {
    _error(pointer, failures);
    return null;
  }
  _rejectUnknownKeys(value, _regionFields, pointer, failures);
  final name = _requiredString(value, 'name', '$pointer/name', failures);
  final shortName = _requiredString(
    value,
    'shortName',
    '$pointer/shortName',
    failures,
  );
  final priorityRaw = _requiredString(
    value,
    'priority',
    '$pointer/priority',
    failures,
  );
  ManifestPriority? priority;
  if (priorityRaw != null) {
    try {
      priority = ManifestPriority.parse(priorityRaw, regionKey: key);
    } on FormatException {
      _error('$pointer/priority', failures);
    }
  }
  final showInPeakList = _parseBoolean(
    value['showInPeakList'],
    '$pointer/showInPeakList',
    failures,
  );
  final polyPaths = _pathList(value['poly'], '$pointer/poly', failures);
  final mapSet = _stringList(value['mapSet'], '$pointer/mapSet', failures);
  final maps = _parseMaps(value['maps'], '$pointer/maps', failures);
  final aliases = value.containsKey('peakListFilterAliases')
      ? _stringList(
          value['peakListFilterAliases'],
          '$pointer/peakListFilterAliases',
          failures,
        )
      : const <String>[];
  final iso31661 = value['ISO_3166-1'];
  if (iso31661 != null && (iso31661 is! String || iso31661.trim().isEmpty)) {
    _error('$pointer/ISO_3166-1', failures);
  }
  final iso31662 = value.containsKey('ISO_3166-2')
      ? _stringList(value['ISO_3166-2'], '$pointer/ISO_3166-2', failures)
      : const <String>[];
  final compositeValue = value['composite'];
  if (compositeValue != null && compositeValue is! bool) {
    _error('$pointer/composite', failures);
  }
  final seedOnStartupValue = value['seedOnStartup'];
  if (seedOnStartupValue != null && seedOnStartupValue is! bool) {
    _error('$pointer/seedOnStartup', failures);
  }
  final composite = compositeValue == true;
  final seedOnStartup = seedOnStartupValue != false;
  final routingCoverage = value['routingCoverage'];
  if (routingCoverage != null &&
      (routingCoverage is! String || routingCoverage.trim().isEmpty)) {
    _error('$pointer/routingCoverage', failures);
  }
  final peaks = value.containsKey('peaks')
      ? _pathList(value['peaks'], '$pointer/peaks', failures)
      : const <String>[];
  final highways = value.containsKey('highways')
      ? _pathList(value['highways'], '$pointer/highways', failures)
      : const <String>[];
  final fingerprint = value['fingerprint'];
  if (fingerprint != null &&
      (fingerprint is! String || fingerprint.trim().isEmpty)) {
    _error('$pointer/fingerprint', failures);
  }
  if (composite &&
      (value.containsKey('fingerprint') ||
          value.containsKey('routingCoverage') ||
          value.containsKey('highways') ||
          value.containsKey('seedOnStartup'))) {
    _error(pointer, failures);
  }
  if (!composite &&
      seedOnStartup &&
      (fingerprint is! String ||
          fingerprint.trim().isEmpty ||
          (peaks?.isEmpty ?? true))) {
    _error(pointer, failures);
  }
  if (!composite &&
      !seedOnStartup &&
      routingCoverage == null &&
      (value.containsKey('fingerprint') ||
          value.containsKey('peaks') ||
          value.containsKey('highways'))) {
    _error(pointer, failures);
  }
  if (routingCoverage != null && (highways?.isEmpty ?? true)) {
    _error('$pointer/highways', failures);
  }
  if (routingCoverage == null && value.containsKey('highways')) {
    _error('$pointer/highways', failures);
  }
  if (key == 'slovenia' &&
      (highways == null ||
          highways.length != 1 ||
          highways.single != 'Highways/slovenia-highways.json')) {
    _error('$pointer/highways', failures);
  }
  final mapKeys = <String>[];
  final seenMapKeys = <String>{};
  for (final map in maps ?? const <_ParsedBasemap>[]) {
    if (!seenMapKeys.add(map.key)) {
      _error(map.pointer, failures);
    }
    mapKeys.add(map.key);
  }
  final seenMapSet = <String>{};
  for (var index = 0; index < (mapSet?.length ?? 0); index++) {
    final mapKey = mapSet![index];
    if (!seenMapSet.add(mapKey) || !seenMapKeys.contains(mapKey)) {
      _error('$pointer/mapSet/$index', failures);
    }
  }
  if (name == null ||
      shortName == null ||
      priority == null ||
      showInPeakList == null ||
      polyPaths == null ||
      mapSet == null ||
      maps == null ||
      aliases == null ||
      iso31662 == null ||
      peaks == null ||
      highways == null) {
    return null;
  }
  return _ParsedRegion(
    key: key,
    name: name,
    shortName: shortName,
    priority: priority,
    showInPeakList: showInPeakList,
    polyPaths: polyPaths,
    maps: maps,
    basemapKeys: mapKeys,
    mapSet: mapSet,
    peakListFilterAliases: aliases,
    routingCoverage: routingCoverage is String ? routingCoverage : null,
    seedOnStartup: seedOnStartup,
    composite: composite,
    peaks: peaks,
    highways: highways,
    fingerprint: fingerprint is String ? fingerprint : null,
  );
}

List<_ParsedBasemap>? _parseMaps(
  Object? value,
  String pointer,
  List<String> failures,
) {
  if (value is! List) {
    _error(pointer, failures);
    return null;
  }
  final maps = <_ParsedBasemap>[];
  for (var index = 0; index < value.length; index++) {
    final entryPointer = '$pointer/$index';
    final map = value[index];
    if (map is! Map<String, dynamic>) {
      _error(entryPointer, failures);
      continue;
    }
    _rejectUnknownKeys(
      map,
      const {
        'key',
        'name',
        'tileUrl',
        'attribution',
        'maxZoom',
        'coveragePoly',
      },
      entryPointer,
      failures,
    );
    final key = _requiredString(map, 'key', '$entryPointer/key', failures);
    final name = _requiredString(map, 'name', '$entryPointer/name', failures);
    final tileUrl = _requiredString(
      map,
      'tileUrl',
      '$entryPointer/tileUrl',
      failures,
    );
    final attribution = _requiredString(
      map,
      'attribution',
      '$entryPointer/attribution',
      failures,
    );
    final maxZoom = map['maxZoom'];
    if (maxZoom != null && maxZoom is! int) {
      _error('$entryPointer/maxZoom', failures);
    }
    final coverage = map.containsKey('coveragePoly')
        ? _pathList(map['coveragePoly'], '$entryPointer/coveragePoly', failures)
        : const <String>[];
    if (key == null ||
        name == null ||
        tileUrl == null ||
        attribution == null ||
        coverage == null ||
        (maxZoom != null && maxZoom is! int)) {
      continue;
    }
    if (!_manifestBasemapKeys.contains(key)) {
      _error('$entryPointer/key', failures);
    }
    maps.add(
      _ParsedBasemap(
        key: key,
        name: name,
        tileUrl: tileUrl,
        attribution: attribution,
        maxZoom: maxZoom,
        coveragePolygonPaths: coverage,
        pointer: entryPointer,
      ),
    );
  }
  return maps;
}

enum Basemap {
  tasmapTopo,
  tasmap50k,
  tasmap25k,
  tracestrack,
  openstreetmap,
  mapyCz,
  nswImagery,
  nswBasemap,
  nswTopo,
  sloveniaTopo,
  fvgTopo,
  localTopo,
}

const _manifestBasemapKeys = <String>{
  'tasmapTopo',
  'tasmap50k',
  'tasmap25k',
  'tracestrack',
  'openstreetmap',
  'mapyCz',
  'nswImagery',
  'nswBasemap',
  'nswTopo',
  'sloveniaTopo',
  'fvgTopo',
};

const _regionFields = <String>{
  'priority',
  'name',
  'shortName',
  'showInPeakList',
  'routingCoverage',
  'fingerprint',
  'ISO_3166-1',
  'ISO_3166-2',
  'poly',
  'peaks',
  'highways',
  'maps',
  'mapSet',
  'peakListFilterAliases',
  'composite',
  'seedOnStartup',
};

Map<String, dynamic>? _requiredObject(
  Map<String, dynamic> value,
  String key,
  String pointer,
  List<String> failures,
) {
  final candidate = value[key];
  if (candidate is! Map<String, dynamic>) {
    _error(pointer, failures);
    return null;
  }
  return candidate;
}

void _rejectUnknownKeys(
  Map<String, dynamic> value,
  Set<String> allowedKeys,
  String pointer,
  List<String> failures,
) {
  for (final key in value.keys) {
    if (!allowedKeys.contains(key)) {
      _error('$pointer/${_escapePointer(key)}', failures);
    }
  }
}

String? _requiredString(
  Map<String, dynamic> value,
  String key,
  String pointer,
  List<String> failures,
) {
  final candidate = value[key];
  if (candidate is! String || candidate.trim().isEmpty) {
    _error(pointer, failures);
    return null;
  }
  return candidate.trim();
}

String? _requiredPath(
  Map<String, dynamic> value,
  String key,
  String pointer,
  List<String> failures,
) {
  final path = _requiredString(value, key, pointer, failures);
  if (path != null && !_isSafePath(path)) {
    _error(pointer, failures);
    return null;
  }
  return path;
}

List<String>? _pathList(Object? value, String pointer, List<String> failures) {
  if (value is! List) {
    _error(pointer, failures);
    return null;
  }
  final paths = <String>[];
  for (var index = 0; index < value.length; index++) {
    final path = value[index];
    if (path is! String || path.trim().isEmpty || !_isSafePath(path.trim())) {
      _error('$pointer/$index', failures);
      continue;
    }
    paths.add(path.trim());
  }
  return paths;
}

List<String>? _stringList(
  Object? value,
  String pointer,
  List<String> failures,
) {
  if (value is! List) {
    _error(pointer, failures);
    return null;
  }
  final strings = <String>[];
  for (var index = 0; index < value.length; index++) {
    final candidate = value[index];
    if (candidate is! String || candidate.trim().isEmpty) {
      _error('$pointer/$index', failures);
      continue;
    }
    strings.add(candidate.trim());
  }
  return strings;
}

bool? _parseBoolean(Object? value, String pointer, List<String> failures) {
  return switch (value) {
    true || 'true' => true,
    false || 'false' => false,
    _ => () {
      _error(pointer, failures);
      return null;
    }(),
  };
}

bool _isSafePath(String value) {
  if (value.isEmpty || p.isAbsolute(value) || value.contains(r'\')) {
    return false;
  }
  final segments = value.split('/');
  return segments.every(
    (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
  );
}

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();

void _error(
  String pointer,
  List<String> failures, {
  String manifestPath = _regionManifestPath,
}) {
  failures.add('$manifestPath#$pointer');
}

String _escapePointer(String value) =>
    value.replaceAll('~', '~0').replaceAll('/', '~1');

bool _sameStrings(List<String> left, List<String> right) =>
    left.length == right.length &&
    List.generate(
      left.length,
      (index) => left[index] == right[index],
    ).every((same) => same);

class _MappingStoreManifest {
  const _MappingStoreManifest({
    required this.tasmapCatalogPath,
    required this.naturalFeaturesCatalogPath,
    required this.demSources,
    required this.regions,
    required this.basemapsByKey,
    required this.routingCoverageRegionKeys,
  });

  final String tasmapCatalogPath;
  final String naturalFeaturesCatalogPath;
  final Map<String, String> demSources;
  final List<_ParsedRegion> regions;
  final Map<String, _ParsedBasemap> basemapsByKey;
  final Map<String, List<String>> routingCoverageRegionKeys;
}

class _ParsedRegion {
  const _ParsedRegion({
    required this.key,
    required this.name,
    required this.shortName,
    required this.priority,
    required this.showInPeakList,
    required this.polyPaths,
    required this.maps,
    required this.basemapKeys,
    required this.mapSet,
    required this.peakListFilterAliases,
    required this.routingCoverage,
    required this.seedOnStartup,
    required this.composite,
    required this.peaks,
    required this.highways,
    required this.fingerprint,
  });

  final String key;
  final String name;
  final String shortName;
  final ManifestPriority priority;
  final bool showInPeakList;
  final List<String> polyPaths;
  final List<_ParsedBasemap> maps;
  final List<String> basemapKeys;
  final List<String> mapSet;
  final List<String> peakListFilterAliases;
  final String? routingCoverage;
  final bool seedOnStartup;
  final bool composite;
  final List<String> peaks;
  final List<String> highways;
  final String? fingerprint;
}

class _ParsedBasemap {
  const _ParsedBasemap({
    required this.key,
    required this.name,
    required this.tileUrl,
    required this.attribution,
    required this.maxZoom,
    required this.coveragePolygonPaths,
    required this.pointer,
  });

  final String key;
  final String name;
  final String tileUrl;
  final String attribution;
  final int? maxZoom;
  final List<String> coveragePolygonPaths;
  final String pointer;

  bool sameDescriptor(_ParsedBasemap other) =>
      key == other.key &&
      name == other.name &&
      tileUrl == other.tileUrl &&
      attribution == other.attribution &&
      maxZoom == other.maxZoom &&
      _sameStrings(coveragePolygonPaths, other.coveragePolygonPaths);
}
