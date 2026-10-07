import 'dart:io';
import 'dart:convert';
import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_tool_resolver.dart';

import 'region_peak_fingerprint_support.dart';
import 'mapping_tool_support.dart';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) throw ArgumentError('No CLI overrides are permitted.');
  final updated = await updateRegionPeakFingerprints();
  stdout.writeln(
    updated
        ? 'Updated region peak fingerprints.'
        : 'Region peak fingerprints already current.',
  );
}

Future<bool> updateRegionPeakFingerprints({
  MappingToolResolver? resolver,
}) async {
  final tool =
      resolver ?? await openMappingTool('update-region-peak-fingerprints');
  await tool.validateInputs();
  validateMappingRegionManifest(
    jsonDecode(await tool.readInputText('regions')) as Object,
  );
  var updated = false;
  await tool.writeOutputs((outputs) async {
    updated = await updateSeedableRegionFingerprints(
      readText: tool.readDeclaredText,
      readBytes: tool.readDeclaredBytes,
      writeText: (_, text) => outputs.writeText('updated-manifest', text),
    );
    // The output is required even when fingerprints already match.
    if (!updated) {
      await outputs.writeText(
        'updated-manifest',
        await tool.readInputText('regions'),
      );
    }
  });
  return updated;
}
