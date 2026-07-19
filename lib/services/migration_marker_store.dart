import 'package:shared_preferences/shared_preferences.dart';

enum TrackStartupAction {
  importTracks,
  loadTracks,
  showRecovery,
  wipeAndImport,
}

class TrackStartupDecision {
  const TrackStartupDecision({
    required this.action,
    required this.markMigrationComplete,
  });

  final TrackStartupAction action;
  final bool markMigrationComplete;
}

class MigrationMarkerStore {
  static const migrationKey = 'track_optimization_migration_v1_complete';
  static const peaksBaggedBackfillKey = 'peaks_bagged_backfill_v1_complete';
  static const itemVisibilityBackfillKey =
      'item_visibility_backfill_v1_complete';
  static const peakListCoverageBackfillKey =
      'peak_list_coverage_backfill_v1_complete';

  const MigrationMarkerStore({
    Future<SharedPreferences> Function()? loadPreferences,
  }) : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _loadPreferences;

  Future<bool> isMarked() async {
    final preferences = await _loadPreferences();
    return preferences.getBool(migrationKey) ?? false;
  }

  Future<void> markComplete() async {
    final preferences = await _loadPreferences();
    await preferences.setBool(migrationKey, true);
  }

  Future<bool> isPeaksBaggedBackfillMarked() async {
    final preferences = await _loadPreferences();
    return preferences.getBool(peaksBaggedBackfillKey) ?? false;
  }

  Future<void> markPeaksBaggedBackfillComplete() async {
    final preferences = await _loadPreferences();
    await preferences.setBool(peaksBaggedBackfillKey, true);
  }

  Future<bool> isItemVisibilityBackfillMarked() async {
    final preferences = await _loadPreferences();
    return preferences.getBool(itemVisibilityBackfillKey) ?? false;
  }

  Future<void> markItemVisibilityBackfillComplete() async {
    final preferences = await _loadPreferences();
    await preferences.setBool(itemVisibilityBackfillKey, true);
  }

  Future<bool> isPeakListCoverageBackfillMarked() async {
    final preferences = await _loadPreferences();
    return preferences.getBool(peakListCoverageBackfillKey) ?? false;
  }

  Future<void> markPeakListCoverageBackfillComplete() async {
    final preferences = await _loadPreferences();
    await preferences.setBool(peakListCoverageBackfillKey, true);
  }

  static TrackStartupDecision decideStartupAction({
    required bool migrationMarked,
    required bool hasPersistedTracks,
    required bool hasRecoveryIssue,
  }) {
    if (!migrationMarked) {
      if (hasPersistedTracks) {
        return const TrackStartupDecision(
          action: TrackStartupAction.wipeAndImport,
          markMigrationComplete: true,
        );
      }

      return const TrackStartupDecision(
        action: TrackStartupAction.importTracks,
        markMigrationComplete: true,
      );
    }

    if (!hasPersistedTracks) {
      return const TrackStartupDecision(
        action: TrackStartupAction.importTracks,
        markMigrationComplete: false,
      );
    }

    if (hasRecoveryIssue) {
      return const TrackStartupDecision(
        action: TrackStartupAction.showRecovery,
        markMigrationComplete: false,
      );
    }

    return const TrackStartupDecision(
      action: TrackStartupAction.loadTracks,
      markMigrationComplete: false,
    );
  }
}
