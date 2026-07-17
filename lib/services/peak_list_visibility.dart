import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';

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
    final normalizedKey = canonicalRegionKey(
      normalizePeakListRegionKey(region.key),
    );
    if (normalizedKey != null) {
      regionKeys.add(normalizedKey);
    }
  }
  return Set<String>.unmodifiable(regionKeys);
}

Set<String> visibleRegionKeysForRegionKey(String? regionKey) {
  final normalizedKey = canonicalRegionKey(
    normalizePeakListRegionKey(regionKey),
  );
  if (normalizedKey == null) {
    return const <String>{};
  }
  return {normalizedKey};
}

Set<String> memberRegionKeysForPeakList({
  required PeakList peakList,
  required Iterable<Peak> peaks,
}) {
  late final List<PeakListItem> items;
  try {
    items = decodePeakListItems(peakList.peakList);
  } catch (_) {
    return const <String>{};
  }

  final peaksByOsmId = {for (final peak in peaks) peak.osmId: peak};
  final regionKeys = <String>{};
  for (final item in items) {
    final peak = peaksByOsmId[item.peakOsmId];
    if (peak == null) {
      continue;
    }

    final regionKey = canonicalPeakRegionKey(peak);
    if (regionKey != null) {
      regionKeys.add(regionKey);
    }
  }

  return Set<String>.unmodifiable(regionKeys);
}

Set<String> visibleMemberRegionKeysForPeakList({
  required PeakList peakList,
  required Iterable<Peak> peaks,
}) {
  final regionKeys = <String>{};
  for (final regionKey in memberRegionKeysForPeakList(
    peakList: peakList,
    peaks: peaks,
  )) {
    regionKeys.add(regionKey);
    final broaderRegionKey = peakListFilterRegionKey(regionKey);
    if (broaderRegionKey != null) {
      regionKeys.add(broaderRegionKey);
    }
  }

  return Set<String>.unmodifiable(regionKeys);
}

bool peakListIsPinned({
  required PeakList peakList,
  required Map<String, Set<int>> pinnedPeakListIdsByRegion,
  required Iterable<Peak> peaks,
}) {
  final regionKeys = peakList.region == PeakList.mixedRegion
      ? memberRegionKeysForPeakList(peakList: peakList, peaks: peaks)
      : {
          if (canonicalRegionKey(normalizePeakListRegionKey(peakList.region))
              case final String regionKey)
            regionKey,
        };

  for (final regionKey in regionKeys) {
    if (pinnedPeakListIdsByRegion[regionKey]?.contains(peakList.peakListId) ==
        true) {
      return true;
    }
  }

  return false;
}

bool peakListAppliesToVisibleRegions(
  PeakList peakList,
  Set<String> visibleRegionKeys, {
  LatLngBounds? visibleBounds,
  Iterable<Peak>? peaks,
}) {
  final normalizedPeakListRegionKey = canonicalRegionKey(
    peakListFilterRegionKey(peakList.region),
  );
  if (normalizedPeakListRegionKey == PeakList.mixedRegion) {
    return _mixedPeakListAppliesToVisibleRegions(
      peakList,
      visibleRegionKeys,
      visibleBounds: visibleBounds,
      peaks: peaks,
    );
  }

  return normalizedPeakListRegionKey != null &&
      visibleRegionKeys.contains(normalizedPeakListRegionKey);
}

Set<int> renderablePeakListIdsForVisibleRegions({
  required Iterable<PeakList> peakLists,
  required Iterable<int> selectedPeakListIds,
  required Set<String> visibleRegionKeys,
  LatLngBounds? visibleBounds,
  Iterable<Peak>? peaks,
}) {
  final selectedIds = selectedPeakListIds.toSet();
  final validPeakListIds = <int>{};

  for (final peakList in peakLists) {
    if (!selectedIds.contains(peakList.peakListId) ||
        !peakListAppliesToVisibleRegions(
          peakList,
          visibleRegionKeys,
          visibleBounds: visibleBounds,
          peaks: peaks,
        )) {
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

bool _mixedPeakListAppliesToVisibleRegions(
  PeakList peakList,
  Set<String> visibleRegionKeys, {
  LatLngBounds? visibleBounds,
  Iterable<Peak>? peaks,
}) {
  if (visibleBounds != null &&
      _peakListBoundsIntersectVisibleBounds(peakList, visibleBounds)) {
    return true;
  }

  if (peaks == null) {
    return false;
  }

  final memberRegionKeys = visibleMemberRegionKeysForPeakList(
    peakList: peakList,
    peaks: peaks,
  );
  return memberRegionKeys.any(visibleRegionKeys.contains);
}

bool _peakListBoundsIntersectVisibleBounds(
  PeakList peakList,
  LatLngBounds visibleBounds,
) {
  final minLat = peakList.minLat;
  final maxLat = peakList.maxLat;
  final minLng = peakList.minLng;
  final maxLng = peakList.maxLng;
  if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
    return false;
  }

  return minLat <= visibleBounds.northEast.latitude &&
      maxLat >= visibleBounds.southWest.latitude &&
      minLng <= visibleBounds.northEast.longitude &&
      maxLng >= visibleBounds.southWest.longitude;
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
  return normalizePeakListRegionKey(regionKey);
}

String? peakListFilterRegionKey(String? regionKey) {
  return regionManifestCatalog.peakListFilterRegionKey(regionKey);
}

String? canonicalPeakRegionKey(Peak peak) {
  return canonicalRegionKey(
    regionManifestCatalog.regionKeyForPoint(
          LatLng(peak.latitude, peak.longitude),
        ) ??
        peak.region,
  );
}

bool _isPeakWithinBounds({required Peak peak, required LatLngBounds bounds}) {
  return peak.latitude >= bounds.southWest.latitude &&
      peak.latitude <= bounds.northEast.latitude &&
      peak.longitude >= bounds.southWest.longitude &&
      peak.longitude <= bounds.northEast.longitude;
}
