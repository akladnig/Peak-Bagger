import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_tool_manifest.dart';

typedef MappingToolProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments,
      String workingDirectory,
      Map<String, String> environment,
    );
typedef MappingToolFileCommit =
    Future<void> Function(String staged, String finalPath, bool replace);

Future<ProcessResult> _runProcess(
  String executable,
  List<String> arguments,
  String workingDirectory,
  Map<String, String> environment,
) => Process.run(
  executable,
  arguments,
  workingDirectory: workingDirectory,
  environment: environment,
  includeParentEnvironment: false,
  runInShell: false,
);

/// Publish without a check-then-rename overwrite race. macOS RENAME_EXCL also
/// works on mounts without hard-link support. Other POSIX test hosts use link().
/// Both names are siblings on the same filesystem; publication is atomic.
Future<void> _commitFile(String staged, String finalPath, bool replace) async {
  if (replace) {
    await File(staged).rename(finalPath);
    return;
  }
  final source = staged.toNativeUtf8();
  final target = finalPath.toNativeUtf8();
  try {
    final int result;
    if (Platform.isMacOS) {
      final renameExclusive = DynamicLibrary.process()
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Uint32),
            int Function(Pointer<Utf8>, Pointer<Utf8>, int)
          >('renamex_np');
      // /usr/include/sys/stdio.h: RENAME_EXCL = 0x00000004.
      result = renameExclusive(source, target, 0x00000004);
    } else {
      final link = DynamicLibrary.process()
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
            int Function(Pointer<Utf8>, Pointer<Utf8>)
          >('link');
      result = link(source, target);
    }
    if (result != 0) {
      throw FileSystemException(
        'Atomic no-overwrite publication failed',
        finalPath,
      );
    }
  } finally {
    malloc.free(source);
    malloc.free(target);
  }
  if (!Platform.isMacOS) await File(staged).delete();
}

/// Named-tool capability. It never returns a Mapping-store path. Only the
/// resolver's trusted subprocess/binary adapters receive canonical paths.
class MappingToolResolver {
  MappingToolResolver._({
    required this._store,
    required this.contract,
    required String repositoryRoot,
    required this._runner,
    required MappingToolFileCommit commitFile,
    required Map<String, String> environment,
  }) : _repositoryRoot = p.normalize(p.absolute(repositoryRoot)),
       _commit = commitFile,
       _environment = Map.unmodifiable(environment);

  static Future<MappingToolResolver> namedTool({
    required String toolId,
    required String repositoryRoot,
    String rootPath = mappingStoreRootPath,
    MappingToolProcessRunner runner = _runProcess,
    MappingToolFileCommit commitFile = _commitFile,
    Map<String, String>? environment,
  }) async {
    final store = await _ToolStore.open(rootPath);
    final path = await store.target('tool_manifest.json', required: true);
    final manifest = MappingToolManifest.parse(await File(path).readAsString());
    return MappingToolResolver._(
      store: store,
      contract: manifest.requireTool(toolId),
      repositoryRoot: repositoryRoot,
      runner: runner,
      commitFile: commitFile,
      environment: environment ?? Platform.environment,
    );
  }

  final _ToolStore _store;
  final MappingToolContract contract;
  final String _repositoryRoot;
  final MappingToolProcessRunner _runner;
  final MappingToolFileCommit _commit;
  final Map<String, String> _environment;
  bool _running = false;

  Future<String> readInputText(String id, {String? child}) =>
      openInput(id, child: child, opener: (path) => File(path).readAsString());

  Future<T> openInput<T>(
    String id, {
    String? child,
    required Future<T> Function(String canonicalPath) opener,
  }) async {
    final input = contract.inputs[id];
    if (input == null ||
        input.kind == MappingToolPathKind.glob ||
        (child != null && input.kind != MappingToolPathKind.directory)) {
      throw StateError('Undeclared file input: ${contract.toolId}:$id');
    }
    if (input.kind == MappingToolPathKind.directory && child == null) {
      throw ArgumentError('A directory read requires a safe child path.');
    }
    if (child != null) validateToolPath(child, MappingToolPathKind.file);
    final path = await _store.target(
      child == null ? input.path : '${input.path}/$child',
      required: true,
    );
    await _store.requireKind(path, MappingToolPathKind.file);
    return opener(path);
  }

  /// Reads matched glob files without leaking their absolute paths.
  Future<List<String>> readGlobTexts(String id) async {
    final input = contract.inputs[id];
    if (input == null || input.kind != MappingToolPathKind.glob) {
      throw StateError('Undeclared glob input: $id');
    }
    final paths = await _inputPaths(input, input.path);
    return [for (final path in paths) await File(path).readAsString()];
  }

  Future<ProcessResult> execute({
    Map<String, String> overrides = const {},
  }) async {
    late ProcessResult result;
    await _withOutputs(overrides, (outputs, inputPaths) async {
      final arguments = <String>[];
      for (final argument in contract.arguments) {
        final placeholder = mappingToolPlaceholder.firstMatch(argument);
        if (placeholder == null) {
          arguments.add(argument);
        } else if (placeholder[1] == 'input') {
          arguments.addAll(inputPaths[placeholder[2]]!);
        } else {
          arguments.add(outputs._stages[placeholder[2]]!.stagedPath);
        }
      }
      result = await _runner(
        contract.executable,
        List.unmodifiable(arguments),
        _repositoryRoot,
        _environment,
      );
      if (result.exitCode != 0) {
        throw ProcessException(
          contract.executable,
          arguments,
          '${result.stderr}',
          result.exitCode,
        );
      }
    });
    return result;
  }

  /// In-process writers receive operations, not staging or final paths.
  Future<void> writeOutputs(
    Future<void> Function(MappingToolOutputs) action, {
    Map<String, String> overrides = const {},
  }) => _withOutputs(overrides, (outputs, _) => action(outputs));

  Future<void> _withOutputs(
    Map<String, String> overrides,
    Future<void> Function(MappingToolOutputs, Map<String, List<String>>) action,
  ) async {
    if (_running) throw StateError('Tool execution already pending.');
    _running = true;
    final stages = <String, _OutputStage>{};
    final outputs = MappingToolOutputs._(stages);
    try {
      final replaced = <String, String>{};
      for (final entry in overrides.entries) {
        final declaration = contract.overrides[entry.key];
        if (declaration == null) {
          throw ArgumentError('Undeclared override: ${entry.key}');
        }
        final path = (declaration.output
            ? contract.outputs
            : contract.inputs)[declaration.id]!;
        validateToolPath(entry.value, path.kind);
        replaced[declaration.placeholder] = entry.value;
      }
      final inputPaths = <String, List<String>>{};
      for (final input in contract.inputs.values) {
        inputPaths[input.id] = await _inputPaths(
          input,
          replaced['{input:${input.id}}'] ?? input.path,
        );
      }
      final outputPaths = <String, String>{};
      for (final id in contract.permittedWrites) {
        final output = contract.outputs[id]!;
        final relative = replaced['{output:$id}'] ?? output.path;
        final target = await _store.outputTarget(relative);
        outputPaths[id] = target;
        final type = await FileSystemEntity.type(target, followLinks: false);
        if (type != FileSystemEntityType.notFound) {
          if (type == FileSystemEntityType.link) {
            throw FileSystemException('Output symlink', relative);
          }
          await _store.requireKind(target, output.kind);
          if (output.kind == MappingToolPathKind.file && !output.replace) {
            throw FileSystemException('Replacement forbidden', relative);
          }
          if (output.kind == MappingToolPathKind.directory) {
            final snapshot = await _store.snapshot(target);
            if (!output.replace && snapshot.files.isNotEmpty) {
              throw FileSystemException('Replacement forbidden', relative);
            }
          }
        }
      }
      final targets = outputPaths.values.toList();
      for (var i = 0; i < targets.length; i++) {
        for (var j = i + 1; j < targets.length; j++) {
          if (targets[i] == targets[j] ||
              p.isWithin(targets[i], targets[j]) ||
              p.isWithin(targets[j], targets[i])) {
            throw ArgumentError('Overrides produced overlapping outputs.');
          }
        }
      }
      // All no-replacement checks above precede even staging writes.
      for (final entry in outputPaths.entries) {
        final output = contract.outputs[entry.key]!;
        await _store.createDirectory(p.dirname(entry.value));
        final temporary = await Directory(
          p.dirname(entry.value),
        ).createTemp('.${p.basename(entry.value)}.stage-');
        stages[entry.key] = _OutputStage(
          output,
          entry.value,
          temporary,
          output.kind == MappingToolPathKind.file
              ? '${temporary.path}.tmp'
              : temporary.path,
        );
      }
      await action(outputs, inputPaths);
      for (final stage in stages.values) {
        await stage.validate(_store);
      }
      for (final output in contract.outputs.values) {
        if (output.required && !contract.permittedWrites.contains(output.id)) {
          final path = await _store.target(output.path, required: true);
          await _store.requireKind(path, output.kind);
        }
      }
      outputs._active = false;
      for (final stage in stages.values) {
        await stage.commit(_store, _commit);
      }
    } finally {
      outputs._active = false;
      for (final stage in stages.values) {
        await stage.cleanup();
      }
      _running = false;
    }
  }

  Future<List<String>> _inputPaths(
    MappingToolPath input,
    String relative,
  ) async {
    if (input.kind == MappingToolPathKind.glob) {
      final expression = _globExpression(relative);
      // Traverse only the literal directory prefix, never an unrelated tree.
      final segments = relative.split('/');
      final wildcard = segments.indexWhere(
        (s) => s.contains('*') || s.contains('?'),
      );
      final prefix = wildcard < 0
          ? p.posix.dirname(relative)
          : segments.take(wildcard).join('/');
      final directory = prefix.isEmpty
          ? _store.root
          : await _store.target(prefix, required: input.required);
      final matches = <(String, String)>[];
      if (await Directory(directory).exists()) {
        for (final relativePath in await _store.inputFiles(directory)) {
          final storeRelative = p.relative(relativePath, from: _store.root);
          if (expression.hasMatch(storeRelative)) {
            final canonical = await _store.target(
              storeRelative,
              required: true,
            );
            matches.add((storeRelative, canonical));
          }
        }
      }
      matches.sort((a, b) => a.$1.compareTo(b.$1));
      if (input.required && matches.isEmpty) {
        throw FileSystemException(
          'Required glob has no regular files',
          relative,
        );
      }
      return [for (final match in matches) match.$2];
    }
    final path = await _store.target(relative, required: input.required);
    if (await FileSystemEntity.type(path) != FileSystemEntityType.notFound) {
      await _store.requireKind(path, input.kind);
    }
    return [path];
  }
}

class MappingToolOutputs {
  MappingToolOutputs._(this._stages);
  final Map<String, _OutputStage> _stages;
  bool _active = true;

  Future<void> writeText(String id, String contents, {String? child}) =>
      writeBytes(id, utf8.encode(contents), child: child);

  Future<void> writeBytes(String id, List<int> bytes, {String? child}) async {
    final stage = _stages[id];
    if (!_active || stage == null) throw StateError('Unauthorized output: $id');
    if ((child != null) !=
        (stage.declaration.kind == MappingToolPathKind.directory)) {
      throw ArgumentError(
        'Directory writes require a safe child; file writes do not.',
      );
    }
    if (child != null) validateToolPath(child, MappingToolPathKind.file);
    final path = child == null
        ? stage.stagedPath
        : p.join(stage.stagedPath, child);
    // Do not follow symlinks introduced by a retained writer or subprocess.
    await _rejectLinksBetween(stage.stagedPath, path);
    await Directory(p.dirname(path)).create(recursive: true);
    await File(path).writeAsBytes(bytes, flush: true);
  }
}

class _OutputStage {
  _OutputStage(
    this.declaration,
    this.finalPath,
    this.temporary,
    this.stagedPath,
  );
  final MappingToolPath declaration;
  final String finalPath;
  final Directory temporary;
  final String stagedPath;
  _Snapshot? _snapshot;
  bool _exists = false;

  Future<void> validate(_ToolStore store) async {
    await _rejectLinksBetween(store.root, stagedPath);
    final type = await FileSystemEntity.type(stagedPath, followLinks: false);
    _exists = type != FileSystemEntityType.notFound;
    if (!_exists) {
      if (declaration.required) {
        throw FileSystemException('Required output missing', declaration.path);
      }
      return;
    }
    if (type == FileSystemEntityType.link) {
      throw FileSystemException('Staged output symlink', declaration.path);
    }
    await store.requireKind(stagedPath, declaration.kind);
    if (declaration.kind == MappingToolPathKind.directory) {
      _snapshot = await store.snapshot(stagedPath);
    }
  }

  Future<void> commit(
    _ToolStore store,
    MappingToolFileCommit commitFile,
  ) async {
    if (!_exists) return;
    await _rejectLinksBetween(store.root, finalPath);
    if (declaration.kind == MappingToolPathKind.file) {
      await commitFile(stagedPath, finalPath, declaration.replace);
      return;
    }
    final previous = await Directory(finalPath).exists()
        ? await store.snapshot(finalPath)
        : const _Snapshot([], []);
    final snapshot = _snapshot!;
    await store.createDirectory(finalPath);
    for (final directory in snapshot.directories) {
      await store.createDirectory(p.join(finalPath, directory));
    }
    for (final relative in snapshot.files) {
      final target = p.join(finalPath, relative);
      await _rejectLinksBetween(store.root, target);
      await commitFile(
        p.join(stagedPath, relative),
        target,
        declaration.replace,
      );
    }
    // A failed replacement leaves stale files in place. Per-file publication is
    // atomic; this is intentionally not a whole-directory transaction.
    for (final stale in previous.files.where(
      (path) => !snapshot.files.contains(path),
    )) {
      final target = p.join(finalPath, stale);
      await _rejectLinksBetween(store.root, target);
      await File(target).delete();
    }
    for (final stale in previous.directories.reversed.where(
      (path) => !snapshot.directories.contains(path),
    )) {
      await Directory(p.join(finalPath, stale)).delete();
    }
  }

  Future<void> cleanup() async {
    if (declaration.kind == MappingToolPathKind.file &&
        await FileSystemEntity.type(stagedPath, followLinks: false) !=
            FileSystemEntityType.notFound) {
      final type = await FileSystemEntity.type(stagedPath, followLinks: false);
      if (type == FileSystemEntityType.link) {
        await Link(stagedPath).delete();
      } else if (type == FileSystemEntityType.directory) {
        await Directory(stagedPath).delete(recursive: true);
      } else {
        await File(stagedPath).delete();
      }
    }
    final temporaryType = await FileSystemEntity.type(
      temporary.path,
      followLinks: false,
    );
    if (temporaryType == FileSystemEntityType.link) {
      await Link(temporary.path).delete();
    } else if (temporaryType == FileSystemEntityType.directory) {
      await temporary.delete(recursive: true);
    }
  }
}

class _Snapshot {
  const _Snapshot(this.files, this.directories);
  final List<String> files;
  final List<String> directories;
}

class _ToolStore {
  _ToolStore(this.root);
  final String root;
  static Future<_ToolStore> open(String path) async =>
      _ToolStore(await Directory(path).resolveSymbolicLinks());

  Future<String> target(String relative, {required bool required}) async {
    if (!isSafeMappingStorePath(relative)) {
      throw ArgumentError('Unsafe path: $relative');
    }
    final candidate = p.join(root, relative);
    final type = await FileSystemEntity.type(candidate, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await _validateAncestors(candidate);
      if (required) {
        throw FileSystemException('Required input missing', relative);
      }
      return candidate;
    }
    final canonical = await File(candidate).resolveSymbolicLinks();
    if (!p.isWithin(root, canonical)) {
      throw FileSystemException('Outside Mapping store', relative);
    }
    return canonical;
  }

  Future<String> outputTarget(String relative) async {
    validateToolPath(relative, MappingToolPathKind.file);
    final candidate = p.join(root, relative);
    await _rejectLinksBetween(root, candidate);
    await _validateAncestors(candidate);
    return candidate;
  }

  Future<void> _validateAncestors(String candidate) async {
    var parent = p.dirname(candidate);
    while (parent != root) {
      if (await FileSystemEntity.type(parent, followLinks: false) !=
          FileSystemEntityType.notFound) {
        final canonical = await Directory(parent).resolveSymbolicLinks();
        if (!p.isWithin(root, canonical)) {
          throw FileSystemException('Outside Mapping store', candidate);
        }
        await requireKind(canonical, MappingToolPathKind.directory);
        break;
      }
      parent = p.dirname(parent);
    }
  }

  Future<void> requireKind(String path, MappingToolPathKind kind) async {
    final actual = await FileSystemEntity.type(path);
    if (actual !=
        (kind == MappingToolPathKind.directory
            ? FileSystemEntityType.directory
            : FileSystemEntityType.file)) {
      throw FileSystemException('Incorrect declared path kind', path);
    }
  }

  Future<void> createDirectory(String path) async {
    await _rejectLinksBetween(root, path);
    await _validateAncestors(p.join(path, '.directory-check'));
    await Directory(path).create(recursive: true);
  }

  Future<_Snapshot> snapshot(String path) async {
    final files = <String>[];
    final directories = <String>[];
    await for (final entity in Directory(
      path,
    ).list(recursive: true, followLinks: false)) {
      final relative = p.relative(entity.path, from: path);
      if (!isSafeMappingStorePath(relative)) {
        throw FileSystemException('Escaped snapshot path', relative);
      }
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link ||
          (type != FileSystemEntityType.file &&
              type != FileSystemEntityType.directory)) {
        throw FileSystemException(
          'Snapshot contains a symlink or non-regular entry',
          relative,
        );
      }
      (type == FileSystemEntityType.file ? files : directories).add(relative);
    }
    files.sort();
    directories.sort();
    return _Snapshot(files, directories);
  }

  Future<List<String>> inputFiles(
    String directory, [
    Set<String> ancestors = const {},
  ]) async {
    final canonical = await Directory(directory).resolveSymbolicLinks();
    if (canonical != root && !p.isWithin(root, canonical)) {
      throw FileSystemException('Outside Mapping store', directory);
    }
    if (ancestors.contains(canonical)) {
      throw FileSystemException('Symlink directory cycle', directory);
    }
    final paths = <String>[];
    await for (final entity in Directory(directory).list(followLinks: false)) {
      final relative = p.relative(entity.path, from: root);
      final targetPath = await target(relative, required: true);
      final type = await FileSystemEntity.type(targetPath);
      if (type == FileSystemEntityType.directory) {
        paths.addAll(await inputFiles(entity.path, {...ancestors, canonical}));
      } else if (type == FileSystemEntityType.file) {
        paths.add(entity.path);
      }
    }
    return paths;
  }
}

Future<void> _rejectLinksBetween(String root, String target) async {
  if (target != root && !p.isWithin(root, target)) {
    throw ArgumentError('Escaped output path');
  }
  var path = target;
  while (path != root) {
    if (await FileSystemEntity.type(path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw FileSystemException('Output symlink', path);
    }
    path = p.dirname(path);
  }
  if (await FileSystemEntity.type(root, followLinks: false) ==
      FileSystemEntityType.link) {
    throw FileSystemException('Output symlink', root);
  }
}

RegExp _globExpression(String pattern) {
  final segments = pattern.split('/');
  final buffer = StringBuffer('^');
  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    if (segment == '**') {
      buffer.write(i == segments.length - 1 ? '.*' : '(?:[^/]+/)*');
      continue;
    }
    for (final character in segment.split('')) {
      buffer.write(switch (character) {
        '*' => '[^/]*',
        '?' => '[^/]',
        _ => RegExp.escape(character),
      });
    }
    if (i != segments.length - 1) buffer.write('/');
  }
  buffer.write(r'$');
  return RegExp(buffer.toString());
}

/// Trusted bootstrap has no arbitrary-output API and cannot run named tools.
class MappingToolManifestBootstrap {
  const MappingToolManifestBootstrap();

  Future<bool> install({
    required String fixtureText,
    String rootPath = mappingStoreRootPath,
  }) async {
    MappingToolManifest.parse(fixtureText);
    final store = await _ToolStore.open(rootPath);
    final target = await store.outputTarget('tool_manifest.json');
    if (await FileSystemEntity.type(target, followLinks: false) !=
        FileSystemEntityType.notFound) {
      final existing = await File(target).readAsString();
      MappingToolManifest.parse(existing);
      if (!_sameJson(jsonDecode(existing), jsonDecode(fixtureText))) {
        throw StateError(
          'Existing tool_manifest.json conflicts with the v1 fixture; refusing overwrite.',
        );
      }
      return false;
    }
    final temporary = await Directory(
      store.root,
    ).createTemp('.tool-manifest-bootstrap-');
    final staged = '${temporary.path}.tmp';
    try {
      await File(staged).writeAsString(fixtureText, flush: true);
      await _commitFile(staged, target, false);
      return true;
    } finally {
      if (await File(staged).exists()) await File(staged).delete();
      await temporary.delete(recursive: true);
    }
  }
}

bool _sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _sameJson(a[key], b[key]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(
          a.length,
          (i) => _sameJson(a[i], b[i]),
        ).every((same) => same);
  }
  return a == b;
}
