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

List<MapSearchRegionOption> buildMapSearchRegionOptions(
  MappingCatalog catalog,
) {
  return [
    for (final region in catalog.peakListRegions())
      MapSearchRegionOption(
        key: region.key,
        name: region.name,
        compactName: region.shortName,
      ),
  ];
}

String? mapSearchRegionLabel(String? key, {required MappingCatalog catalog}) {
  if (key == null) {
    return null;
  }

  final region = catalog.regionByKey(key);
  if (region != null) {
    return region.shortName;
  }

  return null;
}

bool peakMatchesSearchRegion({
  required MappingCatalog catalog,
  required String? storedPeakRegionKey,
  required String? resolvedRegionKey,
  required String? filterRegionKey,
}) {
  if (filterRegionKey == null) {
    return true;
  }

  if (_isAggregateRegionFilterKey(filterRegionKey, catalog)) {
    return _aggregateRegionMatchesStoredPeak(
          aggregateRegionKey: filterRegionKey,
          storedPeakRegionKey: storedPeakRegionKey,
          catalog: catalog,
        ) ||
        resolvedRegionKey == filterRegionKey;
  }

  if (_isChildRegionFilterKey(filterRegionKey, catalog)) {
    return storedPeakRegionKey == filterRegionKey;
  }

  return resolvedRegionKey == filterRegionKey ||
      storedPeakRegionKey == filterRegionKey;
}

bool nonPeakMatchesSearchRegion({
  required MappingCatalog catalog,
  required String? resolvedRegionKey,
  required String? filterRegionKey,
}) {
  if (filterRegionKey == null) {
    return true;
  }

  final broaderFilterKey =
      catalog.peakListFilterRegionKey(filterRegionKey) ?? filterRegionKey;
  return catalog.peakListFilterRegionKey(resolvedRegionKey) == broaderFilterKey;
}

bool _isAggregateRegionFilterKey(
  String filterRegionKey,
  MappingCatalog catalog,
) {
  final region = catalog.regionByKey(filterRegionKey);
  return region != null && region.peakListFilterAliases.isNotEmpty;
}

bool _isChildRegionFilterKey(String filterRegionKey, MappingCatalog catalog) {
  final region = catalog.regionByKey(filterRegionKey);
  if (region == null) {
    return false;
  }

  final broaderRegionKey = catalog.peakListFilterRegionKey(filterRegionKey);
  return broaderRegionKey != null && broaderRegionKey != filterRegionKey;
}

bool _aggregateRegionMatchesStoredPeak({
  required MappingCatalog catalog,
  required String aggregateRegionKey,
  required String? storedPeakRegionKey,
}) {
  if (storedPeakRegionKey == null) {
    return false;
  }
  if (storedPeakRegionKey == aggregateRegionKey) {
    return true;
  }

  final aggregateRegion = catalog.regionByKey(aggregateRegionKey);
  return aggregateRegion?.peakListFilterAliases.contains(storedPeakRegionKey) ==
      true;
}
