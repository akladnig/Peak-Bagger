import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

class TassyFullPeakListSyncResult {
  const TassyFullPeakListSyncResult({
    required this.addedCount,
    required this.updatedCount,
    required this.removedCount,
  });

  final int addedCount;
  final int updatedCount;
  final int removedCount;

  bool get hasChanges => addedCount > 0 || updatedCount > 0 || removedCount > 0;
}

class TassyFullPeakListSyncService {
  TassyFullPeakListSyncService(this._repository);

  static const String targetName = 'Tassy Full';

  final PeakListRepository _repository;

  Future<TassyFullPeakListSyncResult> refresh() async {
    final peakRegionsByOsmId = _repository.peakRegionsByOsmId();
    final sourceItemsByPeakOsmId = <int, PeakListItem>{};

    for (final peakList in _repository.getAllPeakLists()) {
      if (peakList.name == targetName) {
        continue;
      }

      final items = _repository.getPeakListItemsForList(peakList.peakListId);

      for (final item in items) {
        if (!_isTasmanianPeak(item.peakOsmId, peakRegionsByOsmId)) {
          continue;
        }

        final existing = sourceItemsByPeakOsmId[item.peakOsmId];
        if (existing == null || item.points > existing.points) {
          sourceItemsByPeakOsmId[item.peakOsmId] = item;
        }
      }
    }

    final existingTarget = _repository.findByName(targetName);

    final mergedByPeakOsmId = <int, PeakListItem>{};
    var removedCount = 0;
    for (final item in existingTarget == null
        ? const <PeakListItem>[]
        : _repository.getPeakListItemsForList(existingTarget.peakListId)) {
      if (_isTasmanianPeak(item.peakOsmId, peakRegionsByOsmId)) {
        mergedByPeakOsmId[item.peakOsmId] = item;
        continue;
      }

      removedCount += 1;
    }

    var addedCount = 0;
    var updatedCount = 0;
    for (final entry in sourceItemsByPeakOsmId.entries) {
      final previous = mergedByPeakOsmId[entry.key];
      if (previous == null) {
        addedCount += 1;
      } else if (previous.points != entry.value.points) {
        updatedCount += 1;
      }
      mergedByPeakOsmId[entry.key] = entry.value;
    }

    final mergedItems = mergedByPeakOsmId.values.toList()
      ..sort((left, right) => left.peakOsmId.compareTo(right.peakOsmId));

    await _repository.saveWithoutSync(
      PeakList(name: targetName),
      items: mergedItems,
      recomputeDerivedFields: true,
    );

    return TassyFullPeakListSyncResult(
      addedCount: addedCount,
      updatedCount: updatedCount,
      removedCount: removedCount,
    );
  }

  bool _isTasmanianPeak(int peakOsmId, Map<int, String?> peakRegionsByOsmId) {
    return peakRegionsByOsmId[peakOsmId] == Peak.defaultRegion;
  }
}
