import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/services/route_graph_errors.dart';
import 'package:peak_bagger/services/route_graph_import_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

void main() {
  test(
    'bootstrapIfNeeded imports once and reuses the active generation',
    () async {
      var rawJsonCalls = 0;
      final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
      final service = RouteGraphImportService(
        repository,
        assetLoader: (_) async {
          rawJsonCalls += 1;
          return _fixture;
        },
        generationPreparer: _syncGenerationPreparer,
      );

      final first = await service.bootstrapIfNeeded();
      final second = await service.bootstrapIfNeeded();

      expect(first.imported, isTrue);
      expect(second.reusedExisting, isTrue);
      expect(rawJsonCalls, 1);
      expect(repository.manifest?.activeGeneration, 1);
      expect(
        repository.manifest?.readinessState,
        RouteGraphManifest.readinessReady,
      );
      expect(repository.activeChunks(), isNotEmpty);
    },
  );

  test(
    'bootstrapIfNeeded rebuilds when active schema version mismatches',
    () async {
      var rawJsonCalls = 0;
      final repository = RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: RouteGraphManifest(
            sourceHash: 'old',
            schemaVersion: 'route-graph-v1',
            activeGeneration: 1,
            importedAt: DateTime.utc(2024),
            chunkCount: 1,
            nodeCount: 2,
            edgeCount: 1,
            readinessState: RouteGraphManifest.readinessReady,
          ),
        ),
      );
      final service = RouteGraphImportService(
        repository,
        assetLoader: (_) async {
          rawJsonCalls += 1;
          return _fixture;
        },
        generationPreparer: _syncGenerationPreparer,
      );

      final outcome = await service.bootstrapIfNeeded();

      expect(outcome.imported, isTrue);
      expect(outcome.reusedExisting, isFalse);
      expect(rawJsonCalls, 1);
      expect(repository.manifest?.activeGeneration, 2);
      expect(repository.manifest?.schemaVersion, service.schemaVersion);
    },
  );

  test(
    'bootstrapIfNeeded rebuilds when trail display rows are missing',
    () async {
      var rawJsonCalls = 0;
      final repository = RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: RouteGraphManifest(
            sourceHash: 'current',
            schemaVersion: 'route-graph-v4',
            activeGeneration: 1,
            importedAt: DateTime.utc(2024),
            chunkCount: 1,
            nodeCount: 2,
            edgeCount: 1,
            readinessState: RouteGraphManifest.readinessReady,
          ),
        ),
      );
      final service = RouteGraphImportService(
        repository,
        assetLoader: (_) async {
          rawJsonCalls += 1;
          return _trailFixture;
        },
      );

      final outcome = await service.bootstrapIfNeeded();

      expect(outcome.imported, isTrue);
      expect(rawJsonCalls, 1);
      expect(repository.manifest?.activeGeneration, 2);
      expect(repository.activeTrailDisplayChunks(), isNotEmpty);
    },
  );

  test(
    'bootstrapIfNeeded rebuilds older prepared generations on startup once',
    () async {
      var rawJsonCalls = 0;
      final repository = RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: RouteGraphManifest(
            sourceHash: 'old',
            schemaVersion: 'route-graph-v3',
            activeGeneration: 1,
            importedAt: DateTime.utc(2024),
            chunkCount: 1,
            nodeCount: 2,
            edgeCount: 1,
            readinessState: RouteGraphManifest.readinessReady,
          ),
        ),
      );
      final service = RouteGraphImportService(
        repository,
        assetLoader: (_) async {
          rawJsonCalls += 1;
          return _trailFixture;
        },
      );

      final first = await service.bootstrapIfNeeded();
      final second = await service.bootstrapIfNeeded();

      expect(first.imported, isTrue);
      expect(second.reusedExisting, isTrue);
      expect(rawJsonCalls, 1);
      expect(repository.manifest?.activeGeneration, 2);
      expect(repository.manifest?.schemaVersion, service.schemaVersion);
      expect(repository.activeTrailDisplayChunks(), isNotEmpty);
    },
  );

  test(
    'bootstrapIfNeeded persists first-launch failure and stops retrying',
    () async {
      var rawJsonCalls = 0;
      final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
      final service = RouteGraphImportService(
        repository,
        assetLoader: (_) async {
          rawJsonCalls += 1;
          return 'not-json';
        },
        generationPreparer: _syncGenerationPreparer,
      );

      await expectLater(
        () => service.bootstrapIfNeeded(),
        throwsA(isA<RouteGraphLoadException>()),
      );

      await expectLater(
        () => service.bootstrapIfNeeded(),
        throwsA(isA<RouteGraphLoadException>()),
      );

      expect(rawJsonCalls, 1);
      expect(repository.manifest?.isFailed, isTrue);
      expect(repository.manifest?.activeGeneration, 0);
      expect(
        repository.manifest?.readinessState,
        RouteGraphManifest.readinessFailed,
      );
    },
  );

  test(
    'refreshFromBundledAsset keeps the previous generation on failure',
    () async {
      var rawJson = _fixture;
      final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
      final service = RouteGraphImportService(
        repository,
        assetLoader: (_) async => rawJson,
        generationPreparer: _syncGenerationPreparer,
      );

      await service.bootstrapIfNeeded();
      expect(repository.manifest?.activeGeneration, 1);
      expect(repository.activeTrailDisplayChunks(), isNotEmpty);

      rawJson = 'not-json';

      await expectLater(
        () => service.refreshFromBundledAsset(),
        throwsA(isA<RouteGraphLoadException>()),
      );

      expect(repository.manifest?.activeGeneration, 1);
      expect(
        repository.manifest?.readinessState,
        RouteGraphManifest.readinessReady,
      );
      expect(repository.activeTrailDisplayChunks(), isNotEmpty);
    },
  );

  test('bootstrapIfNeeded persists indexed way rows for hot tags', () async {
    final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
    final service = RouteGraphImportService(
      repository,
      assetLoader: (_) async => _richFixture,
    );

    await service.bootstrapIfNeeded();

    expect(repository.activeWayIndexRows(), hasLength(2));
    expect(
      repository.activeWayIndexRows().map((row) => row.chunkKey).toSet(),
      hasLength(2),
    );
    for (final row in repository.activeWayIndexRows()) {
      expect(
        row.recordKey,
        RouteGraphWayIndex.recordKeyFor(
          generation: 1,
          chunkKey: row.chunkKey,
          osmWayId: 10,
        ),
      );
      expect(row.highway, 'footway');
      expect(row.surface, 'gravel');
      expect(row.footway, 'sidewalk');
      expect(row.foot, 'no');
      expect(row.route, 'mtb');
      expect(row.access, 'private');
      expect(row.name, 'Tassy Paths');
      expect(row.normalizedName, 'tassy paths');
      expect(row.tagCount, 7);
      expect(row.lengthMeters, greaterThan(0));
    }
  });

  test(
    'bootstrapIfNeeded creates trail cache rows for matching ways at each zoom',
    () async {
      final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
      final service = RouteGraphImportService(
        repository,
        assetLoader: (_) async => _trailFixture,
      );

      await service.bootstrapIfNeeded();

      final rows = repository.activeTrailDisplayChunks();
      expect(rows, isNotEmpty);
      expect(rows.map((row) => row.cacheZoom).toSet(), {
        for (
          var zoom = TrackDisplayCacheBuilder.minZoom;
          zoom <= TrackDisplayCacheBuilder.maxZoom;
          zoom++
        )
          zoom,
      });

      final cachedWayIds = rows
          .expand((row) => row.decodeWays())
          .map((way) => way.osmWayId)
          .toSet();
      expect(cachedWayIds.contains(10), isTrue);
      expect(cachedWayIds.contains(11), isTrue);
      expect(cachedWayIds.contains(12), isFalse);
      expect(cachedWayIds.contains(13), isFalse);
      expect(cachedWayIds.contains(14), isFalse);
    },
  );
}

Future<Map<String, Object?>> _syncGenerationPreparer(
  String rawJson,
  String schemaVersion,
  int generation,
) async {
  jsonDecode(rawJson);
  return _prepare(rawJson, schemaVersion, generation);
}

Map<String, Object?> _prepare(
  String rawJson,
  String schemaVersion,
  int generation,
) {
  return {
    'generation': generation,
    'sourceHash': rawJson.hashCode.toString(),
    'schemaVersion': schemaVersion,
    'importedAtMillis': DateTime.utc(2025).millisecondsSinceEpoch,
    'chunkCount': 1,
    'nodeCount': 2,
    'edgeCount': 1,
    'chunks': [
      {
        'recordKey': '$generation|0_0',
        'chunkKey': '0_0',
        'generation': generation,
        'minLat': -42.0,
        'minLon': 146.0,
        'maxLat': -41.0,
        'maxLon': 147.0,
        'elementCount': 3,
        'payloadJson': _fixture,
      },
    ],
    'trailDisplayChunks': [
      {
        'recordKey': RouteGraphTrailDisplayChunk.recordKeyFor(
          generation: generation,
          cacheZoom: TrackDisplayCacheBuilder.minZoom,
          chunkKey: '0_0',
        ),
        'generation': generation,
        'cacheZoom': TrackDisplayCacheBuilder.minZoom,
        'chunkKey': '0_0',
        'payloadJson': RouteGraphTrailDisplayChunk.encodeWays([
          const RouteGraphTrailDisplayWay(
            osmWayId: 10,
            points: [LatLng(-42.0, 146.0), LatLng(-42.01, 146.01)],
          ),
        ]),
      },
    ],
  };
}

const _fixture = '''
{"elements":[
  {"type":"node","id":1,"lat":-42.0,"lon":146.0},
  {"type":"node","id":2,"lat":-42.01,"lon":146.01},
  {"type":"way","id":10,"nodes":[1,2],"tags":{"highway":"path"}}
]}
''';

const _richFixture = '''
{"elements":[
  {"type":"node","id":1,"lat":-42.0,"lon":146.0},
  {"type":"node","id":2,"lat":-42.01,"lon":146.01},
  {"type":"way","id":10,"nodes":[1,2],"tags":{"highway":"footway","surface":"gravel","footway":"sidewalk","foot":"no","route":"mtb","access":"private","name":"Tassy Paths"}}
]}
''';

const _trailFixture = '''
{"elements":[
  {"type":"node","id":1,"lat":-42.0000,"lon":146.0000},
  {"type":"node","id":2,"lat":-41.9940,"lon":146.0000},
  {"type":"node","id":3,"lat":-41.9880,"lon":146.0000},
  {"type":"node","id":4,"lat":-41.9820,"lon":146.0000},
  {"type":"node","id":5,"lat":-41.9760,"lon":146.0000},
  {"type":"node","id":6,"lat":-41.9700,"lon":146.0000},
  {"type":"way","id":10,"nodes":[1,2],"tags":{"highway":"path","name":"Public Path"}},
  {"type":"way","id":11,"nodes":[1,6],"tags":{"highway":"footway","name":"Long Footway"}},
  {"type":"way","id":12,"nodes":[1,6],"tags":{"highway":"path","access":"private","name":"Private Path"}},
  {"type":"way","id":13,"nodes":[1,6],"tags":{"highway":"track","name":"Track"}},
  {"type":"way","id":14,"nodes":[1,6],"tags":{"highway":"path","surface":"concrete","name":"Concrete Path"}}
]}
''';
