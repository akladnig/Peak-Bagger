import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';

int renderablePeakCount({
  required Iterable<Peak> peaks,
  required PeakList peakList,
}) {
  final renderablePeakIds = peaks.map((peak) => peak.osmId).toSet();
  final items = decodePeakListItems(peakList.peakList);

  return items
      .map((item) => item.peakOsmId)
      .where(renderablePeakIds.contains)
      .toSet()
      .length;
}

Set<int> renderablePeakListIds({
  required Iterable<Peak> peaks,
  required Iterable<PeakList> peakLists,
  required Iterable<int> selectedPeakListIds,
}) {
  final selectedIds = selectedPeakListIds.toSet();
  final validPeakListIds = <int>{};

  for (final peakList in peakLists) {
    if (!selectedIds.contains(peakList.peakListId)) {
      continue;
    }

    try {
      if (renderablePeakCount(peaks: peaks, peakList: peakList) > 0) {
        validPeakListIds.add(peakList.peakListId);
      }
    } catch (_) {
      continue;
    }
  }

  return validPeakListIds;
}
