import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_runtime_selection.dart';

import '../harness/mapping_runtime_fixture.dart';

Future<void> captured(
  MappingRuntimeFixture fixture,
  String id,
  String time,
) async {
  await fixture.generation(id, time: time);
  final eligibility = await fixture.read('eligibility/$id.json');
  final receipt = runtimeRecord('mapping-durable-receipt', {
    'receiptId': id,
    'operationId': id,
    'generationId': id,
    'inventorySha256': eligibility['inventorySha256'],
    'sourceCompletionSha256': eligibility['sourceCompletionSha256'],
    'localValidationReportSha256': eligibility['validationReportSha256'],
    'controllerRelease': runtimeControllerRelease,
    'storedAtUtc': time,
  });
  await fixture.write('receipts/$id.json', receipt);
  await fixture.write('acknowledgements/$id.json', receipt);
}

Future<ProcessResult> cleanup(String base) => Process.run('python3', [
  'tool/mapping_replica.py',
  '--base',
  base,
  '--lock-wait',
  '0',
  'cleanup',
]);

void main() {
  test(
    'overlapping app launches exclude cleanup until their selected roots are pinned',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await captured(fixture, runtimeGenerationA, '2026-10-13T00:00:00Z');
      final entered = Completer<void>();
      final proceed = Completer<void>();
      final first = MappingRuntimeSelector(
        fixture.base,
        loadCatalog: (root) async {
          entered.complete();
          await proceed.future;
          return loadRuntimeCatalog(root);
        },
      ).launch();
      await entered.future;
      final second = MappingRuntimeSelector(fixture.base).launch();
      final blocked = await cleanup(fixture.base);
      expect(blocked.exitCode, isNot(0));
      expect(blocked.stderr, contains('selection-retention.lock'));
      proceed.complete();
      final sessions = await Future.wait([first, second]);
      for (final session in sessions) {
        addTearDown(session.close);
      }
      final cleaned = await cleanup(fixture.base);
      expect(cleaned.exitCode, 0, reason: '${cleaned.stderr}');
      for (final session in sessions) {
        expect(session.catalog.rootPath, contains(runtimeGenerationA));
        expect(
          await File(
            p.join(session.catalog.rootPath, 'region_manifest.json'),
          ).exists(),
          isTrue,
        );
      }
    },
  );
  test(
    'controller cleanup preserves a closed UI session while native ownership remains',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await captured(fixture, runtimeGenerationA, '2026-10-13T00:00:00Z');
      final old = await MappingRuntimeSelector(fixture.base).launch();
      addTearDown(old.close);
      final releaseNative = old.catalog.sessionProtection!.retainNative();
      addTearDown(releaseNative);
      final path = p.join(old.catalog.rootPath, 'Polygons', 'tasmania.poly');
      final original = await File(path).readAsString();
      old.close();
      for (final entry in {
        runtimeGenerationB: '01',
        runtimeGenerationC: '02',
      }.entries) {
        await captured(fixture, entry.key, '2026-10-13T00:${entry.value}:00Z');
        final next = await MappingRuntimeSelector(fixture.base).launch();
        next.close();
      }
      final retained = await cleanup(fixture.base);
      expect(retained.exitCode, 0, reason: '${retained.stderr}');
      final result = jsonDecode(retained.stdout as String) as Map;
      expect(
        (result['protectedGenerations'] as Map)[runtimeGenerationA],
        isNotNull,
      );
      expect(await File(path).readAsString(), original);
      expect(old.catalog.rootPath, contains(runtimeGenerationA));
      releaseNative();
      final pruned = await cleanup(fixture.base);
      expect(pruned.exitCode, 0, reason: '${pruned.stderr}');
      expect(
        (jsonDecode(pruned.stdout as String) as Map)['prunedGenerations'],
        [runtimeGenerationA],
      );
      expect(await File(path).exists(), isFalse);
      expect(
        await Directory(
          p.join(fixture.base, 'generations', runtimeGenerationB),
        ).exists(),
        isTrue,
      );
      expect(
        await Directory(
          p.join(fixture.base, 'generations', runtimeGenerationC),
        ).exists(),
        isTrue,
      );
    },
  );
}
