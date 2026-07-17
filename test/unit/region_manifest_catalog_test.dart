import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/services/manifest_priority.dart';
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

  test('exact manifest display-name lookup trims without accepting keys', () {
    expect(
      regionManifestCatalog.regionKeyByDisplayName(' Slovenia '),
      'slovenia',
    );
    expect(
      regionManifestCatalog.regionKeyByDisplayName('Friuli Venezia Giulia'),
      'fvg',
    );
    expect(regionManifestCatalog.regionKeyByDisplayName('slovenia'), isNull);
    expect(regionManifestCatalog.regionKeyByDisplayName('fvg'), isNull);
    expect(
      regionManifestCatalog.regionKeyByDisplayName('italy-nord-est'),
      isNull,
    );
  });

  test(
    'manifest priority parsing rejects malformed values deterministically',
    () {
      for (final value in const ['', '2..1', '2.a', '2.1.3.4']) {
        expect(() => ManifestPriority.parse(value), throwsFormatException);
      }
    },
  );

  test(
    'manifest priority comparison is numeric and prefers longer prefixes',
    () {
      expect(
        ManifestPriority.parse('2.10').compareTo(ManifestPriority.parse('2.2')),
        greaterThan(0),
      );
      expect(
        ManifestPriority.parse('2.1').compareTo(ManifestPriority.parse('2')),
        greaterThan(0),
      );
      expect(
        ManifestPriority.parse(
          '2.1.3',
        ).compareTo(ManifestPriority.parse('2.1')),
        greaterThan(0),
      );
    },
  );

  test(
    'priority-ordered point lookup keeps specific FVG ahead of aggregates',
    () {
      expect(
        regionManifestCatalog
            .regionsForPointByPriority(const LatLng(46.1, 13.2))
            .take(3)
            .map((region) => region.key)
            .toList(growable: false),
        const ['fvg', 'italy-nord-est', 'italy'],
      );
      expect(
        regionManifestCatalog
            .uniqueHighestPriorityRegionForPoint(const LatLng(46.1, 13.2))
            ?.key,
        'fvg',
      );
    },
  );

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

  test('tracestrack headers follow TRACESTRACK_API_KEY', () {
    expect(
      mapTileHeaders(Basemap.tracestrack),
      hasTracestrackApiKey ? {'Referer': tracestrackReferer} : const {},
    );
    expect(mapTileHeaders(Basemap.openstreetmap), const {});
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

  test('region manifest surfaces peak-list metadata for visible regions', () {
    expect(regionManifestCatalog.regionByKey('tasmania')?.shortName, 'Tas');
    expect(
      regionManifestCatalog.regionByKey('new-south-wales')?.shortName,
      'NSW',
    );
    expect(
      regionManifestCatalog.regionByKey('italy-nord-est')?.shortName,
      'Italy NE',
    );
    expect(
      regionManifestCatalog.regionByKey('italy-nord-ovest')?.shortName,
      'Italy NW',
    );
    expect(regionManifestCatalog.regionByKey('italy')?.showInPeakList, isFalse);
    expect(regionManifestCatalog.regionByKey('fvg')?.shortName, 'FVG');
    expect(regionManifestCatalog.regionByKey('fvg')?.showInPeakList, isFalse);
    expect(
      regionManifestCatalog.regionByKey('veneto')?.showInPeakList,
      isFalse,
    );
    expect(
      regionManifestCatalog.regionByKey('trentino-alto-adige')?.showInPeakList,
      isFalse,
    );
    expect(
      regionManifestCatalog.regionByKey('emilia-romagna')?.showInPeakList,
      isFalse,
    );
    expect(
      regionManifestCatalog.regionByKey('croatia')?.showInPeakList,
      isFalse,
    );
    expect(
      regionManifestCatalog
          .regionByKey('italy-nord-est')
          ?.peakListFilterAliases,
      containsAll(const [
        'fvg',
        'friuli-venezia-giulia',
        'veneto',
        'trentino-alto-adige',
        'emilia-romagna',
      ]),
    );
  });

  test(
    'manifest-backed peak-list filter aliases resolve to canonical keys',
    () {
      expect(
        regionManifestCatalog.peakListFilterRegionKey('fvg'),
        'italy-nord-est',
      );
      expect(
        regionManifestCatalog.peakListFilterRegionKey('friuli-venezia-giulia'),
        'italy-nord-est',
      );
      expect(
        regionManifestCatalog.peakListFilterRegionKey('veneto'),
        'italy-nord-est',
      );
      expect(
        regionManifestCatalog.peakListFilterRegionKey('trentino-alto-adige'),
        'italy-nord-est',
      );
      expect(
        regionManifestCatalog.peakListFilterRegionKey('emilia-romagna'),
        'italy-nord-est',
      );
    },
  );

  test('peak-list regions follow the manifest showInPeakList contract', () {
    final manifest =
        jsonDecode(File('assets/region_manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final expectedRegionKeys = [
      for (final entry in manifest.entries)
        if ((entry.value as Map<String, dynamic>)['showInPeakList'] == 'true')
          entry.key,
    ];

    final visibleRegions = regionManifestCatalog.peakListRegions();
    expect(
      visibleRegions.map((region) => region.key).toList(growable: false),
      expectedRegionKeys,
    );
    expect(
      visibleRegions.map((region) => region.shortName).toList(growable: false),
      const ['Tas', 'Italy NE', 'Italy NW', 'Slovenia'],
    );
    expect(
      visibleRegions.map((region) => region.name).toList(growable: false),
      const ['Tasmania', 'Italy North East', 'Italy North West', 'Slovenia'],
    );
    expect(
      visibleRegions.map((region) => region.key),
      isNot(contains('italy')),
    );
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
          : regionManifestCatalog.basemapByKey('openstreetmap')!.tileUrl,
    );
    expect(
      mapTileUrl(Basemap.nswTopo),
      regionManifestCatalog.basemapByKey('nswTopo')!.tileUrl,
    );
    expect(
      mapTileUrl(Basemap.mapyCz),
      hasMapyCzApiKey
          ? 'https://api.mapy.com/v1/maptiles/outdoor/256/{z}/{x}/{y}?lang=en&apikey=${Uri.encodeQueryComponent(mapyCzApiKey)}'
          : mapTileUrl(Basemap.tracestrack),
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
