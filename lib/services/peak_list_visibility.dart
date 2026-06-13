import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';

int renderablePeakCount({
  required Iterable<Peak> peaks,
  LatLng? cursorPoint,
  required LatLngBounds? visibleBounds,
  required PeakList peakList,
}) {
  final renderablePeakIds = cursorPoint == null
      ? (visibleBounds == null
            ? peaks.map((peak) => peak.osmId).toSet()
            : peaks
                  .where(
                    (peak) =>
                        _isPeakWithinBounds(peak: peak, bounds: visibleBounds),
                  )
                  .map((peak) => peak.osmId)
                  .toSet())
      : _peakIdsInRegion(peaks, cursorPoint);
  final items = decodePeakListItems(peakList.peakList);

  return items
      .map((item) => item.peakOsmId)
      .where(renderablePeakIds.contains)
      .toSet()
      .length;
}

Set<int> renderablePeakListIds({
  required Iterable<Peak> peaks,
  LatLng? cursorPoint,
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
      if (renderablePeakCount(
            peaks: peaks,
            cursorPoint: cursorPoint,
            visibleBounds: visibleBounds,
            peakList: peakList,
          ) >
          0) {
        validPeakListIds.add(peakList.peakListId);
      }
    } catch (_) {
      continue;
    }
  }

  return validPeakListIds;
}

Set<int> _peakIdsInRegion(Iterable<Peak> peaks, LatLng point) {
  final regionKey = regionManifestCatalog.regionKeyForPoint(point);
  if (regionKey == null) {
    return const <int>{};
  }

  return peaks
      .where(
        (peak) =>
            regionManifestCatalog.regionKeyForPoint(
              LatLng(peak.latitude, peak.longitude),
            ) ==
            regionKey,
      )
      .map((peak) => peak.osmId)
      .toSet();
}

bool _isPeakWithinBounds({required Peak peak, required LatLngBounds bounds}) {
  return peak.latitude >= bounds.southWest.latitude &&
      peak.latitude <= bounds.northEast.latitude &&
      peak.longitude >= bounds.southWest.longitude &&
      peak.longitude <= bounds.northEast.longitude;
}
