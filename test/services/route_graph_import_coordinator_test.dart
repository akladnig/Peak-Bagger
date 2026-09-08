import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/route_graph_coverage.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/services/route_graph_coverage_resolver.dart';
import 'package:peak_bagger/services/route_graph_import_coordinator.dart';
import 'package:peak_bagger/services/route_graph_import_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';

void main() {
  test(
    'runs coverage imports sequentially, continues failures, and joins',
    () async {
      final firstImportHold = Completer<void>();
      final started = <int>[];
      final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
      final importService = RouteGraphImportService(
        repository,
        generationPreparer: (rawJson, schemaVersion, generation) async {
          started.add(generation);
          if (generation == 1) {
            await firstImportHold.future;
          }
          if (generation == 2) {
            throw StateError('northeast alps is invalid');
          }
          return _preparedGeneration(rawJson, schemaVersion, generation);
        },
      );
      final coordinator = RouteGraphImportCoordinator(
        coverageResolver: _Resolver([
          _input('tasmania'),
          _input('northeast-alps'),
        ]),
        importService: importService,
        repository: repository,
      );

      final bootstrap = coordinator.bootstrap();
      expect(identical(bootstrap, coordinator.refreshAll()), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(started, [1]);
      expect(
        coordinator.stateFor('northeast-alps')?.status,
        RouteGraphCoverageImportStatus.queued,
      );

      firstImportHold.complete();
      final result = await bootstrap;

      expect(started, [1, 2]);
      expect(result, isA<RouteGraphImportBatchCompleted>());
      final completed = result as RouteGraphImportBatchCompleted;
      expect(completed.outcomes.map((outcome) => outcome.routingCoverageKey), [
        'tasmania',
        'northeast-alps',
      ]);
      expect(completed.outcomes.map((outcome) => outcome.status), [
        RouteGraphCoverageOutcomeStatus.refreshed,
        RouteGraphCoverageOutcomeStatus.failed,
      ]);
      expect(repository.hasUsableActiveGenerationFor('tasmania'), isTrue);
      expect(
        repository.hasUsableActiveGenerationFor('northeast-alps'),
        isFalse,
      );
      expect(
        coordinator.stateFor('northeast-alps')?.status,
        RouteGraphCoverageImportStatus.failed,
      );
    },
  );

  test('reuses an unchanged coverage without reserving a generation', () async {
    final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
    var prepareCount = 0;
    final input = _input('tasmania');
    final coordinator = RouteGraphImportCoordinator(
      coverageResolver: _Resolver([input]),
      importService: RouteGraphImportService(
        repository,
        generationPreparer: (rawJson, schemaVersion, generation) async {
          prepareCount += 1;
          return _preparedGeneration(rawJson, schemaVersion, generation);
        },
      ),
      repository: repository,
    );

    await coordinator.bootstrap();
    final generation = repository.activeGenerationFor('tasmania');
    final result = await coordinator.refreshAll();

    expect(prepareCount, 1);
    expect(repository.activeGenerationFor('tasmania'), generation);
    expect(
      (result as RouteGraphImportBatchCompleted).outcomes.single.elementCount,
      3,
    );
  });

  test(
    'returns configuration failure without touching existing coverage state',
    () async {
      final repository = RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifests: [
            RouteGraphManifest(
              routingCoverageKey: 'tasmania',
              activeGeneration: 7,
              readinessState: RouteGraphManifest.readinessReady,
            ),
          ],
        ),
      );
      var imports = 0;
      final coordinator = RouteGraphImportCoordinator(
        coverageResolver: _FailingResolver(),
        importService: RouteGraphImportService(
          repository,
          generationPreparer: (rawJson, schemaVersion, generation) async {
            imports += 1;
            return _preparedGeneration(rawJson, schemaVersion, generation);
          },
        ),
        repository: repository,
      );

      final result = await coordinator.bootstrap();

      expect(result, isA<RouteGraphImportBatchConfigurationFailure>());
      expect(imports, 0);
      expect(repository.activeGenerationFor('tasmania'), 7);
      expect(coordinator.states, isEmpty);
    },
  );
}

class _Resolver extends RouteGraphCoverageResolver {
  _Resolver(this._inputs) : super(assetLoader: (_) async => '{}');

  final List<RouteGraphCoverageImportInput> _inputs;

  @override
  Future<List<RouteGraphCoverageImportInput>> resolve() async => _inputs;
}

class _FailingResolver extends RouteGraphCoverageResolver {
  _FailingResolver() : super(assetLoader: (_) async => '{}');

  @override
  Future<List<RouteGraphCoverageImportInput>> resolve() {
    throw const FormatException('bad manifest');
  }
}

RouteGraphCoverageImportInput _input(String key) {
  return RouteGraphCoverageImportInput(
    definition: RouteGraphCoverageDefinition(
      key: key,
      displayName: key == 'tasmania' ? 'Tasmania' : 'Northeast Alps',
      sourceRegions: const [],
    ),
    sourceHash: 'hash-$key',
    acceptedWayCount: 1,
    mergedOverpass: const {
      'elements': [
        {'type': 'node', 'id': 1, 'lat': -42.0, 'lon': 146.0},
        {'type': 'node', 'id': 2, 'lat': -42.01, 'lon': 146.01},
        {
          'type': 'way',
          'id': 10,
          'nodes': [1, 2],
          'tags': {'highway': 'path'},
        },
      ],
    },
    unavailableFootprint: const [
      RouteGraphFootprintBound(
        minLat: -43,
        minLon: 145,
        maxLat: -41,
        maxLon: 147,
      ),
    ],
  );
}

Map<String, Object?> _preparedGeneration(
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
        'payloadJson': jsonEncode(_input('tasmania').mergedOverpass),
      },
    ],
    'trailDisplayChunks': [
      {
        'recordKey': '$generation|10|0_0',
        'generation': generation,
        'cacheZoom': 10,
        'chunkKey': '0_0',
        'payloadJson': '[]',
      },
    ],
  };
}
