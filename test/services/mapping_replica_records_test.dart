import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/mapping_replica_records.dart'
    show MappingReplicaRecords;

import '../harness/mapping_runtime_fixture.dart';

void main() {
  test(
    'installed v1 compatibility registers release UUIDs without remote checks',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final report = await fixture.read(
        'generations/$runtimeGenerationA/validation.json',
      );
      await fixture.rewriteEvidence(
        runtimeGenerationA,
        report: {...report, 'validatorRelease': runtimeGenerationC},
      );
      final eligibility = {
        ...await fixture.read('eligibility/$runtimeGenerationA.json'),
        'controllerRelease': runtimeGenerationC,
      };
      await fixture.write('eligibility/$runtimeGenerationA.json', eligibility);
      final operation = await fixture.read(
        'operations/$runtimeGenerationA.json',
      );
      await fixture.write('operations/$runtimeGenerationA.json', {
        ...operation,
        'releaseId': runtimeGenerationC,
        'outcomeRecordSha256': runtimeDigest(eligibility),
      });
      final compatibility = {
        'kind': 'mapping-reader-compatibility',
        'schemaVersion': 1,
        'appReaderRelease': 'e442ea38-fc1d-4ca0-b07d-223b01df6c35',
        'profile': 'mapping-runtime-v1',
        'contracts': {
          for (final kind in [
            'mapping-integrity',
            'mapping-source-completion',
            'mapping-publication',
            'mapping-publication-journal',
            'mapping-operation',
            'mapping-durable-receipt',
            'mapping-validation-report',
            'mapping-eligibility',
            'mapping-selection',
            'mapping-selection-transaction',
            'mapping-session',
          ])
            kind: 1,
        },
        'sourceReleases': ['36363ecc-d359-5591-ba2a-a6a7ffff0e60'],
        'controllerReleases': [
          'fb5e6371-026c-5381-8994-eb5d74a17321',
          runtimeGenerationC,
        ],
      };
      await fixture.write('reader-compatibility.json', compatibility);
      expect(
        (await MappingReplicaRecords(
          fixture.base,
        ).eligible(runtimeGenerationA)).generationId,
        runtimeGenerationA,
      );
      await fixture.write('reader-compatibility.json', {
        ...compatibility,
        'profile': 'unsupported',
      });
      await expectLater(
        MappingReplicaRecords(fixture.base).eligible(runtimeGenerationA),
        throwsA(isA<FormatException>()),
      );
    },
  );
  test(
    'versioned records reject missing diagnostic times even with a matching publication witness',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final eligibility = await fixture.read(
        'eligibility/$runtimeGenerationA.json',
      );
      final operation = await fixture.read(
        'operations/$runtimeGenerationA.json',
      );
      for (final time in [null, '2026-99-13T00:00:00Z']) {
        final changed = {...eligibility, 'eligibleAtUtc': time};
        await fixture.write('eligibility/$runtimeGenerationA.json', changed);
        await fixture.write('operations/$runtimeGenerationA.json', {
          ...operation,
          'outcomeRecordSha256': runtimeDigest(changed),
        });
        await expectLater(
          MappingReplicaRecords(fixture.base).eligible(runtimeGenerationA),
          throwsA(isA<FormatException>()),
        );
      }
    },
  );
  test(
    'eligibility cannot authorize a different inventory or incomplete publication',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final reader = MappingReplicaRecords(fixture.base);
      final value = await fixture.read('eligibility/$runtimeGenerationA.json');
      value['inventorySha256'] = 'a' * 64;
      await fixture.write('eligibility/$runtimeGenerationA.json', value);
      await expectLater(
        reader.eligible(runtimeGenerationA),
        throwsA(isA<FormatException>()),
      );
    },
  );
  test(
    'requires the exact passed report, supported releases and durable operation witness',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final reader = MappingReplicaRecords(fixture.base);
      final original = await fixture.read(
        'eligibility/$runtimeGenerationA.json',
      );
      for (final change in <Map<String, Object?>>[
        {'generationId': runtimeGenerationB},
        {'schemaVersion': 2},
        {'unexpected': true},
        {'sourceCompletionSha256': 'a' * 64},
        {'validationReportSha256': 'b' * 64},
        {'controllerRelease': runtimeGenerationC},
        {'validationProfile': 'unsupported'},
        {'eligibleAtUtc': null},
        {'eligibleAtUtc': '2026-99-13T00:00:00Z'},
      ]) {
        await fixture.write('eligibility/$runtimeGenerationA.json', {
          ...original,
          ...change,
        });
        await expectLater(
          reader.eligible(runtimeGenerationA),
          throwsA(isA<FormatException>()),
          reason: '$change',
        );
      }
      await fixture.write('eligibility/$runtimeGenerationA.json', original);
      final operation = await fixture.read(
        'operations/$runtimeGenerationA.json',
      );
      for (final change in <Map<String, Object?>>[
        {'state': 'running'},
        {'generationId': runtimeGenerationB},
        {'outcomeRecordSha256': 'c' * 64},
        {'releaseId': runtimeGenerationC},
        {'owner': <String, Object?>{}},
        {'stage': 'unsupported'},
        {
          'protectedGenerationIds': ['../escape'],
        },
      ]) {
        await fixture.write('operations/$runtimeGenerationA.json', {
          ...operation,
          ...change,
        });
        await expectLater(
          reader.eligible(runtimeGenerationA),
          throwsA(isA<FormatException>()),
          reason: '$change',
        );
      }
      await fixture.write('operations/$runtimeGenerationA.json', operation);
      expect(
        (await reader.eligible(runtimeGenerationA)).paths,
        contains('DEM/Elvis/elvis_runtime_10m.tif'),
      );
    },
  );
  test(
    'rejects duplicate JSON, unsafe inventory and mutable or linked generations',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final reader = MappingReplicaRecords(fixture.base);
      final eligibilityPath = p.join(
        fixture.base,
        'eligibility',
        '$runtimeGenerationA.json',
      );
      final original = await File(eligibilityPath).readAsString();
      await File(
        eligibilityPath,
      ).writeAsString(original.replaceFirst('{', '{"schemaVersion":2,'));
      await expectLater(
        reader.eligible(runtimeGenerationA),
        throwsA(isA<FormatException>()),
      );
      await File(eligibilityPath).writeAsString(original);
      final payload = p.join(
        fixture.base,
        'generations',
        runtimeGenerationA,
        'payload',
      );
      await Process.run('chmod', ['u+w', payload]);
      await expectLater(
        reader.eligible(runtimeGenerationA),
        throwsA(isA<FormatException>()),
      );
      await Process.run('chmod', ['u-w', payload]);
      // A readonly hard link is still not an independent immutable capture.
      await Process.run('ln', [
        p.join(payload, 'region_manifest.json'),
        p.join(fixture.base, 'alias.json'),
      ]);
      await expectLater(
        reader.eligible(runtimeGenerationA),
        throwsA(isA<FormatException>()),
      );
    },
  );
  test(
    'rejects noncanonical inventory and unsupported source/report metadata even when rebound',
    () async {
      final fixture = await MappingRuntimeFixture.create();
      addTearDown(fixture.dispose);
      await fixture.generation(runtimeGenerationA);
      final reader = MappingReplicaRecords(fixture.base);
      final original = await fixture.read(
        'generations/$runtimeGenerationA/integrity.json',
      );
      final files = original['files'] as List;
      for (final changed in <List>[
        files.reversed.toList(),
        [...files, files.first],
        [
          {...(files.first as Map), 'path': '../escaped'},
          ...files.skip(1),
        ],
        [
          {...(files.first as Map), 'size': -1},
          ...files.skip(1),
        ],
        files.where((f) => f['path'] != 'region_manifest.json').toList(),
      ]) {
        await fixture.rewriteEvidence(
          runtimeGenerationA,
          integrity: {...original, 'files': changed},
        );
        await expectLater(
          reader.eligible(runtimeGenerationA),
          throwsA(isA<FormatException>()),
        );
      }
      await fixture.rewriteEvidence(runtimeGenerationA, integrity: original);
      final report = await fixture.read(
        'generations/$runtimeGenerationA/validation.json',
      );
      await fixture.rewriteEvidence(
        runtimeGenerationA,
        report: {...report, 'checks': []},
      );
      await expectLater(
        reader.eligible(runtimeGenerationA),
        throwsA(isA<FormatException>()),
      );
    },
  );
}
