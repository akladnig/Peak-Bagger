import 'dart:io';

import 'package:peak_bagger/services/mapping_store_core.dart';
import 'package:peak_bagger/services/mapping_data_store.dart'
    show mappingCatalogProvider;
export 'package:peak_bagger/services/mapping_data_store.dart'
    show mappingCatalogProvider;

/// Canonical fixture metadata parsed through the production schema with small,
/// deterministic test geometry. Never reads the mount or a generated catalog.
final testMappingCatalog = MappingDataStoreCore.catalogFromManifestTexts(
  rootPath: '/test',
  regionManifestText: File(
    'test/fixtures/mapping_store/v1/region_manifest.json',
  ).readAsStringSync(),
  polygonManifestText: File(
    'test/fixtures/mapping_store/v1/Polygons/manifest.json',
  ).readAsStringSync(),
  polygonTexts: {
    for (final entry in _bounds.entries) entry.key: _poly(entry.value),
  },
);

const _bounds = <String, List<double>>{
  'Polygons/tasmania.poly': [-44.5, 143.5, -39.0, 149.0],
  'Polygons/new-south-wales.poly': [-38.0, 140.8, -28.0, 160.0],
  'Polygons/italy-nord-est.poly': [43.7, 10.0, 47.0, 13.9],
  'Polygons/italy-nord-ovest.poly': [43.7, 6.6, 46.7, 10.5],
  'Polygons/friuli-venezia-giulia-mainland.poly': [45.6, 12.3, 46.7, 13.8],
  'Polygons/friuli-venezia-giulia-islet.poly': [45.67, 13.7, 45.7, 13.75],
  'Polygons/slovenia.poly': [45.4, 13.81, 46.9, 16.6],
  'Polygons/croatia.poly': [42.0, 13.0, 45.39, 19.5],
};

String _poly(List<double> b) =>
    'fixture\n1\n${b[1]} ${b[0]}\n${b[3]} ${b[0]}\n${b[3]} ${b[2]}\n${b[1]} ${b[2]}\nEND\nEND\n';

final mappingCatalogTestOverrides = [
  mappingCatalogProvider.overrideWithValue(testMappingCatalog),
];
