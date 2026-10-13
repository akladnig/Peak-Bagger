import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_runtime_selection.dart';
import 'package:peak_bagger/services/mapping_runtime_io.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';

import '../harness/mapping_runtime_fixture.dart';

void main() {
  test(
    'launch validates, selects and pins a concrete immutable generation',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final session = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(session.close);
      expect(
        session.catalog.rootPath,
        p.join(fixture.base, 'generations', runtimeGenerationA, 'payload'),
      );
      final selection = await fixture.read('selection.json');
      expect(selection['kind'], 'mapping-selection');
      expect(selection['revision'], 1);
      expect((selection['active'] as Map)['generationId'], runtimeGenerationA);
      expect(selection['recovery'], isNull);
      expect(
        (await fixture.read('selection-transaction.json'))['state'],
        'committed',
      );
    },
  );
  test(
    'a rejected newest candidate leaves the existing active generation usable',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final prior = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(prior.close);
      await fixture.generation(
        runtimeGenerationB,
        time: '2026-10-13T01:00:00Z',
      );
      final value = await fixture.read('eligibility/$runtimeGenerationB.json');
      value['validationReportSha256'] = 'a' * 64;
      await fixture.write('eligibility/$runtimeGenerationB.json', value);
      final session = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(session.close);
      expect(session.catalog.rootPath, prior.catalog.rootPath);
      expect((await fixture.read('selection.json'))['revision'], 1);
      expect(session.diagnostics.single, contains(runtimeGenerationB));
    },
  );
  test(
    'candidate preflight failure falls back to active without skipping required DEMs',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final prior = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(prior.close);
      await fixture.generation(
        runtimeGenerationB,
        time: '2026-10-13T01:00:00Z',
      );
      final directory = p.join(
        fixture.base,
        'generations',
        runtimeGenerationB,
        'payload',
        'DEM',
      );
      await Process.run('chmod', ['u+w', directory]);
      await File(p.join(directory, 'cop30_hh.tif')).delete();
      await Process.run('chmod', ['u-w', directory]);
      final session = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(session.close);
      expect(session.catalog.rootPath, prior.catalog.rootPath);
      expect(session.diagnostics.single, contains('DEM/cop30_hh.tif'));
    },
  );
  test(
    'selection publication failure rejects the candidate and pins active',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final prior = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(prior.close);
      final original = await fixture.read('selection.json');
      await fixture.generation(
        runtimeGenerationB,
        time: '2026-10-13T01:00:00Z',
      );
      final io = MappingRuntimeIo();
      final session = await MappingRuntimeSelector(
        fixture.base,
        publish: (relative, value) async {
          if (relative == 'selection.json') {
            throw const FileSystemException(
              'Injected selection publication failure',
            );
          }
          await io.publishState(fixture.base, relative, value);
        },
      ).launch();
      addTearDown(session.close);
      expect(session.catalog.rootPath, prior.catalog.rootPath);
      expect(await fixture.read('selection.json'), original);
      expect(session.diagnostics.single, contains('publication failure'));
    },
  );
  test(
    'active readiness failure selects the retained recovery after a complete update',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final old = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(old.close);
      await fixture.generation(
        runtimeGenerationB,
        time: '2026-10-13T01:00:00Z',
      );
      final newer = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(newer.close);
      expect(newer.catalog.rootPath, contains(runtimeGenerationB));
      final selected = await fixture.read('selection.json');
      expect((selected['recovery'] as Map)['generationId'], runtimeGenerationA);
      final polygon = File(
        p.join(newer.catalog.rootPath, 'Polygons', 'tasmania.poly'),
      );
      await Process.run('chmod', ['u+w', polygon.path]);
      await polygon.writeAsString('invalid polygon');
      await Process.run('chmod', ['u-w', polygon.path]);
      final recovered = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(recovered.close);
      expect(recovered.catalog.rootPath, old.catalog.rootPath);
      expect(recovered.diagnostics.single, contains(runtimeGenerationB));
    },
  );
  test(
    'launch holds cleanup coordination through readiness and session publication',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final entered = Completer<void>();
      final proceed = Completer<void>();
      final first = MappingRuntimeSelector(
        fixture.base,
        loadCatalog: (root) async {
          entered.complete();
          await proceed.future;
          final store = MappingDataStore(rootPath: root);
          return store.loadCatalogFromPreflight(await store.preflight());
        },
      ).launch();
      await entered.future;
      final io = MappingRuntimeIo();
      await expectLater(
        io.lock(
          p.join(fixture.base, 'locks', 'selection-retention.lock'),
          wait: Duration.zero,
        ),
        throwsA(isA<FileSystemException>()),
      );
      final second = MappingRuntimeSelector(fixture.base).launch();
      proceed.complete();
      final sessions = await Future.wait([first, second]);
      for (final session in sessions) {
        addTearDown(session.close);
      }
      expect(sessions[0].catalog.rootPath, sessions[1].catalog.rootPath);
      expect((await fixture.read('selection.json'))['revision'], 1);
      for (final file in await Directory(
        p.join(fixture.base, 'sessions'),
      ).list().toList()) {
        final id = p.basenameWithoutExtension(file.path);
        await expectLater(
          io.lock(
            p.join(fixture.base, 'locks', 'session-$id.lock'),
            wait: Duration.zero,
          ),
          throwsA(isA<FileSystemException>()),
        );
      }
    },
  );
  test(
    'failure after atomic replacement restores old selection and restart recovers prepared intent',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final prior = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(prior.close);
      final original = await fixture.read('selection.json');
      await fixture.generation(
        runtimeGenerationB,
        time: '2026-10-13T01:00:00Z',
      );
      final io = MappingRuntimeIo();
      final fallback = await MappingRuntimeSelector(
        fixture.base,
        publish: (relative, value) async {
          if (relative == 'selection-transaction.json' &&
              (value as Map)['state'] == 'committed') {
            throw const FileSystemException('Interrupted commit witness');
          }
          await io.publishState(fixture.base, relative, value);
        },
      ).launch();
      addTearDown(fallback.close);
      expect(fallback.catalog.rootPath, prior.catalog.rootPath);
      expect(await fixture.read('selection.json'), original);
      // Interrupted metadata is never merged field by field. Recover from the
      // complete journal and apply the same launch validation sequence.
      await File(
        p.join(fixture.base, 'selection.json'),
      ).writeAsString('{"active":');
      final restarted = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(restarted.close);
      expect(restarted.catalog.rootPath, contains(runtimeGenerationB));
      expect((await fixture.read('selection.json'))['revision'], 2);
    },
  );
  test(
    'manifest-derived catalog must bind the exact eligibility path set before selection',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final selector = MappingRuntimeSelector(
        fixture.base,
        loadCatalog: (root) async {
          final catalog = await loadRuntimeCatalog(root);
          return MappingCatalog(
            rootPath: root,
            regions: catalog.regions,
            basemaps: catalog.basemaps,
            tasmapCatalogPath: catalog.tasmapCatalogPath,
            naturalFeaturesCatalogPath: catalog.naturalFeaturesCatalogPath,
            demSources: const {},
            routingCoverageRegionKeys: catalog.routingCoverageRegionKeys,
            polygonDisplayPaths: catalog.polygonDisplayPaths,
          );
        },
      );
      await expectLater(
        selector.launch(),
        throwsA(isA<MappingRuntimeUnavailable>()),
      );
      expect(
        await File(p.join(fixture.base, 'selection.json')).exists(),
        isFalse,
      );
    },
  );
  test(
    'native ownership retains a session lock after session close until final handle release',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final session = await MappingRuntimeSelector(fixture.base).launch();
      final releaseHandle = session.catalog.sessionProtection!.retainNative();
      final file = (await Directory(
        p.join(fixture.base, 'sessions'),
      ).list().toList()).single;
      final id = p.basenameWithoutExtension(file.path);
      final metadata = await fixture.read('sessions/$id.json');
      expect((metadata['owner'] as Map)['pid'], pid);
      final lockPath = p.join(fixture.base, 'locks', 'session-$id.lock');
      session.close();
      final io = MappingRuntimeIo();
      await expectLater(
        io.lock(lockPath, wait: Duration.zero),
        throwsA(isA<FileSystemException>()),
      );
      releaseHandle();
      (await io.lock(lockPath, wait: Duration.zero)).close();
    },
  );
  test(
    'superseded eligible generations are not reactivated as new pending updates',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      for (final entry in {
        runtimeGenerationA: '00',
        runtimeGenerationB: '01',
        runtimeGenerationC: '02',
      }.entries) {
        await fixture.generation(
          entry.key,
          time: '2026-10-13T${entry.value}:00:00Z',
        );
        final session = await MappingRuntimeSelector(fixture.base).launch();
        addTearDown(session.close);
      }
      final session = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(session.close);
      expect(session.catalog.rootPath, contains(runtimeGenerationC));
      expect((await fixture.read('selection.json'))['revision'], 3);
    },
  );
}
