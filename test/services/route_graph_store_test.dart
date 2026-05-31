import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
import 'package:peak_bagger/services/route_graph_import_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

void main() {
  test('bootstrapData seeds the route graph before service preload', () async {
    var rawJson = _fixture;
    var assetCalls = 0;
    final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
    final importService = RouteGraphImportService(
      repository,
      assetLoader: (_) async {
        assetCalls += 1;
        return rawJson;
      },
      generationPreparer: _syncGenerationPreparer,
    );
    final store = ObjectBoxRouteGraphStore(
      repository: repository,
      importService: importService,
    );

    await store.bootstrapData();
    expect(repository.manifest?.activeGeneration, 1);

    await store.preload();

    expect(assetCalls, 1);
    expect(repository.manifest?.activeGeneration, 1);
  });

  test('preload seeds and caches the route graph service', () async {
    var rawJson = _fixture;
    var assetCalls = 0;
    final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
    final importService = RouteGraphImportService(
      repository,
      assetLoader: (_) async {
        assetCalls += 1;
        return rawJson;
      },
      generationPreparer: _syncGenerationPreparer,
    );
    final store = ObjectBoxRouteGraphStore(
      repository: repository,
      importService: importService,
    );

    final first = await store.preload();
    final second = await store.preload();

    expect(identical(first, second), isTrue);
    expect(assetCalls, 1);
  });

  test('reload refreshes the cached route graph service', () async {
    var rawJson = _fixture;
    var assetCalls = 0;
    final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
    final importService = RouteGraphImportService(
      repository,
      assetLoader: (_) async {
        assetCalls += 1;
        return rawJson;
      },
      generationPreparer: _syncGenerationPreparer,
    );
    final store = ObjectBoxRouteGraphStore(
      repository: repository,
      importService: importService,
    );

    final first = await store.preload();
    rawJson = _alternateFixture;
    final refreshed = await store.reload();

    expect(identical(first, refreshed), isFalse);
    expect(assetCalls, 2);
    expect(repository.manifest?.activeGeneration, 2);
  });

  test(
    'preload keeps the first-launch failure cached as a failure state',
    () async {
      var assetCalls = 0;
      final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
      final importService = RouteGraphImportService(
        repository,
        assetLoader: (_) async {
          assetCalls += 1;
          return 'not-json';
        },
        generationPreparer: _syncGenerationPreparer,
      );
      final store = ObjectBoxRouteGraphStore(
        repository: repository,
        importService: importService,
      );

      await expectLater(
        () => store.preload(),
        throwsA(isA<RouteGraphLoadException>()),
      );
      await expectLater(
        () => store.preload(),
        throwsA(isA<RouteGraphLoadException>()),
      );

      expect(assetCalls, 1);
      expect(repository.manifest?.isFailed, isTrue);
    },
  );

  test('replaceSnapshot validates raw json before writing', () async {
    final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
    final importService = RouteGraphImportService(
      repository,
      assetLoader: (_) async => _fixture,
      generationPreparer: _syncGenerationPreparer,
    );
    final store = ObjectBoxRouteGraphStore(
      repository: repository,
      importService: importService,
    );

    await store.preload();
    final cached = await store.preload();
    expect(cached, isNotNull);

    await expectLater(
      () => store.replaceSnapshot('not-json'),
      throwsA(isA<RouteGraphLoadException>()),
    );

    expect(repository.manifest?.activeGeneration, 1);
  });
}

Future<Map<String, Object?>> _syncGenerationPreparer(
  String rawJson,
  String schemaVersion,
  int generation,
) async {
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map<String, dynamic>) {
    throw const RouteGraphLoadException(
      'Expected top-level route graph object.',
    );
  }

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
        'payloadJson': jsonEncode(decoded),
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

const _alternateFixture = '''
{"elements":[
  {"type":"node","id":11,"lat":-42.1,"lon":146.1},
  {"type":"node","id":12,"lat":-42.11,"lon":146.11},
  {"type":"way","id":20,"nodes":[11,12],"tags":{"highway":"path"}}
]}
''';
