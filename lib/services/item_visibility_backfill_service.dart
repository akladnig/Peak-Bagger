import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/route_repository.dart';

class ItemVisibilityBackfillService {
  ItemVisibilityBackfillService({
    required this._routeRepository,
    required this._gpxTrackRepository,
    required this._migrationMarkerStore,
  });

  final RouteRepository _routeRepository;
  final GpxTrackRepository _gpxTrackRepository;
  final MigrationMarkerStore _migrationMarkerStore;

  Future<bool> backfillVisibleItems() async {
    if (await _migrationMarkerStore.isItemVisibilityBackfillMarked()) {
      return false;
    }

    var changed = false;

    for (final route in _routeRepository.getAllRoutes()) {
      if (route.visible) {
        continue;
      }
      route.visible = true;
      _routeRepository.saveRoute(route);
      changed = true;
    }

    for (final track in _gpxTrackRepository.getAllTracks()) {
      if (track.visible) {
        continue;
      }
      track.visible = true;
      _gpxTrackRepository.saveTrack(track);
      changed = true;
    }

    await _migrationMarkerStore.markItemVisibilityBackfillComplete();
    return changed;
  }
}
