import 'dart:convert';
import 'dart:io';

import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_tool_resolver.dart';

import 'mapping_tool_support.dart';

Future<void> main(List<String> args) async {
  try {
    final result = await runLocalTopoRebuild(args);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exitCode = result.exitCode;
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

Future<ProcessResult> runLocalTopoRebuild(
  List<String> args, {
  MappingToolResolver? resolver,
}) async {
  var source = 'elvis-topo';
  String? demPath;
  String? externalDem;
  final workerOptions = <String>[];
  for (var i = 0; i < args.length; i++) {
    final parts = args[i].split('=');
    final flag = parts.first;
    String value() {
      if (parts.length == 2 && parts[1].isNotEmpty) return parts[1];
      if (++i >= args.length || args[i].startsWith('--')) {
        throw ArgumentError('Missing value for $flag');
      }
      return args[i];
    }

    switch (flag) {
      case '--help':
        stdout.writeln(
          'Local Topo rebuild: --mode manual|scheduled, --dry-run, --skip-prerender, --force-source-refresh, --dem-source elvis-topo|thelist|copernicus|custom, --dem-path STORE_RELATIVE_PATH, --external-dem-path NON_STORE_ABSOLUTE_PATH',
        );
        return ProcessResult(0, 0, '', '');
      case '--dem-source':
        source = value();
      case '--dem-path':
        demPath = value();
      case '--external-dem-path':
        externalDem = value();
      case '--mode':
        final mode = value();
        if (!const {'manual', 'scheduled'}.contains(mode)) {
          throw ArgumentError('Unsupported mode: $mode');
        }
        workerOptions.addAll(['--mode', mode]);
      case '--dry-run' || '--skip-prerender' || '--force-source-refresh':
        workerOptions.add(flag);
      default:
        throw ArgumentError('Unknown option: $flag');
    }
  }
  if (!const {
    'elvis-topo',
    'thelist',
    'copernicus',
    'custom',
  }.contains(source)) {
    throw ArgumentError('Unsupported DEM source: $source');
  }
  if (demPath != null && externalDem != null) {
    throw ArgumentError('Choose one declared or external DEM override.');
  }
  final tool =
      resolver ??
      await openMappingTool(
        externalDem == null
            ? 'local-topo-rebuild'
            : 'local-topo-rebuild-external',
      );
  if (externalDem != null) {
    if (!externalDem.startsWith('/')) {
      throw ArgumentError('External DEM must be absolute.');
    }
    await tool.requireNonStorePath(externalDem);
    return tool.runProcess([
      '--dem-source',
      'custom',
      '--dem-path',
      externalDem,
      ...workerOptions,
    ]);
  }
  if (source == 'custom' && demPath == null) {
    throw ArgumentError('custom requires --dem-path or --external-dem-path.');
  }
  final regions = jsonDecode(await tool.readInputText('regions')) as Object;
  final polygons = jsonDecode(await tool.readInputText('polygons')) as Object;
  validateMappingManifestPair(regions, polygons);
  final sources = (regions as Map)['demSources'] as Map;
  final selected =
      demPath ??
      switch (source) {
        'thelist' => sources['thelist25m'] as String,
        'copernicus' => sources['copernicus'] as String,
        _ => tool.contract.inputs['dem']!.path,
      };
  return tool.runProcess(
    [
      '--dem-path',
      const MappingToolInputPath('dem'),
      '--dem-source',
      source,
      ...workerOptions,
    ],
    overrides: {'--dem-path': selected},
  );
}
