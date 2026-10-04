import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/manifest_priority.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mapping-data-store-test-');
    await _writeStore(root);
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'preflight accepts the retained manifest contract without reading sources',
    () async {
      final reads = <String>[];
      final preflight = await MappingDataStore(
        rootPath: root.path,
        textReader: (path) async {
          reads.add(path);
          return File(path).readAsString();
        },
      ).preflight();

      expect(preflight.requiredPolygonPaths, {'Polygons/tasmania.poly'});
      expect(
        reads.map(p.basename),
        unorderedEquals(['region_manifest.json', 'manifest.json']),
      );
    },
  );

  test('v1 fixtures retain the mounted store contract', () async {
    final fixtureRoot = Directory('test/fixtures/mapping_store/v1');
    final manifest = await _readJson(fixtureRoot, 'region_manifest.json');
    final polygonManifest =
        jsonDecode(
              await File(
                '${fixtureRoot.path}/Polygons/manifest.json',
              ).readAsString(),
            )
            as List<dynamic>;

    expect(File('${fixtureRoot.path}/tool_manifest.json').existsSync(), isTrue);
    expect(
      (manifest['tasmap'] as Map<String, dynamic>)['catalog'],
      'Maps/tasmap50k.csv',
    );
    expect(
      (manifest['naturalFeatures'] as Map<String, dynamic>)['catalog'],
      'Features/tasmania_natural_features.json',
    );
    expect(
      manifest.keys,
      containsAll(['tasmania', 'fvg', 'veneto', 'slovenia']),
    );
    expect(
      (manifest['slovenia'] as Map<String, dynamic>)['highways'],
      contains('Highways/slovenia-highways.json'),
    );
    expect(polygonManifest, contains('Polygons/tasmania.poly'));
  });

  test(
    'catalog loads required geometry and derives routing coverage',
    () async {
      final catalog = await MappingDataStore(rootPath: root.path).loadCatalog();

      expect(catalog.regionKeyForPoint(const LatLng(0.2, 0.2)), 'tasmania');
      expect(
        catalog.routingCoverageForPoint(const LatLng(0.2, 0.2)),
        'tasmania',
      );
      expect(catalog.basemapByKey('localTopo')?.maxZoom, 18);
    },
  );

  test('catalog resolves exact display names and peak-list aliases', () async {
    final manifest = await _readJson(root, 'region_manifest.json');
    (manifest['tasmania'] as Map<String, dynamic>)['peakListFilterAliases'] = [
      'Tas Alias',
    ];
    await _writeJson(root, 'region_manifest.json', manifest);
    final catalog = await MappingDataStore(rootPath: root.path).loadCatalog();

    expect(catalog.regionKeyByDisplayName(' Tasmania '), 'tasmania');
    expect(catalog.regionKeyByDisplayName('tasmania'), isNull);
    expect(catalog.peakListFilterRegionKey('Tas Alias'), 'tasmania');
  });

  test(
    'catalog is available only through a ready-scope provider override',
    () async {
      final catalog = await MappingDataStore(rootPath: root.path).loadCatalog();
      final container = ProviderContainer(
        overrides: [mappingCatalogProvider.overrideWithValue(catalog)],
      );
      addTearDown(container.dispose);

      expect(container.read(mappingCatalogProvider), same(catalog));
    },
  );

  test('catalog descriptors do not retain caller-owned collections', () {
    final paths = ['Polygons/tasmania.poly'];
    final vertices = [
      const LatLng(0, 0),
      const LatLng(1, 0),
      const LatLng(0, 1),
    ];
    final region = MappingCatalogRegion(
      key: 'tasmania',
      name: 'Tasmania',
      shortName: 'Tas',
      priority: const ManifestPriority([1]),
      showInPeakList: true,
      polyPaths: paths,
      polygons: [vertices],
      basemapKeys: const [],
      mapSet: const [],
      peakListFilterAliases: const [],
      routingCoverage: null,
      seedOnStartup: true,
      composite: false,
      peaks: const [],
      highways: const [],
      fingerprint: 'fingerprint',
    );

    paths.clear();
    vertices.clear();

    expect(region.polyPaths, ['Polygons/tasmania.poly']);
    expect(region.polygons.single, hasLength(3));
    expect(() => region.polyPaths.add('other.poly'), throwsUnsupportedError);
  });

  test('catalog rebuilds after a corrupt cache entry', () async {
    final cacheDirectory = await Directory.systemTemp.createTemp(
      'mapping-catalog-cache-test-',
    );
    addTearDown(() => cacheDirectory.delete(recursive: true));
    final store = MappingDataStore(
      rootPath: root.path,
      cache: MappingCatalogCache(cacheDirectory.path),
    );

    await store.loadCatalog();
    final cacheFile = File(
      '${cacheDirectory.path}/mapping_catalog_geometry.json',
    );
    expect(cacheFile.existsSync(), isTrue);
    await cacheFile.writeAsString('{corrupt');

    await expectLater(store.loadCatalog(), completes);
    expect(
      jsonDecode(await cacheFile.readAsString()),
      isA<Map<String, dynamic>>(),
    );
  });

  test('catalog reparses a changed required polygon', () async {
    final cacheDirectory = await Directory.systemTemp.createTemp(
      'mapping-catalog-cache-test-',
    );
    addTearDown(() => cacheDirectory.delete(recursive: true));
    final store = MappingDataStore(
      rootPath: root.path,
      cache: MappingCatalogCache(cacheDirectory.path),
    );

    await store.loadCatalog();
    await File('${root.path}/Polygons/tasmania.poly').writeAsString('invalid');

    await expectLater(
      store.loadCatalog(),
      throwsA(
        isA<MappingStoreFailure>().having(
          (failure) => failure.paths,
          'paths',
          contains('Polygons/tasmania.poly'),
        ),
      ),
    );
  });

  test('catalog remains available when cache reads or writes fail', () async {
    final catalog = await MappingDataStore(
      rootPath: root.path,
      cache: _FailingCache(),
    ).loadCatalog();

    expect(catalog.regionByKey('tasmania'), isNotNull);
  });

  test(
    'preflight reports malformed routing coverage without crashing',
    () async {
      final manifest = await _readJson(root, 'region_manifest.json');
      (manifest['routingCoverages'] as Map<String, dynamic>).remove('tasmania');
      await _writeJson(root, 'region_manifest.json', manifest);

      await expectLater(
        MappingDataStore(rootPath: root.path).preflight(),
        throwsA(
          isA<MappingStoreFailure>().having(
            (failure) => failure.paths,
            'paths',
            contains('region_manifest.json#/routingCoverages/tasmania'),
          ),
        ),
      );
    },
  );

  test('preflight validates typed ISO region metadata', () async {
    final manifest = await _readJson(root, 'region_manifest.json');
    (manifest['tasmania'] as Map<String, dynamic>)['ISO_3166-2'] = 42;
    await _writeJson(root, 'region_manifest.json', manifest);

    await expectLater(
      MappingDataStore(rootPath: root.path).preflight(),
      throwsA(
        isA<MappingStoreFailure>().having(
          (failure) => failure.paths,
          'paths',
          contains('region_manifest.json#/tasmania/ISO_3166-2'),
        ),
      ),
    );
  });

  test(
    'preflight reports every conflicting shared basemap descriptor',
    () async {
      final manifest = await _readJson(root, 'region_manifest.json');
      final fvgMaps =
          (manifest['fvg'] as Map<String, dynamic>)['maps'] as List<dynamic>;
      (fvgMaps.single as Map<String, dynamic>)['tileUrl'] =
          'https://example.invalid/{z}/{x}/{y}.png';
      await _writeJson(root, 'region_manifest.json', manifest);

      await expectLater(
        MappingDataStore(rootPath: root.path).preflight(),
        throwsA(
          isA<MappingStoreFailure>().having(
            (failure) => failure.paths,
            'paths',
            containsAll([
              'region_manifest.json#/tasmania/maps/0',
              'region_manifest.json#/fvg/maps/0',
            ]),
          ),
        ),
      );
    },
  );

  test('preflight rejects a map set key absent from its region maps', () async {
    final manifest = await _readJson(root, 'region_manifest.json');
    (manifest['tasmania'] as Map<String, dynamic>)['mapSet'] = ['fvgTopo'];
    await _writeJson(root, 'region_manifest.json', manifest);

    await expectLater(
      MappingDataStore(rootPath: root.path).preflight(),
      throwsA(
        isA<MappingStoreFailure>().having(
          (failure) => failure.paths,
          'paths',
          contains('region_manifest.json#/tasmania/mapSet/0'),
        ),
      ),
    );
  });

  test('preflight reports unsafe paths using their JSON pointer', () async {
    final manifest = await _readJson(root, 'region_manifest.json');
    (manifest['tasmap'] as Map<String, dynamic>)['catalog'] = '../escape.csv';
    await _writeJson(root, 'region_manifest.json', manifest);

    await expectLater(
      MappingDataStore(rootPath: root.path).preflight(),
      throwsA(
        isA<MappingStoreFailure>().having(
          (failure) => failure.paths,
          'paths',
          contains('region_manifest.json#/tasmap/catalog'),
        ),
      ),
    );
  });

  test(
    'preflight reports each unsafe list path using its original index',
    () async {
      final manifest = await _readJson(root, 'region_manifest.json');
      (manifest['tasmania'] as Map<String, dynamic>)['poly'] = [
        '../escape.poly',
        r'Polygons\\windows.poly',
        '.',
        '/absolute.poly',
      ];
      await _writeJson(root, 'region_manifest.json', manifest);

      await expectLater(
        MappingDataStore(rootPath: root.path).preflight(),
        throwsA(
          isA<MappingStoreFailure>().having(
            (failure) => failure.paths,
            'paths',
            containsAll([
              'region_manifest.json#/tasmania/poly/0',
              'region_manifest.json#/tasmania/poly/1',
              'region_manifest.json#/tasmania/poly/2',
              'region_manifest.json#/tasmania/poly/3',
            ]),
          ),
        ),
      );
    },
  );

  test(
    'preflight rejects unknown manifest metadata with JSON pointers',
    () async {
      final manifest = await _readJson(root, 'region_manifest.json');
      manifest['unknownMetadata'] = {'enabled': true};
      await _writeJson(root, 'region_manifest.json', manifest);

      await expectLater(
        MappingDataStore(rootPath: root.path).preflight(),
        throwsA(
          isA<MappingStoreFailure>().having(
            (failure) => failure.paths,
            'paths',
            contains('region_manifest.json#/unknownMetadata/name'),
          ),
        ),
      );
    },
  );

  test(
    'preflight rejects a composite region with seedable-only metadata',
    () async {
      final manifest = await _readJson(root, 'region_manifest.json');
      final tasmania =
          Map<String, dynamic>.from(
              manifest['tasmania'] as Map<String, dynamic>,
            )
            ..['composite'] = true
            ..['seedOnStartup'] = false
            ..remove('fingerprint')
            ..remove('routingCoverage')
            ..remove('highways');
      manifest['tasmania'] = tasmania;
      await _writeJson(root, 'region_manifest.json', manifest);

      await expectLater(
        MappingDataStore(rootPath: root.path).preflight(),
        throwsA(
          isA<MappingStoreFailure>().having(
            (failure) => failure.paths,
            'paths',
            contains('region_manifest.json#/tasmania'),
          ),
        ),
      );
    },
  );

  test('preflight enforces required mapping-store metadata paths', () async {
    final manifest = await _readJson(root, 'region_manifest.json');
    (manifest['tasmap'] as Map<String, dynamic>)['catalog'] = 'Maps/other.csv';
    (manifest['naturalFeatures'] as Map<String, dynamic>)['catalog'] =
        'Features/other.json';
    (manifest['demSources'] as Map<String, dynamic>)['copernicus'] =
        'DEM/other.tif';
    await _writeJson(root, 'region_manifest.json', manifest);

    await expectLater(
      MappingDataStore(rootPath: root.path).preflight(),
      throwsA(
        isA<MappingStoreFailure>().having(
          (failure) => failure.paths,
          'paths',
          containsAll([
            'region_manifest.json#/tasmap/catalog',
            'region_manifest.json#/naturalFeatures/catalog',
            'region_manifest.json#/demSources/copernicus',
          ]),
        ),
      ),
    );
  });

  test('preflight derives and validates routing coverage membership', () async {
    final manifest = await _readJson(root, 'region_manifest.json');
    (manifest['veneto'] as Map<String, dynamic>)['routingCoverage'] =
        'tasmania';
    await _writeJson(root, 'region_manifest.json', manifest);

    await expectLater(
      MappingDataStore(rootPath: root.path).preflight(),
      throwsA(
        isA<MappingStoreFailure>().having(
          (failure) => failure.paths,
          'paths',
          containsAll([
            'region_manifest.json#/routingCoverages/tasmania',
            'region_manifest.json#/routingCoverages/northeast-alps',
          ]),
        ),
      ),
    );
  });

  test(
    'preflight rejects manifest basemaps outside the supported enum',
    () async {
      final manifest = await _readJson(root, 'region_manifest.json');
      ((manifest['tasmania'] as Map<String, dynamic>)['maps'] as List<dynamic>)
              .first['key'] =
          'localTopo';
      await _writeJson(root, 'region_manifest.json', manifest);

      await expectLater(
        MappingDataStore(rootPath: root.path).preflight(),
        throwsA(
          isA<MappingStoreFailure>().having(
            (failure) => failure.paths,
            'paths',
            contains('region_manifest.json#/tasmania/maps/0/key'),
          ),
        ),
      );
    },
  );

  test('preflight accepts lazy polygon entries without reading them', () async {
    await _writeJson(root, 'Polygons/manifest.json', [
      'Polygons/tasmania.poly',
      'Polygons/lazy-display.poly',
    ]);

    await expectLater(
      MappingDataStore(rootPath: root.path).preflight(),
      completes,
    );
  });

  test(
    'preflight reports an unlisted required polygon with its manifest path',
    () async {
      await _writeJson(root, 'Polygons/manifest.json', const []);

      await expectLater(
        MappingDataStore(rootPath: root.path).preflight(),
        throwsA(
          isA<MappingStoreFailure>().having(
            (failure) => failure.paths,
            'paths',
            contains('Polygons/manifest.json#/Polygons~1tasmania.poly'),
          ),
        ),
      );
    },
  );

  test(
    'preflight reports unlocatable manifest JSON syntax by path only',
    () async {
      await File('${root.path}/region_manifest.json').writeAsString('{');

      await expectLater(
        MappingDataStore(rootPath: root.path).preflight(),
        throwsA(
          isA<MappingStoreFailure>().having(
            (failure) => failure.paths,
            'paths',
            ['region_manifest.json'],
          ),
        ),
      );
    },
  );

  test('preflight requires the Slovenia highway source', () async {
    await File('${root.path}/Highways/slovenia-highways.json').delete();

    await expectLater(
      MappingDataStore(rootPath: root.path).preflight(),
      throwsA(
        isA<MappingStoreFailure>().having(
          (failure) => failure.paths,
          'paths',
          contains('Highways/slovenia-highways.json'),
        ),
      ),
    );
  });

  test('preflight never parses a peak or highway source', () async {
    for (final path in const [
      'Peaks/tasmania.json',
      'Peaks/slovenia.json',
      'Highways/tasmania.json',
      'Highways/fvg.json',
      'Highways/veneto.json',
      'Highways/slovenia-highways.json',
    ]) {
      await File('${root.path}/$path').writeAsString('{not json');
    }

    await MappingDataStore(rootPath: root.path).preflight();
  });

  test(
    'preflight permits a required polygon symlink within the store',
    () async {
      final source = File('${root.path}/Polygons/tasmania.poly');
      final link = Link('${root.path}/Polygons/tasmania-link.poly');
      await link.create(source.path);
      final manifest = await _readJson(root, 'region_manifest.json');
      (manifest['tasmania'] as Map<String, dynamic>)['poly'] = [
        'Polygons/tasmania-link.poly',
      ];
      await _writeJson(root, 'region_manifest.json', manifest);
      await _writeJson(root, 'Polygons/manifest.json', [
        'Polygons/tasmania-link.poly',
      ]);

      await expectLater(
        MappingDataStore(rootPath: root.path).preflight(),
        completes,
      );
    },
  );

  test('preflight rejects a symlink escaping the store', () async {
    final outside = await File(
      '${Directory.systemTemp.path}/mapping-store-outside.poly',
    ).create();
    addTearDown(outside.delete);
    final link = Link('${root.path}/Polygons/outside.poly');
    await link.create(outside.path);
    final manifest = await _readJson(root, 'region_manifest.json');
    (manifest['tasmania'] as Map<String, dynamic>)['poly'] = [
      'Polygons/outside.poly',
    ];
    await _writeJson(root, 'region_manifest.json', manifest);
    await _writeJson(root, 'Polygons/manifest.json', ['Polygons/outside.poly']);

    await expectLater(
      MappingDataStore(rootPath: root.path).preflight(),
      throwsA(
        isA<MappingStoreFailure>().having(
          (failure) => failure.paths,
          'paths',
          contains('Polygons/outside.poly'),
        ),
      ),
    );
  });
}

Future<void> _writeStore(Directory root) async {
  for (final directory in const [
    'Polygons',
    'Maps',
    'Features',
    'DEM/Elvis',
    'Peaks',
    'Highways',
  ]) {
    await Directory('${root.path}/$directory').create(recursive: true);
  }
  await _writeJson(root, 'region_manifest.json', _manifest);
  await _writeJson(root, 'Polygons/manifest.json', ['Polygons/tasmania.poly']);
  await File('${root.path}/Polygons/tasmania.poly').writeAsString('''
Tasmania
1
0 0
1 0
0 1
END
END
''');
  for (final path in const [
    'Maps/tasmap50k.csv',
    'Features/tasmania_natural_features.json',
    'DEM/Elvis/elvis_runtime_10m.tif',
    'DEM/tasmania_dem_25m.tif',
    'DEM/cop30_hh.tif',
    'Peaks/tasmania.json',
    'Peaks/slovenia.json',
    'Highways/tasmania.json',
    'Highways/fvg.json',
    'Highways/veneto.json',
    'Highways/slovenia-highways.json',
  ]) {
    await File('${root.path}/$path').writeAsString('source');
  }
}

Future<Map<String, dynamic>> _readJson(Directory root, String path) async {
  return jsonDecode(await File('${root.path}/$path').readAsString())
      as Map<String, dynamic>;
}

Future<void> _writeJson(Directory root, String path, Object value) =>
    File('${root.path}/$path').writeAsString(jsonEncode(value));

class _FailingCache extends MappingCatalogCache {
  _FailingCache() : super(Directory.systemTemp.path);

  @override
  Future<Map<String, List<LatLng>>> read({
    required String manifestHash,
    required Iterable<MappingCatalogCacheSource> sources,
  }) => throw StateError('cache unavailable');

  @override
  Future<void> replace({
    required String manifestHash,
    required Iterable<MappingCatalogCacheSource> sources,
    required Map<String, List<LatLng>> polygons,
  }) => throw StateError('cache unavailable');
}

const _map = {
  'key': 'openstreetmap',
  'name': 'OpenStreetMap',
  'tileUrl': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  'attribution': 'OpenStreetMap contributors',
};

const _manifest = {
  'tasmap': {'catalog': 'Maps/tasmap50k.csv'},
  'naturalFeatures': {'catalog': 'Features/tasmania_natural_features.json'},
  'demSources': {
    'elvisRuntime': 'DEM/Elvis/elvis_runtime_10m.tif',
    'thelist25m': 'DEM/tasmania_dem_25m.tif',
    'copernicus': 'DEM/cop30_hh.tif',
  },
  'routingCoverages': {
    'tasmania': {'displayName': 'Tasmania'},
    'northeast-alps': {'displayName': 'Northeast Alps'},
  },
  'tasmania': {
    'priority': '1',
    'name': 'Tasmania',
    'shortName': 'Tas',
    'showInPeakList': 'true',
    'routingCoverage': 'tasmania',
    'fingerprint': 'tasmania-fingerprint',
    'poly': ['Polygons/tasmania.poly'],
    'peaks': ['Peaks/tasmania.json'],
    'highways': ['Highways/tasmania.json'],
    'maps': [_map],
    'mapSet': [],
  },
  'fvg': {
    'priority': '2.1',
    'name': 'FVG',
    'shortName': 'FVG',
    'showInPeakList': false,
    'seedOnStartup': false,
    'routingCoverage': 'northeast-alps',
    'poly': [],
    'highways': ['Highways/fvg.json'],
    'maps': [_map],
    'mapSet': [],
  },
  'veneto': {
    'priority': '2.2',
    'name': 'Veneto',
    'shortName': 'Veneto',
    'showInPeakList': false,
    'seedOnStartup': false,
    'routingCoverage': 'northeast-alps',
    'poly': [],
    'highways': ['Highways/veneto.json'],
    'maps': [_map],
    'mapSet': [],
  },
  'slovenia': {
    'priority': '3',
    'name': 'Slovenia',
    'shortName': 'Slovenia',
    'showInPeakList': true,
    'routingCoverage': 'northeast-alps',
    'fingerprint': 'slovenia-fingerprint',
    'poly': [],
    'peaks': ['Peaks/slovenia.json'],
    'highways': ['Highways/slovenia-highways.json'],
    'maps': [_map],
    'mapSet': [],
  },
};
