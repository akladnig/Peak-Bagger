import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/peak_list_region_filter_provider.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';

import '../harness/mapping_catalog_fixture.dart';

void main() {
  test('region options use the injected catalog, never generated data', () {
    final empty = MappingCatalog(
      rootPath: '/test',
      regions: const [],
      basemaps: const [],
      tasmapCatalogPath: 'Maps/test.csv',
      naturalFeaturesCatalogPath: 'Features/test.json',
      demSources: const {},
      routingCoverageRegionKeys: const {},
    );
    final container = ProviderContainer(
      overrides: [mappingCatalogProvider.overrideWithValue(empty)],
    );
    addTearDown(container.dispose);
    expect(container.read(peakListRegionFilterOptionsProvider), isEmpty);
    container.updateOverrides([
      mappingCatalogProvider.overrideWithValue(testMappingCatalog),
    ]);
    expect(
      container.read(peakListRegionFilterOptionsProvider).map((r) => r.key),
      testMappingCatalog.peakListRegions().map((r) => r.key),
    );
  });

  test('catalog access outside a ready scope fails explicitly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      () => container.read(peakListRegionFilterOptionsProvider),
      throwsA(anything),
    );
  });

  test('tile layers use injected descriptors and the app-owned enum', () {
    final modified = MappingCatalog(
      rootPath: '/test',
      regions: testMappingCatalog.regions,
      basemaps: [
        MappingCatalogBasemap(
          key: 'openstreetmap',
          name: 'Test map',
          tileUrl: 'https://fixture.example/{z}/{x}/{y}.png',
          attribution: 'Fixture',
          maxZoom: 17,
          coveragePolygonPaths: const [],
          coveragePolygons: const [],
        ),
      ],
      tasmapCatalogPath: testMappingCatalog.tasmapCatalogPath,
      naturalFeaturesCatalogPath: testMappingCatalog.naturalFeaturesCatalogPath,
      demSources: testMappingCatalog.demSources,
      routingCoverageRegionKeys: testMappingCatalog.routingCoverageRegionKeys,
    );
    expect(
      mapTileUrl(Basemap.openstreetmap, catalog: modified),
      'https://fixture.example/{z}/{x}/{y}.png',
    );
    expect(
      buildBasemapTileLayer(
        Basemap.openstreetmap,
        catalog: modified,
      ).urlTemplate,
      'https://fixture.example/{z}/{x}/{y}.png',
    );
    expect(Basemap.values.map((b) => b.name), [
      'tasmapTopo',
      'tasmap50k',
      'tasmap25k',
      'tracestrack',
      'openstreetmap',
      'mapyCz',
      'nswImagery',
      'nswBasemap',
      'nswTopo',
      'sloveniaTopo',
      'fvgTopo',
      'localTopo',
    ]);
  });

  test('point lookup uses catalog geometry and manifest priority', () {
    expect(
      testMappingCatalog.regionKeyForPoint(const LatLng(-42, 146)),
      'tasmania',
    );
    expect(
      testMappingCatalog.regionKeyForPoint(const LatLng(46.1, 13.2)),
      'fvg',
    );
    expect(testMappingCatalog.regionKeyForPoint(const LatLng(0, 0)), isNull);
    expect(
      testMappingCatalog
          .regionsForPointByPriority(const LatLng(46.1, 13.2))
          .map((r) => r.key),
      ['fvg', 'italy-nord-est', 'italy'],
    );
    expect(
      testMappingCatalog
          .uniqueHighestPriorityRegionForPoint(const LatLng(46.1, 13.2))
          ?.key,
      'fvg',
    );
    expect(
      testMappingCatalog.regionKeyByDisplayName(' Friuli Venezia Giulia '),
      'fvg',
    );
    expect(testMappingCatalog.regionKeyByDisplayName('fvg'), isNull);
  });

  test('bounds, aliases and basemaps derive from fixture catalog', () {
    final bounds = LatLngBounds(const LatLng(-43, 145), const LatLng(-41, 147));
    expect(testMappingCatalog.regionsForBounds(bounds).map((r) => r.key), [
      'tasmania',
    ]);
    expect(testMappingCatalog.mapSetForBounds(bounds), contains('tasmap50k'));
    expect(testMappingCatalog.peakListFilterRegionKey('FVG'), 'italy-nord-est');
    expect(
      testMappingCatalog.basemapsForRegionKey('tasmania').map((b) => b.key),
      contains('openstreetmap'),
    );
    expect(testMappingCatalog.basemapsForPoint(const LatLng(0, 0)), isEmpty);
  });
}
