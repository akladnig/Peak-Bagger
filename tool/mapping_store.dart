import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_store_contract_verifier.dart';
import 'package:peak_bagger/services/mapping_store_resolver.dart';
import 'package:peak_bagger/services/mapping_tool_manifest.dart';
import 'package:peak_bagger/services/mapping_tool_resolver.dart';

/// Non-store adapter: reads only version-controlled fixture files. All mounted
/// Mapping data reads and writes below go through the resolver capabilities.
Future<String> _fixture(String repositoryRoot, String relative) => File(
  p.join(repositoryRoot, 'test/fixtures/mapping_store/v1', relative),
).readAsString();

Future<void> main(List<String> arguments) async {
  final repositoryRoot = p.normalize(
    p.join(p.dirname(Platform.script.toFilePath()), '..'),
  );
  try {
    if (arguments.length != 1 ||
        !{
          'bootstrap-tool-manifest',
          'provision-or-verify',
        }.contains(arguments.single)) {
      throw ArgumentError(
        'Usage: dart run tool/mapping_store.dart <bootstrap-tool-manifest|provision-or-verify>',
      );
    }
    final fixtureTools = await _fixture(repositoryRoot, 'tool_manifest.json');
    MappingToolManifest.parse(fixtureTools);
    if (arguments.single == 'bootstrap-tool-manifest') {
      final installed = await const MappingToolManifestBootstrap().install(
        fixtureText: fixtureTools,
      );
      stdout.writeln(
        installed
            ? 'Installed $mappingStoreRootPath/tool_manifest.json (atomic, no overwrite).'
            : 'Existing tool_manifest.json matches the v1 fixture; no write.',
      );
      return;
    }
    final fixtureRegion = await _fixture(
      repositoryRoot,
      'region_manifest.json',
    );
    final fixturePolygons = await _fixture(
      repositoryRoot,
      'Polygons/manifest.json',
    );
    final preflight = await MappingDataStoreCore().preflight();
    final runtime = MappingStoreReadResolver.runtime(preflight: preflight);
    final tool = await MappingToolResolver.namedTool(
      toolId: 'mapping-store-provision',
      repositoryRoot: repositoryRoot,
    );
    final manifestInput = tool.contract.inputs['tools'];
    if (manifestInput?.path != mappingToolManifestPath ||
        manifestInput?.kind != MappingToolPathKind.file) {
      throw StateError(
        'Provision tool must declare tool_manifest.json as its tools input.',
      );
    }
    final differences = verifyMappingStoreContract(
      fixtureRegion: fixtureRegion,
      fixturePolygons: fixturePolygons,
      fixtureTools: fixtureTools,
      mountedRegion: await runtime.readText('region_manifest.json'),
      mountedPolygons: await runtime.readText('Polygons/manifest.json'),
      mountedTools: await tool.readInputText('tools'),
    );
    for (final difference in differences) {
      stdout.writeln('Allowed data-derived difference: $difference');
    }
    stdout.writeln(
      'Mapping store satisfies the v1 retained contract (${differences.length} allowed differences). No Mapping data was overwritten.',
    );
  } on Object catch (error, stack) {
    stderr.writeln(error);
    stderr.writeln(stack);
    exitCode = 1;
  }
}
