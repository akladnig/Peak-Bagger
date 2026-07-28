import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/import_path_helpers.dart';

const elvisDemCanonicalSourcePath =
    '/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics/Tasmania_Statewide_2m_DEM_14-08-2021.tif';
const elvisDemSourceLabel = 'Elvis 2m DEM';

const _runtimeArtifactName = 'elvis_runtime_10m.tif';
const _runtimeMetadataName = 'elvis_runtime_10m.metadata.json';
const _topoArtifactName = 'elvis_topo_5m.tif';
const _topoMetadataName = 'elvis_topo_5m.metadata.json';
const _topoHillshadeArtifactName = 'elvis_topo_5m.hillshade.tif';
const _topoHillshadePreviewName = 'elvis_topo_5m.hillshade.preview.jpg';
const _hillshadePreviewJpegWidthPixels = 2880;

typedef ElvisDemCommandChecker = Future<void> Function(String command);
typedef ElvisDemCommandRunner =
    Future<ElvisDemCommandResult> Function(
      String executable,
      List<String> arguments,
    );
typedef ElvisDemProgressWriter = void Function(String message);

enum _ElvisDemCommand { validateSource, buildRuntime, buildTopo, buildAll }

extension on _ElvisDemCommand {
  String get cliName => switch (this) {
    _ElvisDemCommand.validateSource => 'validate-source',
    _ElvisDemCommand.buildRuntime => 'build-runtime',
    _ElvisDemCommand.buildTopo => 'build-topo',
    _ElvisDemCommand.buildAll => 'build-all',
  };
}

class _Invocation {
  const _Invocation({
    required this.command,
    required this.showHelp,
    required this.validateBuildInputs,
  });

  final _ElvisDemCommand? command;
  final bool showHelp;
  final bool validateBuildInputs;
}

class _SourceValidationResult {
  const _SourceValidationResult({
    required this.sourcePath,
    required this.validatedAtUtc,
    required this.validationEnabled,
    this.error,
  });

  final String sourcePath;
  final String validatedAtUtc;
  final bool validationEnabled;
  final String? error;

  bool get isSuccess => error == null;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'state': isSuccess ? 'validated' : 'failed',
      'validationEnabled': validationEnabled,
      'sourceLabel': elvisDemSourceLabel,
      'sourcePath': sourcePath,
      'validatedAtUtc': validatedAtUtc,
      'sourceComplete': isSuccess,
      if (error != null) 'error': error,
    };
  }
}

class _ArtifactContract {
  const _ArtifactContract({
    required this.command,
    required this.artifactType,
    required this.artifactPath,
    required this.metadataPath,
    required this.resolutionMeters,
    this.targetSrs,
  });

  final String command;
  final String artifactType;
  final String artifactPath;
  final String metadataPath;
  final int resolutionMeters;
  final String? targetSrs;
}

class _BuildArtifactResult {
  const _BuildArtifactResult({
    required this.contract,
    required this.sourcePath,
    required this.executedCommands,
    required this.rasterInputCount,
  });

  final _ArtifactContract contract;
  final String sourcePath;
  final List<Map<String, Object>> executedCommands;
  final int rasterInputCount;
}

class ElvisDemCommandResult {
  const ElvisDemCommandResult({this.stdout = '', this.stderr = ''});

  final String stdout;
  final String stderr;
}

void main(List<String> args) async {
  final exitCode = await runElvisDemTool(args: args);
  exit(exitCode);
}

Future<int> runElvisDemTool({
  List<String> args = const [],
  String sourcePath = elvisDemCanonicalSourcePath,
  ElvisDemCommandChecker? commandChecker,
  ElvisDemCommandRunner? commandRunner,
  String? homeDirectory,
  DateTime Function()? clock,
  Future<void> Function(String path)? sourceReadableChecker,
  void Function(String message)? stdoutWriter,
  void Function(String message)? stderrWriter,
}) async {
  final stdoutLine =
      stdoutWriter ?? ((String message) => stdout.writeln(message));
  final stderrLine =
      stderrWriter ?? ((String message) => stderr.writeln(message));
  final now = clock ?? DateTime.now;
  final requireCommand = commandChecker ?? _requireCommand;
  final runCommand = commandRunner ?? _runCommand;
  final ensureReadableSource = sourceReadableChecker ?? _ensureReadableSource;

  late final _Invocation invocation;
  try {
    invocation = _parseInvocation(args);
  } on Object catch (error) {
    stderrLine(_errorMessage(error));
    stdoutLine(_usage());
    return 1;
  }

  if (invocation.showHelp) {
    stdoutLine(_usage());
    return invocation.command == null ? 1 : 0;
  }

  final command = invocation.command;
  if (command == null) {
    stderrLine('Missing required subcommand.');
    stdoutLine(_usage());
    return 1;
  }

  late final String tasmaniaDemRoot;
  try {
    tasmaniaDemRoot = resolveTasmaniaDemRoot(homeDirectory: homeDirectory);
  } on Object catch (error) {
    stderrLine(_errorMessage(error));
    return 1;
  }

  await Directory(tasmaniaDemRoot).create(recursive: true);
  final reportPath = _reportPath(
    commandName: command.cliName,
    tasmaniaDemRoot: tasmaniaDemRoot,
    timestamp: now().toUtc(),
  );

  if (command == _ElvisDemCommand.validateSource) {
    return _runValidateCommand(
      sourcePath: sourcePath,
      reportPath: reportPath,
      clock: now,
      progressWriter: stdoutLine,
      stdoutLine: stdoutLine,
      stderrLine: stderrLine,
      commandChecker: requireCommand,
      commandRunner: runCommand,
      sourceReadableChecker: ensureReadableSource,
    );
  }

  if (command == _ElvisDemCommand.buildRuntime) {
    final contract = _runtimeContract(tasmaniaDemRoot);
    return _runBuildCommand(
      commandName: command.cliName,
      validateBuildInputs: invocation.validateBuildInputs,
      sourcePath: sourcePath,
      reportPath: reportPath,
      contracts: [contract],
      clock: now,
      progressWriter: stdoutLine,
      stdoutLine: stdoutLine,
      stderrLine: stderrLine,
      commandChecker: requireCommand,
      commandRunner: runCommand,
      sourceReadableChecker: ensureReadableSource,
      action: (validatedSourcePath) async {
        return <_BuildArtifactResult>[
          await _buildArtifact(
            sourcePath: validatedSourcePath,
            contract: contract,
            commandChecker: requireCommand,
            commandRunner: runCommand,
            progressWriter: stdoutLine,
          ),
        ];
      },
    );
  }

  if (command == _ElvisDemCommand.buildTopo) {
    final contract = _topoContract(tasmaniaDemRoot);
    return _runBuildCommand(
      commandName: command.cliName,
      validateBuildInputs: invocation.validateBuildInputs,
      sourcePath: sourcePath,
      reportPath: reportPath,
      contracts: [contract],
      clock: now,
      progressWriter: stdoutLine,
      stdoutLine: stdoutLine,
      stderrLine: stderrLine,
      commandChecker: requireCommand,
      commandRunner: runCommand,
      sourceReadableChecker: ensureReadableSource,
      action: (validatedSourcePath) async {
        return <_BuildArtifactResult>[
          await _buildArtifact(
            sourcePath: validatedSourcePath,
            contract: contract,
            commandChecker: requireCommand,
            commandRunner: runCommand,
            progressWriter: stdoutLine,
          ),
        ];
      },
    );
  }

  final runtimeContract = _runtimeContract(tasmaniaDemRoot);
  final topoContract = _topoContract(tasmaniaDemRoot);
  return _runBuildCommand(
    commandName: command.cliName,
    validateBuildInputs: invocation.validateBuildInputs,
    sourcePath: sourcePath,
    reportPath: reportPath,
    contracts: [runtimeContract, topoContract],
    clock: now,
    progressWriter: stdoutLine,
    stdoutLine: stdoutLine,
    stderrLine: stderrLine,
    commandChecker: requireCommand,
    commandRunner: runCommand,
    sourceReadableChecker: ensureReadableSource,
    action: (validatedSourcePath) async {
      return <_BuildArtifactResult>[
        await _buildArtifact(
          sourcePath: validatedSourcePath,
          contract: runtimeContract,
          commandChecker: requireCommand,
          commandRunner: runCommand,
          progressWriter: stdoutLine,
        ),
        await _buildArtifact(
          sourcePath: validatedSourcePath,
          contract: topoContract,
          commandChecker: requireCommand,
          commandRunner: runCommand,
          progressWriter: stdoutLine,
        ),
      ];
    },
  );
}

_Invocation _parseInvocation(List<String> args) {
  if (args.isEmpty) {
    return const _Invocation(
      command: null,
      showHelp: false,
      validateBuildInputs: false,
    );
  }

  var showHelp = false;
  var validateBuildInputs = false;
  _ElvisDemCommand? command;

  for (final arg in args) {
    if (arg == '--help' || arg == '-h') {
      showHelp = true;
      continue;
    }

    if (arg == '--validate') {
      validateBuildInputs = true;
      continue;
    }

    final parsedCommand = switch (arg) {
      'validate-source' => _ElvisDemCommand.validateSource,
      'build-runtime' => _ElvisDemCommand.buildRuntime,
      'build-topo' => _ElvisDemCommand.buildTopo,
      'build-all' => _ElvisDemCommand.buildAll,
      _ => throw ArgumentError('Unknown subcommand or flag: $arg'),
    };

    if (command != null) {
      throw ArgumentError('Only one subcommand may be provided.');
    }

    command = parsedCommand;
  }

  if (validateBuildInputs &&
      command != _ElvisDemCommand.buildRuntime &&
      command != _ElvisDemCommand.buildTopo &&
      command != _ElvisDemCommand.buildAll) {
    throw ArgumentError(
      '--validate is only supported for build-runtime, build-topo, and build-all.',
    );
  }

  return _Invocation(
    command: command,
    showHelp: showHelp,
    validateBuildInputs: validateBuildInputs,
  );
}

String _usage() {
  return '''
Usage:
  ./elvis_dem.sh validate-source
  ./elvis_dem.sh build-runtime [--validate]
  ./elvis_dem.sh build-topo [--validate]
  ./elvis_dem.sh build-all [--validate]

Contract:
  $elvisDemSourceLabel: $elvisDemCanonicalSourcePath

Flags:
  --validate  Only supported build flag. Before build, check the exact
              canonical Elvis 2m DEM TIFF for existence, readability,
              and GDAL openability. Default: off.
''';
}

Future<int> _runValidateCommand({
  required String sourcePath,
  required String reportPath,
  required DateTime Function() clock,
  required ElvisDemProgressWriter progressWriter,
  required void Function(String message) stdoutLine,
  required void Function(String message) stderrLine,
  required ElvisDemCommandChecker commandChecker,
  required ElvisDemCommandRunner commandRunner,
  required Future<void> Function(String path) sourceReadableChecker,
}) async {
  try {
    final validation = await _validateExactSource(
      sourcePath: sourcePath,
      clock: clock,
      progressWriter: progressWriter,
      commandChecker: commandChecker,
      commandRunner: commandRunner,
      sourceReadableChecker: sourceReadableChecker,
      validationEnabled: true,
    );
    await _writeReport(
      reportPath: reportPath,
      report: <String, Object?>{
        'command': _ElvisDemCommand.validateSource.cliName,
        'status': validation.isSuccess ? 'success' : 'failure',
        'sourceLabel': elvisDemSourceLabel,
        'sourcePath': sourcePath,
        'artifacts': const <Object>[],
        'validation': validation.toJson(),
        if (!validation.isSuccess) 'error': validation.error,
      },
    );
    _printCommandSummary(
      stdoutLine: stdoutLine,
      sourcePath: sourcePath,
      reportPath: reportPath,
      artifactPaths: const <String>[],
    );

    if (!validation.isSuccess) {
      stderrLine(validation.error!);
      return 1;
    }

    return 0;
  } on Object catch (error, stackTrace) {
    await _writeFailureReport(
      reportPath: reportPath,
      commandName: _ElvisDemCommand.validateSource.cliName,
      sourcePath: sourcePath,
      artifactPaths: const <String>[],
      error: error,
      stackTrace: stackTrace,
    );
    _printCommandSummary(
      stdoutLine: stdoutLine,
      sourcePath: sourcePath,
      reportPath: reportPath,
      artifactPaths: const <String>[],
    );
    stderrLine(_errorMessage(error));
    return 1;
  }
}

Future<int> _runBuildCommand({
  required String commandName,
  required bool validateBuildInputs,
  required String sourcePath,
  required String reportPath,
  required List<_ArtifactContract> contracts,
  required DateTime Function() clock,
  required ElvisDemProgressWriter progressWriter,
  required void Function(String message) stdoutLine,
  required void Function(String message) stderrLine,
  required ElvisDemCommandChecker commandChecker,
  required ElvisDemCommandRunner commandRunner,
  required Future<void> Function(String path) sourceReadableChecker,
  required Future<List<_BuildArtifactResult>> Function(String sourcePath)
  action,
}) async {
  final artifactPaths = contracts
      .map((contract) => contract.artifactPath)
      .toList(growable: false);

  try {
    _SourceValidationResult? validation;
    if (validateBuildInputs) {
      validation = await _validateExactSource(
        sourcePath: sourcePath,
        clock: clock,
        progressWriter: progressWriter,
        commandChecker: commandChecker,
        commandRunner: commandRunner,
        sourceReadableChecker: sourceReadableChecker,
        validationEnabled: true,
      );
      if (!validation.isSuccess) {
        await _writeReport(
          reportPath: reportPath,
          report: <String, Object?>{
            'command': commandName,
            'status': 'failure',
            'sourceLabel': elvisDemSourceLabel,
            'sourcePath': sourcePath,
            'artifacts': contracts
                .map(_artifactContractToJson)
                .toList(growable: false),
            'validation': validation.toJson(),
            'error': validation.error,
          },
        );
        _printCommandSummary(
          stdoutLine: stdoutLine,
          sourcePath: sourcePath,
          reportPath: reportPath,
          artifactPaths: artifactPaths,
        );
        stderrLine(validation.error!);
        return 1;
      }
    } else {
      progressWriter(
        'Validation skipped; building directly from the exact canonical Elvis 2m DEM file.',
      );
    }

    final buildResults = await action(sourcePath);
    for (final result in buildResults) {
      await _writeArtifactMetadata(
        sourcePath: sourcePath,
        validation: validation,
        validateBuildInputs: validateBuildInputs,
        buildResult: result,
        clock: clock,
      );
    }

    await _writeReport(
      reportPath: reportPath,
      report: <String, Object?>{
        'command': commandName,
        'status': 'success',
        'sourceLabel': elvisDemSourceLabel,
        'sourcePath': sourcePath,
        'artifacts': buildResults
            .map(_buildResultToJson)
            .toList(growable: false),
        'validation': _buildValidationSummary(
          sourcePath: sourcePath,
          validation: validation,
          validateBuildInputs: validateBuildInputs,
        ),
      },
    );
    _printCommandSummary(
      stdoutLine: stdoutLine,
      sourcePath: sourcePath,
      reportPath: reportPath,
      artifactPaths: artifactPaths,
    );
    return 0;
  } on Object catch (error, stackTrace) {
    await _writeFailureReport(
      reportPath: reportPath,
      commandName: commandName,
      sourcePath: sourcePath,
      artifactPaths: artifactPaths,
      error: error,
      stackTrace: stackTrace,
    );
    _printCommandSummary(
      stdoutLine: stdoutLine,
      sourcePath: sourcePath,
      reportPath: reportPath,
      artifactPaths: artifactPaths,
    );
    stderrLine(_errorMessage(error));
    return 1;
  }
}

Future<_SourceValidationResult> _validateExactSource({
  required String sourcePath,
  required DateTime Function() clock,
  required ElvisDemProgressWriter progressWriter,
  required ElvisDemCommandChecker commandChecker,
  required ElvisDemCommandRunner commandRunner,
  required Future<void> Function(String path) sourceReadableChecker,
  required bool validationEnabled,
}) async {
  final validatedAtUtc = clock().toUtc().toIso8601String();

  try {
    progressWriter('Checking exact Elvis 2m DEM file: $sourcePath');
    await sourceReadableChecker(sourcePath);
    progressWriter('Opening Elvis 2m DEM with gdalinfo: $sourcePath');
    await _ensureOpenableByGdal(
      sourcePath: sourcePath,
      commandChecker: commandChecker,
      commandRunner: commandRunner,
    );
    return _SourceValidationResult(
      sourcePath: sourcePath,
      validatedAtUtc: validatedAtUtc,
      validationEnabled: validationEnabled,
    );
  } on Object catch (error) {
    return _SourceValidationResult(
      sourcePath: sourcePath,
      validatedAtUtc: validatedAtUtc,
      validationEnabled: validationEnabled,
      error: _errorMessage(error),
    );
  }
}

Future<void> _ensureReadableSource(String sourcePath) async {
  final sourceType = await FileSystemEntity.type(sourcePath, followLinks: true);
  if (sourceType != FileSystemEntityType.file) {
    throw StateError('Missing exact Elvis 2m DEM TIFF at $sourcePath.');
  }

  final sourceFile = File(sourcePath);
  try {
    final handle = await sourceFile.open(mode: FileMode.read);
    await handle.close();
  } on FileSystemException catch (error) {
    throw StateError(
      'Elvis 2m DEM is not readable at $sourcePath. ${error.message}',
    );
  }
}

Future<void> _ensureOpenableByGdal({
  required String sourcePath,
  required ElvisDemCommandChecker commandChecker,
  required ElvisDemCommandRunner commandRunner,
}) async {
  try {
    await commandChecker('gdalinfo');
    await commandRunner('gdalinfo', [sourcePath]);
  } on Object catch (error) {
    throw StateError(
      'Elvis 2m DEM could not be opened by gdalinfo at $sourcePath. ${_errorMessage(error)}',
    );
  }
}

Future<_BuildArtifactResult> _buildArtifact({
  required String sourcePath,
  required _ArtifactContract contract,
  required ElvisDemCommandChecker commandChecker,
  required ElvisDemCommandRunner commandRunner,
  ElvisDemProgressWriter? progressWriter,
}) async {
  await commandChecker('gdalwarp');

  final outputFile = File(contract.artifactPath);
  await outputFile.parent.create(recursive: true);
  final stagedOutputPath = _stagedSiblingPath(outputFile.path);
  final executedCommands = <Map<String, Object>>[];

  try {
    progressWriter?.call('Running gdalwarp for ${contract.command}...');
    await _runTrackedCommand(
      commandRunner: commandRunner,
      executedCommands: executedCommands,
      executable: 'gdalwarp',
      arguments: _warpArguments(
        contract: contract,
        inputPath: sourcePath,
        outputPath: stagedOutputPath,
      ),
    );

    if (!await File(stagedOutputPath).exists()) {
      throw StateError(
        'Expected staged output artifact was not created: $stagedOutputPath',
      );
    }

    await _replaceFileAtomically(stagedOutputPath, outputFile.path);

    if (!await outputFile.exists()) {
      throw StateError(
        'Expected output artifact was not created: ${outputFile.path}',
      );
    }

    await _writeTopoHillshadePreviewArtifacts(
      contract: contract,
      commandChecker: commandChecker,
      commandRunner: commandRunner,
      executedCommands: executedCommands,
      progressWriter: progressWriter,
    );

    progressWriter?.call(
      'Finished ${contract.command}: ${contract.artifactPath}',
    );

    return _BuildArtifactResult(
      contract: contract,
      sourcePath: sourcePath,
      executedCommands: executedCommands,
      rasterInputCount: 1,
    );
  } finally {
    final stagedOutputFile = File(stagedOutputPath);
    if (await stagedOutputFile.exists()) {
      await stagedOutputFile.delete();
    }
  }
}

Future<void> _writeArtifactMetadata({
  required String sourcePath,
  required _SourceValidationResult? validation,
  required bool validateBuildInputs,
  required _BuildArtifactResult buildResult,
  required DateTime Function() clock,
}) {
  return _writeJsonFile(buildResult.contract.metadataPath, <String, Object?>{
    'artifactType': buildResult.contract.artifactType,
    'artifactPath': buildResult.contract.artifactPath,
    'generatedAtUtc': clock().toUtc().toIso8601String(),
    'sourceCompleteness': _buildSourceCompletenessMetadata(
      sourcePath: sourcePath,
      validation: validation,
      validateBuildInputs: validateBuildInputs,
    ),
    'derivation': <String, Object?>{
      'command': buildResult.contract.command,
      'sourcePath': buildResult.sourcePath,
      'resolutionMeters': buildResult.contract.resolutionMeters,
      'targetSrs': buildResult.contract.targetSrs,
      'resampling': 'bilinear',
      'rasterInputCount': buildResult.rasterInputCount,
      'commands': buildResult.executedCommands,
    },
  });
}

Map<String, Object?> _buildValidationSummary({
  required String sourcePath,
  required _SourceValidationResult? validation,
  required bool validateBuildInputs,
}) {
  if (validation != null) {
    return validation.toJson();
  }

  return <String, Object?>{
    'state': 'skipped',
    'validationEnabled': validateBuildInputs,
    'sourceLabel': elvisDemSourceLabel,
    'sourcePath': sourcePath,
  };
}

Map<String, Object?> _buildSourceCompletenessMetadata({
  required String sourcePath,
  required _SourceValidationResult? validation,
  required bool validateBuildInputs,
}) {
  if (validation != null) {
    return <String, Object?>{
      'state': 'validated',
      'validationEnabled': validateBuildInputs,
      'sourceLabel': elvisDemSourceLabel,
      'sourcePath': validation.sourcePath,
      'validatedAtUtc': validation.validatedAtUtc,
      'sourceComplete': validation.isSuccess,
    };
  }

  return <String, Object?>{
    'state': 'skipped',
    'validationEnabled': validateBuildInputs,
    'sourceLabel': elvisDemSourceLabel,
    'sourcePath': sourcePath,
  };
}

Future<ElvisDemCommandResult> _runTrackedCommand({
  required ElvisDemCommandRunner commandRunner,
  required List<Map<String, Object>> executedCommands,
  required String executable,
  required List<String> arguments,
}) async {
  executedCommands.add(<String, Object>{
    'executable': executable,
    'arguments': arguments,
  });
  return commandRunner(executable, arguments);
}

Future<void> _writeTopoHillshadePreviewArtifacts({
  required _ArtifactContract contract,
  required ElvisDemCommandChecker commandChecker,
  required ElvisDemCommandRunner commandRunner,
  required List<Map<String, Object>> executedCommands,
  ElvisDemProgressWriter? progressWriter,
}) async {
  if (contract.artifactType != 'elvis-topo-dem') {
    return;
  }

  await commandChecker('gdaldem');
  await commandChecker('gdal_translate');

  final hillshadePath = p.join(
    p.dirname(contract.artifactPath),
    _topoHillshadeArtifactName,
  );
  final hillshadePreviewPath = p.join(
    p.dirname(contract.artifactPath),
    _topoHillshadePreviewName,
  );
  final stagedHillshadePath = _stagedSiblingPath(hillshadePath);
  final stagedHillshadePreviewPath = _stagedSiblingPath(hillshadePreviewPath);

  try {
    progressWriter?.call(
      'Running gdaldem hillshade for ${contract.command}...',
    );
    await _runTrackedCommand(
      commandRunner: commandRunner,
      executedCommands: executedCommands,
      executable: 'gdaldem',
      arguments: _hillshadeArguments(
        inputPath: contract.artifactPath,
        outputPath: stagedHillshadePath,
      ),
    );

    if (!await File(stagedHillshadePath).exists()) {
      throw StateError(
        'Expected staged hillshade artifact was not created: $stagedHillshadePath',
      );
    }

    await _replaceFileAtomically(stagedHillshadePath, hillshadePath);

    progressWriter?.call(
      'Running gdal_translate hillshade preview for ${contract.command}...',
    );
    await _runTrackedCommand(
      commandRunner: commandRunner,
      executedCommands: executedCommands,
      executable: 'gdal_translate',
      arguments: _jpegPreviewArguments(
        inputPath: hillshadePath,
        outputPath: stagedHillshadePreviewPath,
      ),
    );

    if (!await File(stagedHillshadePreviewPath).exists()) {
      throw StateError(
        'Expected staged hillshade preview artifact was not created: $stagedHillshadePreviewPath',
      );
    }

    await _replaceFileAtomically(
      stagedHillshadePreviewPath,
      hillshadePreviewPath,
    );
  } finally {
    final stagedHillshadeFile = File(stagedHillshadePath);
    if (await stagedHillshadeFile.exists()) {
      await stagedHillshadeFile.delete();
    }

    final stagedHillshadePreviewFile = File(stagedHillshadePreviewPath);
    if (await stagedHillshadePreviewFile.exists()) {
      await stagedHillshadePreviewFile.delete();
    }
  }
}

List<String> _warpArguments({
  required _ArtifactContract contract,
  required String inputPath,
  required String outputPath,
}) {
  return <String>[
    '-overwrite',
    '-r',
    'bilinear',
    '-tr',
    '${contract.resolutionMeters}',
    '${contract.resolutionMeters}',
    '-multi',
    '-wo',
    'NUM_THREADS=ALL_CPUS',
    if (contract.targetSrs != null) ...['-t_srs', contract.targetSrs!],
    '-of',
    'GTiff',
    '-co',
    'TILED=YES',
    '-co',
    'COMPRESS=DEFLATE',
    '-co',
    'BIGTIFF=IF_SAFER',
    inputPath,
    outputPath,
  ];
}

List<String> _hillshadeArguments({
  required String inputPath,
  required String outputPath,
}) {
  return <String>[
    'hillshade',
    inputPath,
    outputPath,
    '-of',
    'GTiff',
    '-compute_edges',
    '-multidirectional',
  ];
}

List<String> _jpegPreviewArguments({
  required String inputPath,
  required String outputPath,
}) {
  return <String>[
    '-of',
    'JPEG',
    '-outsize',
    '$_hillshadePreviewJpegWidthPixels',
    '0',
    '-co',
    'QUALITY=90',
    inputPath,
    outputPath,
  ];
}

String _reportPath({
  required String commandName,
  required String tasmaniaDemRoot,
  required DateTime timestamp,
}) {
  final utc = timestamp.toUtc();
  final formattedTimestamp =
      '${utc.year.toString().padLeft(4, '0')}'
      '${utc.month.toString().padLeft(2, '0')}'
      '${utc.day.toString().padLeft(2, '0')}'
      'T'
      '${utc.hour.toString().padLeft(2, '0')}'
      '${utc.minute.toString().padLeft(2, '0')}'
      '${utc.second.toString().padLeft(2, '0')}Z';
  return p.join(
    tasmaniaDemRoot,
    'elvis_reports',
    '$commandName-$formattedTimestamp.report.json',
  );
}

void _printCommandSummary({
  required void Function(String message) stdoutLine,
  required String sourcePath,
  required String reportPath,
  required List<String> artifactPaths,
}) {
  stdoutLine('Raw source: $sourcePath');
  if (artifactPaths.isEmpty) {
    stdoutLine('Artifacts: none');
  } else {
    for (final artifactPath in artifactPaths) {
      stdoutLine('Artifact: $artifactPath');
    }
  }
  stdoutLine('Report: $reportPath');
}

Map<String, Object?> _artifactContractToJson(_ArtifactContract contract) {
  return <String, Object?>{
    'artifactType': contract.artifactType,
    'artifactPath': contract.artifactPath,
    'metadataPath': contract.metadataPath,
    'resolutionMeters': contract.resolutionMeters,
    'targetSrs': contract.targetSrs,
  };
}

Map<String, Object?> _buildResultToJson(_BuildArtifactResult result) {
  return <String, Object?>{
    ..._artifactContractToJson(result.contract),
    'sourcePath': result.sourcePath,
    'rasterInputCount': result.rasterInputCount,
    'commands': result.executedCommands,
  };
}

_ArtifactContract _runtimeContract(String tasmaniaDemRoot) {
  return _ArtifactContract(
    command: _ElvisDemCommand.buildRuntime.cliName,
    artifactType: 'elvis-runtime-dem',
    artifactPath: p.join(tasmaniaDemRoot, _runtimeArtifactName),
    metadataPath: p.join(tasmaniaDemRoot, _runtimeMetadataName),
    resolutionMeters: 10,
    targetSrs: 'EPSG:7855',
  );
}

_ArtifactContract _topoContract(String tasmaniaDemRoot) {
  final topoRoot = p.join(tasmaniaDemRoot, 'elvis_topo');
  return _ArtifactContract(
    command: _ElvisDemCommand.buildTopo.cliName,
    artifactType: 'elvis-topo-dem',
    artifactPath: p.join(topoRoot, _topoArtifactName),
    metadataPath: p.join(topoRoot, _topoMetadataName),
    resolutionMeters: 5,
    targetSrs: 'EPSG:28355',
  );
}

Future<void> _writeReport({
  required String reportPath,
  required Map<String, Object?> report,
}) async {
  await _writeJsonFile(reportPath, report);
}

Future<void> _writeFailureReport({
  required String reportPath,
  required String commandName,
  required String sourcePath,
  required List<String> artifactPaths,
  required Object error,
  required StackTrace stackTrace,
}) {
  return _writeReport(
    reportPath: reportPath,
    report: <String, Object?>{
      'command': commandName,
      'status': 'failure',
      'sourceLabel': elvisDemSourceLabel,
      'sourcePath': sourcePath,
      'artifacts': artifactPaths,
      'error': _errorMessage(error),
      'stackTrace': stackTrace.toString(),
    },
  );
}

Future<void> _writeJsonFile(String path, Map<String, Object?> json) async {
  final contents = const JsonEncoder.withIndent('  ').convert(json);
  await _writeTextFileAtomically(path, '$contents\n');
}

Future<void> _writeTextFileAtomically(String path, String contents) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final tempPath = _stagedSiblingPath(path);
  final tempFile = File(tempPath);
  await tempFile.writeAsString(contents);
  await _replaceFileAtomically(tempPath, file.path);
}

String _stagedSiblingPath(String path) {
  final directory = p.dirname(path);
  final extension = p.extension(path);
  final basenameWithoutExtension = p.basenameWithoutExtension(path);
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  return p.join(
    directory,
    '$basenameWithoutExtension.$timestamp.tmp$extension',
  );
}

Future<void> _replaceFileAtomically(
  String stagedPath,
  String destinationPath,
) async {
  final destinationFile = File(destinationPath);
  await destinationFile.parent.create(recursive: true);
  if (await destinationFile.exists()) {
    await destinationFile.delete();
  }
  await File(stagedPath).rename(destinationPath);
}

Future<void> _requireCommand(String command) async {
  final result = await Process.run('which', [command]);
  if (result.exitCode != 0) {
    throw StateError('Required command not found on PATH: $command');
  }
}

Future<ElvisDemCommandResult> _runCommand(
  String executable,
  List<String> arguments,
) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode == 0) {
    return ElvisDemCommandResult(
      stdout: result.stdout.toString(),
      stderr: result.stderr.toString(),
    );
  }

  final stderrOutput = result.stderr.toString().trim();
  throw ProcessException(
    executable,
    arguments,
    stderrOutput.isEmpty ? result.stdout.toString() : stderrOutput,
    result.exitCode,
  );
}

String _errorMessage(Object error) {
  final message = error.toString();
  for (final prefix in const ['Bad state: ', 'StateError: ', 'Exception: ']) {
    if (message.startsWith(prefix)) {
      return message.substring(prefix.length);
    }
  }
  return message;
}
