import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

class PeakListCoverageBackfillService {
  const PeakListCoverageBackfillService({
    required this._peakListRepository,
    required this._migrationMarkerStore,
  });

  final PeakListRepository _peakListRepository;
  final MigrationMarkerStore _migrationMarkerStore;

  Future<bool> backfillStoredPeakLists() async {
    if (await _migrationMarkerStore.isPeakListCoverageBackfillMarked()) {
      return false;
    }

    final changed = await _peakListRepository.backfillStoredPeakLists();
    await _migrationMarkerStore.markPeakListCoverageBackfillComplete();
    return changed;
  }
}
