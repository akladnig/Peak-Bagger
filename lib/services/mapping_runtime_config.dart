import 'dart:io';

import 'package:path/path.dart' as p;
import 'mapping_runtime_io.dart';

enum MappingRuntimeMode { replica, canonical }

class MappingRuntimeConfiguration {
  const MappingRuntimeConfiguration({
    required this.mode,
    required this.rootPath,
    required this.configurationPath,
  });

  final MappingRuntimeMode mode;
  final String rootPath;
  final String configurationPath;

  static Future<MappingRuntimeConfiguration> load(
    String supportPath, {
    Future<bool> Function(String)? isLocal,
  }) async {
    final path = p.join(supportPath, 'mapping-runtime.json');
    final local = isLocal ?? MappingRuntimeIo().isLocal;
    try {
      await requireLocalRuntimePath(supportPath, local);
      final io = MappingRuntimeIo();
      if (await io.exists(path)) {
        final value = (await io.readMetadata(path)).value;
        if (value is Map &&
            value.length == 3 &&
            value['schemaVersion'] is int &&
            value['schemaVersion'] == 1 &&
            value['mode'] == 'canonical' &&
            value['canonicalRoot'] == '/Volumes/Services/Mapping') {
          if (!await local(value['canonicalRoot'] as String)) {
            throw const FormatException(
              'Canonical mode requires the mini attached store; SMB is not permitted',
            );
          }
          await io.rejectLinks(value['canonicalRoot'] as String);
          return MappingRuntimeConfiguration(
            mode: MappingRuntimeMode.canonical,
            rootPath: value['canonicalRoot'] as String,
            configurationPath: path,
          );
        }
        if (value is! Map ||
            value['schemaVersion'] is! int ||
            value['schemaVersion'] != 1 ||
            value['mode'] != 'replica' ||
            value['replicaBase'] is! String ||
            value.length != 3 ||
            !p.isAbsolute(value['replicaBase'] as String)) {
          throw const FormatException(
            'Invalid machine-local runtime configuration',
          );
        }
        await requireLocalRuntimePath(value['replicaBase'] as String, local);
        return MappingRuntimeConfiguration(
          mode: MappingRuntimeMode.replica,
          rootPath: p.normalize(value['replicaBase'] as String),
          configurationPath: path,
        );
      }
      return MappingRuntimeConfiguration(
        mode: MappingRuntimeMode.replica,
        rootPath: p.join(supportPath, 'MappingRuntimeReplica'),
        configurationPath: path,
      );
    } catch (error) {
      throw MappingRuntimeConfigurationFailure(path, '$error');
    }
  }
}

Future<void> requireLocalRuntimePath(
  String path,
  Future<bool> Function(String) isLocal,
) async {
  if (!p.isAbsolute(path) || path.contains('\u0000') || !await isLocal(path)) {
    throw const FormatException(
      'Mapping runtime configuration and replicas require local absolute paths',
    );
  }
  final normalized = p.normalize(path);
  final home = Platform.environment['HOME']!;
  final roots = [
    if ([
      'peak_bagger',
      'trip_routing',
      'flutter_map_tile_caching',
    ].contains(p.basename(p.current)))
      p.current,
    for (final parent in [
      p.join(home, 'Development', 'mapping'),
      '/Volumes/Development/mapping',
    ])
      for (final name in [
        'peak_bagger',
        'trip_routing',
        'flutter_map_tile_caching',
      ])
        p.join(parent, name),
  ];
  if (roots.any(
        (root) => p.equals(root, normalized) || p.isWithin(root, normalized),
      ) ||
      p.equals(normalized, '/Volumes/Services/Mapping') ||
      p.isWithin('/Volumes/Services/Mapping', normalized) ||
      p.isWithin(normalized, '/Volumes/Services/Mapping')) {
    throw const FormatException(
      'Local runtime state must be outside Mapping and source synchronization roots',
    );
  }
  // macOS /var is a system alias. Reject configurable aliases below it instead
  // of trusting lexical containment of user-created symlinks.
  var component = normalized;
  while (component != p.dirname(component)) {
    if (await FileSystemEntity.type(component, followLinks: false) ==
            FileSystemEntityType.link &&
        component != '/var' &&
        component != '/tmp') {
      throw FileSystemException(
        'Runtime state path contains a symlink',
        component,
      );
    }
    component = p.dirname(component);
  }
}

class MappingRuntimeConfigurationFailure implements Exception {
  const MappingRuntimeConfigurationFailure(this.path, this.diagnostic);
  final String path;
  final String diagnostic;
  @override
  String toString() => 'Local Mapping configuration: $path: $diagnostic';
}
