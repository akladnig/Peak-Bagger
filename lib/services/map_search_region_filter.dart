import 'package:peak_bagger/services/region_manifest_catalog.dart';

class MapSearchRegionOption {
  const MapSearchRegionOption({required this.key, required this.name});

  final String key;
  final String name;
}

const _italyNorthEastRegionKey = 'italy-nord-est';

const _northEastSubregionOptions = [
  MapSearchRegionOption(key: 'fvg', name: 'FVG'),
  MapSearchRegionOption(key: 'veneto', name: 'Veneto'),
  MapSearchRegionOption(
    key: 'trentino-alto-adige',
    name: 'Trentino Alto Adige',
  ),
  MapSearchRegionOption(key: 'emilia-romagna', name: 'Emilia Romagna'),
];

final _northEastSubregionLabelByKey = {
  for (final option in _northEastSubregionOptions) option.key: option.name,
};

List<MapSearchRegionOption> buildMapSearchRegionOptions() {
  return [
    ...regionManifestCatalog.allRegions().map(
      (region) => MapSearchRegionOption(key: region.key, name: region.name),
    ),
    ..._northEastSubregionOptions,
  ];
}

bool isNorthEastSubregionKey(String? key) {
  return key != null && _northEastSubregionLabelByKey.containsKey(key);
}

String? mapSearchRegionLabel(String? key) {
  if (key == null) {
    return null;
  }
  final subregionLabel = _northEastSubregionLabelByKey[key];
  if (subregionLabel != null) {
    return subregionLabel;
  }
  return regionManifestCatalog.regionByKey(key)?.name;
}

bool peakMatchesSearchRegion({
  required String? storedPeakRegionKey,
  required String? resolvedRegionKey,
  required String? filterRegionKey,
}) {
  if (filterRegionKey == null) {
    return true;
  }
  if (isNorthEastSubregionKey(filterRegionKey)) {
    return storedPeakRegionKey == filterRegionKey;
  }
  if (filterRegionKey == _italyNorthEastRegionKey) {
    return storedPeakRegionKey == _italyNorthEastRegionKey ||
        isNorthEastSubregionKey(storedPeakRegionKey) ||
        resolvedRegionKey == _italyNorthEastRegionKey;
  }
  return resolvedRegionKey == filterRegionKey || storedPeakRegionKey == filterRegionKey;
}

bool nonPeakMatchesSearchRegion({
  required String? resolvedRegionKey,
  required String? filterRegionKey,
}) {
  if (filterRegionKey == null) {
    return true;
  }
  final broaderFilterKey = isNorthEastSubregionKey(filterRegionKey)
      ? _italyNorthEastRegionKey
      : filterRegionKey;
  return resolvedRegionKey == broaderFilterKey;
}
