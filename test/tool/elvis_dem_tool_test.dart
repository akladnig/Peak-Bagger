import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

  test('requires a subcommand and prints help', () async {
    final exitCode = await runElvisDemTool(
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('Missing required subcommand'));
    expect(stdoutLines.single, contains('./elvis_dem.sh build-all'));
  });

  test(
    'bootstrap-manifest writes an explicit file manifest and ignores .DS_Store',
    () async {
      final sourceRoot = await _createFixtureSourceRoot();
      final manifestFile = File(
        p.join(sourceRoot.parent.path, 'manifest.json'),
      );

      final exitCode = await runElvisDemTool(
        args: const ['bootstrap-manifest'],
        sourceRootPath: sourceRoot.path,
        manifestPath: manifestFile.path,
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(stderrLines, isEmpty);
      expect(
        stdoutLines,
        contains('Creating frozen manifest from 2 payload files...'),
      );
      expect(stdoutLines, contains('Manifest hashing: 2/2'));
      expect(stdoutLines, contains('Raw source: ${sourceRoot.path}'));
      expect(stdoutLines, contains('Manifest: ${manifestFile.path}'));

      final manifest = _readJsonFile(manifestFile.path);
      expect(manifest['sourceRoot'], sourceRoot.path);
      expect(manifest['fileCount'], 2);
      expect(manifest['totalBytes'], 16);
      expect(manifest['generatedAtUtc'], '2024-01-02T03:04:05.000Z');

      final files = (manifest['files'] as List).cast<Map<String, dynamic>>();
      expect(files, hasLength(2));
      expect(files[0]['path'], 'elevation/1m-dem/tile_a.tif');
      expect(files[0]['bytes'], 8);
      expect(files[0]['sha256'], _sha256Hex('tile-a-1'));
      expect(files[1]['path'], 'elevation/2m-dem/tile_b.tif');
      expect(files[1]['bytes'], 8);
      expect(files[1]['sha256'], _sha256Hex('tile-b-2'));
    },
  );

  test('validate-source writes a timestamped success report', () async {
    final sourceRoot = await _createFixtureSourceRoot();
    final manifestFile = File(p.join(sourceRoot.parent.path, 'manifest.json'));
    final home = await Directory.systemTemp.createTemp('elvis-dem-home');
    addTearDown(() => home.deleteSync(recursive: true));
    Directory(
      p.join(home.path, 'Documents', 'Bushwalking'),
    ).createSync(recursive: true);
    await _bootstrapFixtureManifest(
      sourceRoot: sourceRoot,
      manifestFile: manifestFile,
    );

    final exitCode = await runElvisDemTool(
      args: const ['validate-source'],
      sourceRootPath: sourceRoot.path,
      manifestPath: manifestFile.path,
      homeDirectory: home.path,
      clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
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

    expect(exitCode, 0);
    expect(stderrLines, isEmpty);
    expect(
      stdoutLines,
      contains('Loading frozen manifest: ${manifestFile.path}'),
    );
    expect(
      stdoutLines,
      contains('Validating 2 manifest entries against ${sourceRoot.path}'),
    );
    expect(
      stdoutLines,
      contains('Discovered 2 payload files in the raw source tree.'),
    );
    expect(stdoutLines, contains('Validation progress: 2/2'));
    expect(stdoutLines, contains('Raw source: ${sourceRoot.path}'));
    expect(stdoutLines, contains('Artifacts: none'));
    expect(stdoutLines, contains('Report: $reportPath'));

    final report = _readJsonFile(reportPath);
    expect(report['status'], 'success');
    expect(report['sourceRoot'], sourceRoot.path);
    expect(report['manifestPath'], manifestFile.path);
    expect((report['artifacts'] as List), isEmpty);
    expect(
      (report['validation'] as Map<String, dynamic>)['sourceComplete'],
      true,
    );
  });

  test('validate-source fails on missing expected files', () async {
    final sourceRoot = await _createFixtureSourceRoot();
    final manifestFile = File(p.join(sourceRoot.parent.path, 'manifest.json'));
    final home = await Directory.systemTemp.createTemp(
      'elvis-dem-missing-home',
    );
    addTearDown(() => home.deleteSync(recursive: true));
    await _bootstrapFixtureManifest(
      sourceRoot: sourceRoot,
      manifestFile: manifestFile,
    );

    File(
      p.join(sourceRoot.path, 'elevation', '1m-dem', 'tile_a.tif'),
    ).deleteSync();

    final exitCode = await runElvisDemTool(
      args: const ['validate-source'],
      sourceRootPath: sourceRoot.path,
      manifestPath: manifestFile.path,
      homeDirectory: home.path,
      clock: () => DateTime.utc(2024, 2, 3, 4, 5, 6),
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
    expect(stderrLines.single, contains('Missing expected file'));
    expect(report['status'], 'failure');
    expect(
      ((report['validation'] as Map<String, dynamic>)['missingFiles'] as List),
      ['elevation/1m-dem/tile_a.tif'],
    );
  });

  test('validate-source fails on wrong file sizes', () async {
    final sourceRoot = await _createFixtureSourceRoot();
    final manifestFile = File(p.join(sourceRoot.parent.path, 'manifest.json'));
    final home = await Directory.systemTemp.createTemp('elvis-dem-size-home');
    addTearDown(() => home.deleteSync(recursive: true));
    await _bootstrapFixtureManifest(
      sourceRoot: sourceRoot,
      manifestFile: manifestFile,
    );

    File(
      p.join(sourceRoot.path, 'elevation', '1m-dem', 'tile_a.tif'),
    ).writeAsStringSync('short');

    final exitCode = await runElvisDemTool(
      args: const ['validate-source'],
      sourceRootPath: sourceRoot.path,
      manifestPath: manifestFile.path,
      homeDirectory: home.path,
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('Wrong size'));
  });

  test('validate-source fails on checksum mismatches', () async {
    final sourceRoot = await _createFixtureSourceRoot();
    final manifestFile = File(p.join(sourceRoot.parent.path, 'manifest.json'));
    final home = await Directory.systemTemp.createTemp('elvis-dem-hash-home');
    addTearDown(() => home.deleteSync(recursive: true));
    await _bootstrapFixtureManifest(
      sourceRoot: sourceRoot,
      manifestFile: manifestFile,
    );

    File(
      p.join(sourceRoot.path, 'elevation', '1m-dem', 'tile_a.tif'),
    ).writeAsStringSync('tile-a-x');

    final exitCode = await runElvisDemTool(
      args: const ['validate-source'],
      sourceRootPath: sourceRoot.path,
      manifestPath: manifestFile.path,
      homeDirectory: home.path,
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('Checksum mismatch'));
  });

  test(
    'build-all skips source validation by default and writes metadata sidecars',
    () async {
      final sourceRoot = await _createFixtureSourceRoot();
      final manifestFile = File(
        p.join(sourceRoot.parent.path, 'manifest.json'),
      );
      final home = await Directory.systemTemp.createTemp(
        'elvis-dem-build-home',
      );
      addTearDown(() => home.deleteSync(recursive: true));
      await _bootstrapFixtureManifest(
        sourceRoot: sourceRoot,
        manifestFile: manifestFile,
      );

      final recordedCommands = <(String executable, List<String> arguments)>[];
      final requiredCommands = <String>[];

      final exitCode = await runElvisDemTool(
        args: const ['build-all'],
        sourceRootPath: sourceRoot.path,
        manifestPath: manifestFile.path,
        homeDirectory: home.path,
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        commandChecker: (command) async {
          requiredCommands.add(command);
        },
        commandRunner: (executable, arguments) async {
          recordedCommands.add((executable, arguments));
          final outputPath = _fakeCommandOutputPath(executable, arguments);
          await File(outputPath).parent.create(recursive: true);
          if (executable == 'gdalbuildvrt') {
            await _writeFakeVrtFromInputList(outputPath, arguments[1]);
            return const ElvisDemCommandResult();
          }
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
      final topoInputsPath = p.join(
        tasmaniaDemRoot,
        'elvis_topo',
        'inputs.txt',
      );
      final topoVrtPath = p.join(
        tasmaniaDemRoot,
        'elvis_topo',
        'elvis_topo_5m.vrt',
      );
      final reportPath = p.join(
        tasmaniaDemRoot,
        'elvis_reports',
        'build-all-20240102T030405Z.report.json',
      );

      expect(exitCode, 0);
      expect(stderrLines, isEmpty);
      expect(requiredCommands, [
        'gdalbuildvrt',
        'gdalwarp',
        'gdalbuildvrt',
        'gdalwarp',
        'gdaldem',
        'gdal_translate',
      ]);
      expect(recordedCommands, hasLength(6));
      expect(
        stdoutLines,
        contains('Validation skipped; building from 2 manifest entries.'),
      );
      expect(
        stdoutLines.where(
          (line) => line.contains('Validating 2 manifest entries against'),
        ),
        isEmpty,
      );
      expect(
        recordedCommands
            .where((entry) => entry.$1 == 'gdalwarp')
            .map((entry) => entry.$2),
        contains(
          allOf(
            isNot(contains(runtimeArtifactPath)),
            containsAll(['-tr', '10', '10']),
          ),
        ),
      );
      expect(
        recordedCommands
            .where((entry) => entry.$1 == 'gdalwarp')
            .map((entry) => entry.$2),
        contains(
          allOf(
            isNot(contains(topoArtifactPath)),
            containsAll(['-t_srs', 'EPSG:28355']),
            containsAll(['-tr', '5', '5']),
          ),
        ),
      );
      expect(stdoutLines, contains('Artifact: $runtimeArtifactPath'));
      expect(stdoutLines, contains('Artifact: $topoArtifactPath'));
      expect(File(runtimeArtifactPath).existsSync(), isTrue);
      expect(File(topoArtifactPath).existsSync(), isTrue);
      expect(File(topoHillshadePath).existsSync(), isTrue);
      expect(File(topoHillshadePreviewPath).existsSync(), isTrue);
      expect(File(topoInputsPath).existsSync(), isTrue);
      expect(File(topoVrtPath).existsSync(), isFalse);
      expect(File(topoInputsPath).readAsLinesSync(), [
        p.join(sourceRoot.path, 'elevation', '1m-dem', 'tile_a.tif'),
        p.join(sourceRoot.path, 'elevation', '2m-dem', 'tile_b.tif'),
      ]);

      final runtimeMetadata = _readJsonFile(runtimeMetadataPath);
      final topoMetadata = _readJsonFile(topoMetadataPath);
      final report = _readJsonFile(reportPath);

      expect(runtimeMetadata['artifactPath'], runtimeArtifactPath);
      expect(
        (runtimeMetadata['sourceCompleteness']
            as Map<String, dynamic>)['state'],
        'skipped',
      );
      expect(
        (runtimeMetadata['sourceCompleteness']
            as Map<String, dynamic>)['validationEnabled'],
        false,
      );
      expect(
        (runtimeMetadata['derivation']
            as Map<String, dynamic>)['resolutionMeters'],
        10,
      );
      expect(topoMetadata['artifactPath'], topoArtifactPath);
      expect(
        (topoMetadata['derivation'] as Map<String, dynamic>)['targetSrs'],
        'EPSG:28355',
      );
      expect(
        (topoMetadata['derivation']
            as Map<String, dynamic>)['saveIntermediateVrt'],
        false,
      );
      expect(
        (topoMetadata['derivation']
            as Map<String, dynamic>)['savedIntermediateVrtPath'],
        isNull,
      );
      expect(
        (topoMetadata['derivation']
            as Map<String, dynamic>)['projectionGroupAuditPath'],
        isNull,
      );
      expect(report['status'], 'success');
      expect((report['artifacts'] as List), hasLength(2));
      expect(
        (report['validation'] as Map<String, dynamic>)['state'],
        'skipped',
      );
    },
  );

  test('build-topo saves a debugging VRT when --save-vrt is passed', () async {
    final sourceRoot = await _createFixtureSourceRoot();
    final manifestFile = File(p.join(sourceRoot.parent.path, 'manifest.json'));
    final home = await Directory.systemTemp.createTemp('elvis-dem-topo-home');
    addTearDown(() => home.deleteSync(recursive: true));
    await _bootstrapFixtureManifest(
      sourceRoot: sourceRoot,
      manifestFile: manifestFile,
    );

    final recordedCommands = <(String executable, List<String> arguments)>[];

    final exitCode = await runElvisDemTool(
      args: const ['build-topo', '--validate', '--save-vrt'],
      sourceRootPath: sourceRoot.path,
      manifestPath: manifestFile.path,
      homeDirectory: home.path,
      commandChecker: (_) async {},
      commandRunner: (executable, arguments) async {
        recordedCommands.add((executable, arguments));
        final outputPath = _fakeCommandOutputPath(executable, arguments);
        await File(outputPath).parent.create(recursive: true);
        if (executable == 'gdalbuildvrt') {
          await _writeFakeVrtFromInputList(outputPath, arguments[1]);
          return const ElvisDemCommandResult();
        }
        await File(outputPath).writeAsString('$executable output');
        return const ElvisDemCommandResult();
      },
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    final topoMetadataPath = p.join(
      home.path,
      'DEM',
      'Tasmania',
      'elvis_topo',
      'elvis_topo_5m.metadata.json',
    );
    final topoVrtPath = p.join(
      home.path,
      'DEM',
      'Tasmania',
      'elvis_topo',
      'elvis_topo_5m.vrt',
    );
    final hillshadePreviewPath = p.join(
      home.path,
      'DEM',
      'Tasmania',
      'elvis_topo',
      'elvis_topo_5m.hillshade.preview.jpg',
    );
    final topoMetadata = _readJsonFile(topoMetadataPath);

    expect(exitCode, 0);
    expect(stderrLines, isEmpty);
    expect(
      stdoutLines,
      contains('Validating 2 manifest entries against ${sourceRoot.path}'),
    );
    expect(stdoutLines, contains('Validation progress: 2/2'));
    expect(
      (topoMetadata['sourceCompleteness'] as Map<String, dynamic>)['state'],
      'validated',
    );
    expect(File(topoVrtPath).existsSync(), isTrue);
    expect(
      File(topoVrtPath).readAsStringSync(),
      contains('<SourceFilename relativeToVRT="0">'),
    );
    expect(File(hillshadePreviewPath).existsSync(), isTrue);
    expect(
      recordedCommands.where((entry) => entry.$1 == 'gdalwarp').single.$2,
      contains(topoVrtPath),
    );
    expect(
      recordedCommands.where((entry) => entry.$1 == 'gdal_translate').single.$2,
      containsAll(['-outsize', '2880', '0']),
    );
    expect(
      (topoMetadata['sourceCompleteness']
          as Map<String, dynamic>)['validationEnabled'],
      true,
    );
    expect(
      (topoMetadata['derivation']
          as Map<String, dynamic>)['saveIntermediateVrt'],
      true,
    );
    expect(
      (topoMetadata['derivation']
          as Map<String, dynamic>)['savedIntermediateVrtPath'],
      topoVrtPath,
    );
    expect(
      (topoMetadata['derivation']
          as Map<String, dynamic>)['projectionGroupAuditPath'],
      isNull,
    );
  });

  test(
    'build-topo merges skipped projection groups instead of dropping them',
    () async {
      final sourceRoot = await _createFixtureSourceRoot();
      final fiveMeterDir = Directory(
        p.join(sourceRoot.path, 'elevation', '5m-dem'),
      );
      fiveMeterDir.createSync(recursive: true);
      File(
        p.join(fiveMeterDir.path, 'tile_c.tif'),
      ).writeAsStringSync('tile-c-3');
      final manifestFile = File(
        p.join(sourceRoot.parent.path, 'manifest.json'),
      );
      final home = await Directory.systemTemp.createTemp(
        'elvis-dem-mixed-home',
      );
      addTearDown(() => home.deleteSync(recursive: true));
      await _bootstrapFixtureManifest(
        sourceRoot: sourceRoot,
        manifestFile: manifestFile,
      );

      final requiredCommands = <String>[];
      final recordedCommands = <(String executable, List<String> arguments)>[];
      var gdalbuildvrtCallCount = 0;
      final tileAPath = p.join(
        sourceRoot.path,
        'elevation',
        '1m-dem',
        'tile_a.tif',
      );
      final tileBPath = p.join(
        sourceRoot.path,
        'elevation',
        '2m-dem',
        'tile_b.tif',
      );
      final tileCPath = p.join(
        sourceRoot.path,
        'elevation',
        '5m-dem',
        'tile_c.tif',
      );

      final exitCode = await runElvisDemTool(
        args: const ['build-topo', '--save-vrt'],
        sourceRootPath: sourceRoot.path,
        manifestPath: manifestFile.path,
        homeDirectory: home.path,
        commandChecker: (command) async {
          requiredCommands.add(command);
        },
        commandRunner: (executable, arguments) async {
          recordedCommands.add((executable, arguments));
          if (executable == 'gdalbuildvrt') {
            final outputPath = _fakeCommandOutputPath(executable, arguments);
            await File(outputPath).parent.create(recursive: true);
            final inputPaths = File(
              arguments[1],
            ).readAsLinesSync().where((line) => line.isNotEmpty);
            final buffer = StringBuffer('<VRTDataset>\n');
            final sourcePaths = switch (gdalbuildvrtCallCount) {
              0 => inputPaths.where((inputPath) => inputPath == tileAPath),
              1 => inputPaths.where((inputPath) => inputPath == tileCPath),
              _ => inputPaths,
            };
            for (final inputPath in sourcePaths) {
              buffer.writeln(
                '  <SourceFilename relativeToVRT="0">$inputPath</SourceFilename>',
              );
            }
            buffer.write('</VRTDataset>\n');
            await File(outputPath).writeAsString(buffer.toString());
            gdalbuildvrtCallCount += 1;
            if (gdalbuildvrtCallCount == 1) {
              return ElvisDemCommandResult(
                stderr:
                    'Warning 1: gdalbuildvrt does not support heterogeneous projection: expected GDA2020 / MGA zone 55, got GDA94 / MGA zone 55. Skipping $tileCPath\n',
              );
            }
            return const ElvisDemCommandResult();
          }
          final outputPath = _fakeCommandOutputPath(executable, arguments);
          await File(outputPath).parent.create(recursive: true);
          await File(outputPath).writeAsString('$executable output');
          return const ElvisDemCommandResult();
        },
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      final topoArtifactPath = p.join(
        home.path,
        'DEM',
        'Tasmania',
        'elvis_topo',
        'elvis_topo_5m.tif',
      );
      final topoVrtPath = p.join(
        home.path,
        'DEM',
        'Tasmania',
        'elvis_topo',
        'elvis_topo_5m.vrt',
      );
      final topoMetadataPath = p.join(
        home.path,
        'DEM',
        'Tasmania',
        'elvis_topo',
        'elvis_topo_5m.metadata.json',
      );
      final topoMetadata = _readJsonFile(topoMetadataPath);
      final groupAuditPath = p.join(
        home.path,
        'DEM',
        'Tasmania',
        'elvis_topo',
        'elvis_topo_5m.vrt.parts',
        'audit.json',
      );
      final groupAudit = _readJsonFile(groupAuditPath);
      final groupHillshadePreviewPaths = List<String>.generate(
        3,
        (index) => p.join(
          home.path,
          'DEM',
          'Tasmania',
          'elvis_topo',
          'elvis_topo_5m.vrt.parts',
          'projection-group-$index.hillshade.preview.jpg',
        ),
      );

      expect(exitCode, 0);
      expect(stderrLines, isEmpty);
      expect(requiredCommands, contains('gdal_translate'));
      expect(
        stdoutLines,
        contains(
          'Detected at least 2 source projection groups for build-topo; reprojecting groups before merge.',
        ),
      );
      expect(
        stdoutLines,
        contains(
          'Recovered 1 silently skipped raster inputs for build-topo by repartitioning remaining inputs.',
        ),
      );
      expect(File(topoArtifactPath).existsSync(), isTrue);
      expect(File(topoVrtPath).existsSync(), isTrue);
      expect(File(groupAuditPath).existsSync(), isTrue);
      for (final previewPath in groupHillshadePreviewPaths) {
        expect(File(previewPath).existsSync(), isTrue);
      }
      expect(
        recordedCommands.map((entry) => entry.$1).toList(growable: false),
        [
          'gdalbuildvrt',
          'gdalbuildvrt',
          'gdalbuildvrt',
          'gdalwarp',
          'gdalwarp',
          'gdalwarp',
          'gdaldem',
          'gdal_translate',
          'gdaldem',
          'gdal_translate',
          'gdaldem',
          'gdal_translate',
          'gdalbuildvrt',
          'gdal_translate',
          'gdaldem',
          'gdal_translate',
        ],
      );
      expect(
        recordedCommands
            .where((entry) => entry.$1 == 'gdal_translate')
            .where((entry) => entry.$2.last.endsWith('.jpg'))
            .map((entry) => entry.$2)
            .toList(growable: false),
        hasLength(4),
      );
      expect(
        recordedCommands
            .where((entry) => entry.$1 == 'gdal_translate')
            .where((entry) => entry.$2.last.endsWith('.jpg'))
            .map((entry) => entry.$2),
        everyElement(containsAll(['-outsize', '2880', '0'])),
      );
      expect(
        recordedCommands.where((entry) => entry.$1 == 'gdalwarp').first.$2.last,
        contains('.vrt.parts${Platform.pathSeparator}projection-group-0.tif'),
      );
      expect(
        recordedCommands.where((entry) => entry.$1 == 'gdalwarp').first.$2,
        contains(
          p.join(
            home.path,
            'DEM',
            'Tasmania',
            'elvis_topo',
            'elvis_topo_5m.vrt.parts',
            'projection-group-0.vrt',
          ),
        ),
      );
      expect(
        (topoMetadata['derivation']
            as Map<String, dynamic>)['savedIntermediateVrtPath'],
        topoVrtPath,
      );
      expect(
        (topoMetadata['derivation']
            as Map<String, dynamic>)['projectionGroupAuditPath'],
        groupAuditPath,
      );
      expect(groupAudit['groupCount'], 3);
      expect(groupAudit['missingInputCount'], 0);
      expect(groupAudit['missingInputPaths'], isEmpty);
      expect(groupAudit['recoveredSilentlyOmittedCount'], 1);
      expect(groupAudit['recoveredSilentlyOmittedPaths'], [tileBPath]);

      final savedVrt = File(topoVrtPath).readAsStringSync();
      final sourcePaths = RegExp(
        r'<SourceFilename[^>]*>(.*?)</SourceFilename>',
      ).allMatches(savedVrt).map((match) => match.group(1)!).toList();
      expect(sourcePaths, isNotEmpty);
      expect(
        sourcePaths,
        everyElement(contains('.vrt.parts${Platform.pathSeparator}')),
      );
      for (final sourcePath in sourcePaths) {
        expect(File(sourcePath).existsSync(), isTrue);
      }
      final group1VrtPath = p.join(
        home.path,
        'DEM',
        'Tasmania',
        'elvis_topo',
        'elvis_topo_5m.vrt.parts',
        'projection-group-1.vrt',
      );
      final group2VrtPath = p.join(
        home.path,
        'DEM',
        'Tasmania',
        'elvis_topo',
        'elvis_topo_5m.vrt.parts',
        'projection-group-2.vrt',
      );
      final groupVrtContents = [
        File(group1VrtPath).readAsStringSync(),
        File(group2VrtPath).readAsStringSync(),
      ];
      expect(
        groupVrtContents.where((contents) => contents.contains(tileBPath)),
        hasLength(1),
      );
      expect(
        groupVrtContents.where((contents) => contents.contains(tileCPath)),
        hasLength(1),
      );
    },
  );

  test(
    'build-topo stages artifact replacement before publishing output',
    () async {
      final sourceRoot = await _createFixtureSourceRoot();
      final manifestFile = File(
        p.join(sourceRoot.parent.path, 'manifest.json'),
      );
      final home = await Directory.systemTemp.createTemp(
        'elvis-dem-stage-home',
      );
      addTearDown(() => home.deleteSync(recursive: true));
      await _bootstrapFixtureManifest(
        sourceRoot: sourceRoot,
        manifestFile: manifestFile,
      );

      final topoArtifactPath = p.join(
        home.path,
        'DEM',
        'Tasmania',
        'elvis_topo',
        'elvis_topo_5m.tif',
      );
      await File(topoArtifactPath).create(recursive: true);
      await File(topoArtifactPath).writeAsString('old output');

      final recordedCommands = <(String executable, List<String> arguments)>[];

      final exitCode = await runElvisDemTool(
        args: const ['build-topo'],
        sourceRootPath: sourceRoot.path,
        manifestPath: manifestFile.path,
        homeDirectory: home.path,
        commandChecker: (_) async {},
        commandRunner: (executable, arguments) async {
          recordedCommands.add((executable, arguments));
          final outputPath = _fakeCommandOutputPath(executable, arguments);
          await File(outputPath).parent.create(recursive: true);
          if (executable == 'gdalbuildvrt') {
            await _writeFakeVrtFromInputList(outputPath, arguments[1]);
            return const ElvisDemCommandResult();
          }
          await File(outputPath).writeAsString('$executable output');
          return const ElvisDemCommandResult();
        },
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(stderrLines, isEmpty);
      expect(File(topoArtifactPath).readAsStringSync(), 'gdalwarp output');
      expect(
        recordedCommands.where((entry) => entry.$1 == 'gdalwarp').single.$2,
        isNot(contains(topoArtifactPath)),
      );
    },
  );

  test(
    'shell wrapper forwards subcommands and flags to the tool entrypoint',
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
        [scriptPath, 'build-topo', '--validate', '--save-vrt', '--help'],
        environment: {
          ...Platform.environment,
          'PEAK_BAGGER_ELVIS_DEM_TOOL_BINARY': fakeBinary.path,
        },
      );

      expect(result.exitCode, 0);
      expect(argsFile.readAsLinesSync(), [
        'build-topo',
        '--validate',
        '--save-vrt',
        '--help',
      ]);
    },
  );
}

Future<Directory> _createFixtureSourceRoot() async {
  final sourceRoot = await Directory.systemTemp.createTemp('elvis-dem-source');
  addTearDown(() => sourceRoot.deleteSync(recursive: true));

  File(p.join(sourceRoot.path, '.DS_Store')).writeAsStringSync('ignore-me');
  final oneMeterDir = Directory(p.join(sourceRoot.path, 'elevation', '1m-dem'));
  final twoMeterDir = Directory(p.join(sourceRoot.path, 'elevation', '2m-dem'));
  oneMeterDir.createSync(recursive: true);
  twoMeterDir.createSync(recursive: true);
  File(p.join(oneMeterDir.path, 'tile_a.tif')).writeAsStringSync('tile-a-1');
  File(p.join(twoMeterDir.path, 'tile_b.tif')).writeAsStringSync('tile-b-2');
  File(
    p.join(twoMeterDir.path, '.DS_Store'),
  ).writeAsStringSync('ignore-me-too');
  return sourceRoot;
}

Future<void> _bootstrapFixtureManifest({
  required Directory sourceRoot,
  required File manifestFile,
}) async {
  final exitCode = await runElvisDemTool(
    args: const ['bootstrap-manifest'],
    sourceRootPath: sourceRoot.path,
    manifestPath: manifestFile.path,
    clock: () => DateTime.utc(2024, 1, 1),
    stdoutWriter: (_) {},
    stderrWriter: (_) {},
  );
  expect(exitCode, 0);
}

Map<String, dynamic> _readJsonFile(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  return (decoded as Map).cast<String, dynamic>();
}

String _sha256Hex(String input) {
  final bytes = utf8.encode(input);
  return sha256.convert(bytes).toString();
}

String _fakeCommandOutputPath(String executable, List<String> arguments) {
  return switch (executable) {
    'gdaldem' => arguments[2],
    _ => arguments.last,
  };
}

Future<void> _writeFakeVrtFromInputList(
  String outputPath,
  String inputListPath,
) async {
  final inputPaths = File(
    inputListPath,
  ).readAsLinesSync().where((line) => line.isNotEmpty);
  final buffer = StringBuffer('<VRTDataset>\n');
  for (final inputPath in inputPaths) {
    buffer.writeln(
      '  <SourceFilename relativeToVRT="0">$inputPath</SourceFilename>',
    );
  }
  buffer.write('</VRTDataset>\n');
  await File(outputPath).writeAsString(buffer.toString());
}
