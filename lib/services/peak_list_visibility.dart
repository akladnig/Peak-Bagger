import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';

int renderablePeakCount({
  required Iterable<Peak> peaks,
  required LatLngBounds? visibleBounds,
  required PeakList peakList,
}) {
  final visiblePeaks = visibleBounds == null
      ? peaks
      : peaks.where(
          (peak) => _isPeakWithinBounds(
            peak: peak,
            bounds: visibleBounds,
          ),
        );
  final renderablePeakIds = visiblePeaks.map((peak) => peak.osmId).toSet();
  final items = decodePeakListItems(peakList.peakList);

  return items
      .map((item) => item.peakOsmId)
      .where(renderablePeakIds.contains)
      .toSet()
      .length;
}

Set<int> renderablePeakListIds({
  required Iterable<Peak> peaks,
  required LatLngBounds? visibleBounds,
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
      if (
          renderablePeakCount(
            peaks: peaks,
            visibleBounds: visibleBounds,
            peakList: peakList,
          ) > 0) {
        validPeakListIds.add(peakList.peakListId);
      }
    } catch (_) {
      continue;
    }
  }

  return validPeakListIds;
}

bool _isPeakWithinBounds({
  required Peak peak,
  required LatLngBounds bounds,
}) {
  return peak.latitude >= bounds.southWest.latitude &&
      peak.latitude <= bounds.northEast.latitude &&
      peak.longitude >= bounds.southWest.longitude &&
      peak.longitude <= bounds.northEast.longitude;
}
