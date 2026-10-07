import 'dart:io';
import 'dart:convert';
import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_tool_resolver.dart';

import 'region_peak_fingerprint_support.dart';
import 'mapping_tool_support.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) throw ArgumentError('No CLI overrides are permitted.');
  final staleRegions = await validateRegionPeakFingerprints();
  if (staleRegions.isEmpty) {
    stdout.writeln('Region peak fingerprints are current.');
    return;
  }

  stderr.writeln('Stale region peak fingerprints: ${staleRegions.join(', ')}');
  exitCode = 1;
}

Future<List<String>> validateRegionPeakFingerprints({
  MappingToolResolver? resolver,
}) async {
  final tool =
      resolver ?? await openMappingTool('validate-region-peak-fingerprints');
  await tool.validateInputs();
  validateMappingRegionManifest(
    jsonDecode(await tool.readInputText('regions')) as Object,
  );
  return findStaleSeedableRegionFingerprints(
    readText: tool.readDeclaredText,
    readBytes: tool.readDeclaredBytes,
  );
}
