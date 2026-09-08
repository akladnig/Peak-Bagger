import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/route_graph_coverage_resolver.dart';

void main() {
  test(
    'resolves declared coverage and source ordering with a stable hash',
    () async {
      final resolver = RouteGraphCoverageResolver(
        assetLoader: _loader({
          'assets/region_manifest.json': jsonEncode({
            'routingCoverages': {
              'tasmania': {'displayName': 'Tasmania'},
              'northeast-alps': {'displayName': 'Northeast Alps'},
            },
            'late': {
              'priority': '2.1',
              'routingCoverage': 'northeast-alps',
              'highways': ['assets/highways/z.json', 'assets/highways/a.json'],
            },
            'early': {
              'priority': '1.2',
              'routingCoverage': 'northeast-alps',
              'highways': ['assets/highways/b.json'],
            },
            'tas': {
              'priority': '1.1',
              'routingCoverage': 'tasmania',
              'highways': ['assets/highways/tas.json'],
            },
            'legacy': {
              'highways': ['assets/highways/legacy.json'],
            },
            'composite': {
              'composite': true,
              'routingCoverage': 'tasmania',
              'highways': ['assets/highways/composite.json'],
            },
          }),
          'assets/highways/tas.json': _overpass([
            {'type': 'node', 'id': 1, 'lat': -42.0, 'lon': 146.0},
            {'type': 'node', 'id': 2, 'lat': -42.01, 'lon': 146.01},
            {
              'type': 'way',
              'id': 2,
              'nodes': [1, 2],
              'tags': {'highway': 'path'},
            },
          ]),
          'assets/highways/a.json': _overpass([
            {'type': 'node', 'id': 4, 'lat': 1.0, 'lon': 2.0},
          ]),
          'assets/highways/b.json': _overpass([
            {'type': 'node', 'id': 3, 'lat': 1, 'lon': 2},
          ]),
          'assets/highways/z.json': _overpass([
            {
              'type': 'way',
              'id': 5,
              'tags': {'highway': 'track'},
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
        ['assets/highways/a.json', 'assets/highways/z.json'],
      );
      expect(inputs[0].acceptedWayCount, 1);
      expect(
        inputs[0].sourceHash,
        'fc18f9a781b218049158b882eec61d907228d4460b8986d482f1d16b686c72a5',
      );
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
        'highways': ['assets/highways/tas.json'],
      },
    };
    final assets = {'assets/highways/tas.json': _overpass([])};
    final first = await RouteGraphCoverageResolver(
      assetLoader: _loader({
        'assets/region_manifest.json': jsonEncode(manifest),
        ...assets,
      }),
    ).resolve();
    (manifest['routingCoverages']! as Map<String, Object?>)['tasmania'] = {
      'displayName': 'Different',
    };
    final second = await RouteGraphCoverageResolver(
      assetLoader: _loader({
        'assets/region_manifest.json': jsonEncode(manifest),
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
              'assets/region_manifest.json': jsonEncode(manifest),
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
          'highways': ['assets/highways/tas.json'],
        },
      };
      await expectInvalid(
        {
          ...base,
          'other': {
            'priority': '1.2',
            'routingCoverage': 'missing',
            'highways': ['assets/highways/tas.json'],
          },
        },
        {'assets/highways/tas.json': _overpass([])},
      );
      await expectInvalid(
        {...base, 'metadata': 'not a region'},
        {'assets/highways/tas.json': _overpass([])},
      );
      await expectInvalid({
        ...base,
        'tasmania': {
          ...base['tasmania']! as Map<String, Object?>,
          'highways': ['assets\\highways\\tas.json'],
        },
      }, const {});
      await expectInvalid(base, {'assets/highways/tas.json': '[]'});
      await expectInvalid(base, {
        'assets/highways/tas.json': _overpass([
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
          'assets/region_manifest.json': jsonEncode({
            'routingCoverages': {
              'tasmania': {'displayName': 'Tasmania'},
            },
            'tasmania': {
              'priority': '1.1',
              'routingCoverage': 'tasmania',
              'highways': ['assets/highways/a.json', 'assets/highways/b.json'],
            },
          }),
          'assets/highways/a.json': _overpass([
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
          'assets/highways/b.json': _overpass([
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
