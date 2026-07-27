import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../tool/elvis_dem.dart';

void main() {
  List<String> stdoutLines = [];
  List<String> stderrLines = [];

  setUp(() {
    stdoutLines = [];
    stderrLines = [];
  });

  test(
    'requires a subcommand and prints only the active single-file help',
    () async {
      final exitCode = await runElvisDemTool(
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('Missing required subcommand'));
      expect(
        stdoutLines.single,
        contains('./elvis_dem.sh build-all [--validate]'),
      );
      expect(stdoutLines.single, contains('Only supported build flag'));
      expect(stdoutLines.single, contains('existence, readability,'));
      expect(stdoutLines.single, contains('and GDAL openability'));
      expect(stdoutLines.single, contains(elvisDemCanonicalSourcePath));
      expect(stdoutLines.single, isNot(contains('bootstrap-manifest')));
      expect(stdoutLines.single, isNot(contains('--save-vrt')));
      expect(
        stdoutLines.single,
        isNot(contains('/Volumes/Elvis/tas-elvis')),
      );
    },
  );

  test('rejects the removed bootstrap-manifest subcommand', () async {
    final exitCode = await runElvisDemTool(
      args: const ['bootstrap-manifest'],
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(
      stderrLines.single,
      contains('Unknown subcommand or flag: bootstrap-manifest'),
    );
    expect(stdoutLines.single, isNot(contains('bootstrap-manifest')));
  });

  test('rejects the removed --save-vrt flag', () async {
    final exitCode = await runElvisDemTool(
      args: const ['build-topo', '--save-vrt'],
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(
      stderrLines.single,
      contains('Unknown subcommand or flag: --save-vrt'),
    );
    expect(stdoutLines.single, isNot(contains('--save-vrt')));
  });

  test(
    'validate-source validates the exact TIFF and writes a success report',
    () async {
      final sourceFile = await _createFixtureSourceFile();
      final alternateFile = File(
        p.join(sourceFile.parent.path, 'alternate.tif'),
      )..writeAsStringSync('alternate');
      final home = await Directory.systemTemp.createTemp('elvis-dem-home');
      addTearDown(() => home.deleteSync(recursive: true));
      Directory(
        p.join(home.path, 'Documents', 'Bushwalking'),
      ).createSync(recursive: true);

      final requiredCommands = <String>[];
      final recordedCommands = <(String executable, List<String> arguments)>[];

      final exitCode = await runElvisDemTool(
        args: const ['validate-source'],
        sourcePath: sourceFile.path,
        homeDirectory: home.path,
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        commandChecker: (command) async {
          requiredCommands.add(command);
        },
        commandRunner: (executable, arguments) async {
          recordedCommands.add((executable, arguments));
          return const ElvisDemCommandResult(stdout: 'Driver: GTiff/GeoTIFF\n');
        },
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      final reportPath = p.join(
        home.path,
        'Documents',
        'Bushwalking',
        'DEM',
        'Tasmania',
        'elvis_reports',
        'validate-source-20240102T030405Z.report.json',
      );
      final report = _readJsonFile(reportPath);

      expect(exitCode, 0);
      expect(stderrLines, isEmpty);
      expect(requiredCommands, ['gdalinfo']);
      expect(recordedCommands, hasLength(1));
      expect(recordedCommands.single.$1, 'gdalinfo');
      expect(recordedCommands.single.$2, [sourceFile.path]);
      expect(recordedCommands.single.$2, isNot(contains(alternateFile.path)));
      expect(
        stdoutLines,
        contains('Checking exact Elvis 2m DEM file: ${sourceFile.path}'),
      );
      expect(
        stdoutLines,
        contains('Opening Elvis 2m DEM with gdalinfo: ${sourceFile.path}'),
      );
      expect(stdoutLines, contains('Raw source: ${sourceFile.path}'));
      expect(stdoutLines, contains('Artifacts: none'));
      expect(stdoutLines, contains('Report: $reportPath'));
      expect(report['status'], 'success');
      expect(report['sourceLabel'], elvisDemSourceLabel);
      expect(report['sourcePath'], sourceFile.path);
      expect(report.containsKey('manifestPath'), isFalse);
      expect((report['artifacts'] as List), isEmpty);
      expect(
        (report['validation'] as Map<String, dynamic>)['state'],
        'validated',
      );
      expect(
        (report['validation'] as Map<String, dynamic>)['sourceComplete'],
        true,
      );
    },
  );

  test(
    'validate-source fails clearly when the exact TIFF is missing',
    () async {
      final missingPath = p.join(
        (await Directory.systemTemp.createTemp('elvis-dem-missing')).path,
        'Tasmania_Statewide_2m_DEM_14-08-2021.tif',
      );
      final home = await Directory.systemTemp.createTemp(
        'elvis-dem-missing-home',
      );
      addTearDown(() => home.deleteSync(recursive: true));

      final exitCode = await runElvisDemTool(
        args: const ['validate-source'],
        sourcePath: missingPath,
        homeDirectory: home.path,
        clock: () => DateTime.utc(2024, 2, 3, 4, 5, 6),
        commandChecker: (_) async {
          fail('gdalinfo should not run when the source file is missing');
        },
        commandRunner: (_, arguments) async {
          expect(arguments, isNotEmpty);
          fail('gdalinfo should not run when the source file is missing');
        },
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      final report = _readJsonFile(
        p.join(
          home.path,
          'DEM',
          'Tasmania',
          'elvis_reports',
          'validate-source-20240203T040506Z.report.json',
        ),
      );

      expect(exitCode, 1);
      expect(stderrLines.single, contains('Missing exact Elvis 2m DEM TIFF'));
      expect(report['status'], 'failure');
      expect((report['validation'] as Map<String, dynamic>)['state'], 'failed');
      expect(
        (report['validation'] as Map<String, dynamic>)['error'],
        contains(missingPath),
      );
    },
  );

  test(
    'validate-source fails clearly when the exact TIFF is unreadable',
    () async {
      final sourceFile = await _createFixtureSourceFile();
      final home = await Directory.systemTemp.createTemp(
        'elvis-dem-unreadable-home',
      );
      addTearDown(() => home.deleteSync(recursive: true));

      final exitCode = await runElvisDemTool(
        args: const ['validate-source'],
        sourcePath: sourceFile.path,
        homeDirectory: home.path,
        sourceReadableChecker: (_) async {
          throw StateError(
            'Elvis 2m DEM is not readable at ${sourceFile.path}.',
          );
        },
        commandChecker: (_) async {
          fail('gdalinfo should not run when the source file is unreadable');
        },
        commandRunner: (_, arguments) async {
          expect(arguments, isNotEmpty);
          fail('gdalinfo should not run when the source file is unreadable');
        },
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(
        stderrLines.single,
        contains('Elvis 2m DEM is not readable at ${sourceFile.path}.'),
      );
    },
  );

  test(
    'validate-source fails clearly when gdalinfo cannot open the exact TIFF',
    () async {
      final sourceFile = await _createFixtureSourceFile();
      final home = await Directory.systemTemp.createTemp('elvis-dem-gdal-home');
      addTearDown(() => home.deleteSync(recursive: true));

      final exitCode = await runElvisDemTool(
        args: const ['validate-source'],
        sourcePath: sourceFile.path,
        homeDirectory: home.path,
        commandChecker: (_) async {},
        commandRunner: (executable, arguments) async {
          throw ProcessException(executable, arguments, 'corrupt dataset', 1);
        },
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(
        stderrLines.single,
        contains(
          'Elvis 2m DEM could not be opened by gdalinfo at ${sourceFile.path}.',
        ),
      );
      expect(stderrLines.single, contains('corrupt dataset'));
    },
  );

  test(
    'build-all skips validation by default and writes single-file provenance',
    () async {
      final sourceFile = await _createFixtureSourceFile();
      final alternateFile = File(p.join(sourceFile.parent.path, 'other.tif'))
        ..writeAsStringSync('other');
      final home = await Directory.systemTemp.createTemp(
        'elvis-dem-build-home',
      );
      addTearDown(() => home.deleteSync(recursive: true));

      final requiredCommands = <String>[];
      final recordedCommands = <(String executable, List<String> arguments)>[];

      final exitCode = await runElvisDemTool(
        args: const ['build-all'],
        sourcePath: sourceFile.path,
        homeDirectory: home.path,
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        commandChecker: (command) async {
          requiredCommands.add(command);
        },
        commandRunner: (executable, arguments) async {
          recordedCommands.add((executable, arguments));
          final outputPath = _fakeCommandOutputPath(executable, arguments);
          await File(outputPath).parent.create(recursive: true);
          await File(outputPath).writeAsString('$executable output');
          return const ElvisDemCommandResult();
        },
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      final tasmaniaDemRoot = p.join(home.path, 'DEM', 'Tasmania');
      final runtimeArtifactPath = p.join(
        tasmaniaDemRoot,
        'elvis_runtime_10m.tif',
      );
      final runtimeMetadataPath = p.join(
        tasmaniaDemRoot,
        'elvis_runtime_10m.metadata.json',
      );
      final topoArtifactPath = p.join(
        tasmaniaDemRoot,
        'elvis_topo',
        'elvis_topo_5m.tif',
      );
      final topoMetadataPath = p.join(
        tasmaniaDemRoot,
        'elvis_topo',
        'elvis_topo_5m.metadata.json',
      );
      final topoHillshadePath = p.join(
        tasmaniaDemRoot,
        'elvis_topo',
        'elvis_topo_5m.hillshade.tif',
      );
      final topoHillshadePreviewPath = p.join(
        tasmaniaDemRoot,
        'elvis_topo',
        'elvis_topo_5m.hillshade.preview.jpg',
      );
      final reportPath = p.join(
        tasmaniaDemRoot,
        'elvis_reports',
        'build-all-20240102T030405Z.report.json',
      );
      final runtimeMetadata = _readJsonFile(runtimeMetadataPath);
      final topoMetadata = _readJsonFile(topoMetadataPath);
      final report = _readJsonFile(reportPath);

      expect(exitCode, 0);
      expect(stderrLines, isEmpty);
      expect(requiredCommands, [
        'gdalwarp',
        'gdalwarp',
        'gdaldem',
        'gdal_translate',
      ]);
      expect(
        recordedCommands.map((entry) => entry.$1).toList(growable: false),
        ['gdalwarp', 'gdalwarp', 'gdaldem', 'gdal_translate'],
      );
      expect(
        recordedCommands
            .where((entry) => entry.$1 == 'gdalwarp')
            .map((entry) => entry.$2),
        everyElement(contains(sourceFile.path)),
      );
      expect(
        recordedCommands
            .where((entry) => entry.$1 == 'gdalwarp')
            .map((entry) => entry.$2),
        everyElement(isNot(contains(alternateFile.path))),
      );
      expect(
        recordedCommands.map((entry) => entry.$1),
        isNot(contains('gdalbuildvrt')),
      );
      expect(
        stdoutLines,
        contains(
          'Validation skipped; building directly from the exact canonical Elvis 2m DEM file.',
        ),
      );
      expect(
        stdoutLines.where(
          (line) => line.contains('Opening Elvis 2m DEM with gdalinfo:'),
        ),
        isEmpty,
      );
      expect(File(runtimeArtifactPath).existsSync(), isTrue);
      expect(File(topoArtifactPath).existsSync(), isTrue);
      expect(File(topoHillshadePath).existsSync(), isTrue);
      expect(File(topoHillshadePreviewPath).existsSync(), isTrue);
      expect(runtimeMetadata['artifactPath'], runtimeArtifactPath);
      expect(
        (runtimeMetadata['sourceCompleteness']
            as Map<String, dynamic>)['state'],
        'skipped',
      );
      expect(
        (runtimeMetadata['sourceCompleteness']
            as Map<String, dynamic>)['sourcePath'],
        sourceFile.path,
      );
      expect(runtimeMetadata.containsKey('manifestPath'), isFalse);
      expect(
        (runtimeMetadata['derivation'] as Map<String, dynamic>)['sourcePath'],
        sourceFile.path,
      );
      expect(
        (runtimeMetadata['derivation']
            as Map<String, dynamic>)['rasterInputCount'],
        1,
      );
      expect(topoMetadata['artifactPath'], topoArtifactPath);
      expect(
        (topoMetadata['derivation'] as Map<String, dynamic>)['targetSrs'],
        'EPSG:28355',
      );
      expect(
        (topoMetadata['derivation'] as Map<String, dynamic>)['sourcePath'],
        sourceFile.path,
      );
      expect(
        (report['validation'] as Map<String, dynamic>)['state'],
        'skipped',
      );
      expect(report['sourcePath'], sourceFile.path);
      expect(report.containsKey('manifestPath'), isFalse);
    },
  );

  test(
    'build-topo --validate runs exact-file validation before building',
    () async {
      final sourceFile = await _createFixtureSourceFile();
      final home = await Directory.systemTemp.createTemp('elvis-dem-topo-home');
      addTearDown(() => home.deleteSync(recursive: true));

      final recordedCommands = <(String executable, List<String> arguments)>[];

      final exitCode = await runElvisDemTool(
        args: const ['build-topo', '--validate'],
        sourcePath: sourceFile.path,
        homeDirectory: home.path,
        commandChecker: (_) async {},
        commandRunner: (executable, arguments) async {
          recordedCommands.add((executable, arguments));
          if (executable != 'gdalinfo') {
            final outputPath = _fakeCommandOutputPath(executable, arguments);
            await File(outputPath).parent.create(recursive: true);
            await File(outputPath).writeAsString('$executable output');
          }
          return const ElvisDemCommandResult(stdout: 'Driver: GTiff/GeoTIFF\n');
        },
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      final topoMetadata = _readJsonFile(
        p.join(
          home.path,
          'DEM',
          'Tasmania',
          'elvis_topo',
          'elvis_topo_5m.metadata.json',
        ),
      );

      expect(exitCode, 0);
      expect(stderrLines, isEmpty);
      expect(recordedCommands.first.$1, 'gdalinfo');
      expect(recordedCommands.first.$2, [sourceFile.path]);
      expect(
        stdoutLines,
        contains('Checking exact Elvis 2m DEM file: ${sourceFile.path}'),
      );
      expect(
        stdoutLines,
        contains('Opening Elvis 2m DEM with gdalinfo: ${sourceFile.path}'),
      );
      expect(
        (topoMetadata['sourceCompleteness'] as Map<String, dynamic>)['state'],
        'validated',
      );
      expect(
        (topoMetadata['sourceCompleteness']
            as Map<String, dynamic>)['validationEnabled'],
        true,
      );
    },
  );

  test(
    'build-runtime --validate fails before gdalwarp when gdalinfo cannot open the TIFF',
    () async {
      final sourceFile = await _createFixtureSourceFile();
      final home = await Directory.systemTemp.createTemp(
        'elvis-dem-build-fail-home',
      );
      addTearDown(() => home.deleteSync(recursive: true));

      final recordedCommands = <(String executable, List<String> arguments)>[];

      final exitCode = await runElvisDemTool(
        args: const ['build-runtime', '--validate'],
        sourcePath: sourceFile.path,
        homeDirectory: home.path,
        commandChecker: (_) async {},
        commandRunner: (executable, arguments) async {
          recordedCommands.add((executable, arguments));
          if (executable == 'gdalinfo') {
            throw ProcessException(executable, arguments, 'corrupt dataset', 1);
          }
          fail('gdalwarp should not run when validation fails');
        },
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(recordedCommands, hasLength(1));
      expect(recordedCommands.single.$1, 'gdalinfo');
      expect(recordedCommands.single.$2, [sourceFile.path]);
      expect(stderrLines.single, contains('corrupt dataset'));
    },
  );

  test(
    'shell wrapper forwards subcommands and supported flags to the tool entrypoint',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'elvis-dem-wrapper',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final argsFile = File(p.join(tempDir.path, 'args.txt'));
      final fakeBinary = File(p.join(tempDir.path, 'fake-binary.sh'))
        ..writeAsStringSync(
          '#!/usr/bin/env bash\nset -euo pipefail\nprintf "%s\\n" "\$@" > "${argsFile.path}"\n',
        );
      Process.runSync('chmod', ['+x', fakeBinary.path]);

      final scriptPath = p.join(Directory.current.path, 'elvis_dem.sh');
      final result = await Process.run(
        '/bin/bash',
        [scriptPath, 'build-topo', '--validate', '--help'],
        environment: {
          ...Platform.environment,
          'PEAK_BAGGER_ELVIS_DEM_TOOL_BINARY': fakeBinary.path,
        },
      );

      expect(result.exitCode, 0);
      expect(argsFile.readAsLinesSync(), [
        'build-topo',
        '--validate',
        '--help',
      ]);
    },
  );
}

Future<File> _createFixtureSourceFile() async {
  final sourceRoot = await Directory.systemTemp.createTemp('elvis-dem-source');
  addTearDown(() => sourceRoot.deleteSync(recursive: true));

  final sourceFile = File(
    p.join(sourceRoot.path, 'Tasmania_Statewide_2m_DEM_14-08-2021.tif'),
  );
  sourceFile.writeAsStringSync('fixture-dem');
  return sourceFile;
}

Map<String, dynamic> _readJsonFile(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  return (decoded as Map).cast<String, dynamic>();
}

String _fakeCommandOutputPath(String executable, List<String> arguments) {
  return switch (executable) {
    'gdaldem' => arguments[2],
    _ => arguments.last,
  };
}
