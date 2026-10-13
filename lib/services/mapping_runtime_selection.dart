import 'dart:developer' as developer;

import 'package:path/path.dart' as p;
import 'mapping_data_store.dart';
import 'mapping_replica_records.dart';
import 'mapping_runtime_io.dart';
import 'mapping_session_protection.dart';
import 'mapping_runtime_config.dart';
import 'performance_measurement.dart';

class MappingRuntimeSession {
  MappingRuntimeSession(this.catalog, this.diagnostics);
  final MappingCatalog catalog;
  final List<String> diagnostics;
  void close() => catalog.sessionProtection!.close();
}

class MappingRuntimeSelector {
  MappingRuntimeSelector(
    this.base, {
    MappingRuntimeIo? io,
    this._publish,
    this.loadCatalog = loadRuntimeCatalog,
  }) : io = io ?? MappingRuntimeIo();
  final String base;
  final MappingRuntimeIo io;
  final Future<MappingCatalog> Function(String root) loadCatalog;
  final Future<void> Function(String relative, Object value)? _publish;
  Future<void> publish(String relative, Object value) =>
      _publish?.call(relative, value) ?? io.publishState(base, relative, value);

  Future<MappingRuntimeSession> launch() async {
    await requireLocalRuntimePath(base, io.isLocal);
    final coordination = await io.lock(
      p.join(base, 'locks', 'selection-retention.lock'),
    );
    try {
      final prior = await _recoverSelection();
      final active = prior?['active'] as Map<String, Object?>?;
      final recovery = prior?['recovery'] as Map<String, Object?>?;
      final diagnostics = <String>[];
      final ids = await io.eligibleIds(base);
      final candidates = <({String id, DateTime time})>[];
      ({String id, DateTime time})? newestSelected;
      for (final selected in [active, recovery]) {
        if (selected == null) continue;
        try {
          final value =
              (await io.readMetadata(
                    p.join(
                      base,
                      'eligibility',
                      '${selected['generationId']}.json',
                    ),
                  )).value
                  as Map;
          final order = (
            id: selected['generationId'] as String,
            time: DateTime.parse(value['eligibleAtUtc'] as String),
          );
          if (newestSelected == null ||
              compareGenerationOrder(order, newestSelected) > 0) {
            newestSelected = order;
          }
        } catch (_) {
          // Readiness attempts below report the actual selected-record failure.
        }
      }
      for (final id in ids) {
        if (id == active?['generationId'] || id == recovery?['generationId']) {
          continue;
        }
        try {
          requireRuntimeUuid(id);
          final record =
              (await io.readMetadata(
                    p.join(base, 'eligibility', '$id.json'),
                  )).value
                  as Map;
          final order = (
            id: id,
            time: DateTime.parse(record['eligibleAtUtc'] as String),
          );
          if (newestSelected == null ||
              compareGenerationOrder(order, newestSelected) > 0) {
            candidates.add(order);
          }
        } catch (error, stack) {
          final diagnostic = 'Candidate $id at $base: $error';
          diagnostics.add(diagnostic);
          developer.log(
            diagnostic,
            name: 'mapping-runtime',
            error: error,
            stackTrace: stack,
          );
        }
      }
      candidates.sort((a, b) => compareGenerationOrder(b, a));
      final attempts = <({String id, Map<String, Object?>? expected})>[
        if (candidates.isNotEmpty) (id: candidates.first.id, expected: null),
        if (active != null)
          (id: active['generationId'] as String, expected: active),
        if (recovery != null)
          (id: recovery['generationId'] as String, expected: recovery),
      ];
      for (final attempt in attempts) {
        try {
          final generation = await MappingReplicaRecords(
            base,
          ).eligible(attempt.id);
          if (attempt.expected != null &&
              runtimeDigest(generation.entry) !=
                  runtimeDigest(attempt.expected!)) {
            throw const FormatException(
              'Selected eligibility identity changed',
            );
          }
          final catalog = await loadCatalog(generation.rootPath);
          if (!p.equals(catalog.rootPath, generation.rootPath) ||
              catalog.authorizedPaths.length != generation.paths.length ||
              !catalog.authorizedPaths.containsAll(generation.paths)) {
            throw const FormatException(
              'Catalog root/path set differs from validated integrity inventory',
            );
          }
          final sessionId = runtimeUuid();
          final lock = await io.lock(
            p.join(base, 'locks', 'session-$sessionId.lock'),
          );
          try {
            await publish('sessions/$sessionId.json', {
              'kind': 'mapping-session',
              'schemaVersion': 1,
              'sessionId': sessionId,
              'owner': io.owner(sessionId),
              'generationId': generation.generationId,
              'inventorySha256': generation.inventorySha256,
              'appReaderRelease': 'e442ea38-fc1d-4ca0-b07d-223b01df6c35',
            });
            if (active?['generationId'] != generation.generationId) {
              await _commitSelection(generation, prior);
            }
            return MappingRuntimeSession(
              catalog.withSessionProtection(
                MappingSessionProtection(lock.close),
              ),
              List.unmodifiable(diagnostics),
            );
          } catch (_) {
            lock.close();
            rethrow;
          }
        } catch (error, stack) {
          final diagnostic =
              'Generation ${attempt.id} at ${p.join(base, 'generations', attempt.id, 'payload')}: $error';
          diagnostics.add(diagnostic);
          developer.log(
            diagnostic,
            name: 'mapping-runtime',
            error: error,
            stackTrace: stack,
          );
        }
      }
      if (attempts.isEmpty && await io.exists(p.join(base, 'operation.json'))) {
        try {
          final operation = runtimeRecord(
            (await io.readMetadata(p.join(base, 'operation.json'))).value,
            'mapping-operation',
            'operationId parentOperationId owner releaseId stage state generationId publicationId protectedExportIds protectedGenerationIds startedAtUtc progressAtUtc outcomeRecordSha256',
          );
          if (operation['state'] == 'failed' ||
              operation['state'] == 'outcome-unknown') {
            diagnostics.add(
              'Local refresh ${operation['state']} stage=${operation['stage']} operation=${operation['operationId']} at ${p.join(base, 'operation.json')}',
            );
            final failurePath = p.join(
              base,
              'failures',
              '${operation['operationId']}.json',
            );
            if (await io.exists(failurePath)) {
              final failure = runtimeRecord(
                (await io.readMetadata(failurePath)).value,
                'mapping-validation-report',
                'generationId inventorySha256 operationId validationProfile validatorRelease state checks diagnostics validatedAtUtc',
              );
              diagnostics.add('$failurePath: ${failure['diagnostics']}');
            }
          }
        } catch (error) {
          diagnostics.add(
            'Invalid local refresh metadata at ${p.join(base, 'operation.json')}: $error',
          );
        }
      }
      throw MappingRuntimeUnavailable(
        rootPath: base,
        paths: [base, ...diagnostics],
        diagnostic: diagnostics.isEmpty
            ? 'Initial synchronization must complete before this replica can be used.'
            : 'Local replica validation or selection failed.',
      );
    } finally {
      coordination.close();
    }
  }

  Future<void> _commitSelection(
    MappingReplicaGeneration generation,
    Map<String, Object?>? prior,
  ) async {
    final next = <String, Object?>{
      'kind': 'mapping-selection',
      'schemaVersion': 1,
      'selectionId': runtimeUuid(),
      'active': generation.entry,
      'recovery': prior?['active'],
      'revision': (prior?['revision'] as int? ?? 0) + 1,
      'selectedAtUtc': DateTime.now().toUtc().toIso8601String(),
    };
    final transaction = <String, Object?>{
      'kind': 'mapping-selection-transaction',
      'schemaVersion': 1,
      'operationId': runtimeUuid(),
      'priorSelection': prior,
      'nextSelection': next,
      'state': 'prepared',
    };
    try {
      await publish('selection-transaction.json', transaction);
      await publish('selection.json', next);
      await publish('selection-transaction.json', {
        ...transaction,
        'state': 'committed',
      });
    } catch (error) {
      if (prior != null) {
        try {
          await io.publishState(base, 'selection.json', prior);
        } catch (rollbackError) {
          throw StateError(
            '$error; selection restoration failed: $rollbackError; retained transaction protects old/new',
          );
        }
      }
      rethrow;
    }
  }

  Future<Map<String, Object?>?> _recoverSelection() async {
    Map<String, Object?>? current;
    Object? readError;
    try {
      if (await io.exists(p.join(base, 'selection.json'))) {
        current = checkedSelection(
          (await io.readMetadata(p.join(base, 'selection.json'))).value,
        );
      }
    } catch (error) {
      readError = error;
    }
    if (!await io.exists(p.join(base, 'selection-transaction.json'))) {
      if (readError != null) {
        throw FormatException('Invalid selection at $base: $readError');
      }
      return current;
    }
    final transaction = runtimeRecord(
      (await io.readMetadata(p.join(base, 'selection-transaction.json'))).value,
      'mapping-selection-transaction',
      'operationId priorSelection nextSelection state',
    );
    final prior = transaction['priorSelection'] == null
        ? null
        : checkedSelection(transaction['priorSelection']);
    final next = checkedSelection(transaction['nextSelection']);
    if (!{'prepared', 'committed'}.contains(transaction['state']) ||
        next['revision'] != (prior?['revision'] as int? ?? 0) + 1) {
      throw const FormatException(
        'Invalid selection transaction state/revision',
      );
    }
    if (current != null &&
        (runtimeDigest(current) == runtimeDigest(next) ||
            prior != null && runtimeDigest(current) == runtimeDigest(prior))) {
      return current;
    }
    final recovered = transaction['state'] == 'committed' ? next : prior;
    if (recovered != null) {
      await io.publishState(base, 'selection.json', recovered);
    }
    return recovered;
  }
}

int compareGenerationOrder(
  ({String id, DateTime time}) a,
  ({String id, DateTime time}) b,
) {
  final time = a.time.compareTo(b.time);
  return time == 0 ? a.id.compareTo(b.id) : time;
}

class MappingRuntimeUnavailable implements Exception {
  MappingRuntimeUnavailable({
    required this.rootPath,
    required Iterable<String> paths,
    required this.diagnostic,
    this.isReplica = true,
  }) : paths = List.unmodifiable(paths);
  final String rootPath;
  final List<String> paths;
  final String diagnostic;
  final bool isReplica;
  @override
  String toString() => '$diagnostic ${paths.join('\n')}';
}

Future<MappingCatalog> loadRuntimeCatalog(String root) async {
  final store = MappingDataStore(rootPath: root);
  performanceMeasurement.context['selected_root'] = root;
  final preflight = await performanceMeasurement.phase(
    'startup.manifest-path-validation',
    store.preflight,
  );
  return performanceMeasurement.phase(
    'startup.polygon-catalog',
    () => store.loadCatalogFromPreflight(preflight),
  );
}

Map<String, Object?> checkedSelection(Object? value) {
  final selection = runtimeRecord(
    value,
    'mapping-selection',
    'selectionId active recovery revision selectedAtUtc',
  );
  if (selection['revision'] is! int || (selection['revision'] as int) < 1) {
    throw const FormatException('Invalid selection revision');
  }
  for (final key in ['active', 'recovery']) {
    final entry = selection[key];
    if (entry == null && key == 'recovery') continue;
    if (entry is! Map ||
        entry.length != 3 ||
        !entry.keys.toSet().containsAll({
          'generationId',
          'inventorySha256',
          'eligibilitySha256',
        })) {
      throw const FormatException('Invalid selection entry');
    }
    requireRuntimeUuid(entry['generationId']);
    for (final digest in ['inventorySha256', 'eligibilitySha256']) {
      if (entry[digest] is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(entry[digest] as String)) {
        throw const FormatException('Invalid selected digest');
      }
    }
  }
  return selection;
}
