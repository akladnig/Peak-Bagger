import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/mapping_runtime_startup.dart';
import 'package:peak_bagger/startup_shell.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';

import '../harness/mapping_runtime_fixture.dart';
import '../harness/mapping_catalog_fixture.dart';

void main() {
  test(
    'failed initial validation reports the local stage instead of unfinished synchronization',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      await File(
        '${fixture.base}/eligibility/$runtimeGenerationA.json',
      ).delete();
      final operation = await fixture.read(
        'operations/$runtimeGenerationA.json',
      );
      await fixture.write('operation.json', {
        ...operation,
        'state': 'failed',
        'stage': 'validate',
      });
      await fixture.write('mapping-runtime.json', {
        'schemaVersion': 1,
        'mode': 'replica',
        'replicaBase': fixture.base,
      });
      final runtime = MappingRuntimeLauncher(
        supportDirectory: () async => fixture.base,
      );
      final coordinator = MappingStoreStartupCoordinator(
        isMacOS: true,
        prepareCatalog: runtime.launch,
        initialize: (_) async => fail('No eligible generation'),
      );
      final result = await coordinator.start();
      expect(result.diagnostic, isNot(contains('Initial synchronization')));
      expect(result.pathFailures.join('\n'), contains('stage=validate'));
      expect(
        result.pathFailures.join('\n'),
        contains('${fixture.base}/operation.json'),
      );
    },
  );
  test(
    'active replica ignores unavailable remote services and initialization failure never rolls back Mapping',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      await fixture.write('mapping-runtime.json', {
        'schemaVersion': 1,
        'mode': 'replica',
        'replicaBase': fixture.base,
      });
      final runtime = MappingRuntimeLauncher(
        supportDirectory: () async => fixture.base,
        isLocal: (path) async {
          if (path.startsWith('/Volumes/') || path.contains('incoming')) {
            fail('Remote/transport readiness must never be queried');
          }
          return true;
        },
      );
      addTearDown(runtime.close);
      var initialization = 0;
      final coordinator = MappingStoreStartupCoordinator(
        isMacOS: true,
        prepareCatalog: runtime.launch,
        initialize: (_) async {
          initialization++;
          throw StateError('ObjectBox failed');
        },
      );
      expect(
        (await coordinator.start()).state,
        StartupState.initializationFailed,
      );
      final selection = await fixture.read('selection.json');
      await fixture.generation(
        runtimeGenerationB,
        time: '2026-10-13T01:00:00Z',
      );
      expect(
        (await coordinator.retry()).state,
        StartupState.initializationFailed,
      );
      expect(await fixture.read('selection.json'), selection);
      expect(initialization, 1);
    },
  );
  test(
    'canonical selection reads only an attached store and rejects SMB before readiness',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.write('mapping-runtime.json', {
        'schemaVersion': 1,
        'mode': 'canonical',
        'canonicalRoot': mappingStoreRootPath,
      });
      var reads = 0;
      var attached = false;
      final runtime = MappingRuntimeLauncher(
        supportDirectory: () async => fixture.base,
        isLocal: (path) async => path != mappingStoreRootPath || attached,
        loadCatalog: (root) async {
          expect(root, mappingStoreRootPath);
          reads++;
          throw MappingStoreFailure(['Polygons/tasmania.poly']);
        },
      );
      final coordinator = MappingStoreStartupCoordinator(
        isMacOS: true,
        prepareCatalog: runtime.launch,
        initialize: (_) async =>
            fail('Cannot initialize an unavailable canonical store'),
      );
      final denied = await coordinator.start();
      expect(denied.state, StartupState.unavailable);
      expect(denied.rootPath, '${fixture.base}/mapping-runtime.json');
      expect(denied.diagnostic, contains('SMB'));
      expect(reads, 0);
      attached = true;
      final failed = await coordinator.retry();
      expect(failed.isReplica, isFalse);
      expect(failed.rootPath, mappingStoreRootPath);
      expect(reads, 1);
    },
  );
  test(
    'missing local replica withholds ready dependencies and rereads configuration on retry',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.write('mapping-runtime.json', {
        'schemaVersion': 1,
        'mode': 'replica',
        'replicaBase': '${fixture.base}/replica',
      });
      final runtime = MappingRuntimeLauncher(
        supportDirectory: () async => fixture.base,
      );
      addTearDown(runtime.close);
      var initialized = 0;
      final coordinator = MappingStoreStartupCoordinator(
        isMacOS: true,
        prepareCatalog: runtime.launch,
        initialize: (_) async {
          initialized++;
        },
      );
      final unavailable = await coordinator.start();
      expect(unavailable.state, StartupState.unavailable);
      expect(unavailable.isReplica, isTrue);
      expect(unavailable.rootPath, '${fixture.base}/replica');
      expect(unavailable.diagnostic, contains('Initial synchronization'));
      expect(initialized, 0);
      // Retry rereads configuration and activates the newly validated fixture.
      await fixture.generation(runtimeGenerationA);
      await fixture.write('mapping-runtime.json', {
        'schemaVersion': 1,
        'mode': 'replica',
        'replicaBase': fixture.base,
      });
      final ready = await coordinator.retry();
      expect(ready.state, StartupState.ready);
      expect(ready.catalog!.rootPath, contains(runtimeGenerationA));
      expect(initialized, 1);
      expect(
        await File('${fixture.base}/replica/selection.json').exists(),
        isFalse,
      );
    },
  );
  test(
    'concurrent startup/retry shares one attempt and ready initialization is terminal',
    () async {
      final pending = Completer<MappingCatalog>();
      var reads = 0;
      var initialization = 0;
      final coordinator = MappingStoreStartupCoordinator(
        isMacOS: true,
        prepareCatalog: () {
          reads++;
          return pending.future;
        },
        initialize: (_) async {
          initialization++;
        },
      );
      final first = coordinator.start();
      final duplicate = coordinator.retry();
      expect(reads, 1);
      expect(initialization, 0);
      pending.complete(testMappingCatalog);
      expect((await first).state, StartupState.ready);
      expect((await duplicate).state, StartupState.ready);
      await coordinator.retry();
      expect(reads, 1);
      expect(initialization, 1);
    },
  );
}
