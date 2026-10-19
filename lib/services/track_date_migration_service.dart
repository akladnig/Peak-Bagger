import '../models/track_date_migration_metadata.dart';
import 'track_date_derivation_service.dart';
import 'track_date_migration_repository.dart';

enum TrackDateMigrationPhase { preparing, committing }

class TrackDateMigrationProgress {
  const TrackDateMigrationProgress(this.phase, this.processed, this.total);
  final TrackDateMigrationPhase phase;
  final int processed;
  final int total;
}

class TrackDateMigrationResult {
  const TrackDateMigrationResult(
    this.metadata, {
    this.alreadyCompleted = false,
  });
  final TrackDateMigrationMetadata metadata;
  final bool alreadyCompleted;
}

class TrackDateMigrationService {
  TrackDateMigrationService({
    required this.repository,
    required this.derivation,
    DateTime Function()? clock,
    Future<void> Function()? yieldToUi,
  }) : clock = clock ?? DateTime.now,
       yieldToUi = yieldToUi ?? _yield;

  final TrackDateMigrationRepository repository;
  final TrackDateDerivationService Function() derivation;
  final DateTime Function() clock;
  final Future<void> Function() yieldToUi;
  Future<TrackDateMigrationResult>? _attempt;
  bool _disposed = false;

  static Future<void> _yield() => Future<void>.delayed(Duration.zero);

  void dispose() => _disposed = true;

  Future<TrackDateMigrationResult> run({
    void Function(TrackDateMigrationProgress)? onProgress,
  }) => _attempt ??= Future(
    () => _run(onProgress),
  ).whenComplete(() => _attempt = null);

  void _checkActive() {
    if (_disposed) {
      throw StateError('Date recalculation owner was disposed before commit');
    }
  }

  Future<TrackDateMigrationResult> _run(
    void Function(TrackDateMigrationProgress)? onProgress,
  ) async {
    _checkActive();
    final completed = repository.readCompletion();
    if (ObjectBoxTrackDateMigrationRepository.isCurrent(completed)) {
      return TrackDateMigrationResult(completed!, alreadyCompleted: true);
    }
    final snapshot = repository.readSnapshot();
    final total = snapshot.tracks.length;
    onProgress?.call(
      TrackDateMigrationProgress(TrackDateMigrationPhase.preparing, 0, total),
    );
    await yieldToUi();
    _checkActive();
    // No geographic initialization or scan for a completed/empty database.
    final resolver = total == 0 ? null : derivation();
    final outcomes = <TrackDateDerivation>[];
    for (final track in snapshot.tracks) {
      _checkActive();
      outcomes.add(resolver!.derive(track.gpxFile));
      onProgress?.call(
        TrackDateMigrationProgress(
          TrackDateMigrationPhase.preparing,
          outcomes.length,
          total,
        ),
      );
      await yieldToUi();
    }
    _checkActive();
    onProgress?.call(
      TrackDateMigrationProgress(
        TrackDateMigrationPhase.committing,
        total,
        total,
      ),
    );
    await yieldToUi();
    _checkActive();
    final metadata = repository.commit(
      snapshot: snapshot,
      outcomes: outcomes,
      completedAt: clock(),
    );
    return TrackDateMigrationResult(metadata);
  }
}
