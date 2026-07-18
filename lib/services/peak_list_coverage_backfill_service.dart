import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

class PeakListMembershipMigrationResult {
  const PeakListMembershipMigrationResult({
    required this.changed,
    required this.unsupportedPeakListIds,
  });

  final bool changed;
  final List<int> unsupportedPeakListIds;

  bool get hasUnsupportedPeakLists => unsupportedPeakListIds.isNotEmpty;
}

class PeakListCoverageBackfillService {
  const PeakListCoverageBackfillService({
    required this._peakListRepository,
    required this._migrationMarkerStore,
  });

  final PeakListRepository _peakListRepository;
  final MigrationMarkerStore _migrationMarkerStore;

  Future<PeakListMembershipMigrationResult> backfillStoredPeakLists() async {
    if (await _migrationMarkerStore.isPeakListMembershipMigrationMarked()) {
      return PeakListMembershipMigrationResult(
        changed: false,
        unsupportedPeakListIds: _peakListRepository
            .getAllPeakLists()
            .where((peakList) => peakList.isUnsupportedLegacy)
            .map((peakList) => peakList.peakListId)
            .toList(growable: false),
      );
    }

    var changed = false;
    final unsupportedPeakListIds = <int>[];

    for (final peakList in _peakListRepository.getAllPeakLists()) {
      if (!peakList.needsLegacyMembershipMigration) {
        if (peakList.isUnsupportedLegacy) {
          unsupportedPeakListIds.add(peakList.peakListId);
        }
        continue;
      }

      try {
        final items = decodePeakListItems(peakList.peakList);
        await _peakListRepository.replaceLegacyMembershipWithStoredItems(
          peakListId: peakList.peakListId,
          items: items,
        );
        changed = true;
      } catch (_) {
        await _peakListRepository.markUnsupportedLegacyMembership(
          peakList.peakListId,
        );
        unsupportedPeakListIds.add(peakList.peakListId);
        changed = true;
      }
    }

    await _migrationMarkerStore.markPeakListMembershipMigrationComplete();
    return PeakListMembershipMigrationResult(
      changed: changed,
      unsupportedPeakListIds: List<int>.unmodifiable(unsupportedPeakListIds),
    );
  }
}
