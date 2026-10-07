import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/manifest_priority.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';

const mappingHighwaySource = {
  'elements': [
    {'type': 'node', 'id': 1, 'lat': -42.0, 'lon': 146.0},
    {'type': 'node', 'id': 2, 'lat': -42.001, 'lon': 146.001},
    {
      'type': 'way',
      'id': 10,
      'nodes': [1, 2],
      'tags': {'highway': 'path'},
    },
  ],
};

final mappingCoverageCatalog = MappingCatalog(
  rootPath: '/unused-test-root',
  regions: [
    for (final key in ['tasmania', 'northeast-alps'])
      MappingCatalogRegion(
        key: key,
        name: key,
        shortName: key,
        priority: ManifestPriority.parse(key == 'tasmania' ? '1' : '2'),
        showInPeakList: true,
        polyPaths: const [],
        polygons: [
          key == 'tasmania'
              ? const [
                  LatLng(-43, 145),
                  LatLng(-43, 147),
                  LatLng(-41, 147),
                  LatLng(-41, 145),
                ]
              : const [
                  LatLng(45, 13),
                  LatLng(45, 15),
                  LatLng(47, 15),
                  LatLng(47, 13),
                ],
        ],
        basemapKeys: const [],
        mapSet: const [],
        peakListFilterAliases: const [],
        routingCoverage: key,
        seedOnStartup: false,
        composite: false,
        peaks: const [],
        highways: ['Highways/$key.json'],
        fingerprint: null,
      ),
  ],
  basemaps: const [],
  tasmapCatalogPath: 'Maps/maps.csv',
  naturalFeaturesCatalogPath: 'Features/features.json',
  demSources: const {
    'elvisRuntime': 'DEM/Elvis/elvis_runtime_10m.tif',
    'thelist25m': 'DEM/tasmania_dem_25m.tif',
    'copernicus': 'DEM/cop30_hh.tif',
  },
  routingCoverageRegionKeys: const {
    'tasmania': ['tasmania'],
    'northeast-alps': ['northeast-alps'],
  },
);

class MappingCoverageFileAccess extends MappingStoreOperationFileAccess {
  MappingCoverageFileAccess() : super(catalog: mappingCoverageCatalog);
  final reads = <String>[];
  final sources = <String, String>{};
  final failures = <String, Object>{};

  @override
  Future<String> readText(String relativePath) async {
    reads.add(relativePath);
    if (failures[relativePath] case final error?) throw error;
    return sources[relativePath] ?? jsonEncode(mappingHighwaySource);
  }
}
