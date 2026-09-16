import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart';

/// Importer-facing plan returned by the selective-import API.
///
/// Contains prospective additive and replacement candidates in selected-file order.
class GpxTrackImportPlan {
  const GpxTrackImportPlan({
    required this.items,
    required this.addedCount,
    required this.replacedCount,
    required this.unchangedCount,
    required this.unsupportedCount,
    required this.errorCount,
    required this.errors,
    this.warningMessage,
  });

  final List<GpxTrackImportPlanItem> items;
  final int addedCount;
  final int replacedCount;
  final int unchangedCount;
  final int unsupportedCount;
  final int errorCount;
  final List<GpxTrackImportError> errors;
  final String? warningMessage;
}

/// A single file in an import plan.
class GpxTrackImportPlanItem {
  const GpxTrackImportPlanItem({
    required this.sourcePath,
    required this.track,
    this.replacedTrack,
    this.plannedManagedRelativePath,
    this.shouldPlaceInManagedStorage = false,
  });

  final String sourcePath;
  final GpxTrack track;
  final GpxTrack? replacedTrack;
  final String? plannedManagedRelativePath;
  final bool shouldPlaceInManagedStorage;

  bool get isReplacement => replacedTrack != null;
}

class GpxTrackImportError {
  const GpxTrackImportError({required this.sourcePath, required this.reason});

  final String sourcePath;
  final String reason;
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
    this.replacedCount = 0,
    required this.unchangedCount,
    required this.unsupportedCount,
    required this.errorCount,
    this.errors = const [],
    this.warningMessage,
  });

  final List<TItem> items;
  final int addedCount;
  final int replacedCount;
  final int unchangedCount;
  final int unsupportedCount;
  final int errorCount;
  final List<GpxTrackImportError> errors;
  final String? warningMessage;
}

typedef GpxTrackImportResult = GpxImportResult<GpxTrackImportItem>;
