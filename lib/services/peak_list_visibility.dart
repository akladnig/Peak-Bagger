import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';

const _regionAliases = <String, String>{
  'friuli-venezia-giulia': 'italy-nord-est',
};

Set<int> peakIdsForRegion({
  required Iterable<Peak> peaks,
  required LatLng cursorPoint,
}) {
  final regionKey = canonicalRegionKey(
    regionManifestCatalog.regionKeyForPoint(cursorPoint),
  );
  if (regionKey == null) {
    return const <int>{};
  }

  return peaks
      .where(
        (peak) =>
            canonicalRegionKey(
              regionManifestCatalog.regionKeyForPoint(
                LatLng(peak.latitude, peak.longitude),
              ),
            ) ==
            regionKey,
      )
      .map((peak) => peak.osmId)
      .toSet();
}

int renderablePeakCount({
  required Iterable<Peak> peaks,
  LatLng? cursorPoint,
  required LatLngBounds? visibleBounds,
  required PeakList peakList,
  Set<int>? renderablePeakIds,
}) {
  final renderableIds =
      renderablePeakIds ??
      (cursorPoint == null
          ? (visibleBounds == null
                ? peaks.map((peak) => peak.osmId).toSet()
                : peaks
                      .where(
                        (peak) => _isPeakWithinBounds(
                          peak: peak,
                          bounds: visibleBounds,
                        ),
                      )
                      .map((peak) => peak.osmId)
                      .toSet())
          : peakIdsForRegion(peaks: peaks, cursorPoint: cursorPoint));
  final items = decodePeakListItems(peakList.peakList);

  return items
      .map((item) => item.peakOsmId)
      .where(renderableIds.contains)
      .toSet()
      .length;
}

Set<String> visibleRegionKeysForBounds(LatLngBounds? bounds) {
  if (bounds == null) {
    return const <String>{};
  }

  final regionKeys = <String>{};
  for (final region in regionManifestCatalog.regionsForBounds(bounds)) {
    final normalizedKey = canonicalRegionKey(normalizePeakListRegionKey(region.key));
    if (normalizedKey != null) {
      regionKeys.add(normalizedKey);
    }
  }
  return Set<String>.unmodifiable(regionKeys);
}

Set<String> visibleRegionKeysForRegionKey(String? regionKey) {
  final normalizedKey = canonicalRegionKey(normalizePeakListRegionKey(regionKey));
  if (normalizedKey == null) {
    return const <String>{};
  }
  return {normalizedKey};
}

bool peakListAppliesToVisibleRegions(
  PeakList peakList,
  Set<String> visibleRegionKeys,
) {
  final normalizedPeakListRegionKey = canonicalRegionKey(
    normalizePeakListRegionKey(peakList.region),
  );
  return normalizedPeakListRegionKey != null &&
      visibleRegionKeys.contains(normalizedPeakListRegionKey);
}

Set<int> renderablePeakListIdsForVisibleRegions({
  required Iterable<PeakList> peakLists,
  required Iterable<int> selectedPeakListIds,
  required Set<String> visibleRegionKeys,
}) {
  final selectedIds = selectedPeakListIds.toSet();
  final validPeakListIds = <int>{};

  for (final peakList in peakLists) {
    if (!selectedIds.contains(peakList.peakListId) ||
        !peakListAppliesToVisibleRegions(peakList, visibleRegionKeys)) {
      continue;
    }

    try {
      decodePeakListItems(peakList.peakList);
    } catch (_) {
      continue;
    }

    validPeakListIds.add(peakList.peakListId);
  }

  return validPeakListIds;
}

Set<int> renderablePeakListIds({
  required Iterable<PeakList> peakLists,
  required Iterable<int> selectedPeakListIds,
  required String? currentRegionKey,
}) {
  return renderablePeakListIdsForVisibleRegions(
    peakLists: peakLists,
    selectedPeakListIds: selectedPeakListIds,
    visibleRegionKeys: visibleRegionKeysForRegionKey(currentRegionKey),
  );
}

bool peakListAppliesToRegion(PeakList peakList, String? currentRegionKey) {
  return peakListAppliesToVisibleRegions(
    peakList,
    visibleRegionKeysForRegionKey(currentRegionKey),
  );
}

String? normalizePeakListRegionKey(String? regionKey) {
  final trimmed = regionKey?.trim();
  if (trimmed == null) {
    return null;
  }
  if (trimmed.isEmpty) {
    return Peak.defaultRegion;
  }

  return trimmed.toLowerCase();
}

String? canonicalRegionKey(String? regionKey) {
  final normalized = normalizePeakListRegionKey(regionKey);
  if (normalized == null) {
    return null;
  }

  return _regionAliases[normalized] ?? normalized;
}

bool _isPeakWithinBounds({required Peak peak, required LatLngBounds bounds}) {
  return peak.latitude >= bounds.southWest.latitude &&
      peak.latitude <= bounds.northEast.latitude &&
      peak.longitude >= bounds.southWest.longitude &&
      peak.longitude <= bounds.northEast.longitude;
}
