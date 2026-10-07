import 'dart:convert';

import 'package:peak_bagger/services/mapping_store_core.dart';

enum MappingToolPathKind { file, directory, glob }

class MappingToolPath {
  const MappingToolPath({
    required this.id,
    required this.path,
    required this.kind,
    required this.required,
    this.replace = false,
    this.atomic = false,
  });

  final String id;
  final String path;
  final MappingToolPathKind kind;
  final bool required;
  final bool replace;
  final bool atomic;
}

class MappingToolOverride {
  const MappingToolOverride(this.flag, this.id, {required this.output});
  final String flag;
  final String id;
  final bool output;
  String get placeholder => '{${output ? 'output' : 'input'}:$id}';
}

class MappingToolContract {
  MappingToolContract({
    required this.toolId,
    required this.executable,
    required Iterable<String> arguments,
    required Map<String, MappingToolPath> inputs,
    required Map<String, MappingToolPath> outputs,
    required Iterable<String> permittedWrites,
    required Map<String, MappingToolOverride> overrides,
  }) : arguments = List.unmodifiable(arguments),
       inputs = Map.unmodifiable(inputs),
       outputs = Map.unmodifiable(outputs),
       permittedWrites = Set.unmodifiable(permittedWrites),
       overrides = Map.unmodifiable(overrides);

  final String toolId;
  final String executable;
  final List<String> arguments;
  final Map<String, MappingToolPath> inputs;
  final Map<String, MappingToolPath> outputs;
  final Set<String> permittedWrites;
  final Map<String, MappingToolOverride> overrides;
}

class MappingToolManifest {
  MappingToolManifest._(Map<String, MappingToolContract> tools)
    : tools = Map.unmodifiable(tools);

  final Map<String, MappingToolContract> tools;

  factory MappingToolManifest.parse(String text) {
    final decoded = jsonDecode(text);
    final root = _object(decoded, '/');
    final tools = <String, MappingToolContract>{};
    for (final entry in root.entries) {
      if (!_id.hasMatch(entry.key)) {
        _invalid('/${entry.key}', 'invalid tool ID');
      }
      final pointer = '/${entry.key}';
      final value = _object(entry.value, pointer);
      _keys(value, {
        'command',
        'inputs',
        'outputs',
        'permittedWrites',
        'overrides',
      }, pointer);
      final command = _object(value['command'], '$pointer/command');
      _keys(command, {'executable', 'arguments'}, '$pointer/command');
      final executable = _string(
        command['executable'],
        '$pointer/command/executable',
      );
      _literal(executable, '$pointer/command/executable', executable: true);
      final arguments = _strings(
        command['arguments'],
        '$pointer/command/arguments',
      );
      final inputs = _paths(value['inputs'], '$pointer/inputs', output: false);
      final outputs = _paths(
        value['outputs'],
        '$pointer/outputs',
        output: true,
      );
      if (inputs.keys.any(outputs.containsKey)) {
        _invalid(pointer, 'input/output IDs must be unique');
      }
      final writes = _strings(
        value['permittedWrites'],
        '$pointer/permittedWrites',
      );
      if (writes.toSet().length != writes.length ||
          writes.any((id) => !outputs.containsKey(id))) {
        _invalid(
          '$pointer/permittedWrites',
          'must name unique declared outputs',
        );
      }
      // Overlapping declarations can otherwise bypass a no-replacement policy.
      final outputPaths = outputs.values.map((output) => output.path).toList();
      for (var i = 0; i < outputPaths.length; i++) {
        for (var j = i + 1; j < outputPaths.length; j++) {
          if (_overlap(outputPaths[i], outputPaths[j])) {
            _invalid('$pointer/outputs', 'overlapping output paths');
          }
        }
      }
      for (var i = 0; i < arguments.length; i++) {
        final argument = arguments[i];
        final match = mappingToolPlaceholder.firstMatch(argument);
        if (match == null) {
          _literal(argument, '$pointer/command/arguments/$i');
          if ([...inputs.values, ...outputs.values].any(
            (path) =>
                argument == path.path || argument.endsWith('=${path.path}'),
          )) {
            _invalid(
              '$pointer/command/arguments/$i',
              'use a declared placeholder',
            );
          }
        } else {
          final output = match[1] == 'output';
          final id = match[2]!;
          if (!(output ? outputs : inputs).containsKey(id) ||
              (output && !writes.contains(id))) {
            _invalid(
              '$pointer/command/arguments/$i',
              'undeclared or unauthorized placeholder',
            );
          }
        }
      }
      final overrides = <String, MappingToolOverride>{};
      for (final raw in _list(value['overrides'], '$pointer/overrides')) {
        final override = _object(raw, '$pointer/overrides');
        _keys(override, {'flag', 'inputId', 'outputId'}, '$pointer/overrides');
        final flag = _string(override['flag'], '$pointer/overrides/flag');
        if (!RegExp(r'^--[a-z][a-z0-9-]*$').hasMatch(flag) ||
            overrides.containsKey(flag) ||
            override.containsKey('inputId') ==
                override.containsKey('outputId')) {
          _invalid('$pointer/overrides', 'invalid or duplicate flag/target');
        }
        final output = override.containsKey('outputId');
        final id = _string(
          override[output ? 'outputId' : 'inputId'],
          '$pointer/overrides',
        );
        final parsed = MappingToolOverride(flag, id, output: output);
        if (!(output ? outputs : inputs).containsKey(id) ||
            !arguments.contains(parsed.placeholder) ||
            overrides.values.any(
              (existing) => existing.placeholder == parsed.placeholder,
            )) {
          _invalid(
            '$pointer/overrides',
            'override must replace exactly its declared placeholder',
          );
        }
        overrides[flag] = parsed;
      }
      tools[entry.key] = MappingToolContract(
        toolId: entry.key,
        executable: executable,
        arguments: arguments,
        inputs: inputs,
        outputs: outputs,
        permittedWrites: writes,
        overrides: overrides,
      );
    }
    return MappingToolManifest._(tools);
  }

  MappingToolContract requireTool(String toolId) =>
      tools[toolId] ??
      (throw StateError('Undeclared Mapping-store tool: $toolId'));
}

final mappingToolPlaceholder = RegExp(r'^\{(input|output):([^{}:\s]+)\}$');
final _id = RegExp(r'^[^{}:\s\x00]+$');

bool _overlap(String a, String b) =>
    a == b || a.startsWith('$b/') || b.startsWith('$a/');

Map<String, MappingToolPath> _paths(
  Object? raw,
  String pointer, {
  required bool output,
}) {
  final result = <String, MappingToolPath>{};
  for (final item in _list(raw, pointer)) {
    final value = _object(item, pointer);
    _keys(
      value,
      output
          ? {'id', 'path', 'kind', 'required', 'replace', 'atomic'}
          : {'id', 'path', 'kind', 'required'},
      pointer,
    );
    final id = _string(value['id'], '$pointer/id');
    final path = _string(value['path'], '$pointer/path');
    final kindName = value['kind'];
    final kind = MappingToolPathKind.values
        .where((kind) => kind.name == kindName)
        .firstOrNull;
    if (!_id.hasMatch(id) ||
        result.containsKey(id) ||
        kind == null ||
        (output && kind == MappingToolPathKind.glob)) {
      _invalid(pointer, 'invalid/duplicate ID or kind');
    }
    validateToolPath(path, kind);
    result[id] = MappingToolPath(
      id: id,
      path: path,
      kind: kind,
      required: _boolean(value['required'], '$pointer/required'),
      replace: output ? _boolean(value['replace'], '$pointer/replace') : false,
      atomic: output ? _boolean(value['atomic'], '$pointer/atomic') : false,
    );
  }
  return result;
}

void validateToolPath(String path, MappingToolPathKind kind) {
  if (!isSafeMappingStorePath(path) ||
      path.startsWith('assets/') ||
      path.contains('{') ||
      path.contains('}') ||
      path.contains('[') ||
      path.contains(']') ||
      (kind != MappingToolPathKind.glob &&
          (path.contains('*') || path.contains('?'))) ||
      (kind == MappingToolPathKind.glob &&
          path
              .split('/')
              .any((segment) => segment.contains('**') && segment != '**'))) {
    _invalid(path, 'unsafe store-relative ${kind.name} path');
  }
}

void _literal(String argument, String pointer, {bool executable = false}) {
  if (argument.contains('{') ||
      argument.contains('}') ||
      argument.contains('\u0000') ||
      argument.contains(mappingStoreRootPath) ||
      argument.contains('assets/') ||
      (!executable && RegExp(r'(^|=)(/|[A-Za-z]:[\\/])').hasMatch(argument)) ||
      (!executable && _undeclaredPathLiteral(argument)) ||
      RegExp(
        r'(^|=)(Peaks|Highways|Polygons|Maps|Features|DEM)/',
      ).hasMatch(argument) ||
      argument == 'region_manifest.json' ||
      argument == 'tool_manifest.json') {
    _invalid(
      pointer,
      'malformed placeholder or undeclared Mapping path literal',
    );
  }
}

bool _undeclaredPathLiteral(String argument) {
  final value = argument.startsWith('--') && argument.contains('=')
      ? argument.substring(argument.indexOf('=') + 1)
      : argument;
  // Repository entrypoints and external service URLs are non-store literals.
  if (RegExp(r'^(tool/[^/]+\.dart|local_topo/[^{}]+\.sh)$').hasMatch(value) ||
      value.startsWith('https://') ||
      value.startsWith('http://')) {
    return false;
  }
  return value.contains('/') ||
      RegExp(r'\.(json|poly|csv|tif|tiff|vrt)$').hasMatch(value);
}

Never _invalid(String pointer, String message) =>
    throw FormatException('tool_manifest.json#$pointer: $message');
Map<String, dynamic> _object(Object? value, String pointer) =>
    value is Map<String, dynamic>
    ? value
    : _invalid(pointer, 'expected object');
List<dynamic> _list(Object? value, String pointer) =>
    value is List ? value : _invalid(pointer, 'expected array');
List<String> _strings(Object? value, String pointer) => [
  for (final item in _list(value, pointer))
    if (item is String) item else _invalid(pointer, 'expected string argument'),
];
String _string(Object? value, String pointer) =>
    value is String && value.trim().isNotEmpty && value == value.trim()
    ? value
    : _invalid(pointer, 'expected non-empty string');
bool _boolean(Object? value, String pointer) =>
    value is bool ? value : _invalid(pointer, 'expected boolean');
void _keys(Map<String, dynamic> value, Set<String> keys, String pointer) {
  for (final key in value.keys) {
    if (!keys.contains(key)) _invalid('$pointer/$key', 'unknown field');
  }
}
