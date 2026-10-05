import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/manifest_priority.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';

const elvisRuntimePath = 'DEM/Elvis/elvis_runtime_10m.tif';
const elevationRoutePoints = [LatLng(-41.5, 146.5), LatLng(-41.501, 146.501)];

final elevationMappingCatalog = MappingCatalog(
  rootPath: '/mapping',
  regions: [
    MappingCatalogRegion(
      key: 'tasmania',
      name: 'Tasmania',
      shortName: 'Tas',
      priority: ManifestPriority.parse('1'),
      showInPeakList: true,
      polyPaths: const [],
      polygons: const [
        [
          LatLng(-44, 144),
          LatLng(-40, 144),
          LatLng(-40, 149),
          LatLng(-44, 149),
        ],
      ],
      basemapKeys: const [],
      mapSet: const [],
      peakListFilterAliases: const [],
      routingCoverage: null,
      seedOnStartup: false,
      composite: false,
      peaks: const [],
      highways: const [],
      fingerprint: null,
    ),
  ],
  basemaps: const [],
  tasmapCatalogPath: 'Maps/tasmap50k.csv',
  naturalFeaturesCatalogPath: 'Features/tasmania_natural_features.json',
  demSources: const {
    'elvisRuntime': elvisRuntimePath,
    'thelist25m': 'DEM/tasmania_dem_25m.tif',
    'copernicus': 'DEM/cop30_hh.tif',
  },
  routingCoverageRegionKeys: const {},
);

enum FakeDemAccessFailure { missing, unreadable, outsideRoot }

class FakeDemFileSystem implements MappingStoreFileSystem {
  FakeDemAccessFailure? failure;
  final checkedPaths = <String>[];

  @override
  Future<String> canonicalize(String absolutePath) async {
    if (absolutePath.endsWith(elvisRuntimePath) &&
        failure == FakeDemAccessFailure.outsideRoot) {
      return '/outside/elvis_runtime_10m.tif';
    }
    return absolutePath;
  }

  @override
  Future<bool> fileExists(String absolutePath) async =>
      failure != FakeDemAccessFailure.missing;

  @override
  Future<void> checkReadable(String absolutePath) async {
    checkedPaths.add(absolutePath);
    if (failure == FakeDemAccessFailure.unreadable) {
      throw FileSystemException('Unreadable DEM', absolutePath);
    }
  }

  @override
  Future<String> readText(String absolutePath) =>
      throw StateError('DEM must use the opaque binary opener');

  @override
  Future<MappingStoreFileMetadata> metadata(String absolutePath) =>
      throw StateError('DEM must not be hashed or parsed by the catalog');
}

class FakeDemDatasetOpener implements DemDatasetOpener {
  FakeDemDatasetOpener(this.dataset);

  final DemDataset dataset;
  final openedPaths = <String>[];
  Object? error;

  @override
  Future<DemDataset> open(String datasetPath) async {
    openedPaths.add(datasetPath);
    if (error case final error?) {
      throw error;
    }
    return dataset;
  }
}

class LookupDemDataset implements DemDataset {
  LookupDemDataset(this.lookup);

  final double? Function(LatLng point) lookup;

  @override
  double? sampleElevation(LatLng point) => lookup(point);
}
