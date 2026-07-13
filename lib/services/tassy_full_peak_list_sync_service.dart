import 'dart:developer' as developer;

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

      final items = _decodeItemsOrNull(peakList);
      if (items == null) {
        continue;
      }

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
    for (final item in _decodeTargetItemsOrNull(existingTarget) ?? const []) {
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
      PeakList(name: targetName, peakList: encodePeakListItems(mergedItems)),
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

  List<PeakListItem>? _decodeItemsOrNull(PeakList peakList) {
    try {
      return decodePeakListItems(peakList.peakList);
    } catch (error, stackTrace) {
      developer.log(
        'Skipping malformed source peak list ${peakList.peakListId} during Tassy Full refresh.',
        error: error,
        stackTrace: stackTrace,
        name: 'tassy_full_peak_list_sync_service',
      );
      return null;
    }
  }

  List<PeakListItem>? _decodeTargetItemsOrNull(PeakList? peakList) {
    if (peakList == null) {
      return null;
    }

    try {
      return decodePeakListItems(peakList.peakList);
    } catch (error, stackTrace) {
      developer.log(
        'Skipping malformed Tassy Full peak list ${peakList.peakListId} during refresh.',
        error: error,
        stackTrace: stackTrace,
        name: 'tassy_full_peak_list_sync_service',
      );
      return const [];
    }
  }
}
