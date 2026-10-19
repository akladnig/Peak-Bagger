import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/track_date_migration_repository.dart';
import '../services/track_date_migration_service.dart';
import 'track_date_derivation_provider.dart';

// Production injects its database. Isolated widgets without a database do not
// silently open a different store or attempt a migration.
final trackDateMigrationRepositoryProvider =
    Provider<TrackDateMigrationRepository?>((ref) => null);
final trackDateMigrationServiceProvider = Provider<TrackDateMigrationService?>((
  ref,
) {
  final repository = ref.watch(trackDateMigrationRepositoryProvider);
  if (repository == null) return null;
  final service = TrackDateMigrationService(
    repository: repository,
    derivation: () => ref.read(trackDateDerivationServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

enum TrackDateMigrationStatus {
  checking,
  running,
  completed,
  failed,
  notRequired,
}

class TrackDateMigrationState {
  const TrackDateMigrationState(
    this.status, {
    this.progress,
    this.result,
    this.error,
  });
  final TrackDateMigrationStatus status;
  final TrackDateMigrationProgress? progress;
  final TrackDateMigrationResult? result;
  final Object? error;

  bool get isReady =>
      status == TrackDateMigrationStatus.completed ||
      status == TrackDateMigrationStatus.notRequired;
}

final trackDateMigrationProvider =
    NotifierProvider<TrackDateMigrationNotifier, TrackDateMigrationState>(
      TrackDateMigrationNotifier.new,
    );

/// App-scoped, never auto-disposed when a route/status widget leaves the tree.
class TrackDateMigrationNotifier extends Notifier<TrackDateMigrationState> {
  Future<bool>? _attempt;

  @override
  TrackDateMigrationState build() => TrackDateMigrationState(
    ref.watch(trackDateMigrationServiceProvider) == null
        ? TrackDateMigrationStatus.notRequired
        : TrackDateMigrationStatus.checking,
  );

  Future<bool> ensureCurrent() {
    if (state.isReady) return Future.value(true);
    return _attempt ??= Future(_run).whenComplete(() => _attempt = null);
  }

  Future<bool> _run() async {
    if (!ref.mounted) return false;
    state = const TrackDateMigrationState(TrackDateMigrationStatus.running);
    try {
      final result = await ref
          .read(trackDateMigrationServiceProvider)!
          .run(
            onProgress: (progress) {
              if (ref.mounted) {
                state = TrackDateMigrationState(
                  TrackDateMigrationStatus.running,
                  progress: progress,
                );
              }
            },
          );
      if (ref.mounted) {
        state = TrackDateMigrationState(
          TrackDateMigrationStatus.completed,
          result: result,
        );
      }
      return true;
    } catch (error, stack) {
      developer.log(
        'Track date recalculation failed; database remains incomplete and retryable',
        name: 'track_date_migration',
        error: error,
        stackTrace: stack,
      );
      if (ref.mounted) {
        state = TrackDateMigrationState(
          TrackDateMigrationStatus.failed,
          error: error,
        );
      }
      return false;
    }
  }
}

final trackDateMigrationBootstrapProvider = FutureProvider<bool>(
  (ref) => ref.read(trackDateMigrationProvider.notifier).ensureCurrent(),
);
