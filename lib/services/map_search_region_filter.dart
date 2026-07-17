import 'package:peak_bagger/services/region_manifest_catalog.dart';

class MapSearchRegionOption {
  const MapSearchRegionOption({
    required this.key,
    required this.name,
    required this.compactName,
  });

  final String key;
  final String name;
  final String compactName;
}

List<MapSearchRegionOption> buildMapSearchRegionOptions() {
  return [
    for (final region in regionManifestCatalog.peakListRegions())
      MapSearchRegionOption(
        key: region.key,
        name: region.name,
        compactName: region.shortName,
      ),
  ];
}

String? mapSearchRegionLabel(String? key) {
  if (key == null) {
    return null;
  }

  final region = regionManifestCatalog.regionByKey(key);
  if (region != null) {
    return region.shortName;
  }

  return null;
}

bool peakMatchesSearchRegion({
  required String? storedPeakRegionKey,
  required String? resolvedRegionKey,
  required String? filterRegionKey,
}) {
  if (filterRegionKey == null) {
    return true;
  }

  if (_isAggregateRegionFilterKey(filterRegionKey)) {
    return _aggregateRegionMatchesStoredPeak(
          aggregateRegionKey: filterRegionKey,
          storedPeakRegionKey: storedPeakRegionKey,
        ) ||
        resolvedRegionKey == filterRegionKey;
  }

  if (_isChildRegionFilterKey(filterRegionKey)) {
    return storedPeakRegionKey == filterRegionKey;
  }

  return resolvedRegionKey == filterRegionKey ||
      storedPeakRegionKey == filterRegionKey;
}

bool nonPeakMatchesSearchRegion({
  required String? resolvedRegionKey,
  required String? filterRegionKey,
}) {
  if (filterRegionKey == null) {
    return true;
  }

  final broaderFilterKey =
      regionManifestCatalog.peakListFilterRegionKey(filterRegionKey) ??
      filterRegionKey;
  return resolvedRegionKey == broaderFilterKey;
}

bool _isAggregateRegionFilterKey(String filterRegionKey) {
  final region = regionManifestCatalog.regionByKey(filterRegionKey);
  return region != null && region.peakListFilterAliases.isNotEmpty;
}

bool _isChildRegionFilterKey(String filterRegionKey) {
  final region = regionManifestCatalog.regionByKey(filterRegionKey);
  if (region == null) {
    return false;
  }

  final broaderRegionKey = regionManifestCatalog.peakListFilterRegionKey(
    filterRegionKey,
  );
  return broaderRegionKey != null && broaderRegionKey != filterRegionKey;
}

bool _aggregateRegionMatchesStoredPeak({
  required String aggregateRegionKey,
  required String? storedPeakRegionKey,
}) {
  if (storedPeakRegionKey == null) {
    return false;
  }
  if (storedPeakRegionKey == aggregateRegionKey) {
    return true;
  }

  final aggregateRegion = regionManifestCatalog.regionByKey(aggregateRegionKey);
  return aggregateRegion?.peakListFilterAliases.contains(storedPeakRegionKey) ==
      true;
}
