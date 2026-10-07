import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/manifest_priority.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/route_graph_coverage_resolver.dart';

void main() {
  test(
    'FVG wins complete way and node conflicts with Slovenia in either source order',
    () async {
      for (final catalogMode in [false, true]) {
        for (final keys in [
          ['fvg', 'slovenia'],
          ['slovenia', 'fvg'],
        ]) {
          final sources = _precedenceSources();
          final resolver = _precedenceResolver(
            keys,
            sources,
            catalogMode: catalogMode,
          );
          final input = (await resolver.resolve()).single;
          final elements = {
            for (final element in input.elements.cast<Map>())
              '${element['type']}:${element['id']}': element,
          };
          expect(elements['node:1']!['lat'], 46);
          expect(elements['way:10']!['nodes'], [1, 2]);
          expect(elements['way:10']!['tags'], {
            'highway': 'path',
            'name': 'FVG winner',
          });
          expect(elements['way:11']!['tags'], {
            'highway': 'track',
            'name': 'Slovenia unique',
          });
          expect(elements, hasLength(4));
          expect(input.acceptedWayCount, 2);
        }
      }
    },
  );

  test('precedence never masks conflicting repeats within Slovenia', () async {
    for (final catalogMode in [false, true]) {
      for (final keys in [
        ['fvg', 'slovenia'],
        ['slovenia', 'fvg'],
      ]) {
        final sources = _precedenceSources();
        final source = jsonDecode(sources['Highways/slovenia.json']!) as Map;
        (source['elements'] as List).add({
          'type': 'node',
          'id': 1,
          'lat': 46.03,
          'lon': 13.03,
        });
        sources['Highways/slovenia.json'] = jsonEncode(source);
        await expectLater(
          _precedenceResolver(
            keys,
            sources,
            catalogMode: catalogMode,
          ).resolve(),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('conflicting OSM element node:1'),
            ),
          ),
        );
      }
    }
  });

  test('FVG precedence does not authorize a conflict with Veneto', () async {
    for (final catalogMode in [false, true]) {
      final sources = _precedenceSources();
      sources['Highways/veneto.json'] = sources.remove(
        'Highways/slovenia.json',
      )!;
      await expectLater(
        _precedenceResolver(
          ['fvg', 'veneto'],
          sources,
          catalogMode: catalogMode,
        ).resolve(),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('a malformed retained FVG way still fails the complete graph', () async {
    final sources = _precedenceSources();
    final source = jsonDecode(sources['Highways/fvg.json']!) as Map;
    ((source['elements'] as List).last as Map)['nodes'] = [1, 999];
    sources['Highways/fvg.json'] = jsonEncode(source);
    await expectLater(
      _precedenceResolver(
        ['fvg', 'slovenia'],
        sources,
        catalogMode: true,
      ).resolve(),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'source hash includes losing snapshots even when merged geometry is unchanged',
    () async {
      final sources = _precedenceSources();
      final before = (await _precedenceResolver(
        ['fvg', 'slovenia'],
        sources,
        catalogMode: true,
      ).resolve()).single;
      final source = jsonDecode(sources['Highways/slovenia.json']!) as Map;
      (((source['elements'] as List)[2] as Map)['tags'] as Map)['name'] =
          'Changed losing name';
      sources['Highways/slovenia.json'] = jsonEncode(source);
      final after = (await _precedenceResolver(
        ['fvg', 'slovenia'],
        sources,
        catalogMode: true,
      ).resolve()).single;
      expect(after.elements, before.elements);
      expect(after.sourceHash, isNot(before.sourceHash));
    },
  );
  test(
    'resolves declared coverage and source ordering with a stable hash',
    () async {
      final resolver = RouteGraphCoverageResolver(
        assetLoader: _loader({
          'region_manifest.json': jsonEncode({
            'routingCoverages': {
              'tasmania': {'displayName': 'Tasmania'},
              'northeast-alps': {'displayName': 'Northeast Alps'},
            },
            'late': {
              'priority': '2.1',
              'routingCoverage': 'northeast-alps',
              'highways': ['Highways/z.json', 'Highways/a.json'],
            },
            'early': {
              'priority': '1.2',
              'routingCoverage': 'northeast-alps',
              'highways': ['Highways/b.json'],
            },
            'tas': {
              'priority': '1.1',
              'routingCoverage': 'tasmania',
              'highways': ['Highways/tas.json'],
            },
            'legacy': {
              'highways': ['Highways/legacy.json'],
            },
            'composite': {
              'composite': true,
              'routingCoverage': 'tasmania',
              'highways': ['Highways/composite.json'],
            },
          }),
          'Highways/tas.json': _overpass([
            {'type': 'node', 'id': 1, 'lat': -42.0, 'lon': 146.0},
            {'type': 'node', 'id': 2, 'lat': -42.01, 'lon': 146.01},
            {
              'type': 'way',
              'id': 2,
              'nodes': [1, 2],
              'tags': {'highway': 'path'},
            },
          ]),
          'Highways/a.json': _overpass([
            {'type': 'node', 'id': 4, 'lat': 1.0, 'lon': 2.0},
          ]),
          'Highways/b.json': _overpass([
            {'type': 'node', 'id': 3, 'lat': 1, 'lon': 2},
          ]),
          'Highways/z.json': _overpass([
            {
              'type': 'way',
              'id': 5,
              'tags': {'highway': 'track', 'area': 'yes'},
            },
          ]),
        }),
      );

      final inputs = await resolver.resolve();

      expect(inputs.map((input) => input.definition.key), [
        'tasmania',
        'northeast-alps',
      ]);
      expect(inputs[1].definition.displayName, 'Northeast Alps');
      expect(inputs[1].definition.sourceRegions.map((region) => region.key), [
        'early',
        'late',
      ]);
      expect(
        inputs[1].definition.sourceRegions[1].sourceAssets.map(
          (asset) => asset.path,
        ),
        ['Highways/a.json', 'Highways/z.json'],
      );
      expect(inputs[0].acceptedWayCount, 1);
      expect(inputs[0].sourceHash, hasLength(64));
    },
  );

  test('does not include display names in coverage hashes', () async {
    final manifest = {
      'routingCoverages': {
        'tasmania': {'displayName': 'Tasmania'},
      },
      'tasmania': {
        'priority': '1.1',
        'routingCoverage': 'tasmania',
        'highways': ['Highways/tas.json'],
      },
    };
    final assets = {'Highways/tas.json': _overpass([])};
    final first = await RouteGraphCoverageResolver(
      assetLoader: _loader({
        'region_manifest.json': jsonEncode(manifest),
        ...assets,
      }),
    ).resolve();
    (manifest['routingCoverages']! as Map<String, Object?>)['tasmania'] = {
      'displayName': 'Different',
    };
    final second = await RouteGraphCoverageResolver(
      assetLoader: _loader({
        'region_manifest.json': jsonEncode(manifest),
        ...assets,
      }),
    ).resolve();

    expect(second.single.sourceHash, first.single.sourceHash);
  });

  test(
    'rejects invalid coverage input and conflicting OSM identities',
    () async {
      Future<void> expectInvalid(Object manifest, Map<String, String> assets) {
        return expectLater(
          RouteGraphCoverageResolver(
            assetLoader: _loader({
              'region_manifest.json': jsonEncode(manifest),
              ...assets,
            }),
          ).resolve(),
          throwsA(isA<FormatException>()),
        );
      }

      final base = {
        'routingCoverages': {
          'tasmania': {'displayName': 'Tasmania'},
        },
        'tasmania': {
          'priority': '1.1',
          'routingCoverage': 'tasmania',
          'highways': ['Highways/tas.json'],
        },
      };
      await expectInvalid(
        {
          ...base,
          'other': {
            'priority': '1.2',
            'routingCoverage': 'missing',
            'highways': ['Highways/tas.json'],
          },
        },
        {'Highways/tas.json': _overpass([])},
      );
      await expectInvalid(
        {...base, 'metadata': 'not a region'},
        {'Highways/tas.json': _overpass([])},
      );
      await expectInvalid({
        ...base,
        'tasmania': {
          ...base['tasmania']! as Map<String, Object?>,
          'highways': ['assets\\highways\\tas.json'],
        },
      }, const {});
      await expectInvalid(base, {'Highways/tas.json': '[]'});
      await expectInvalid(base, {
        'Highways/tas.json': _overpass([
          {'type': 'node', 'id': 1},
          {'id': 1, 'type': 'node', 'lat': 1},
        ]),
      });
    },
  );

  test(
    'deduplicates equal identities and validates accepted route graph ways',
    () async {
      final resolver = RouteGraphCoverageResolver(
        assetLoader: _loader({
          'region_manifest.json': jsonEncode({
            'routingCoverages': {
              'tasmania': {'displayName': 'Tasmania'},
            },
            'tasmania': {
              'priority': '1.1',
              'routingCoverage': 'tasmania',
              'highways': ['Highways/a.json', 'Highways/b.json'],
            },
          }),
          'Highways/a.json': _overpass([
            {'type': 'node', 'id': 1, 'lat': 1.0, 'lon': 2.0},
            {'type': 'node', 'id': 2, 'lat': 1.01, 'lon': 2.01},
            {
              'type': 'way',
              'id': 2,
              'nodes': [1, 2],
              'tags': {'highway': 'path'},
            },
            {
              'type': 'way',
              'id': 3,
              'nodes': [1, 2],
              'tags': {'highway': 'path', 'area': 'yes'},
            },
          ]),
          'Highways/b.json': _overpass([
            {'lon': 2, 'id': 1, 'type': 'node', 'lat': 1},
          ]),
        }),
      );

      final input = (await resolver.resolve()).single;

      expect(input.elements, hasLength(4));
      expect(input.acceptedWayCount, 1);
      expect(
        isAcceptedRouteGraphWay({'type': 'way', 'id': 1, 'tags': {}}),
        isFalse,
      );
    },
  );
}

RouteGraphCoverageAssetLoader _loader(Map<String, String> assets) {
  return (path) async => assets[path] ?? (throw StateError('Missing $path'));
}

String _overpass(List<Map<String, Object?>> elements) {
  return jsonEncode({'elements': elements});
}

Map<String, String> _precedenceSources() => {
  'Highways/fvg.json': _overpass([
    {'type': 'node', 'id': 1, 'lat': 46, 'lon': 13},
    {'type': 'node', 'id': 2, 'lat': 46.01, 'lon': 13.01},
    {
      'type': 'way',
      'id': 10,
      'nodes': [1, 2],
      'tags': {'highway': 'path', 'name': 'FVG winner'},
    },
  ]),
  'Highways/slovenia.json': _overpass([
    {'type': 'node', 'id': 1, 'lat': 46.02, 'lon': 13.02},
    {'type': 'node', 'id': 2, 'lat': 46.01, 'lon': 13.01},
    {
      'type': 'way',
      'id': 10,
      'nodes': [2, 1],
      'tags': {'highway': 'track', 'name': 'Slovenia shadow'},
    },
    {
      'type': 'way',
      'id': 11,
      'nodes': [1, 2],
      'tags': {'highway': 'track', 'name': 'Slovenia unique'},
    },
  ]),
};

RouteGraphCoverageResolver _precedenceResolver(
  List<String> keys,
  Map<String, String> sources, {
  required bool catalogMode,
}) {
  final regions = [
    for (var i = 0; i < keys.length; i++)
      MappingCatalogRegion(
        key: keys[i],
        name: keys[i],
        shortName: keys[i],
        priority: ManifestPriority.parse('${i + 1}'),
        showInPeakList: false,
        seedOnStartup: false,
        composite: false,
        polyPaths: const [],
        polygons: const [],
        basemapKeys: const [],
        mapSet: const [],
        peakListFilterAliases: const [],
        routingCoverage: 'northeast-alps',
        peaks: const [],
        highways: ['Highways/${keys[i]}.json'],
        fingerprint: null,
      ),
  ];
  if (catalogMode) {
    final catalog = MappingCatalog(
      rootPath: '/mapping',
      regions: regions,
      basemaps: const [],
      tasmapCatalogPath: 'Maps/tasmap.csv',
      naturalFeaturesCatalogPath: 'Features/features.json',
      demSources: const {},
      routingCoverageRegionKeys: {'northeast-alps': keys},
    );
    return RouteGraphCoverageResolver(
      catalog: catalog,
      fileAccess: _SourceAccess(catalog, sources),
    );
  }
  return RouteGraphCoverageResolver(
    assetLoader: _loader({
      'region_manifest.json': jsonEncode({
        'routingCoverages': {
          'northeast-alps': {'displayName': 'Northeast Alps'},
        },
        for (final region in regions)
          region.key: {
            'priority': region.priority.toString(),
            'routingCoverage': 'northeast-alps',
            'highways': region.highways,
          },
      }),
      ...sources,
    }),
  );
}

class _SourceAccess extends MappingStoreOperationFileAccess {
  _SourceAccess(MappingCatalog catalog, this.sources)
    : super(catalog: catalog, fileSystem: const IoMappingStoreFileSystem());
  final Map<String, String> sources;
  @override
  Future<String> readText(String relativePath) async => sources[relativePath]!;
}
