import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_tool_manifest.dart';
import 'package:peak_bagger/services/mapping_tool_resolver.dart';
import 'package:peak_bagger/services/route_graph_peak_list_generation_service.dart';

import '../../tool/download_tasmania_thelist_dem.dart';
import '../../tool/local_topo_rebuild.dart';
import '../../tool/mapping_tool_support.dart';
import '../../tool/rank_fvg_peaks.dart';
import '../../tool/update_region_peak_fingerprints.dart';
import '../../tool/validate_region_peak_fingerprints.dart';
import '../harness/mapping_catalog_fixture.dart';

void main() {
  late Directory root;
  late Directory reports;
  late MappingToolManifest manifest;
  final calls = <(String, List<String>, String)>[];

  Future<void> write(String path, String text) async {
    final file = File(p.join(root.path, path));
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  Future<MappingToolResolver> tool(
    String id, {
    MappingToolProcessRunner? runner,
  }) => MappingToolResolver.namedTool(
    toolId: id,
    rootPath: root.path,
    repositoryRoot: Directory.current.path,
    runner:
        runner ??
        (executable, argv, cwd, environment) async {
          calls.add((executable, argv, cwd));
          return ProcessResult(0, 0, 'fixture process', '');
        },
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mapping-tool-cutover-');
    root = Directory(await root.resolveSymbolicLinks());
    reports = await Directory.systemTemp.createTemp('mapping-tool-reports-');
    calls.clear();
    final fixture = File(
      'test/fixtures/mapping_store/v1/tool_manifest.json',
    ).readAsStringSync();
    manifest = MappingToolManifest.parse(fixture);
    await write('tool_manifest.json', fixture);
    await write(
      'region_manifest.json',
      File(
        'test/fixtures/mapping_store/v1/region_manifest.json',
      ).readAsStringSync(),
    );
    await write(
      'Polygons/manifest.json',
      File(
        'test/fixtures/mapping_store/v1/Polygons/manifest.json',
      ).readAsStringSync(),
    );
    final polygons = {
      for (final region in testMappingCatalog.regions)
        for (var i = 0; i < region.polyPaths.length; i++)
          region.polyPaths[i]: region.polygons[i],
      for (final map in testMappingCatalog.basemaps)
        for (var i = 0; i < map.coveragePolygonPaths.length; i++)
          map.coveragePolygonPaths[i]: map.coveragePolygons[i],
    };
    for (final path in testMappingCatalog.authorizedPaths) {
      if (const {
        'region_manifest.json',
        'Polygons/manifest.json',
      }.contains(path)) {
        continue;
      }
      if (path.endsWith('.poly')) {
        final vertices = polygons[path]!;
        await write(
          path,
          'fixture\n1\n${vertices.map((v) => '${v.longitude} ${v.latitude}').join('\n')}\nEND\nEND\n',
        );
      } else {
        await write(path, jsonEncode({'elements': <Object>[]}));
      }
    }
    await write('DEM/Elvis/elvis_topo/elvis_topo_5m.tif', 'prepared topo');
  });
  tearDown(() async {
    await root.delete(recursive: true);
    await reports.delete(recursive: true);
  });

  test(
    'all inventory tool defaults resolve only declared inputs and outputs',
    () async {
      expect(
        manifest.tools.keys,
        unorderedEquals([
          'mapping-store-provision',
          'route-graph-peak-list',
          'update-region-peak-fingerprints',
          'validate-region-peak-fingerprints',
          'rank-fvg-peaks',
          'slovenia-hribi-source-peak-list',
          'peak-prominence-csv',
          'sync-peakbagger-csv',
          'download-tasmania-thelist-dem',
          'elvis-dem-runtime',
          'elvis-dem-topo',
          'local-topo-rebuild',
          'local-topo-rebuild-external',
        ]),
      );
      for (final id in manifest.tools.keys) {
        final resolver = await tool(id);
        await resolver.validateInputs();
        for (final input in resolver.contract.inputs.values) {
          if (input.kind == MappingToolPathKind.glob) {
            expect(
              await resolver.readGlobTexts(input.id),
              isNotEmpty,
              reason: id,
            );
          } else {
            expect(
              await resolver.readInputText(input.id),
              isNotEmpty,
              reason: id,
            );
          }
        }
        await expectLater(
          resolver.readDeclaredText('undeclared.json'),
          throwsStateError,
        );
        expect(
          resolver.contract.permittedWrites,
          unorderedEquals(resolver.contract.outputs.keys),
        );
      }
      expect(
        manifest
            .requireTool('download-tasmania-thelist-dem')
            .outputs['dem']!
            .path,
        'DEM/tasmania_dem_25m.tif',
      );
      expect(
        manifest.requireTool('elvis-dem-runtime').outputs['runtime-dem']!.path,
        'DEM/Elvis/elvis_runtime_10m.tif',
      );
      expect(
        manifest.requireTool('elvis-dem-topo').outputs['topo-dem']!.path,
        'DEM/Elvis/elvis_topo',
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'fingerprint entrypoints use declared bytes and atomic publication',
    () async {
      final reader = await tool('validate-region-peak-fingerprints');
      expect(
        await validateRegionPeakFingerprints(resolver: reader),
        isNotEmpty,
      );
      final updater = await tool('update-region-peak-fingerprints');
      expect(await updateRegionPeakFingerprints(resolver: updater), isTrue);
      expect(
        await validateRegionPeakFingerprints(
          resolver: await tool('validate-region-peak-fingerprints'),
        ),
        isEmpty,
      );
      expect(await updateRegionPeakFingerprints(resolver: updater), isFalse);
      expect(
        Directory(
          root.path,
        ).listSync().where((e) => p.basename(e.path).contains('.stage-')),
        isEmpty,
      );
      await expectLater(updater.execute(), throwsStateError);
      expect(
        calls,
        isEmpty,
        reason:
            'Self-publishing writers cannot bypass outer staging via execute.',
      );
    },
  );

  test(
    'shared tool catalog honors fixture geometry without an assets fallback',
    () async {
      final catalog = await loadToolCatalog(
        await tool('slovenia-hribi-source-peak-list'),
      );
      expect(
        catalog.regions.map((r) => r.key),
        testMappingCatalog.regions.map((r) => r.key),
      );
      expect(catalog.regionByKey('tasmania')!.polyPaths, [
        'Polygons/tasmania.poly',
      ]);
      expect(catalog.regionByKey('veneto')!.polyPaths, isEmpty);
      expect(
        catalog.routingCoverageRegionKeys['northeast-alps'],
        unorderedEquals(['fvg', 'veneto', 'slovenia']),
      );
    },
  );

  test(
    'Local Topo default and named/relative overrides are resolver-generated argv',
    () async {
      for (final (args, expected) in <(List<String>, String)>[
        ([], 'DEM/Elvis/elvis_topo/elvis_topo_5m.tif'),
        (['--dem-source', 'thelist'], 'DEM/tasmania_dem_25m.tif'),
        (
          [
            '--dem-source=copernicus',
            '--mode',
            'scheduled',
            '--dry-run',
            '--skip-prerender',
          ],
          'DEM/cop30_hh.tif',
        ),
        (
          ['--dem-source', 'custom', '--dem-path', 'DEM/custom.tif'],
          'DEM/custom.tif',
        ),
      ]) {
        await write('DEM/custom.tif', 'custom');
        await runLocalTopoRebuild(
          args,
          resolver: await tool('local-topo-rebuild'),
        );
        final call = calls.last;
        expect(call.$1, 'local_topo/tasmania/scripts/rebuild_stack_worker.sh');
        expect(call.$2[1], p.join(root.path, expected));
        expect(call.$3, Directory.current.path);
      }
      final before = calls.length;
      for (final args in [
        ['--dem-path', '../escape.tif'],
        ['--dem-path', p.join(root.path, 'DEM/custom.tif')],
        ['--dem-source', 'unsupported'],
        ['--mode', 'unsupported'],
        ['--undeclared'],
      ]) {
        await expectLater(
          runLocalTopoRebuild(args, resolver: await tool('local-topo-rebuild')),
          args.first == '--dem-path'
              ? throwsFormatException
              : throwsArgumentError,
        );
      }
      expect(calls, hasLength(before));
    },
  );

  test(
    'external DEM adapter rejects Mapping paths and symlink aliases',
    () async {
      final external = File(p.join(reports.path, 'external.tif'))
        ..writeAsStringSync('external');
      final resolver = await tool('local-topo-rebuild-external');
      await runLocalTopoRebuild([
        '--dem-source=custom',
        '--external-dem-path',
        external.path,
      ], resolver: resolver);
      expect(calls.single.$2[3], external.path);
      final alias = Link(p.join(reports.path, 'store-alias'));
      await alias.create(root.path);
      for (final path in [
        p.join(root.path, 'DEM/cop30_hh.tif'),
        p.join(alias.path, 'DEM/cop30_hh.tif'),
      ]) {
        await expectLater(
          runLocalTopoRebuild([
            '--external-dem-path',
            path,
          ], resolver: resolver),
          throwsArgumentError,
        );
      }
      expect(calls, hasLength(1));
    },
  );

  test(
    'theLIST options retain non-store workspace and declared output override',
    () async {
      final defaults = TheListDemOptions.parse([]);
      expect(defaults.outputDirectory, isNull);
      expect(defaults.outputFile, isNull);
      expect(defaults.listOnly, isFalse);
      expect(defaults.skipMerge, isFalse);
      final selected = TheListDemOptions.parse([
        '--output-dir',
        reports.path,
        '--output-file=DEM/alternative.tif',
        '--skip-merge',
      ]);
      expect(selected.outputDirectory, reports.path);
      expect(selected.outputFile, 'DEM/alternative.tif');
      expect(selected.skipMerge, isTrue);
      final resolver = await tool('download-tasmania-thelist-dem');
      await resolver.validateOverrides({'--output-file': selected.outputFile!});
      for (final path in [
        '../escape.tif',
        '/tmp/escape.tif',
        'assets/dem.tif',
      ]) {
        await expectLater(
          resolver.validateOverrides({'--output-file': path}),
          throwsFormatException,
        );
      }
      await expectLater(
        resolver.validateOverrides({'--undeclared': 'DEM/test.tif'}),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'GDAL receives only staged output paths; literal Mapping arguments fail closed',
    () async {
      final vrt = File(p.join(reports.path, 'input.vrt'))
        ..writeAsStringSync('vrt');
      final resolver = await tool(
        'download-tasmania-thelist-dem',
        runner: (executable, args, cwd, environment) async {
          expect(executable, 'tool/publish_thelist_dem.sh');
          expect(args[1], vrt.path);
          expect(args[0], isNot(p.join(root.path, 'DEM/custom.tif')));
          expect(args[0], contains('.stage-'));
          await File(args[0]).writeAsString('GDAL result');
          calls.add((executable, args, cwd));
          return ProcessResult(0, 0, '', '');
        },
      );
      await resolver.writeOutputs((outputs) async {
        await outputs.runProcess(resolver.contract.executable, [
          const MappingToolOutputPath('dem'),
          vrt.path,
        ]);
      }, overrides: {'--output-file': 'DEM/custom.tif'});
      expect(
        File(p.join(root.path, 'DEM/custom.tif')).readAsStringSync(),
        'GDAL result',
      );
      for (final path in [
        p.join(root.path, 'DEM/cop30_hh.tif'),
        'file://${root.path}/DEM/cop30_hh.tif',
        '--input=${root.path}/DEM/cop30_hh.tif',
      ]) {
        await expectLater(
          resolver.writeOutputs(
            (outputs) => outputs.runProcess(resolver.contract.executable, [
              const MappingToolOutputPath('dem'),
              path,
            ]),
          ),
          throwsArgumentError,
        );
      }
      expect(calls, hasLength(1));
      await expectLater(
        resolver.writeOutputs(
          (outputs) =>
              outputs.runProcess('rm', [const MappingToolOutputPath('dem')]),
        ),
        throwsStateError,
      );
      await expectLater(
        resolver.writeOutputs(
          (outputs) => outputs.runProcess(resolver.contract.executable, [
            vrt.path,
            const MappingToolOutputPath('dem'),
          ]),
        ),
        throwsStateError,
      );
      final reader = await tool('local-topo-rebuild');
      await expectLater(
        reader.runProcess([
          '--dem-path',
          const MappingToolInputPath('dem'),
          const MappingToolInputPath('dem'),
        ]),
        throwsStateError,
      );
      expect(calls, hasLength(1));
    },
  );

  test(
    'ELVIS streams prepared external files into declared file and directory outputs',
    () async {
      final prepared = File(p.join(reports.path, 'prepared.tif'))
        ..writeAsStringSync('prepared');
      final runtime = await tool('elvis-dem-runtime');
      await runtime.writeOutputs(
        (outputs) => outputs.copyNonStoreFile('runtime-dem', prepared.path),
      );
      expect(
        File(
          p.join(root.path, 'DEM/Elvis/elvis_runtime_10m.tif'),
        ).readAsStringSync(),
        'prepared',
      );
      await write('DEM/Elvis/elvis_topo/stale.tif', 'stale');
      final topo = await tool('elvis-dem-topo');
      await topo.writeOutputs(
        (outputs) => outputs.copyNonStoreFile(
          'topo-dem',
          prepared.path,
          child: 'elvis_topo_5m.tif',
        ),
      );
      expect(
        File(
          p.join(root.path, 'DEM/Elvis/elvis_topo/elvis_topo_5m.tif'),
        ).readAsStringSync(),
        'prepared',
      );
      expect(
        File(p.join(root.path, 'DEM/Elvis/elvis_topo/stale.tif')).existsSync(),
        isFalse,
      );
      await expectLater(
        topo.writeOutputs(
          (outputs) => outputs.copyNonStoreFile(
            'topo-dem',
            prepared.path,
            child: '../escape.tif',
          ),
        ),
        throwsFormatException,
      );
      await expectLater(
        runtime.writeOutputs(
          (outputs) => outputs.copyNonStoreFile(
            'runtime-dem',
            p.join(root.path, 'DEM/cop30_hh.tif'),
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'ranking retains defaults/overrides and produces reports without live services',
    () async {
      final defaults = PeakRankingOptions.parse([]);
      expect(defaults.regionKey, 'fvg');
      expect(defaults.cacheDir, '.cache/fvg-peak-ranker');
      expect(defaults.outputJsonPath, 'fvg-top-peaks.json');
      expect(defaults.outputCsvPath, 'fvg-top-peaks.csv');
      final json = p.join(reports.path, 'ranked.json');
      final csv = p.join(reports.path, 'ranked.csv');
      final resolver = await tool('rank-fvg-peaks');
      await runPeakRankingTool([
        '--offline',
        '--region-key=fvg',
        '--cache-dir',
        reports.path,
        '--output-json',
        json,
        '--output-csv',
        csv,
      ], toolResolver: resolver);
      expect(
        (jsonDecode(File(json).readAsStringSync()) as Map)['regionKey'],
        'fvg',
      );
      expect(File(csv).existsSync(), isTrue);
      await expectLater(
        runPeakRankingTool([
          '--offline',
          '--region-key',
          'veneto',
          '--output-json',
          json,
          '--output-csv',
          csv,
        ], toolResolver: resolver),
        throwsStateError,
      );
      await expectLater(
        runPeakRankingTool([
          '--offline',
          '--output-json',
          p.join(root.path, 'Peaks/illegal.json'),
        ], toolResolver: resolver),
        throwsArgumentError,
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'route-graph peak-list service reads Mapping paths via the named capability',
    () async {
      await write(
        'Highways/tasmania-highways.json',
        jsonEncode({
          'elements': [
            {'type': 'node', 'id': 1, 'lat': -42.0, 'lon': 146.0},
            {'type': 'node', 'id': 2, 'lat': -42.001, 'lon': 146.001},
            {
              'type': 'way',
              'id': 10,
              'nodes': [1, 2],
              'tags': {'highway': 'path'},
            },
          ],
        }),
      );
      final resolver = await tool('route-graph-peak-list');
      final row = {
        'id': '1',
        'osmId': '123',
        'name': 'Fixture Peak',
        'latitude': '-42',
        'longitude': '146',
        'region': 'tasmania',
        'verified': 'false',
      };
      final userCsv = const CsvEncoder().convert([
        RouteGraphPeakListGenerationService.peakSourceHeaders,
        [
          for (final header
              in RouteGraphPeakListGenerationService.peakSourceHeaders)
            row[header] ?? '',
        ],
      ]);
      final sourceReads = <String>[];
      final service = RouteGraphPeakListGenerationService(
        mappingTextReader: (path) {
          sourceReads.add(path);
          return resolver.readDeclaredText(path);
        },
        textReader: (_) async => userCsv,
      );
      final output = p.join(reports.path, 'route-peaks.csv');
      final result = await service.generate(
        regionKey: 'tasmania',
        outputPath: output,
      );
      expect(result.matchedPeakCount, 1);
      expect(sourceReads, [
        'region_manifest.json',
        'Highways/tasmania-highways.json',
      ]);
      expect(File(output).readAsStringSync(), contains('Fixture Peak'));
    },
  );
}
