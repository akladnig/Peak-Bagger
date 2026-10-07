import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/route_graph_coverage_resolver.dart';
import 'package:peak_bagger/services/route_graph_import_coordinator.dart';
import 'package:peak_bagger/services/route_graph_import_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';

import '../harness/mapping_coverage_fixture.dart';
import '../harness/route_graph_mapping_harness.dart';

void main() {
  test(
    'coverage reads are independent, duplicate requests share one execution, failed refresh retains usable state',
    () async {
      final access = _HeldCoverageAccess();
      final operations = MappingStoreOperationCoordinator();
      final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
      final coordinator = RouteGraphImportCoordinator(
        coverageResolver: RouteGraphCoverageResolver(
          catalog: mappingCoverageCatalog,
          fileAccess: access,
        ),
        importService: RouteGraphImportService(
          repository,
          generationPreparer: preparedCoverageFixture,
        ),
        repository: repository,
        mappingOperationCoordinator: operations,
      );
      addTearDown(coordinator.dispose);
      addTearDown(operations.dispose);
      final first = coordinator.ensureCoverage('tasmania');
      final duplicate = coordinator.ensureCoverage('tasmania');
      final other = coordinator.ensureCoverage('northeast-alps');
      await Future<void>.delayed(Duration.zero);
      expect(access.started, [
        'Highways/tasmania.json',
        'Highways/northeast-alps.json',
      ]);
      access.hold.complete();
      await Future.wait([first, duplicate, other]);
      expect(repository.hasUsableActiveGenerationFor('tasmania'), isTrue);
      expect(repository.hasUsableActiveGenerationFor('northeast-alps'), isTrue);
      final generation = repository.activeGenerationFor('tasmania');
      access.sources['Highways/tasmania.json'] = '{"elements":[]}';
      await coordinator.refreshAll();
      expect(repository.activeGenerationFor('tasmania'), generation);
      expect(repository.hasUsableActiveGenerationFor('tasmania'), isTrue);
      expect(repository.hasUsableActiveGenerationFor('northeast-alps'), isTrue);
      expect(
        operations.failureFor(
          MappingStoreOperationKey.routeGraphRefresh('tasmania'),
        ),
        isNotNull,
      );
    },
  );
  test('mismatched coverage is rejected without a write', () async {
    final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
    await expectLater(
      repository.writePreparedGeneration(
        RouteGraphPreparedGeneration(
          generation: 1,
          sourceHash: 'hash',
          schemaVersion: 'v5',
          importedAt: DateTime.utc(2026),
          chunkCount: 1,
          nodeCount: 2,
          edgeCount: 1,
          chunks: [
            RouteGraphChunk(
              recordKey: 'other|1|a',
              chunkKey: 'a',
              routingCoverageKey: 'other',
              generation: 1,
              minLat: -43,
              minLon: 145,
              maxLat: -41,
              maxLon: 147,
              elementCount: 3,
              payloadJson: '{}',
            ),
          ],
          wayIndexRows: const [],
        ),
        routingCoverageKey: 'tasmania',
        pruneStaleGenerations: true,
      ),
      throwsStateError,
    );
    expect(repository.manifests, isEmpty);
  });

  test(
    'a malformed selected highway tag is a typed failure before writes',
    () async {
      final access = MappingCoverageFileAccess()
        ..sources['Highways/tasmania.json'] =
            '{"elements":[{"type":"way","id":10,"nodes":[1,2],"tags":{"highway":123}}]}';
      final operations = MappingStoreOperationCoordinator();
      final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
      final coordinator = RouteGraphImportCoordinator(
        coverageResolver: RouteGraphCoverageResolver(
          catalog: mappingCoverageCatalog,
          fileAccess: access,
        ),
        importService: RouteGraphImportService(repository),
        repository: repository,
        mappingOperationCoordinator: operations,
      );
      addTearDown(coordinator.dispose);
      addTearDown(operations.dispose);
      await expectLater(
        coordinator.ensureCoverage('tasmania'),
        throwsA(isA<MappingStoreOperationException>()),
      );
      expect(repository.manifests, isEmpty);
    },
  );

  test('an empty ready generation is unusable', () {
    final repository = RouteGraphRepository.test(
      InMemoryRouteGraphStorage(
        manifest: RouteGraphManifest(
          id: 1,
          routingCoverageKey: 'tasmania',
          activeGeneration: 1,
          readinessState: RouteGraphManifest.readinessReady,
        ),
      ),
    );
    expect(repository.hasUsableActiveGenerationFor('tasmania'), isFalse);
  });

  test(
    'catalog bootstrap isolates malformed sources and retry state',
    () async {
      final access = MappingCoverageFileAccess()
        ..sources['Highways/northeast-alps.json'] = '{}';
      final operations = MappingStoreOperationCoordinator();
      final repository = RouteGraphRepository.test(InMemoryRouteGraphStorage());
      final coordinator = RouteGraphImportCoordinator(
        coverageResolver: RouteGraphCoverageResolver(
          catalog: mappingCoverageCatalog,
          fileAccess: access,
        ),
        importService: RouteGraphImportService(repository),
        repository: repository,
        mappingOperationCoordinator: operations,
      );
      addTearDown(coordinator.dispose);
      addTearDown(operations.dispose);
      await coordinator.bootstrap();
      expect(repository.hasUsableActiveGenerationFor('tasmania'), isTrue);
      final key = MappingStoreOperationKey.routeGraphBootstrap(
        'northeast-alps',
      );
      expect(operations.failureFor(key)?.paths, [
        'Highways/northeast-alps.json',
      ]);
      access.sources.clear();
      await operations.retry(key);
      expect(
        coordinator.stateFor('northeast-alps')!.status,
        RouteGraphCoverageImportStatus.ready,
      );
      access.reads.clear();
      await coordinator.bootstrap();
      expect(access.reads, isEmpty);
      repository.manifestForCoverage('tasmania')!.nodeCount = 999;
      expect(repository.hasUsableActiveGenerationFor('tasmania'), isFalse);
    },
  );
}

class _HeldCoverageAccess extends MappingCoverageFileAccess {
  final hold = Completer<void>();
  final started = <String>[];
  @override
  Future<String> readText(String relativePath) async {
    started.add(relativePath);
    await hold.future;
    return super.readText(relativePath);
  }
}
