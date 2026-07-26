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
const _topoHillshadeArtifactName = 'elvis_topo_5m.hillshade.tif';
const _topoHillshadePreviewName = 'elvis_topo_5m.hillshade.preview.jpg';

const _ignoredPayloadBasenames = <String>{'.DS_Store'};
const _rasterExtensions = <String>{'.tif', '.tiff', '.img'};
const _hillshadePreviewJpegWidthPixels = 2880;

typedef ElvisDemCommandChecker = Future<void> Function(String command);
typedef ElvisDemCommandRunner =
    Future<ElvisDemCommandResult> Function(
      String executable,
      List<String> arguments,
    );
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
  const _Invocation({
    required this.command,
    required this.showHelp,
    required this.validateBuildInputs,
    required this.saveIntermediateVrt,
  });

  final _ElvisDemCommand? command;
  final bool showHelp;
  final bool validateBuildInputs;
  final bool saveIntermediateVrt;
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
    this.savedIntermediateVrtPath,
    this.projectionGroupAuditPath,
  });

  final _ArtifactContract contract;
  final List<Map<String, Object>> executedCommands;
  final int rasterInputCount;
  final String? savedIntermediateVrtPath;
  final String? projectionGroupAuditPath;
}

class _BuildPreparation {
  const _BuildPreparation({required this.manifest, this.validation});

  final _Manifest manifest;
  final _ValidationResult? validation;
}

class ElvisDemCommandResult {
  const ElvisDemCommandResult({this.stdout = '', this.stderr = ''});

  final String stdout;
  final String stderr;
}

class _ProjectionDifferenceGroup {
  const _ProjectionDifferenceGroup({
    required this.expectedProjection,
    required this.actualProjection,
    required this.paths,
  });

  final String expectedProjection;
  final String actualProjection;
  final List<String> paths;
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
      validateBuildInputs: invocation.validateBuildInputs,
      saveIntermediateVrt: invocation.saveIntermediateVrt,
      sourceRootPath: sourceRootPath,
      manifestPath: manifestPath,
      reportPath: reportPath,
      contracts: [contract],
      clock: now,
      progressWriter: stdoutLine,
      stdoutLine: stdoutLine,
      stderrLine: stderrLine,
      action: (preparation) async {
        return <_BuildArtifactResult>[
          await _buildArtifact(
            manifest: preparation.manifest,
            contract: contract,
            saveIntermediateVrt: invocation.saveIntermediateVrt,
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
      validateBuildInputs: invocation.validateBuildInputs,
      saveIntermediateVrt: invocation.saveIntermediateVrt,
      sourceRootPath: sourceRootPath,
      manifestPath: manifestPath,
      reportPath: reportPath,
      contracts: [contract],
      clock: now,
      progressWriter: stdoutLine,
      stdoutLine: stdoutLine,
      stderrLine: stderrLine,
      action: (preparation) async {
        return <_BuildArtifactResult>[
          await _buildArtifact(
            manifest: preparation.manifest,
            contract: contract,
            saveIntermediateVrt: invocation.saveIntermediateVrt,
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
    validateBuildInputs: invocation.validateBuildInputs,
    saveIntermediateVrt: invocation.saveIntermediateVrt,
    sourceRootPath: sourceRootPath,
    manifestPath: manifestPath,
    reportPath: reportPath,
    contracts: [runtimeContract, topoContract],
    clock: now,
    progressWriter: stdoutLine,
    stdoutLine: stdoutLine,
    stderrLine: stderrLine,
    action: (preparation) async {
      return <_BuildArtifactResult>[
        await _buildArtifact(
          manifest: preparation.manifest,
          contract: runtimeContract,
          saveIntermediateVrt: invocation.saveIntermediateVrt,
          commandChecker: commandRequirements,
          commandRunner: commandExecution,
          progressWriter: stdoutLine,
        ),
        await _buildArtifact(
          manifest: preparation.manifest,
          contract: topoContract,
          saveIntermediateVrt: invocation.saveIntermediateVrt,
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
    return const _Invocation(
      command: null,
      showHelp: false,
      validateBuildInputs: false,
      saveIntermediateVrt: false,
    );
  }

  var showHelp = false;
  var validateBuildInputs = false;
  var saveIntermediateVrt = false;
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

    if (arg == '--save-vrt') {
      saveIntermediateVrt = true;
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

  if (validateBuildInputs &&
      command != _ElvisDemCommand.buildRuntime &&
      command != _ElvisDemCommand.buildTopo &&
      command != _ElvisDemCommand.buildAll) {
    throw ArgumentError(
      '--validate is only supported for build-runtime, build-topo, and build-all.',
    );
  }

  if (saveIntermediateVrt &&
      command != _ElvisDemCommand.buildRuntime &&
      command != _ElvisDemCommand.buildTopo &&
      command != _ElvisDemCommand.buildAll) {
    throw ArgumentError(
      '--save-vrt is only supported for build-runtime, build-topo, and build-all.',
    );
  }

  return _Invocation(
    command: command,
    showHelp: showHelp,
    validateBuildInputs: validateBuildInputs,
    saveIntermediateVrt: saveIntermediateVrt,
  );
}

String _usage() {
  return '''
Usage:
  ./elvis_dem.sh bootstrap-manifest
  ./elvis_dem.sh validate-source
  ./elvis_dem.sh build-runtime [--validate] [--save-vrt]
  ./elvis_dem.sh build-topo [--validate] [--save-vrt]
  ./elvis_dem.sh build-all [--validate] [--save-vrt]

Contracts:
  raw source: $elvisDemCanonicalSourceRoot
  manifest: $elvisDemManifestPath

Flags:
  --validate  Validate the raw source against the frozen manifest before build.
              Default: off.
  --save-vrt  Save the generated intermediate VRT beside the built artifact.
              Default: off.
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
  required bool validateBuildInputs,
  required bool saveIntermediateVrt,
  required String sourceRootPath,
  required String manifestPath,
  required String reportPath,
  required List<_ArtifactContract> contracts,
  required DateTime Function() clock,
  required ElvisDemProgressWriter progressWriter,
  required void Function(String message) stdoutLine,
  required void Function(String message) stderrLine,
  required Future<List<_BuildArtifactResult>> Function(_BuildPreparation source)
  action,
}) async {
  final artifactPaths = contracts
      .map((contract) => contract.artifactPath)
      .toList(growable: false);
  try {
    final preparation = validateBuildInputs
        ? await _prepareValidatedBuild(
            sourceRootPath: sourceRootPath,
            manifestPath: manifestPath,
            clock: clock,
            progressWriter: progressWriter,
          )
        : await _prepareUncheckedBuild(
            sourceRootPath: sourceRootPath,
            manifestPath: manifestPath,
            progressWriter: progressWriter,
          );
    final validation = preparation.validation;
    if (validation != null && !validation.isSuccess) {
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
          'validation': _buildValidationSummary(
            manifest: preparation.manifest,
            validation: validation,
            validateBuildInputs: true,
          ),
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

    final buildResults = await action(preparation);
    for (final result in buildResults) {
      await _writeArtifactMetadata(
        manifest: preparation.manifest,
        validation: validation,
        validateBuildInputs: validateBuildInputs,
        saveIntermediateVrt: saveIntermediateVrt,
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
        'validation': _buildValidationSummary(
          manifest: preparation.manifest,
          validation: validation,
          validateBuildInputs: validateBuildInputs,
        ),
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

Future<_BuildPreparation> _prepareValidatedBuild({
  required String sourceRootPath,
  required String manifestPath,
  required DateTime Function() clock,
  ElvisDemProgressWriter? progressWriter,
}) async {
  final validation = await _loadAndValidateSource(
    sourceRootPath: sourceRootPath,
    manifestPath: manifestPath,
    clock: clock,
    progressWriter: progressWriter,
  );
  return _BuildPreparation(
    manifest: validation.manifest,
    validation: validation,
  );
}

Future<_BuildPreparation> _prepareUncheckedBuild({
  required String sourceRootPath,
  required String manifestPath,
  ElvisDemProgressWriter? progressWriter,
}) async {
  final manifest = await _loadManifestForBuild(
    sourceRootPath: sourceRootPath,
    manifestPath: manifestPath,
    progressWriter: progressWriter,
  );
  return _BuildPreparation(manifest: manifest);
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

Future<_Manifest> _loadManifestForBuild({
  required String sourceRootPath,
  required String manifestPath,
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

  final manifestConsistencyErrors = _manifestConsistencyErrors(manifest);
  if (manifestConsistencyErrors.isNotEmpty) {
    throw StateError(manifestConsistencyErrors.first);
  }

  progressWriter?.call(
    'Validation skipped; building from ${manifest.fileCount} manifest entries.',
  );
  return manifest;
}

List<String> _manifestConsistencyErrors(_Manifest manifest) {
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
  return manifestConsistencyErrors;
}

Future<_BuildArtifactResult> _buildArtifact({
  required _Manifest manifest,
  required _ArtifactContract contract,
  required bool saveIntermediateVrt,
  required ElvisDemCommandChecker commandChecker,
  required ElvisDemCommandRunner commandRunner,
  ElvisDemProgressWriter? progressWriter,
}) async {
  final inputFiles = _deduplicatePreservingOrder(
    manifest.files
        .where((entry) {
          final extension = p.extension(entry.relativePath).toLowerCase();
          return _rasterExtensions.contains(extension);
        })
        .map((entry) => p.join(manifest.sourceRoot, entry.relativePath))
        .toList(growable: false),
  );
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
  final persistentInputListPath = p.join(outputFile.parent.path, 'inputs.txt');
  final persistentVrtPath = p.join(
    outputFile.parent.path,
    '${p.basenameWithoutExtension(outputFile.path)}.vrt',
  );
  final stagedOutputPath = _stagedSiblingPath(outputFile.path);

  final tempDirectory = await Directory.systemTemp.createTemp(
    'elvis-dem-${contract.command}-',
  );
  final executedCommands = <Map<String, Object>>[];
  Directory? persistentVrtPartsDirectory;
  var buildSucceeded = false;
  try {
    final inputListPath = p.join(tempDirectory.path, 'inputs.txt');
    final inputListContents = '${inputFiles.join('\n')}\n';
    await File(inputListPath).writeAsString(inputListContents);
    if (contract.artifactType == 'elvis-topo-dem') {
      await _writeTextFileAtomically(
        persistentInputListPath,
        inputListContents,
      );
    }
    final tempVrtPath = p.join(tempDirectory.path, '${contract.command}.vrt');

    progressWriter?.call('Running gdalbuildvrt for ${contract.command}...');
    final buildVrtResult = await _runTrackedCommand(
      commandRunner: commandRunner,
      executedCommands: executedCommands,
      executable: 'gdalbuildvrt',
      arguments: ['-input_file_list', inputListPath, tempVrtPath],
    );

    final projectionDifferenceGroups = _parseProjectionDifferenceGroups(
      buildVrtResult.stderr,
    );
    final primaryGroupPaths = await _readVrtSourcePaths(tempVrtPath);
    final remainingProjectionGroupPaths = inputFiles
        .where((path) => !primaryGroupPaths.contains(path))
        .toList(growable: false);
    if (remainingProjectionGroupPaths.isNotEmpty) {
      progressWriter?.call(
        'Detected at least ${projectionDifferenceGroups.length + 1} source projection groups for ${contract.command}; reprojecting groups before merge.',
      );
      if (contract.targetSrs == null) {
        throw StateError(
          'Mixed source projections require a target SRS for ${contract.command}.',
        );
      }

      await commandChecker('gdal_translate');

      if (saveIntermediateVrt) {
        persistentVrtPartsDirectory = Directory(
          p.join(
            outputFile.parent.path,
            '${p.basenameWithoutExtension(outputFile.path)}.vrt.parts',
          ),
        );
        if (await persistentVrtPartsDirectory.exists()) {
          await persistentVrtPartsDirectory.delete(recursive: true);
        }
        await persistentVrtPartsDirectory.create(recursive: true);
      }

      if (primaryGroupPaths.isEmpty) {
        throw StateError(
          'gdalbuildvrt skipped every raster input for ${contract.command}.',
        );
      }

      final groupVrtPaths = <String>[
        if (saveIntermediateVrt)
          p.join(persistentVrtPartsDirectory!.path, 'projection-group-0.vrt')
        else
          tempVrtPath,
      ];
      final groupSourcePaths = <List<String>>[
        _deduplicatePreservingOrder(primaryGroupPaths),
      ];
      if (saveIntermediateVrt) {
        await _replaceFileAtomically(tempVrtPath, groupVrtPaths.first);
      }
      progressWriter?.call(
        'Primary projection group captured ${primaryGroupPaths.length} inputs; ${remainingProjectionGroupPaths.length} inputs remain to partition.',
      );
      var remainingPaths = List<String>.from(remainingProjectionGroupPaths);
      while (remainingPaths.isNotEmpty) {
        final remainingBeforePass = remainingPaths.length;
        final index = groupVrtPaths.length - 1;
        final groupInputListPath = p.join(
          tempDirectory.path,
          'projection-group-$index-inputs.txt',
        );
        await File(
          groupInputListPath,
        ).writeAsString('${remainingPaths.join('\n')}\n');
        final groupFileIndex = groupVrtPaths.length;
        final groupVrtPath = p.join(
          saveIntermediateVrt
              ? persistentVrtPartsDirectory!.path
              : tempDirectory.path,
          'projection-group-$groupFileIndex.vrt',
        );
        final groupCountLabel = '${groupFileIndex + 1}/?';
        progressWriter?.call(
          'Running gdalbuildvrt for ${contract.command} projection group $groupCountLabel from $remainingBeforePass remaining inputs...',
        );
        await _runTrackedCommand(
          commandRunner: commandRunner,
          executedCommands: executedCommands,
          executable: 'gdalbuildvrt',
          arguments: ['-input_file_list', groupInputListPath, groupVrtPath],
        );
        final groupPaths = await _readVrtSourcePaths(groupVrtPath);
        if (groupPaths.isEmpty) {
          throw StateError(
            'gdalbuildvrt skipped every remaining raster input for ${contract.command}.',
          );
        }
        groupVrtPaths.add(groupVrtPath);
        groupSourcePaths.add(_deduplicatePreservingOrder(groupPaths));
        remainingPaths = remainingPaths
            .where((path) => !groupPaths.contains(path))
            .toList(growable: false);
        progressWriter?.call(
          'Projection group ${groupFileIndex + 1} captured ${groupPaths.length} inputs; ${remainingPaths.length} inputs remain unassigned.',
        );
      }

      final recoveredSilentlyOmittedPaths = inputFiles
          .where(
            (path) =>
                !primaryGroupPaths.contains(path) &&
                !projectionDifferenceGroups.any(
                  (group) => group.paths.contains(path),
                ),
          )
          .where(
            (path) =>
                groupSourcePaths.any((groupPaths) => groupPaths.contains(path)),
          )
          .toList(growable: false);
      if (recoveredSilentlyOmittedPaths.isNotEmpty) {
        progressWriter?.call(
          'Recovered ${recoveredSilentlyOmittedPaths.length} silently skipped raster inputs for ${contract.command} by repartitioning remaining inputs.',
        );
      }

      final reprojectedGroupPaths = <String>[];
      for (var index = 0; index < groupVrtPaths.length; index += 1) {
        final groupOutputPath = p.join(
          persistentVrtPartsDirectory?.path ?? tempDirectory.path,
          'projection-group-$index.tif',
        );
        progressWriter?.call(
          'Running gdalwarp for ${contract.command} projection group ${index + 1}/${groupVrtPaths.length}...',
        );
        await _runTrackedCommand(
          commandRunner: commandRunner,
          executedCommands: executedCommands,
          executable: 'gdalwarp',
          arguments: _warpArguments(
            contract: contract,
            inputPath: groupVrtPaths[index],
            outputPath: groupOutputPath,
          ),
        );
        reprojectedGroupPaths.add(groupOutputPath);
      }

      if (persistentVrtPartsDirectory != null) {
        await _writeProjectionGroupHillshadePreviewArtifacts(
          contract: contract,
          groupRasterPaths: reprojectedGroupPaths,
          scratchDirectoryPath: tempDirectory.path,
          commandChecker: commandChecker,
          commandRunner: commandRunner,
          executedCommands: executedCommands,
          progressWriter: progressWriter,
        );
      }

      final projectionGroupAuditPath = persistentVrtPartsDirectory == null
          ? null
          : await _writeProjectionGroupAudit(
              contract: contract,
              inputFiles: inputFiles,
              groupVrtPaths: groupVrtPaths,
              recoveredSilentlyOmittedPaths: recoveredSilentlyOmittedPaths,
              auditDirectoryPath: persistentVrtPartsDirectory.path,
              progressWriter: progressWriter,
            );

      final mergedInputListPath = p.join(
        tempDirectory.path,
        'merged-inputs.txt',
      );
      await File(
        mergedInputListPath,
      ).writeAsString('${reprojectedGroupPaths.join('\n')}\n');
      final mergedVrtPath = saveIntermediateVrt
          ? persistentVrtPath
          : tempVrtPath;
      progressWriter?.call(
        'Running gdalbuildvrt merge for ${contract.command}...',
      );
      await _runTrackedCommand(
        commandRunner: commandRunner,
        executedCommands: executedCommands,
        executable: 'gdalbuildvrt',
        arguments: ['-input_file_list', mergedInputListPath, mergedVrtPath],
      );

      progressWriter?.call('Running gdal_translate for ${contract.command}...');
      await _runTrackedCommand(
        commandRunner: commandRunner,
        executedCommands: executedCommands,
        executable: 'gdal_translate',
        arguments: _translateArguments(mergedVrtPath, stagedOutputPath),
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

      buildSucceeded = true;

      progressWriter?.call(
        'Finished ${contract.command}: ${contract.artifactPath}',
      );

      return _BuildArtifactResult(
        contract: contract,
        executedCommands: executedCommands,
        rasterInputCount: inputFiles.length,
        savedIntermediateVrtPath: saveIntermediateVrt
            ? persistentVrtPath
            : null,
        projectionGroupAuditPath: projectionGroupAuditPath,
      );
    }

    final warpInputPath = saveIntermediateVrt ? persistentVrtPath : tempVrtPath;
    if (saveIntermediateVrt) {
      await _replaceFileAtomically(tempVrtPath, persistentVrtPath);
    }

    progressWriter?.call('Running gdalwarp for ${contract.command}...');
    await _runTrackedCommand(
      commandRunner: commandRunner,
      executedCommands: executedCommands,
      executable: 'gdalwarp',
      arguments: _warpArguments(
        contract: contract,
        inputPath: warpInputPath,
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

    buildSucceeded = true;

    progressWriter?.call(
      'Finished ${contract.command}: ${contract.artifactPath}',
    );

    return _BuildArtifactResult(
      contract: contract,
      executedCommands: executedCommands,
      rasterInputCount: inputFiles.length,
      savedIntermediateVrtPath: saveIntermediateVrt ? persistentVrtPath : null,
      projectionGroupAuditPath: null,
    );
  } finally {
    if (!buildSucceeded && persistentVrtPartsDirectory != null) {
      if (await persistentVrtPartsDirectory.exists()) {
        await persistentVrtPartsDirectory.delete(recursive: true);
      }
    }
    final stagedOutputFile = File(stagedOutputPath);
    if (await stagedOutputFile.exists()) {
      await stagedOutputFile.delete();
    }
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  }
}

Future<void> _writeArtifactMetadata({
  required _Manifest manifest,
  required _ValidationResult? validation,
  required bool validateBuildInputs,
  required bool saveIntermediateVrt,
  required _BuildArtifactResult buildResult,
  required String manifestPath,
  required DateTime Function() clock,
}) {
  return _writeJsonFile(buildResult.contract.metadataPath, <String, Object>{
    'artifactType': buildResult.contract.artifactType,
    'artifactPath': buildResult.contract.artifactPath,
    'generatedAtUtc': clock().toUtc().toIso8601String(),
    'sourceCompleteness': _buildSourceCompletenessMetadata(
      manifest: manifest,
      validation: validation,
      manifestPath: manifestPath,
      validateBuildInputs: validateBuildInputs,
    ),
    'derivation': <String, Object?>{
      'command': buildResult.contract.command,
      'resolutionMeters': buildResult.contract.resolutionMeters,
      'targetSrs': buildResult.contract.targetSrs,
      'resampling': 'bilinear',
      'saveIntermediateVrt': saveIntermediateVrt,
      'savedIntermediateVrtPath': buildResult.savedIntermediateVrtPath,
      'projectionGroupAuditPath': buildResult.projectionGroupAuditPath,
      'rasterInputCount': buildResult.rasterInputCount,
      'commands': buildResult.executedCommands,
    },
  });
}

Map<String, Object> _buildValidationSummary({
  required _Manifest manifest,
  required _ValidationResult? validation,
  required bool validateBuildInputs,
}) {
  if (validation != null) {
    return validation.toJson();
  }

  return <String, Object>{
    'state': 'skipped',
    'validationEnabled': validateBuildInputs,
    'sourceRoot': manifest.sourceRoot,
    'manifest': manifest.toJson(),
  };
}

Map<String, Object> _buildSourceCompletenessMetadata({
  required _Manifest manifest,
  required _ValidationResult? validation,
  required String manifestPath,
  required bool validateBuildInputs,
}) {
  if (validation != null) {
    return <String, Object>{
      'state': 'validated',
      'validationEnabled': validateBuildInputs,
      'sourceRoot': validation.manifest.sourceRoot,
      'manifestPath': manifestPath,
      'validatedAtUtc': validation.validatedAtUtc,
      'fileCount': validation.manifest.fileCount,
      'totalBytes': validation.manifest.totalBytes,
    };
  }

  return <String, Object>{
    'state': 'skipped',
    'validationEnabled': validateBuildInputs,
    'sourceRoot': manifest.sourceRoot,
    'manifestPath': manifestPath,
    'manifestGeneratedAtUtc': manifest.generatedAtUtc,
    'fileCount': manifest.fileCount,
    'totalBytes': manifest.totalBytes,
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

Future<void> _writeProjectionGroupHillshadePreviewArtifacts({
  required _ArtifactContract contract,
  required List<String> groupRasterPaths,
  required String scratchDirectoryPath,
  required ElvisDemCommandChecker commandChecker,
  required ElvisDemCommandRunner commandRunner,
  required List<Map<String, Object>> executedCommands,
  ElvisDemProgressWriter? progressWriter,
}) async {
  if (contract.artifactType != 'elvis-topo-dem' || groupRasterPaths.isEmpty) {
    return;
  }

  await commandChecker('gdaldem');
  await commandChecker('gdal_translate');

  for (var index = 0; index < groupRasterPaths.length; index += 1) {
    final groupRasterPath = groupRasterPaths[index];
    final groupBasename = p.basenameWithoutExtension(groupRasterPath);
    final scratchHillshadePath = p.join(
      scratchDirectoryPath,
      '$groupBasename.hillshade.tif',
    );
    final previewPath = p.join(
      p.dirname(groupRasterPath),
      '$groupBasename.hillshade.preview.jpg',
    );
    final stagedPreviewPath = _stagedSiblingPath(previewPath);

    try {
      progressWriter?.call(
        'Running gdaldem hillshade for ${contract.command} projection group ${index + 1}/${groupRasterPaths.length}...',
      );
      await _runTrackedCommand(
        commandRunner: commandRunner,
        executedCommands: executedCommands,
        executable: 'gdaldem',
        arguments: _hillshadeArguments(
          inputPath: groupRasterPath,
          outputPath: scratchHillshadePath,
        ),
      );

      if (!await File(scratchHillshadePath).exists()) {
        throw StateError(
          'Expected projection group hillshade artifact was not created: $scratchHillshadePath',
        );
      }

      progressWriter?.call(
        'Running gdal_translate hillshade preview for ${contract.command} projection group ${index + 1}/${groupRasterPaths.length}...',
      );
      await _runTrackedCommand(
        commandRunner: commandRunner,
        executedCommands: executedCommands,
        executable: 'gdal_translate',
        arguments: _jpegPreviewArguments(
          inputPath: scratchHillshadePath,
          outputPath: stagedPreviewPath,
        ),
      );

      if (!await File(stagedPreviewPath).exists()) {
        throw StateError(
          'Expected projection group hillshade preview artifact was not created: $stagedPreviewPath',
        );
      }

      await _replaceFileAtomically(stagedPreviewPath, previewPath);
    } finally {
      final scratchHillshadeFile = File(scratchHillshadePath);
      if (await scratchHillshadeFile.exists()) {
        await scratchHillshadeFile.delete();
      }
      final stagedPreviewFile = File(stagedPreviewPath);
      if (await stagedPreviewFile.exists()) {
        await stagedPreviewFile.delete();
      }
    }
  }
}

Future<String> _writeProjectionGroupAudit({
  required _ArtifactContract contract,
  required List<String> inputFiles,
  required List<String> groupVrtPaths,
  required List<String> recoveredSilentlyOmittedPaths,
  required String auditDirectoryPath,
  ElvisDemProgressWriter? progressWriter,
}) async {
  progressWriter?.call(
    'Writing projection-group audit for ${contract.command}...',
  );

  final inputFileSet = inputFiles.toSet();
  final coveredPaths = <String>{};
  final groups = <Map<String, Object>>[];

  for (var index = 0; index < groupVrtPaths.length; index += 1) {
    final sourcePaths = _deduplicatePreservingOrder(
      await _readVrtSourcePaths(groupVrtPaths[index]),
    );
    coveredPaths.addAll(sourcePaths);
    groups.add(<String, Object>{
      'index': index,
      'vrtPath': groupVrtPaths[index],
      'sourceCount': sourcePaths.length,
    });
  }

  final missingInputPaths = inputFiles
      .where((path) => !coveredPaths.contains(path))
      .toList(growable: false);
  final unexpectedGroupSourcePaths =
      coveredPaths
          .where((path) => !inputFileSet.contains(path))
          .toList(growable: false)
        ..sort();
  final auditPath = p.join(auditDirectoryPath, 'audit.json');
  await _writeJsonFile(auditPath, <String, Object>{
    'command': contract.command,
    'artifactPath': contract.artifactPath,
    'inputRasterCount': inputFiles.length,
    'groupCount': groupVrtPaths.length,
    'groups': groups,
    'recoveredSilentlyOmittedCount': recoveredSilentlyOmittedPaths.length,
    'recoveredSilentlyOmittedPaths': recoveredSilentlyOmittedPaths,
    'missingInputCount': missingInputPaths.length,
    'missingInputPaths': missingInputPaths,
    'unexpectedGroupSourceCount': unexpectedGroupSourcePaths.length,
    'unexpectedGroupSourcePaths': unexpectedGroupSourcePaths,
  });
  return auditPath;
}

List<String> _silentlyOmittedInputPaths({
  required List<String> inputFiles,
  required List<String> primaryGroupPaths,
  required List<_ProjectionDifferenceGroup> projectionDifferenceGroups,
}) {
  final accountedPaths = <String>{...primaryGroupPaths};
  for (final group in projectionDifferenceGroups) {
    accountedPaths.addAll(group.paths);
  }
  return inputFiles
      .where((path) => !accountedPaths.contains(path))
      .toList(growable: false);
}

Future<List<_ProjectionDifferenceGroup>> _recoverSilentlyOmittedPaths({
  required List<String> omittedPaths,
  required String expectedProjection,
  required ElvisDemCommandChecker commandChecker,
  required ElvisDemCommandRunner commandRunner,
  required List<Map<String, Object>> executedCommands,
}) async {
  if (omittedPaths.isEmpty) {
    return const <_ProjectionDifferenceGroup>[];
  }

  await commandChecker('gdalinfo');
  final groups = <String, _ProjectionDifferenceGroup>{};
  final normalizedExpectedProjection = _normalizeProjectionName(
    expectedProjection,
  );
  for (final path in omittedPaths) {
    final result = await _runTrackedCommand(
      commandRunner: commandRunner,
      executedCommands: executedCommands,
      executable: 'gdalinfo',
      arguments: [path],
    );
    final actualProjection = _parseProjectionNameFromGdalInfo(result.stdout);
    if (actualProjection == null) {
      throw StateError(
        'Unable to determine source projection for silently skipped raster input: $path',
      );
    }
    final existing = groups[actualProjection];
    if (existing == null) {
      groups[actualProjection] = _ProjectionDifferenceGroup(
        expectedProjection: normalizedExpectedProjection,
        actualProjection: actualProjection,
        paths: <String>[path],
      );
      continue;
    }
    existing.paths.add(path);
  }

  return groups.values.toList(growable: false);
}

List<_ProjectionDifferenceGroup> _mergeProjectionDifferenceGroups(
  List<_ProjectionDifferenceGroup> baseGroups,
  List<_ProjectionDifferenceGroup> supplementalGroups,
) {
  if (supplementalGroups.isEmpty) {
    return baseGroups;
  }

  final mergedGroups = <_ProjectionDifferenceGroup>[
    for (final group in baseGroups)
      _ProjectionDifferenceGroup(
        expectedProjection: group.expectedProjection,
        actualProjection: group.actualProjection,
        paths: List<String>.from(group.paths),
      ),
  ];
  final indexByProjection = <String, int>{
    for (var index = 0; index < mergedGroups.length; index += 1)
      mergedGroups[index].actualProjection: index,
  };

  for (final group in supplementalGroups) {
    final existingIndex = indexByProjection[group.actualProjection];
    if (existingIndex == null) {
      mergedGroups.add(group);
      indexByProjection[group.actualProjection] = mergedGroups.length - 1;
      continue;
    }
    mergedGroups[existingIndex].paths.addAll(group.paths);
  }

  return mergedGroups;
}

Future<List<String>> _readVrtSourcePaths(String vrtPath) async {
  final contents = await File(vrtPath).readAsString();
  return RegExp(r'<SourceFilename[^>]*>(.*?)</SourceFilename>', dotAll: true)
      .allMatches(contents)
      .map((match) => match.group(1)!.trim())
      .toList(growable: false);
}

String? _parseProjectionNameFromGdalInfo(String stdout) {
  final projCrsMatch = RegExp(r'PROJCRS\["([^"]+)"').firstMatch(stdout);
  if (projCrsMatch != null) {
    return _normalizeProjectionName(projCrsMatch.group(1)?.trim());
  }
  final projCsMatch = RegExp(r'PROJCS\["([^"]+)"').firstMatch(stdout);
  return _normalizeProjectionName(projCsMatch?.group(1)?.trim());
}

String _normalizeProjectionName(String? projectionName) {
  final trimmed = projectionName?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return '';
  }

  final normalized = trimmed.toLowerCase();
  if (normalized.contains('gda2020') && normalized.contains('zone 55')) {
    return 'GDA2020 / MGA zone 55';
  }
  if (normalized.contains('gda94 / mga zone 55') ||
      normalized.contains('gda_1994_utm_zone_55s')) {
    return 'GDA94 / MGA zone 55';
  }
  if (normalized.contains('gda_1994_transverse_mercator') ||
      normalized == 'transverse_mercator') {
    return 'GDA_1994_Transverse_Mercator';
  }
  return trimmed;
}

List<String> _deduplicatePreservingOrder(List<String> values) {
  final seen = <String>{};
  final unique = <String>[];
  for (final value in values) {
    if (seen.add(value)) {
      unique.add(value);
    }
  }
  return unique;
}

List<_ProjectionDifferenceGroup> _parseProjectionDifferenceGroups(
  String stderr,
) {
  final matches = RegExp(
    r'Warning 1: gdalbuildvrt does not support heterogeneous projection: expected (.*?), got (.*?)\. Skipping (.+?)(?:\r?\n|$)',
    dotAll: true,
    multiLine: true,
  ).allMatches(stderr);
  if (matches.isEmpty) {
    return const <_ProjectionDifferenceGroup>[];
  }

  final groups = <String, _ProjectionDifferenceGroup>{};
  for (final match in matches) {
    final expectedProjection = match.group(1)?.trim();
    final actualProjection = match.group(2)?.trim();
    final path = match.group(3)?.trim();
    if (expectedProjection == null ||
        expectedProjection.isEmpty ||
        actualProjection == null ||
        actualProjection.isEmpty ||
        path == null ||
        path.isEmpty) {
      continue;
    }

    final normalizedExpectedProjection = _normalizeProjectionName(
      expectedProjection,
    );
    final normalizedActualProjection = _normalizeProjectionName(
      actualProjection,
    );

    final existing = groups[normalizedActualProjection];
    if (existing == null) {
      groups[normalizedActualProjection] = _ProjectionDifferenceGroup(
        expectedProjection: normalizedExpectedProjection,
        actualProjection: normalizedActualProjection,
        paths: <String>[path],
      );
      continue;
    }

    existing.paths.add(path);
  }

  return groups.values.toList(growable: false);
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

List<String> _translateArguments(String inputPath, String outputPath) {
  return <String>[
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
    'savedIntermediateVrtPath': result.savedIntermediateVrtPath,
    'projectionGroupAuditPath': result.projectionGroupAuditPath,
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

bool _isSha256Hex(String value) {
  return RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
}

class _PayloadFile {
  const _PayloadFile({required this.relativePath, required this.file});

  final String relativePath;
  final File file;
}
