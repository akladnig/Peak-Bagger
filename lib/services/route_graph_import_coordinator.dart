import 'package:flutter/foundation.dart';
import 'package:peak_bagger/models/route_graph_coverage.dart';
import 'package:peak_bagger/services/route_graph_coverage_resolver.dart';
import 'package:peak_bagger/services/route_graph_import_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';

enum RouteGraphCoverageImportStatus { queued, importing, ready, failed }

enum RouteGraphCoverageOutcomeStatus { refreshed, failed }

class RouteGraphCoverageImportState {
  const RouteGraphCoverageImportState({
    required this.routingCoverageKey,
    required this.displayName,
    required this.status,
    required this.hasActiveGeneration,
    this.error,
  });

  final String routingCoverageKey;
  final String displayName;
  final RouteGraphCoverageImportStatus status;
  final bool hasActiveGeneration;
  final String? error;
}

class RouteGraphCoverageImportOutcome {
  const RouteGraphCoverageImportOutcome.refreshed({
    required this.routingCoverageKey,
    required this.displayName,
    required this.elementCount,
  }) : status = RouteGraphCoverageOutcomeStatus.refreshed,
       error = null;

  const RouteGraphCoverageImportOutcome.failed({
    required this.routingCoverageKey,
    required this.displayName,
    required this.error,
  }) : status = RouteGraphCoverageOutcomeStatus.failed,
       elementCount = null;

  final String routingCoverageKey;
  final String displayName;
  final RouteGraphCoverageOutcomeStatus status;
  final int? elementCount;
  final String? error;
}

sealed class RouteGraphImportBatchResult {
  const RouteGraphImportBatchResult();
}

class RouteGraphImportBatchCompleted extends RouteGraphImportBatchResult {
  const RouteGraphImportBatchCompleted(this.outcomes);

  final List<RouteGraphCoverageImportOutcome> outcomes;
}

class RouteGraphImportBatchConfigurationFailure
    extends RouteGraphImportBatchResult {
  const RouteGraphImportBatchConfigurationFailure({
    this.error = 'Route graph configuration is invalid.',
  });

  final String error;
}

/// Owns the one process-wide route-graph batch so callers cannot overlap imports.
class RouteGraphImportCoordinator extends ChangeNotifier {
  RouteGraphImportCoordinator({
    required RouteGraphCoverageResolver coverageResolver,
    required RouteGraphImportService importService,
    required RouteGraphRepository repository,
  }) : _coverageResolver = coverageResolver,
       _importService = importService,
       _repository = repository;

  final RouteGraphCoverageResolver _coverageResolver;
  final RouteGraphImportService _importService;
  final RouteGraphRepository _repository;
  final Map<String, RouteGraphCoverageImportState> _states = {};

  Future<RouteGraphImportBatchResult>? _activeBatch;
  RouteGraphImportBatchResult? _lastCompletedBatch;

  List<RouteGraphCoverageImportState> get states =>
      List.unmodifiable(_states.values);

  RouteGraphCoverageImportState? stateFor(String routingCoverageKey) =>
      _states[routingCoverageKey];

  RouteGraphImportBatchResult? get lastCompletedBatch => _lastCompletedBatch;

  Future<RouteGraphImportBatchResult> bootstrap() => _startOrJoinBatch();

  Future<RouteGraphImportBatchResult> refreshAll() => _startOrJoinBatch();

  Future<RouteGraphImportBatchResult> _startOrJoinBatch() {
    final activeBatch = _activeBatch;
    if (activeBatch != null) {
      return activeBatch;
    }

    final batch = _runBatch();
    _activeBatch = batch;
    batch.whenComplete(() {
      if (identical(_activeBatch, batch)) {
        _activeBatch = null;
      }
    });
    return batch;
  }

  Future<RouteGraphImportBatchResult> _runBatch() async {
    late final List<RouteGraphCoverageImportInput> inputs;
    try {
      inputs = await _coverageResolver.resolve();
    } catch (_) {
      return _complete(const RouteGraphImportBatchConfigurationFailure());
    }

    try {
      await _repository.ensureMultiCoverageMigration();
    } catch (_) {
      return _complete(const RouteGraphImportBatchConfigurationFailure());
    }

    final preflightFailures = <String, String>{};
    for (final input in inputs) {
      final hasActiveGeneration = _repository.hasUsableActiveGenerationFor(
        input.definition.key,
      );
      try {
        await _repository.ensureCoverageFootprint(
          routingCoverageKey: input.definition.key,
          sourceRegionKeys: input.definition.sourceRegions
              .map((region) => region.key)
              .toList(growable: false),
          unavailableFootprint: input.unavailableFootprint,
        );
        _setState(
          input.definition,
          hasActiveGeneration
              ? RouteGraphCoverageImportStatus.ready
              : RouteGraphCoverageImportStatus.queued,
          hasActiveGeneration: hasActiveGeneration,
        );
      } catch (error) {
        final sanitizedError = _sanitizeCoverageError(error);
        preflightFailures[input.definition.key] = sanitizedError;
        _setState(
          input.definition,
          RouteGraphCoverageImportStatus.failed,
          hasActiveGeneration: hasActiveGeneration,
          error: sanitizedError,
        );
      }
    }

    final outcomes = <RouteGraphCoverageImportOutcome>[];
    for (final input in inputs) {
      final definition = input.definition;
      final preflightFailure = preflightFailures[definition.key];
      if (preflightFailure != null) {
        outcomes.add(
          RouteGraphCoverageImportOutcome.failed(
            routingCoverageKey: definition.key,
            displayName: definition.displayName,
            error: preflightFailure,
          ),
        );
        continue;
      }
      final hadActiveGeneration = _repository.hasUsableActiveGenerationFor(
        definition.key,
      );
      _setState(
        definition,
        RouteGraphCoverageImportStatus.importing,
        hasActiveGeneration: hadActiveGeneration,
      );
      try {
        final outcome = await _importService.importCoverageInput(
          input,
          bootstrap: false,
        );
        _setState(
          definition,
          RouteGraphCoverageImportStatus.ready,
          hasActiveGeneration: true,
        );
        outcomes.add(
          RouteGraphCoverageImportOutcome.refreshed(
            routingCoverageKey: definition.key,
            displayName: definition.displayName,
            elementCount: outcome.elementCount,
          ),
        );
      } catch (error) {
        final hasActiveGeneration = _repository.hasUsableActiveGenerationFor(
          definition.key,
        );
        final sanitizedError = _sanitizeCoverageError(error);
        _setState(
          definition,
          RouteGraphCoverageImportStatus.failed,
          hasActiveGeneration: hasActiveGeneration,
          error: sanitizedError,
        );
        outcomes.add(
          RouteGraphCoverageImportOutcome.failed(
            routingCoverageKey: definition.key,
            displayName: definition.displayName,
            error: sanitizedError,
          ),
        );
      }
    }
    return _complete(
      RouteGraphImportBatchCompleted(List.unmodifiable(outcomes)),
    );
  }

  RouteGraphImportBatchResult _complete(RouteGraphImportBatchResult result) {
    _lastCompletedBatch = result;
    notifyListeners();
    return result;
  }

  void _setState(
    RouteGraphCoverageDefinition definition,
    RouteGraphCoverageImportStatus status, {
    required bool hasActiveGeneration,
    String? error,
  }) {
    _states[definition.key] = RouteGraphCoverageImportState(
      routingCoverageKey: definition.key,
      displayName: definition.displayName,
      status: status,
      hasActiveGeneration: hasActiveGeneration,
      error: error,
    );
    notifyListeners();
  }

  String _sanitizeCoverageError(Object error) {
    final value = '$error'.replaceFirst('RouteGraphLoadException: ', '');
    return value.isEmpty ? 'Route graph import failed.' : value;
  }
}
