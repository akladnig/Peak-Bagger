import 'dart:convert';
import 'dart:io';

import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_store_resolver.dart';

import 'region_peak_fingerprint_support.dart';

/// Read-only observation, not a coordinated export or eligibility record.
/// All content/metadata adapters are invoked through the production resolver.
Future<Map<String, Object?>> auditMappingRuntime({
  String rootPath = mappingStoreRootPath,
  Future<({int size, String sha256})> Function(String path)? inspectFile,
}) async {
  const fileSystem = IoMappingStoreFileSystem();
  final observedText = <String, String>{};
  final store = MappingDataStoreCore(
    rootPath: rootPath,
    textReader: (path) async {
      final text = await fileSystem.readText(path);
      final previous = observedText[path];
      if (previous != null && previous != text) {
        throw MappingStoreFailure([path]);
      }
      observedText[path] = text;
      return text;
    },
  );
  final preflight = await store.preflight();
  final catalog = await store.loadCatalogFromPreflight(preflight);
  final reader = MappingStoreReadResolver.catalog(catalog: catalog);
  final paths = catalog.authorizedPaths.toList()..sort();
  final files = <Map<String, Object?>>[];
  for (final path in paths) {
    final integrity = await reader.open(
      relativePath: path,
      opener: inspectFile ?? fileSystem.inspectIntegrity,
    );
    final requiredPolygon = preflight.requiredPolygonPaths.contains(path);
    final isManifest = const {
      'region_manifest.json',
      'Polygons/manifest.json',
    }.contains(path);
    final isPeak = catalog.regions.any((region) => region.peaks.contains(path));
    final isHighway = catalog.regions.any(
      (region) => region.highways.contains(path),
    );
    final isDisplay = catalog.polygonDisplayPaths.contains(path);
    final isRuntimeDem = catalog.demSources['elvisRuntime'] == path;
    final startupCheck =
        isManifest ||
        requiredPolygon ||
        isPeak ||
        isHighway ||
        catalog.demSources.containsValue(path) ||
        catalog.naturalFeaturesCatalogPath == path ||
        catalog.tasmapCatalogPath == path;
    files.add({
      'path': path,
      'size': integrity.size,
      'sha256': integrity.sha256,
      'startupCheck': startupCheck,
      'startupContent': isManifest || requiredPolygon,
      'startupReaders': [
        if (startupCheck) 'lib/services/mapping_store_core.dart',
      ],
      'latencySensitive': startupCheck || isDisplay || isRuntimeDem,
      'liveRuntime': [
        if (isDisplay) 'lib/services/polygon_asset_repository.dart',
        if (isRuntimeDem) 'lib/services/route_elevation_sampler.dart',
      ],
      'importUpdate': [
        if (isPeak) 'lib/services/peak_region_asset_import_service.dart',
        if (isHighway) 'lib/services/route_graph_coverage_resolver.dart',
        if (catalog.naturalFeaturesCatalogPath == path)
          'lib/services/natural_feature_refresh_service.dart',
        if (catalog.tasmapCatalogPath == path)
          'lib/services/tasmap_repository.dart',
      ],
    });
  }
  final stale = await findStaleSeedableRegionFingerprints(
    readText: reader.readText,
    readBytes: (path) =>
        reader.open(relativePath: path, opener: fileSystem.readBytes),
  );
  for (final path in paths.where(
    (path) =>
        path == 'region_manifest.json' || path == 'Polygons/manifest.json',
  )) {
    await reader.open(
      relativePath: path,
      opener: (absolute) async {
        if (await fileSystem.readText(absolute) != observedText[absolute]) {
          throw MappingStoreFailure([path]);
        }
      },
    );
  }
  return {
    'auditVersion': 1,
    'observedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'root': catalog.rootPath,
    'coordinatedCapture': false,
    'validation':
        'production preflight, required polygons, raw-byte peak fingerprints; payload formats otherwise unchecked',
    'stalePeakFingerprints': stale,
    'fileCount': files.length,
    'totalBytes': files.fold<int>(
      0,
      (sum, file) => sum + (file['size']! as int),
    ),
    'files': files,
  };
}

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.isNotEmpty &&
        (arguments.length != 2 || arguments.first != '--root')) {
      throw ArgumentError(
        'Usage: dart run tool/mapping_runtime_inventory.dart [--root PATH]',
      );
    }
    final report = await auditMappingRuntime(
      rootPath: arguments.isEmpty ? mappingStoreRootPath : arguments[1],
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
    if ((report['stalePeakFingerprints']! as List).isNotEmpty) exitCode = 1;
  } on Object catch (error, stack) {
    stderr.writeln(error);
    stderr.writeln(stack);
    exitCode = 1;
  }
}
