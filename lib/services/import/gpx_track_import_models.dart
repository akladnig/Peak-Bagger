import 'package:peak_bagger/models/gpx_track.dart';

/// Importer-facing plan returned by the selective-import API.
///
/// Contains only successful additive-import candidates. Duplicates, skipped files,
/// and hard failures are represented through counts and warning text instead.
class GpxTrackImportPlan {
  const GpxTrackImportPlan({
    required this.items,
    required this.unchangedCount,
    required this.nonTasmanianCount,
    required this.errorCount,
    this.warningMessage,
  });

  final List<GpxTrackImportPlanItem> items;
  final int unchangedCount;
  final int nonTasmanianCount;
  final int errorCount;
  final String? warningMessage;
}

/// A single file in an import plan.
class GpxTrackImportPlanItem {
  const GpxTrackImportPlanItem({
    required this.sourcePath,
    required this.track,
    this.plannedManagedRelativePath,
    this.shouldPlaceInManagedStorage = false,
  });

  final String sourcePath;
  final GpxTrack track;
  final String? plannedManagedRelativePath;
  final bool shouldPlaceInManagedStorage;
}

/// Provider-facing result returned by MapNotifier after persistence and placement.
class GpxTrackImportResult {
  const GpxTrackImportResult({
    required this.items,
    required this.addedCount,
    required this.unchangedCount,
    required this.nonTasmanianCount,
    required this.errorCount,
    this.warningMessage,
  });

  final List<GpxTrackImportItem> items;
  final int addedCount;
  final int unchangedCount;
  final int nonTasmanianCount;
  final int errorCount;
  final String? warningMessage;
}

/// A single track in the final import result.
class GpxTrackImportItem {
  const GpxTrackImportItem({
    required this.track,
    this.managedRelativePath,
    this.managedPlacementPending = false,
  });

  final GpxTrack track;
  final String? managedRelativePath;
  final bool managedPlacementPending;
}
