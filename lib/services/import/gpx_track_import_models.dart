import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart';

/// Importer-facing plan returned by the selective-import API.
///
/// Contains only successful additive-import candidates. Duplicates, skipped files,
/// and hard failures are represented through counts and warning text instead.
class GpxTrackImportPlan {
  const GpxTrackImportPlan({
    required this.items,
    required this.unchangedCount,
    required this.unsupportedCount,
    required this.errorCount,
    this.warningMessage,
  });

  final List<GpxTrackImportPlanItem> items;
  final int unchangedCount;
  final int unsupportedCount;
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

abstract class GpxImportItem {
  const GpxImportItem();
}

/// A single track in the final import result.
class GpxTrackImportItem extends GpxImportItem {
  const GpxTrackImportItem({required this.track});

  final GpxTrack track;
}

/// A single route in the final import result.
class GpxRouteImportItem extends GpxImportItem {
  const GpxRouteImportItem({required this.route});

  final Route route;
}

/// Provider-facing result returned by MapNotifier after persistence and placement.
class GpxImportResult<TItem extends GpxImportItem> {
  const GpxImportResult({
    required this.items,
    required this.addedCount,
    required this.unchangedCount,
    required this.unsupportedCount,
    required this.errorCount,
    this.warningMessage,
  });

  final List<TItem> items;
  final int addedCount;
  final int unchangedCount;
  final int unsupportedCount;
  final int errorCount;
  final String? warningMessage;
}

typedef GpxTrackImportResult = GpxImportResult<GpxTrackImportItem>;
