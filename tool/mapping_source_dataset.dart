import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_store_resolver.dart';
import 'package:peak_bagger/services/mapping_store_file_access.dart';
import 'package:peak_bagger/services/peak_source_parser.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';
import 'package:peak_bagger/services/csv_importer.dart';
import 'package:peak_bagger/services/natural_feature_refresh_service.dart';
import 'package:peak_bagger/services/route_graph_coverage_resolver.dart';
import 'package:peak_bagger/services/route_graph_import_service.dart';
import 'package:peak_bagger/services/mapping_tool_resolver.dart';
import 'mapping_source_io.dart';
import 'mapping_source_dem.dart';
import 'region_peak_fingerprint_support.dart';

const sourceValidationProfile = 'mapping-runtime-v1';

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length != 1 ||
        !const {
          'capture',
          'inspect',
          'validate',
          'capabilities',
        }.contains(arguments.single)) {
      throw ArgumentError(
        'Usage: mapping_source_dataset capture|inspect|validate (JSON request on stdin)',
      );
    }
    final request = Map<String, Object?>.from(
      jsonDecode(await stdin.transform(utf8.decoder).join()) as Map,
    );
    final root = request['root'] as String;
    final generation = request['generationId'] as String? ?? '';
    final result = switch (arguments.single) {
      'capture' => await captureMappingSource(
        rootPath: root,
        destination: request['destination'] as String,
        generationId: generation,
      ),
      'inspect' => await inspectMappingSource(
        rootPath: root,
        generationId: generation,
        allowSourceLinks: request['allowSourceLinks'] == true,
        onProgress: stderr.writeln,
      ),
      'capabilities' => await sourcePublisherCapabilities(root),
      _ => await validateMappingSource(
        rootPath: root,
        integrity: Map<String, Object?>.from(request['integrity'] as Map),
        validateDem: validateSourceDem,
      ),
    };
    stdout.writeln(jsonEncode(result));
  } on Object catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exitCode = 1;
  }
}

Future<Map<String, Object?>> sourcePublisherCapabilities(String root) async {
  final tools = <String, Object?>{};
  for (final id in [
    'update-region-peak-fingerprints',
    'download-tasmania-thelist-dem',
    'elvis-dem-runtime',
    'elvis-dem-topo',
    'mapping-maintenance-promote',
  ]) {
    final tool = await MappingToolResolver.namedTool(
      toolId: id,
      repositoryRoot: '.',
      rootPath: root,
    );
    tools[id] = [
      for (final output in tool.contract.outputs.values)
        if (tool.contract.permittedWrites.contains(output.id))
          [
            output.path,
            tool.contract.overrides.values.any(
                  (o) => o.output && o.id == output.id,
                )
                ? 'override-file'
                : output.kind.name,
          ],
    ];
  }
  return {'tools': tools};
}

Future<MappingCatalog> _catalog(String root) async {
  final store = MappingDataStoreCore(rootPath: root);
  return store.loadCatalogFromPreflight(await store.preflight());
}

Future<Map<String, Object?>> captureMappingSource({
  required String rootPath,
  required String destination,
  required String generationId,
}) async {
  final catalog = await _catalog(rootPath);
  final reader = MappingStoreReadResolver.catalog(catalog: catalog);
  final io = MappingSourceIo();
  for (final path in catalog.authorizedPaths.toList()..sort()) {
    await reader.open(
      relativePath: path,
      opener: (source) =>
          io.copy(source, p.join(destination, path), sourceRoot: rootPath),
    );
  }
  return inspectMappingSource(
    rootPath: destination,
    generationId: generationId,
  );
}

Future<Map<String, Object?>> inspectMappingSource({
  required String rootPath,
  required String generationId,
  bool allowSourceLinks = false,
  void Function(String)? onProgress,
}) async {
  final catalog = await _catalog(rootPath);
  final reader = MappingStoreReadResolver.catalog(catalog: catalog);
  const fileSystem = IoMappingStoreFileSystem();
  final files = <Map<String, Object?>>[];
  for (final path in catalog.authorizedPaths.toList()..sort()) {
    if (!allowSourceLinks) {
      await MappingSourceIo().rejectLinks(p.join(rootPath, path));
    }
    final observed = await reader.open(
      relativePath: path,
      opener: fileSystem.inspectIntegrity,
    );
    files.add({'path': path, 'size': observed.size, 'sha256': observed.sha256});
    onProgress?.call('Source integrity progress: $path bytes=${observed.size}');
  }
  return {
    'kind': 'mapping-integrity',
    'schemaVersion': 1,
    'generationId': generationId,
    'files': files,
  };
}

Future<Map<String, Object?>> validateMappingSource({
  required String rootPath,
  required Map<String, Object?> integrity,
  required Future<Map<String, Object?>> Function(String) validateDem,
}) async {
  final catalog = await _catalog(rootPath);
  final reader = MappingStoreReadResolver.catalog(catalog: catalog);
  final observed = await inspectMappingSource(
    rootPath: rootPath,
    generationId: integrity['generationId'] as String,
  );
  if (jsonEncode(observed) != jsonEncode(integrity)) {
    throw const FormatException(
      'Integrity inventory/path set differs from captured bytes.',
    );
  }
  final checks = <Map<String, String>>[];
  final diagnostics = <String>[];
  void passed(String path, String check) =>
      checks.add({'path': path, 'checkId': check, 'result': 'passed'});
  passed('region_manifest.json', 'manifest-paths-v1');
  passed('Polygons/manifest.json', 'manifest-paths-v1');
  for (final path in catalog.authorizedPaths.toList()..sort()) {
    passed(path, 'sha256-v1');
    try {
      if (path.endsWith('.poly')) {
        if (!parsePolygonText(await reader.readText(path)).isSuccess) {
          throw const FormatException('Invalid polygon');
        }
        passed(path, 'polygon-v1');
      }
    } on Object catch (error) {
      throw FormatException('$path: $error');
    }
  }
  for (final region in catalog.regions) {
    final ids = <int>{};
    for (final path in region.peaks) {
      final parsed = parsePeakSource(
        await reader.readText(path),
        regionKey: region.key,
        path: path,
      );
      if (parsed.peaks.any((peak) => !ids.add(peak.osmId))) {
        throw FormatException('Duplicate peak identity: ${region.key}:$path');
      }
      if (parsed.skippedPeakCount > 0) {
        diagnostics.add(
          '$path: skipped ${parsed.skippedPeakCount} ineligible peaks',
        );
      }
      passed(path, 'peaks-v1');
    }
    for (final path in region.highways) {
      final decoded = jsonDecode(await reader.readText(path));
      if (decoded is! Map ||
          decoded['elements'] is! List ||
          (decoded['elements'] as List).any(
            (e) =>
                e is! Map ||
                !const {'node', 'way', 'relation'}.contains(e['type']) ||
                e['id'] is! int ||
                (e['id'] as int) <= 0,
          )) {
        throw FormatException('Invalid highway envelope/identity: $path');
      }
      passed(path, 'highway-envelope-v1');
    }
  }
  final stale = await findStaleSeedableRegionFingerprints(
    readText: reader.readText,
    readBytes: (path) => reader.open(
      relativePath: path,
      opener: const IoMappingStoreFileSystem().readBytes,
    ),
  );
  if (stale.isNotEmpty) {
    throw FormatException('Stale regional peak fingerprints: $stale');
  }
  passed('region_manifest.json', 'peak-fingerprints-v1');
  final coverageResolver = RouteGraphCoverageResolver(
    catalog: catalog,
    fileAccess: MappingStoreOperationFileAccess(catalog: catalog),
  );
  for (final definition in coverageResolver.routingCoverageDefinitions()) {
    final input = await coverageResolver.resolveCoverage(definition);
    final prepared = prepareRouteGraphGeneration(
      canonicalJsonEncode(input.mergedOverpass),
      'route-graph-v5',
      1,
    );
    if ((prepared['chunks'] as List).isEmpty) {
      throw FormatException('No prepared chunks: ${definition.key}');
    }
    for (final path in coverageResolver.sourcePathsForCoverage(
      definition.key,
    )) {
      passed(path, 'coverage-generation-v1');
    }
  }
  final naturalPath = catalog.naturalFeaturesCatalogPath;
  final naturalText = await reader.readText(naturalPath);
  final natural = jsonDecode(naturalText);
  if (natural is! Map ||
      natural['elements'] is! List ||
      (natural['elements'] as List).any((e) => e is! Map)) {
    throw FormatException('Invalid Natural Feature envelope: $naturalPath');
  }
  final plan = buildNaturalFeatureRefreshPlan({'sourceText': naturalText});
  for (final feature in plan['features'] as List) {
    PeakMgrsConverter.fromLatLng(
      LatLng(
        (feature['latitude'] as num).toDouble(),
        (feature['longitude'] as num).toDouble(),
      ),
    );
  }
  diagnostics.addAll(
    (plan['geometryErrors'] as List).cast<String>().map(
      (e) => '$naturalPath: $e',
    ),
  );
  passed(naturalPath, 'natural-features-v1');
  try {
    CsvImporter.importFromContents(
      await reader.readText(catalog.tasmapCatalogPath),
    );
  } on Object catch (error) {
    throw FormatException('${catalog.tasmapCatalogPath}: $error');
  }
  passed(catalog.tasmapCatalogPath, 'tasmap-v1');
  for (final path in catalog.demSources.values.toSet()) {
    final details = await reader.open(relativePath: path, opener: validateDem);
    diagnostics.add('$path: ${jsonEncode(details)}');
    passed(path, 'dem-full-band1-v1');
  }
  return {
    'checks': checks,
    'diagnostics': diagnostics,
    'inventorySha256': sha256
        .convert(utf8.encode(jsonEncode(integrity)))
        .toString(),
  };
}
