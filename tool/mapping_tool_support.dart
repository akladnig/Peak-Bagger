import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_tool_resolver.dart';

Future<MappingToolResolver> openMappingTool(String toolId) =>
    MappingToolResolver.namedTool(
      toolId: toolId,
      repositoryRoot: Platform.script.path.endsWith('.dart')
          ? p.normalize(p.join(p.dirname(Platform.script.toFilePath()), '..'))
          : Directory.current.path,
    );

Future<MappingCatalog> loadToolCatalog(MappingToolResolver resolver) async {
  await resolver.validateInputs();
  final regions = await resolver.readInputText('regions');
  final polygons = await resolver.readInputText('polygons');
  final decoded = jsonDecode(regions) as Object;
  final allowlist = jsonDecode(polygons) as Object;
  validateMappingManifestPair(decoded, allowlist);
  final paths = <String>{};
  for (final entry in (decoded as Map).entries) {
    if (const {
      'tasmap',
      'naturalFeatures',
      'demSources',
      'routingCoverages',
    }.contains(entry.key)) {
      continue;
    }
    paths.addAll(List<String>.from(entry.value['poly'] as List));
    for (final map in entry.value['maps'] as List) {
      paths.addAll(List<String>.from(map['coveragePoly'] ?? const []));
    }
  }
  return MappingDataStoreCore.catalogFromManifestTexts(
    rootPath: mappingStoreRootPath,
    regionManifestText: regions,
    polygonManifestText: polygons,
    polygonTexts: {
      for (final path in paths) path: await resolver.readDeclaredText(path),
    },
  );
}
