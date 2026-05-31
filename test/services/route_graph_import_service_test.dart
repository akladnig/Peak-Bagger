import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/services/route_graph_errors.dart';
import 'package:peak_bagger/services/route_graph_import_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';

void main() {
  test('bootstrapIfNeeded imports once and reuses the active generation', () async {
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
    expect(repository.manifest?.readinessState, RouteGraphManifest.readinessReady);
    expect(repository.activeChunks(), isNotEmpty);
  });

  test('bootstrapIfNeeded persists first-launch failure and stops retrying', () async {
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
    expect(repository.manifest?.readinessState, RouteGraphManifest.readinessFailed);
  });

  test('refreshFromBundledAsset keeps the previous generation on failure', () async {
    var rawJson = _fixture;
    final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
    final service = RouteGraphImportService(
      repository,
      assetLoader: (_) async => rawJson,
      generationPreparer: _syncGenerationPreparer,
    );

    await service.bootstrapIfNeeded();
    expect(repository.manifest?.activeGeneration, 1);

    rawJson = 'not-json';

    await expectLater(
      () => service.refreshFromBundledAsset(),
      throwsA(isA<RouteGraphLoadException>()),
    );

    expect(repository.manifest?.activeGeneration, 1);
    expect(repository.manifest?.readinessState, RouteGraphManifest.readinessReady);
  });

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
      expect(row.recordKey, RouteGraphWayIndex.recordKeyFor(generation: 1, chunkKey: row.chunkKey, osmWayId: 10));
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
}

Future<Map<String, Object?>> _syncGenerationPreparer(
  String rawJson,
  String schemaVersion,
  int generation,
) async {
  jsonDecode(rawJson);
  return _prepare(rawJson, schemaVersion, generation);
}

Map<String, Object?> _prepare(String rawJson, String schemaVersion, int generation) {
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
