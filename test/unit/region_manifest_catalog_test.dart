import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';

List<String> _regionBasemapKeys() {
  final keys = ['openstreetmap', 'tracestrack'];
  if (hasMapyCzApiKey) {
    keys.add('mapyCz');
  }
  return keys;
}

void main() {
  test('Basemap.values keeps the manifest-prescribed order', () {
    expect(
      Basemap.values.map((basemap) => basemap.name).toList(growable: false),
      const [
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
      ],
    );
  });

  test('region lookup resolves regions and misses cleanly', () {
    expect(
      regionManifestCatalog.regionKeyForPoint(const LatLng(-44.0, 148.8867)),
      'tasmania',
    );
    expect(
      regionManifestCatalog.regionKeyForPoint(const LatLng(46.1, 13.2)),
      'italy-nord-est',
    );
    expect(regionManifestCatalog.regionKeyForPoint(const LatLng(0, 0)), isNull);
  });

  test('region basemaps stay ordered and deduped', () {
    expect(
      regionManifestCatalog
          .basemapsForRegionKey('new-south-wales')
          .map((basemap) => basemap.key)
          .toList(growable: false),
      [..._regionBasemapKeys(), 'nswImagery', 'nswBasemap', 'nswTopo'],
    );
    expect(
      regionManifestCatalog
          .basemapsForRegionKey('tasmania')
          .map((basemap) => basemap.key)
          .toList(growable: false),
      [..._regionBasemapKeys(), 'tasmapTopo', 'tasmap50k', 'tasmap25k'],
    );
    expect(
      regionManifestCatalog
          .basemapsForRegionKey('slovenia')
          .map((basemap) => basemap.key)
          .toList(growable: false),
      [..._regionBasemapKeys(), 'sloveniaTopo'],
    );
  });

  test('point-scoped basemaps honor FVG coverage', () {
    expect(
      regionManifestCatalog
          .basemapsForPoint(const LatLng(46.1, 13.2))
          .map((basemap) => basemap.key)
          .toList(growable: false),
      contains('fvgTopo'),
    );
    expect(
      regionManifestCatalog
          .basemapsForPoint(const LatLng(45.4386, 12.3267))
          .map((basemap) => basemap.key)
          .toList(growable: false),
      isNot(contains('fvgTopo')),
    );
  });

  test('all region manifests include mapy.cz', () {
    for (final regionKey in const [
      'tasmania',
      'new-south-wales',
      'italy-nord-est',
      'italy-nord-ovest',
      'italy',
      'slovenia',
      'croatia',
    ]) {
      expect(
        regionManifestCatalog.regionByKey(regionKey)?.basemapKeys,
        contains('mapyCz'),
      );
    }
  });

  test('mapy.cz availability follows MAPY_CZ_API_KEY', () {
    expect(isBasemapAvailable(Basemap.mapyCz), hasMapyCzApiKey);
    expect(
      regionManifestCatalog.basemapByKey('mapyCz')?.tileUrl,
      'https://api.mapy.com/v1/maptiles/outdoor/256/{z}/{x}/{y}?lang=en',
    );
  });

  test('region mapSet stays available in typed catalog', () {
    expect(regionManifestCatalog.regionByKey('tasmania')?.mapSet, const [
      'tasmap50k',
    ]);
    expect(
      regionManifestCatalog.regionByKey('new-south-wales')?.mapSet,
      isEmpty,
    );
    expect(regionManifestCatalog.regionByKey('slovenia')?.mapSet, isEmpty);
  });

  test('mapSet union follows visible bounds', () {
    expect(
      regionManifestCatalog.mapSetForBounds(
        LatLngBounds(const LatLng(-44.0, 143.0), const LatLng(-39.0, 149.0)),
      ),
      {'tasmap50k'},
    );
  });

  test('mapTileUrl reads from the manifest catalog', () {
    expect(
      mapTileUrl(Basemap.tasmap50k),
      regionManifestCatalog.basemapByKey('tasmap50k')!.tileUrl,
    );
    expect(
      mapTileUrl(Basemap.tracestrack),
      hasTracestrackApiKey
          ? 'https://tile.tracestrack.com/topo__/{z}/{x}/{y}.webp?key=${Uri.encodeQueryComponent(tracestrackApiKey)}'
          : regionManifestCatalog.basemapByKey('tracestrack')!.tileUrl,
    );
    expect(
      mapTileUrl(Basemap.nswTopo),
      regionManifestCatalog.basemapByKey('nswTopo')!.tileUrl,
    );
    expect(
      mapTileUrl(Basemap.mapyCz),
      hasMapyCzApiKey
          ? 'https://api.mapy.com/v1/maptiles/outdoor/256/{z}/{x}/{y}?lang=en&apikey=${Uri.encodeQueryComponent(mapyCzApiKey)}'
          : regionManifestCatalog
                .basemapByKey(Basemap.tracestrack.name)!
                .tileUrl,
    );
    expect(mapTileUrl(Basemap.sloveniaTopo), sloveniaTopoDebugTileUrl);
    expect(mapTileUrl(Basemap.fvgTopo), fvgTopoDebugTileUrl);
  });

  test('Slovenia topo uses the proxy tile layer config', () {
    final layer = buildBasemapTileLayer(Basemap.sloveniaTopo);

    expect(layer, isA<TileLayer>());
    final tileLayer = layer;
    expect(tileLayer.wmsOptions, isNull);
    expect(tileLayer.urlTemplate, sloveniaTopoDebugTileUrl);
  });
}
