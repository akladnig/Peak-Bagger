import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/import_path_helpers.dart';

const elvisDemCanonicalSourceRoot = '/Volumes/Media/Elvis/tas-elvis';
const elvisDemManifestPath = 'tool/elvis_dem_manifest.json';

const _runtimeArtifactName = 'elvis_runtime_10m.tif';
const _runtimeMetadataName = 'elvis_runtime_10m.metadata.json';
const _topoArtifactName = 'elvis_topo_5m.tif';
const _topoMetadataName = 'elvis_topo_5m.metadata.json';

const _ignoredPayloadBasenames = <String>{'.DS_Store'};
const _rasterExtensions = <String>{'.tif', '.tiff', '.img'};

typedef ElvisDemCommandChecker = Future<void> Function(String command);
typedef ElvisDemCommandRunner =
    Future<void> Function(String executable, List<String> arguments);
typedef ElvisDemProgressWriter = void Function(String message);

const _progressLogInterval = 5000;

enum _ElvisDemCommand {
  bootstrapManifest,
  validateSource,
  buildRuntime,
  buildTopo,
  buildAll,
}

extension on _ElvisDemCommand {
  String get cliName => switch (this) {
    _ElvisDemCommand.bootstrapManifest => 'bootstrap-manifest',
    _ElvisDemCommand.validateSource => 'validate-source',
    _ElvisDemCommand.buildRuntime => 'build-runtime',
    _ElvisDemCommand.buildTopo => 'build-topo',
    _ElvisDemCommand.buildAll => 'build-all',
  };
}

class _Invocation {
  const _Invocation({required this.command, required this.showHelp});

  final _ElvisDemCommand? command;
  final bool showHelp;
}

class _ManifestEntry {
  const _ManifestEntry({
    required this.relativePath,
    required this.bytes,
    required this.sha256,
  });

  final String relativePath;
  final int bytes;
  final String sha256;

  Map<String, Object> toJson() {
    return <String, Object>{
      'path': relativePath,
      'bytes': bytes,
      'sha256': sha256,
    };
  }

  static _ManifestEntry fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    final bytes = json['bytes'];
    final checksum = json['sha256'];
    if (path is! String || path.isEmpty) {
      throw StateError('Manifest entry path must be a non-empty string.');
    }
    if (bytes is! int || bytes < 0) {
      throw StateError('Manifest entry bytes must be a non-negative integer.');
    }
    if (checksum is! String || !_isSha256Hex(checksum)) {
      throw StateError(
        'Manifest entry sha256 must be 64 lowercase hexadecimal characters.',
      );
    }

    return _ManifestEntry(relativePath: path, bytes: bytes, sha256: checksum);
  }
}

class _Manifest {
  const _Manifest({
    required this.sourceRoot,
    required this.generatedAtUtc,
    required this.fileCount,
    required this.totalBytes,
    required this.files,
  });

  final String sourceRoot;
  final String generatedAtUtc;
  final int fileCount;
  final int totalBytes;
  final List<_ManifestEntry> files;

  Map<String, Object> toJson() {
    return <String, Object>{
      'sourceRoot': sourceRoot,
      'generatedAtUtc': generatedAtUtc,
      'fileCount': fileCount,
      'totalBytes': totalBytes,
      'files': files.map((entry) => entry.toJson()).toList(growable: false),
    };
  }

  static _Manifest fromJson(Map<String, dynamic> json) {
    final sourceRoot = json['sourceRoot'];
    final generatedAtUtc = json['generatedAtUtc'];
    final fileCount = json['fileCount'];
    final totalBytes = json['totalBytes'];
    final filesValue = json['files'];

    if (sourceRoot is! String || sourceRoot.isEmpty) {
      throw StateError('Manifest sourceRoot must be a non-empty string.');
    }
    if (generatedAtUtc is! String || generatedAtUtc.isEmpty) {
      throw StateError('Manifest generatedAtUtc must be a non-empty string.');
    }
    if (fileCount is! int || fileCount < 0) {
      throw StateError('Manifest fileCount must be a non-negative integer.');
    }
    if (totalBytes is! int || totalBytes < 0) {
      throw StateError('Manifest totalBytes must be a non-negative integer.');
    }
    if (filesValue is! List) {
      throw StateError('Manifest files must be a JSON array.');
    }

    final files =
        filesValue
            .map((value) {
              if (value is! Map<String, dynamic>) {
                throw StateError('Manifest file entries must be JSON objects.');
              }
              return _ManifestEntry.fromJson(value);
            })
            .toList(growable: false)
          ..sort(
            (left, right) => left.relativePath.compareTo(right.relativePath),
          );

    return _Manifest(
      sourceRoot: sourceRoot,
      generatedAtUtc: generatedAtUtc,
      fileCount: fileCount,
      totalBytes: totalBytes,
      files: files,
    );
  }
}

class _ValidationResult {
  const _ValidationResult({
    required this.manifest,
    required this.validatedAtUtc,
    required this.missingFiles,
    required this.unexpectedFiles,
    required this.wrongSizeFiles,
    required this.checksumMismatchFiles,
    required this.manifestConsistencyErrors,
  });

  final _Manifest manifest;
  final String validatedAtUtc;
  final List<String> missingFiles;
  final List<String> unexpectedFiles;
  final List<Map<String, Object>> wrongSizeFiles;
  final List<Map<String, Object>> checksumMismatchFiles;
  final List<String> manifestConsistencyErrors;

  bool get isSuccess {
    return missingFiles.isEmpty &&
        unexpectedFiles.isEmpty &&
        wrongSizeFiles.isEmpty &&
        checksumMismatchFiles.isEmpty &&
        manifestConsistencyErrors.isEmpty;
  }

  String failureSummary() {
    final parts = <String>[];
    if (manifestConsistencyErrors.isNotEmpty) {
      parts.add(manifestConsistencyErrors.first);
    }
    if (missingFiles.isNotEmpty) {
      parts.add('Missing expected file: ${missingFiles.first}');
    }
    if (wrongSizeFiles.isNotEmpty) {
      final failure = wrongSizeFiles.first;
      parts.add(
        'Wrong size for ${failure['path']}: expected ${failure['expectedBytes']} bytes, got ${failure['actualBytes']}',
      );
    }
    if (checksumMismatchFiles.isNotEmpty) {
      final failure = checksumMismatchFiles.first;
      parts.add(
        'Checksum mismatch for ${failure['path']}: expected ${failure['expectedSha256']}, got ${failure['actualSha256']}',
      );
    }
    if (unexpectedFiles.isNotEmpty) {
      parts.add('Unexpected payload file: ${unexpectedFiles.first}');
    }
    return parts.join('; ');
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'validatedAtUtc': validatedAtUtc,
      'sourceComplete': isSuccess,
      'manifest': manifest.toJson(),
      'manifestConsistencyErrors': manifestConsistencyErrors,
      'missingFiles': missingFiles,
      'unexpectedFiles': unexpectedFiles,
      'wrongSizeFiles': wrongSizeFiles,
      'checksumMismatchFiles': checksumMismatchFiles,
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
    required this.executedCommands,
    required this.rasterInputCount,
  });

  final _ArtifactContract contract;
  final List<Map<String, Object>> executedCommands;
  final int rasterInputCount;
}

void main(List<String> args) async {
  final exitCode = await runElvisDemTool(args: args);
  exit(exitCode);
}

Future<int> runElvisDemTool({
  List<String> args = const [],
  String sourceRootPath = elvisDemCanonicalSourceRoot,
  String manifestPath = elvisDemManifestPath,
  ElvisDemCommandChecker? commandChecker,
  ElvisDemCommandRunner? commandRunner,
  String? homeDirectory,
  bool Function(String path)? directoryExists,
  DateTime Function()? clock,
  void Function(String message)? stdoutWriter,
  void Function(String message)? stderrWriter,
}) async {
  final stdoutLine =
      stdoutWriter ?? ((String message) => stdout.writeln(message));
  final stderrLine =
      stderrWriter ?? ((String message) => stderr.writeln(message));
  final now = clock ?? DateTime.now;

  late final _Invocation invocation;
  try {
    invocation = _parseInvocation(args);
  } on Object catch (error) {
    stderrLine(error.toString());
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

  if (command == _ElvisDemCommand.bootstrapManifest) {
    try {
      final manifest = await _createManifest(
        sourceRootPath: sourceRootPath,
        generatedAt: now().toUtc(),
        progressWriter: stdoutLine,
      );
      await _writeJsonFile(manifestPath, manifest.toJson());
      stdoutLine('Raw source: $sourceRootPath');
      stdoutLine('Manifest: $manifestPath');
      return 0;
    } on Object catch (error) {
      stderrLine(error.toString());
      return 1;
    }
  }

  late final String tasmaniaDemRoot;
  try {
    tasmaniaDemRoot = resolveTasmaniaDemRoot(
      homeDirectory: homeDirectory,
      directoryExists: directoryExists,
    );
  } on Object catch (error) {
    stderrLine(error.toString());
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
      sourceRootPath: sourceRootPath,
      manifestPath: manifestPath,
      reportPath: reportPath,
      clock: now,
      progressWriter: stdoutLine,
      stdoutLine: stdoutLine,
      stderrLine: stderrLine,
    );
  }

  final commandRequirements = commandChecker ?? _requireCommand;
  final commandExecution = commandRunner ?? _runCommand;

  if (command == _ElvisDemCommand.buildRuntime) {
    final contract = _runtimeContract(tasmaniaDemRoot);
    return _runBuildCommand(
      commandName: command.cliName,
      sourceRootPath: sourceRootPath,
      manifestPath: manifestPath,
      reportPath: reportPath,
      contracts: [contract],
      clock: now,
      progressWriter: stdoutLine,
      stdoutLine: stdoutLine,
      stderrLine: stderrLine,
      action: (validation) async {
        return <_BuildArtifactResult>[
          await _buildArtifact(
            validation: validation,
            contract: contract,
            commandChecker: commandRequirements,
            commandRunner: commandExecution,
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
      sourceRootPath: sourceRootPath,
      manifestPath: manifestPath,
      reportPath: reportPath,
      contracts: [contract],
      clock: now,
      progressWriter: stdoutLine,
      stdoutLine: stdoutLine,
      stderrLine: stderrLine,
      action: (validation) async {
        return <_BuildArtifactResult>[
          await _buildArtifact(
            validation: validation,
            contract: contract,
            commandChecker: commandRequirements,
            commandRunner: commandExecution,
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
    sourceRootPath: sourceRootPath,
    manifestPath: manifestPath,
    reportPath: reportPath,
    contracts: [runtimeContract, topoContract],
    clock: now,
    progressWriter: stdoutLine,
    stdoutLine: stdoutLine,
    stderrLine: stderrLine,
    action: (validation) async {
      return <_BuildArtifactResult>[
        await _buildArtifact(
          validation: validation,
          contract: runtimeContract,
          commandChecker: commandRequirements,
          commandRunner: commandExecution,
          progressWriter: stdoutLine,
        ),
        await _buildArtifact(
          validation: validation,
          contract: topoContract,
          commandChecker: commandRequirements,
          commandRunner: commandExecution,
          progressWriter: stdoutLine,
        ),
      ];
    },
  );
}

_Invocation _parseInvocation(List<String> args) {
  if (args.isEmpty) {
    return const _Invocation(command: null, showHelp: false);
  }

  var showHelp = false;
  _ElvisDemCommand? command;

  for (final arg in args) {
    if (arg == '--help' || arg == '-h') {
      showHelp = true;
      continue;
    }

    command ??= switch (arg) {
      'bootstrap-manifest' => _ElvisDemCommand.bootstrapManifest,
      'validate-source' => _ElvisDemCommand.validateSource,
      'build-runtime' => _ElvisDemCommand.buildRuntime,
      'build-topo' => _ElvisDemCommand.buildTopo,
      'build-all' => _ElvisDemCommand.buildAll,
      _ => throw ArgumentError('Unknown subcommand or flag: $arg'),
    };

    if (command.cliName != arg) {
      throw ArgumentError('Only one subcommand may be provided.');
    }
  }

  return _Invocation(command: command, showHelp: showHelp);
}

String _usage() {
  return '''
Usage:
  ./elvis_dem.sh bootstrap-manifest
  ./elvis_dem.sh validate-source
  ./elvis_dem.sh build-runtime
  ./elvis_dem.sh build-topo
  ./elvis_dem.sh build-all

Contracts:
  raw source: $elvisDemCanonicalSourceRoot
  manifest: $elvisDemManifestPath
''';
}

Future<int> _runValidateCommand({
  required String sourceRootPath,
  required String manifestPath,
  required String reportPath,
  required DateTime Function() clock,
  required ElvisDemProgressWriter progressWriter,
  required void Function(String message) stdoutLine,
  required void Function(String message) stderrLine,
}) async {
  try {
    final validation = await _loadAndValidateSource(
      sourceRootPath: sourceRootPath,
      manifestPath: manifestPath,
      clock: clock,
      progressWriter: progressWriter,
    );
    await _writeReport(
      reportPath: reportPath,
      report: <String, Object>{
        'command': _ElvisDemCommand.validateSource.cliName,
        'status': validation.isSuccess ? 'success' : 'failure',
        'sourceRoot': sourceRootPath,
        'manifestPath': manifestPath,
        'artifacts': const <Object>[],
        'validation': validation.toJson(),
      },
    );
    _printCommandSummary(
      stdoutLine: stdoutLine,
      sourceRootPath: sourceRootPath,
      reportPath: reportPath,
      artifactPaths: const <String>[],
    );

    if (!validation.isSuccess) {
      stderrLine(validation.failureSummary());
      return 1;
    }

    return 0;
  } on Object catch (error, stackTrace) {
    await _writeFailureReport(
      reportPath: reportPath,
      commandName: _ElvisDemCommand.validateSource.cliName,
      sourceRootPath: sourceRootPath,
      manifestPath: manifestPath,
      artifactPaths: const <String>[],
      error: error,
      stackTrace: stackTrace,
    );
    _printCommandSummary(
      stdoutLine: stdoutLine,
      sourceRootPath: sourceRootPath,
      reportPath: reportPath,
      artifactPaths: const <String>[],
    );
    stderrLine(error.toString());
    return 1;
  }
}

Future<int> _runBuildCommand({
  required String commandName,
  required String sourceRootPath,
  required String manifestPath,
  required String reportPath,
  required List<_ArtifactContract> contracts,
  required DateTime Function() clock,
  required ElvisDemProgressWriter progressWriter,
  required void Function(String message) stdoutLine,
  required void Function(String message) stderrLine,
  required Future<List<_BuildArtifactResult>> Function(
    _ValidationResult validation,
  )
  action,
}) async {
  final artifactPaths = contracts
      .map((contract) => contract.artifactPath)
      .toList(growable: false);
  try {
    final validation = await _loadAndValidateSource(
      sourceRootPath: sourceRootPath,
      manifestPath: manifestPath,
      clock: clock,
      progressWriter: progressWriter,
    );
    if (!validation.isSuccess) {
      await _writeReport(
        reportPath: reportPath,
        report: <String, Object>{
          'command': commandName,
          'status': 'failure',
          'sourceRoot': sourceRootPath,
          'manifestPath': manifestPath,
          'artifacts': contracts
              .map(_artifactContractToJson)
              .toList(growable: false),
          'validation': validation.toJson(),
          'error': validation.failureSummary(),
        },
      );
      _printCommandSummary(
        stdoutLine: stdoutLine,
        sourceRootPath: sourceRootPath,
        reportPath: reportPath,
        artifactPaths: artifactPaths,
      );
      stderrLine(validation.failureSummary());
      return 1;
    }

    final buildResults = await action(validation);
    for (final result in buildResults) {
      await _writeArtifactMetadata(
        validation: validation,
        buildResult: result,
        manifestPath: manifestPath,
        clock: clock,
      );
    }

    await _writeReport(
      reportPath: reportPath,
      report: <String, Object>{
        'command': commandName,
        'status': 'success',
        'sourceRoot': sourceRootPath,
        'manifestPath': manifestPath,
        'artifacts': buildResults
            .map(_buildResultToJson)
            .toList(growable: false),
        'validation': validation.toJson(),
      },
    );
    _printCommandSummary(
      stdoutLine: stdoutLine,
      sourceRootPath: sourceRootPath,
      reportPath: reportPath,
      artifactPaths: artifactPaths,
    );
    return 0;
  } on Object catch (error, stackTrace) {
    await _writeFailureReport(
      reportPath: reportPath,
      commandName: commandName,
      sourceRootPath: sourceRootPath,
      manifestPath: manifestPath,
      artifactPaths: artifactPaths,
      error: error,
      stackTrace: stackTrace,
    );
    _printCommandSummary(
      stdoutLine: stdoutLine,
      sourceRootPath: sourceRootPath,
      reportPath: reportPath,
      artifactPaths: artifactPaths,
    );
    stderrLine(error.toString());
    return 1;
  }
}

Future<_Manifest> _createManifest({
  required String sourceRootPath,
  required DateTime generatedAt,
  ElvisDemProgressWriter? progressWriter,
}) async {
  final payloadFiles = await _collectPayloadFiles(sourceRootPath);
  if (payloadFiles.isEmpty) {
    throw StateError('No ELVIS payload files found under $sourceRootPath.');
  }

  progressWriter?.call(
    'Creating frozen manifest from ${payloadFiles.length} payload files...',
  );

  final entries = <_ManifestEntry>[];
  var totalBytes = 0;

  for (var index = 0; index < payloadFiles.length; index += 1) {
    final payloadFile = payloadFiles[index];
    final bytes = await payloadFile.file.length();
    final checksum = await _computeSha256(payloadFile.file);
    totalBytes += bytes;
    entries.add(
      _ManifestEntry(
        relativePath: payloadFile.relativePath,
        bytes: bytes,
        sha256: checksum,
      ),
    );
    _reportFileProgress(
      progressWriter: progressWriter,
      label: 'Manifest hashing',
      completed: index + 1,
      total: payloadFiles.length,
    );
  }

  return _Manifest(
    sourceRoot: sourceRootPath,
    generatedAtUtc: generatedAt.toIso8601String(),
    fileCount: entries.length,
    totalBytes: totalBytes,
    files: entries,
  );
}

Future<_ValidationResult> _loadAndValidateSource({
  required String sourceRootPath,
  required String manifestPath,
  required DateTime Function() clock,
  ElvisDemProgressWriter? progressWriter,
}) async {
  final manifestFile = File(manifestPath);
  if (!await manifestFile.exists()) {
    throw StateError('Missing required frozen manifest at $manifestPath.');
  }

  final sourceDirectory = Directory(sourceRootPath);
  if (!await sourceDirectory.exists()) {
    throw StateError('Raw ELVIS source does not exist at $sourceRootPath.');
  }

  progressWriter?.call('Loading frozen manifest: $manifestPath');
  final manifest = _Manifest.fromJson(await _readJsonObject(manifestPath));
  if (manifest.sourceRoot != sourceRootPath) {
    throw StateError(
      'Manifest sourceRoot ${manifest.sourceRoot} does not match $sourceRootPath.',
    );
  }
  progressWriter?.call(
    'Validating ${manifest.fileCount} manifest entries against $sourceRootPath',
  );

  final manifestConsistencyErrors = <String>[];
  final declaredTotalBytes = manifest.files.fold<int>(
    0,
    (sum, entry) => sum + entry.bytes,
  );
  if (manifest.fileCount != manifest.files.length) {
    manifestConsistencyErrors.add(
      'Manifest fileCount ${manifest.fileCount} does not match ${manifest.files.length} file entries.',
    );
  }
  if (manifest.totalBytes != declaredTotalBytes) {
    manifestConsistencyErrors.add(
      'Manifest totalBytes ${manifest.totalBytes} does not match declared file bytes $declaredTotalBytes.',
    );
  }

  final actualFiles = <String, File>{};
  progressWriter?.call('Scanning raw source tree for payload files...');
  await for (final entity in sourceDirectory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }

    final basename = p.basename(entity.path);
    if (_shouldIgnorePayloadFile(basename)) {
      continue;
    }

    final relativePath = p.relative(entity.path, from: sourceRootPath);
    actualFiles[relativePath] = entity;
  }
  progressWriter?.call(
    'Discovered ${actualFiles.length} payload files in the raw source tree.',
  );

  final missingFiles = <String>[];
  final wrongSizeFiles = <Map<String, Object>>[];
  final checksumMismatchFiles = <Map<String, Object>>[];

  for (var index = 0; index < manifest.files.length; index += 1) {
    final entry = manifest.files[index];
    final file = actualFiles.remove(entry.relativePath);
    if (file == null) {
      missingFiles.add(entry.relativePath);
      _reportFileProgress(
        progressWriter: progressWriter,
        label: 'Validation progress',
        completed: index + 1,
        total: manifest.files.length,
      );
      continue;
    }

    final actualBytes = await file.length();
    if (actualBytes != entry.bytes) {
      wrongSizeFiles.add(<String, Object>{
        'path': entry.relativePath,
        'expectedBytes': entry.bytes,
        'actualBytes': actualBytes,
      });
      _reportFileProgress(
        progressWriter: progressWriter,
        label: 'Validation progress',
        completed: index + 1,
        total: manifest.files.length,
      );
      continue;
    }

    final actualSha256 = await _computeSha256(file);
    if (actualSha256 != entry.sha256) {
      checksumMismatchFiles.add(<String, Object>{
        'path': entry.relativePath,
        'expectedSha256': entry.sha256,
        'actualSha256': actualSha256,
      });
    }

    _reportFileProgress(
      progressWriter: progressWriter,
      label: 'Validation progress',
      completed: index + 1,
      total: manifest.files.length,
    );
  }

  final unexpectedFiles = actualFiles.keys.toList()..sort();

  return _ValidationResult(
    manifest: manifest,
    validatedAtUtc: clock().toUtc().toIso8601String(),
    missingFiles: missingFiles,
    unexpectedFiles: unexpectedFiles,
    wrongSizeFiles: wrongSizeFiles,
    checksumMismatchFiles: checksumMismatchFiles,
    manifestConsistencyErrors: manifestConsistencyErrors,
  );
}

Future<_BuildArtifactResult> _buildArtifact({
  required _ValidationResult validation,
  required _ArtifactContract contract,
  required ElvisDemCommandChecker commandChecker,
  required ElvisDemCommandRunner commandRunner,
  ElvisDemProgressWriter? progressWriter,
}) async {
  final inputFiles = validation.manifest.files
      .where((entry) {
        final extension = p.extension(entry.relativePath).toLowerCase();
        return _rasterExtensions.contains(extension);
      })
      .map(
        (entry) => p.join(validation.manifest.sourceRoot, entry.relativePath),
      )
      .toList(growable: false);
  if (inputFiles.isEmpty) {
    throw StateError('Manifest does not contain any raster payload files.');
  }

  progressWriter?.call(
    'Preparing ${contract.command} from ${inputFiles.length} raster inputs...',
  );

  await commandChecker('gdalbuildvrt');
  await commandChecker('gdalwarp');

  final outputFile = File(contract.artifactPath);
  await outputFile.parent.create(recursive: true);

  final tempDirectory = await Directory.systemTemp.createTemp(
    'elvis-dem-${contract.command}-',
  );
  final executedCommands = <Map<String, Object>>[];
  try {
    final inputListPath = p.join(tempDirectory.path, 'inputs.txt');
    await File(inputListPath).writeAsString('${inputFiles.join('\n')}\n');
    final vrtPath = p.join(tempDirectory.path, '${contract.command}.vrt');

    progressWriter?.call('Running gdalbuildvrt for ${contract.command}...');
    await _runTrackedCommand(
      commandRunner: commandRunner,
      executedCommands: executedCommands,
      executable: 'gdalbuildvrt',
      arguments: ['-input_file_list', inputListPath, vrtPath],
    );

    final warpArguments = <String>[
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
      vrtPath,
      contract.artifactPath,
    ];
    progressWriter?.call('Running gdalwarp for ${contract.command}...');
    await _runTrackedCommand(
      commandRunner: commandRunner,
      executedCommands: executedCommands,
      executable: 'gdalwarp',
      arguments: warpArguments,
    );

    if (!await outputFile.exists()) {
      throw StateError(
        'Expected output artifact was not created: ${outputFile.path}',
      );
    }

    progressWriter?.call(
      'Finished ${contract.command}: ${contract.artifactPath}',
    );

    return _BuildArtifactResult(
      contract: contract,
      executedCommands: executedCommands,
      rasterInputCount: inputFiles.length,
    );
  } finally {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<void> _writeArtifactMetadata({
  required _ValidationResult validation,
  required _BuildArtifactResult buildResult,
  required String manifestPath,
  required DateTime Function() clock,
}) {
  return _writeJsonFile(buildResult.contract.metadataPath, <String, Object>{
    'artifactType': buildResult.contract.artifactType,
    'artifactPath': buildResult.contract.artifactPath,
    'generatedAtUtc': clock().toUtc().toIso8601String(),
    'sourceCompleteness': <String, Object>{
      'state': 'validated',
      'sourceRoot': validation.manifest.sourceRoot,
      'manifestPath': manifestPath,
      'validatedAtUtc': validation.validatedAtUtc,
      'fileCount': validation.manifest.fileCount,
      'totalBytes': validation.manifest.totalBytes,
    },
    'derivation': <String, Object?>{
      'command': buildResult.contract.command,
      'resolutionMeters': buildResult.contract.resolutionMeters,
      'targetSrs': buildResult.contract.targetSrs,
      'resampling': 'bilinear',
      'rasterInputCount': buildResult.rasterInputCount,
      'commands': buildResult.executedCommands,
    },
  });
}

Future<void> _runTrackedCommand({
  required ElvisDemCommandRunner commandRunner,
  required List<Map<String, Object>> executedCommands,
  required String executable,
  required List<String> arguments,
}) async {
  executedCommands.add(<String, Object>{
    'executable': executable,
    'arguments': arguments,
  });
  await commandRunner(executable, arguments);
}

Future<List<_PayloadFile>> _collectPayloadFiles(String sourceRootPath) async {
  final directory = Directory(sourceRootPath);
  if (!await directory.exists()) {
    throw StateError('Raw ELVIS source does not exist at $sourceRootPath.');
  }

  final payloadFiles = <_PayloadFile>[];
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }

    final basename = p.basename(entity.path);
    if (_shouldIgnorePayloadFile(basename)) {
      continue;
    }

    payloadFiles.add(
      _PayloadFile(
        relativePath: p.relative(entity.path, from: sourceRootPath),
        file: entity,
      ),
    );
  }

  payloadFiles.sort(
    (left, right) => left.relativePath.compareTo(right.relativePath),
  );
  return payloadFiles;
}

Future<String> _computeSha256(File file) async {
  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}

bool _shouldIgnorePayloadFile(String basename) {
  return _ignoredPayloadBasenames.contains(basename) ||
      basename.startsWith('._');
}

void _reportFileProgress({
  ElvisDemProgressWriter? progressWriter,
  required String label,
  required int completed,
  required int total,
}) {
  if (progressWriter == null) {
    return;
  }

  if (completed != total && completed % _progressLogInterval != 0) {
    return;
  }

  progressWriter('$label: $completed/$total');
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
  required String sourceRootPath,
  required String reportPath,
  required List<String> artifactPaths,
}) {
  stdoutLine('Raw source: $sourceRootPath');
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

Future<Map<String, dynamic>> _readJsonObject(String path) async {
  final decoded = jsonDecode(await File(path).readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Expected a JSON object at $path.');
  }
  return decoded;
}

Future<void> _writeReport({
  required String reportPath,
  required Map<String, Object> report,
}) async {
  await _writeJsonFile(reportPath, report);
}

Future<void> _writeFailureReport({
  required String reportPath,
  required String commandName,
  required String sourceRootPath,
  required String manifestPath,
  required List<String> artifactPaths,
  required Object error,
  required StackTrace stackTrace,
}) {
  return _writeReport(
    reportPath: reportPath,
    report: <String, Object>{
      'command': commandName,
      'status': 'failure',
      'sourceRoot': sourceRootPath,
      'manifestPath': manifestPath,
      'artifacts': artifactPaths,
      'error': error.toString(),
      'stackTrace': stackTrace.toString(),
    },
  );
}

Future<void> _writeJsonFile(String path, Map<String, Object?> json) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final contents = const JsonEncoder.withIndent('  ').convert(json);
  await file.writeAsString('$contents\n');
}

Future<void> _requireCommand(String command) async {
  final result = await Process.run('which', [command]);
  if (result.exitCode != 0) {
    throw StateError('Required command not found on PATH: $command');
  }
}

Future<void> _runCommand(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode == 0) {
    return;
  }

  final stderrOutput = result.stderr.toString().trim();
  throw ProcessException(
    executable,
    arguments,
    stderrOutput.isEmpty ? result.stdout.toString() : stderrOutput,
    result.exitCode,
  );
}

bool _isSha256Hex(String value) {
  return RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
}

class _PayloadFile {
  const _PayloadFile({required this.relativePath, required this.file});

  final String relativePath;
  final File file;
}
