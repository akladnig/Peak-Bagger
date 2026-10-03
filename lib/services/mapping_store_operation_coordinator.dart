import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_data_store.dart';

enum MappingStoreOperationKind {
  peakSeed,
  peakUpdate,
  tasmapBootstrap,
  tasmapUpdate,
  naturalFeaturesBootstrap,
  naturalFeaturesRefresh,
  routeGraphBootstrap,
  routeGraphRefresh,
  demRead,
  polygonDisplay,
}

/// Immutable identity for a Mapping-store operation and its retry inputs.
class MappingStoreOperationKey {
  MappingStoreOperationKey._(this.kind, Map<String, String> parameters)
    : parameters = Map.unmodifiable(parameters);

  factory MappingStoreOperationKey.peakSeed(String regionKey) =>
      MappingStoreOperationKey._(MappingStoreOperationKind.peakSeed, {
        'regionKey': _requiredParameter('regionKey', regionKey),
      });

  factory MappingStoreOperationKey.peakUpdate(String regionKey) =>
      MappingStoreOperationKey._(MappingStoreOperationKind.peakUpdate, {
        'regionKey': _requiredParameter('regionKey', regionKey),
      });

  const MappingStoreOperationKey.tasmapBootstrap()
    : kind = MappingStoreOperationKind.tasmapBootstrap,
      parameters = const {};

  const MappingStoreOperationKey.tasmapUpdate()
    : kind = MappingStoreOperationKind.tasmapUpdate,
      parameters = const {};

  const MappingStoreOperationKey.naturalFeaturesBootstrap()
    : kind = MappingStoreOperationKind.naturalFeaturesBootstrap,
      parameters = const {};

  const MappingStoreOperationKey.naturalFeaturesRefresh()
    : kind = MappingStoreOperationKind.naturalFeaturesRefresh,
      parameters = const {};

  factory MappingStoreOperationKey.routeGraphBootstrap(String coverageKey) =>
      MappingStoreOperationKey._(
        MappingStoreOperationKind.routeGraphBootstrap,
        {
          'routingCoverageKey': _requiredParameter(
            'routingCoverageKey',
            coverageKey,
          ),
        },
      );

  factory MappingStoreOperationKey.routeGraphRefresh(String coverageKey) =>
      MappingStoreOperationKey._(MappingStoreOperationKind.routeGraphRefresh, {
        'routingCoverageKey': _requiredParameter(
          'routingCoverageKey',
          coverageKey,
        ),
      });

  factory MappingStoreOperationKey.demRead({
    required String demSourceKey,
    required String routeGeometryIdentity,
    required String geometryVersion,
  }) => MappingStoreOperationKey._(MappingStoreOperationKind.demRead, {
    'demSourceKey': _requiredParameter('demSourceKey', demSourceKey),
    'routeGeometryIdentity': _requiredParameter(
      'routeGeometryIdentity',
      routeGeometryIdentity,
    ),
    'geometryVersion': _requiredParameter('geometryVersion', geometryVersion),
  });

  factory MappingStoreOperationKey.polygonDisplay(String path) =>
      MappingStoreOperationKey._(MappingStoreOperationKind.polygonDisplay, {
        'path': _requiredParameter('path', path),
      });

  final MappingStoreOperationKind kind;
  final Map<String, String> parameters;

  String get description {
    final name = switch (kind) {
      MappingStoreOperationKind.peakSeed => 'Peak seed',
      MappingStoreOperationKind.peakUpdate => 'Peak update',
      MappingStoreOperationKind.tasmapBootstrap => 'TasMap bootstrap',
      MappingStoreOperationKind.tasmapUpdate => 'TasMap update',
      MappingStoreOperationKind.naturalFeaturesBootstrap =>
        'Natural Features bootstrap',
      MappingStoreOperationKind.naturalFeaturesRefresh =>
        'Natural Features refresh',
      MappingStoreOperationKind.routeGraphBootstrap => 'Route-graph bootstrap',
      MappingStoreOperationKind.routeGraphRefresh => 'Route-graph refresh',
      MappingStoreOperationKind.demRead => 'DEM read',
      MappingStoreOperationKind.polygonDisplay => 'Polygon display',
    };
    if (parameters.isEmpty) {
      return name;
    }
    return '$name (${parameters.values.join(', ')})';
  }

  @override
  bool operator ==(Object other) =>
      other is MappingStoreOperationKey &&
      kind == other.kind &&
      mapEquals(parameters, other.parameters);

  @override
  int get hashCode => Object.hash(
    kind,
    Object.hashAll(
      parameters.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );

  @override
  String toString() => '${kind.name}:${parameters.entries.join(',')}';

  static String _requiredParameter(String name, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, name, 'must not be empty');
    }
    return trimmed;
  }
}

/// A source read failed after the application had reached its ready scope.
class MappingStoreOperationException implements Exception {
  MappingStoreOperationException({required Iterable<String> paths, this.cause})
    : paths = List.unmodifiable(_uniquePaths(paths));

  final List<String> paths;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'Mapping data store operation failed: ${paths.join(', ')}'
      : 'Mapping data store operation failed: $cause';
}

class MappingStoreOperationFailure {
  MappingStoreOperationFailure({
    required this.key,
    required Iterable<String> paths,
    required this.retryAction,
  }) : paths = List.unmodifiable(_uniquePaths(paths));

  final MappingStoreOperationKey key;
  final List<String> paths;
  final Future<void> Function() retryAction;

  Future<void> retry() => retryAction();
}

/// Revalidates a source path immediately before the caller opens it.
class MappingStoreOperationFileAccess {
  MappingStoreOperationFileAccess({
    required this.rootPath,
    required this.fileSystem,
  });

  final String rootPath;
  final MappingStoreFileSystem fileSystem;

  Future<T> open<T>({
    required String relativePath,
    required Future<T> Function(String canonicalPath) opener,
  }) async {
    final canonicalPath = await _resolveReadablePath(relativePath);
    return opener(canonicalPath);
  }

  Future<String> readText(String relativePath) {
    return open(relativePath: relativePath, opener: fileSystem.readText);
  }

  Future<String> _resolveReadablePath(String relativePath) async {
    if (!_isSafeRelativePath(relativePath)) {
      throw MappingStoreOperationException(paths: [relativePath]);
    }
    try {
      final root = await fileSystem.canonicalize(rootPath);
      final candidate = p.join(root, relativePath);
      final target = await fileSystem.canonicalize(candidate);
      if (!p.isWithin(root, target) || !await fileSystem.fileExists(target)) {
        throw MappingStoreOperationException(paths: [relativePath]);
      }
      await fileSystem.checkReadable(target);
      return target;
    } on MappingStoreOperationException {
      rethrow;
    } on Object catch (error) {
      throw MappingStoreOperationException(paths: [relativePath], cause: error);
    }
  }
}

/// Coordinates Mapping-store operations after startup without owning feature state.
class MappingStoreOperationCoordinator extends ChangeNotifier {
  final Map<MappingStoreOperationKey, Future<dynamic>> _pending = {};
  final Map<String, Future<void>> _writerTails = {};
  final List<MappingStoreOperationFailure> _failures = [];
  bool _isRetrying = false;

  List<MappingStoreOperationFailure> get failures =>
      List.unmodifiable(_failures);
  MappingStoreOperationFailure? get activeFailure =>
      _failures.isEmpty ? null : _failures.first;
  bool get isRetrying => _isRetrying;

  Future<T> run<T>({
    required MappingStoreOperationKey key,
    required Future<T> Function() action,
    Iterable<String> writerTables = const [],
  }) {
    final pending = _pending[key];
    if (pending != null) {
      return pending as Future<T>;
    }

    late final Future<T> future;
    future = Future<T>(() async {
      try {
        final result = await _runWithWriterLocks(writerTables, action);
        _removeFailure(key);
        return result;
      } on MappingStoreOperationException catch (error, stackTrace) {
        _recordFailure(
          key: key,
          paths: error.paths,
          retry: () async {
            await run<T>(key: key, action: action, writerTables: writerTables);
          },
        );
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
    _pending[key] = future;
    future.then<void>(
      (_) => _clearPending(key, future),
      onError: (_, _) => _clearPending(key, future),
    );
    return future;
  }

  Future<void> retryActive() async {
    final active = activeFailure;
    if (active == null || _isRetrying) {
      return;
    }
    _isRetrying = true;
    notifyListeners();
    try {
      await active.retry();
    } on Object {
      // The failed retry replaces the active entry with updated details.
    } finally {
      _isRetrying = false;
      notifyListeners();
    }
  }

  void dismissActive() {
    if (_failures.isEmpty) {
      return;
    }
    _failures.removeAt(0);
    notifyListeners();
  }

  Future<T> _runWithWriterLocks<T>(
    Iterable<String> writerTables,
    Future<T> Function() action,
  ) {
    final tables = writerTables.toSet().toList()..sort();
    if (tables.isEmpty) {
      return action();
    }
    final predecessors = [
      for (final table in tables)
        if (_writerTails[table] case final Future<void> tail) tail,
    ];
    final result = Future.wait(predecessors).then((_) => action());
    final settled = result.then<void>((_) {}, onError: (_, _) {});
    for (final table in tables) {
      _writerTails[table] = settled;
    }
    return result;
  }

  void _clearPending(MappingStoreOperationKey key, Future<dynamic> future) {
    if (identical(_pending[key], future)) {
      _pending.remove(key);
    }
  }

  void _recordFailure({
    required MappingStoreOperationKey key,
    required Iterable<String> paths,
    required Future<void> Function() retry,
  }) {
    final failure = MappingStoreOperationFailure(
      key: key,
      paths: paths,
      retryAction: retry,
    );
    final index = _failures.indexWhere((entry) => entry.key == key);
    if (index == -1) {
      _failures.add(failure);
    } else {
      _failures[index] = failure;
    }
    notifyListeners();
  }

  void _removeFailure(MappingStoreOperationKey key) {
    final index = _failures.indexWhere((entry) => entry.key == key);
    if (index == -1) {
      return;
    }
    _failures.removeAt(index);
    notifyListeners();
  }
}

class MappingStoreBootstrapOperation {
  const MappingStoreBootstrapOperation({
    required this.key,
    required this.shouldRun,
    required this.run,
    this.writerTables = const [],
  });

  final MappingStoreOperationKey key;
  final FutureOr<bool> Function() shouldRun;
  final Future<void> Function() run;
  final Iterable<String> writerTables;
}

/// Schedules conditional post-ready work exactly once per immutable operation.
class MappingStoreBootstrapCoordinator {
  MappingStoreBootstrapCoordinator({
    required this.operationCoordinator,
    required Iterable<MappingStoreBootstrapOperation> operations,
  }) : _operations = List.unmodifiable(operations);

  final MappingStoreOperationCoordinator operationCoordinator;
  final List<MappingStoreBootstrapOperation> _operations;
  Future<void>? _scheduled;

  Future<void> schedule() => _scheduled ??= _schedule();

  Future<void> _schedule() async {
    for (final operation in _operations) {
      if (!await operation.shouldRun()) {
        continue;
      }
      try {
        await operationCoordinator.run<void>(
          key: operation.key,
          action: operation.run,
          writerTables: operation.writerTables,
        );
      } on MappingStoreOperationException {
        // The operation coordinator owns the visible failure and retry.
      }
    }
  }
}

bool _isSafeRelativePath(String path) {
  if (path.isEmpty || p.isAbsolute(path) || path.contains('\\')) {
    return false;
  }
  return path
      .split('/')
      .every(
        (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
      );
}

List<String> _uniquePaths(Iterable<String> paths) {
  final unique = <String>{};
  for (final path in paths) {
    if (path.isNotEmpty) {
      unique.add(path);
    }
  }
  if (unique.isEmpty) {
    throw ArgumentError.value(paths, 'paths', 'must not be empty');
  }
  return unique.toList(growable: false);
}
