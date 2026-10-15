import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'mapping_source_fixture.dart';

const runtimeSourceRelease = '36363ecc-d359-5591-ba2a-a6a7ffff0e60';
const runtimeControllerRelease = 'fb5e6371-026c-5381-8994-eb5d74a17321';
const runtimeGenerationA = '00000000-0000-4000-8000-000000000001';
const runtimeGenerationB = '00000000-0000-4000-8000-000000000002';
const runtimeGenerationC = '00000000-0000-4000-8000-000000000003';
const runtimeTime = '2026-10-13T00:00:00Z';

Map<String, Object?> runtimeRecord(String kind, Map<String, Object?> fields) =>
    {'kind': kind, 'schemaVersion': 1, ...fields};
String runtimeDigest(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

/// Tiny preflight-valid payload with fake background profile evidence. The real
/// Python/Dart/GDAL matrix is exercised by mapping_replica_capture_test.
class MappingRuntimeFixture {
  MappingRuntimeFixture._(this.directory);
  final Directory directory;
  String get base => directory.path;

  static Future<MappingRuntimeFixture> create() async {
    final directory = await Directory.systemTemp.createTemp('mapping-runtime-');
    return MappingRuntimeFixture._(
      Directory(await directory.resolveSymbolicLinks()),
    );
  }

  Future<void> write(String relative, Object value) async {
    final file = File(p.join(base, relative));
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(value));
  }

  Future<Map<String, Object?>> read(String relative) async =>
      (jsonDecode(await File(p.join(base, relative)).readAsString()) as Map)
          .cast<String, Object?>();

  Future<void> generation(String id, {String time = runtimeTime}) async {
    final source = await createMappingSourceFixture();
    await File(p.join(source.path, 'Polygons', 'tasmania.poly')).writeAsString(
      'Tasmania\n1\n144 -44\n149 -44\n149 -40\n144 -40\nEND\nEND\n',
    );
    final finalPath = p.join(base, 'generations', id);
    final paths = <String>[];
    for (final entity in await source.list(recursive: true).toList()) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: source.path);
      paths.add(relative);
      final target = File(p.join(finalPath, 'payload', relative));
      await target.parent.create(recursive: true);
      await entity.copy(target.path);
    }
    paths.sort();
    final integrity = runtimeRecord('mapping-integrity', {
      'generationId': id,
      'files': [
        for (final path in paths)
          {
            'path': path,
            'size': await File(p.join(source.path, path)).length(),
            'sha256': sha256
                .convert(await File(p.join(source.path, path)).readAsBytes())
                .toString(),
          },
      ],
    });
    await source.delete(recursive: true);
    final inventorySha = runtimeDigest(integrity);
    final completion = runtimeRecord('mapping-source-completion', {
      'generationId': id,
      'inventorySha256': inventorySha,
      'operationId': id,
      'publicationId': id,
      'sourcePreparerRelease': runtimeSourceRelease,
      'validationProfile': 'mapping-runtime-v1',
      'validatedAtUtc': time,
    });
    final report = runtimeRecord('mapping-validation-report', {
      'generationId': id,
      'inventorySha256': inventorySha,
      'operationId': id,
      'validationProfile': 'mapping-runtime-v1',
      'validatorRelease': runtimeControllerRelease,
      'state': 'passed',
      'checks': [
        for (final path in paths)
          {'path': path, 'checkId': 'sha256-v1', 'result': 'passed'},
        {
          'path': 'region_manifest.json',
          'checkId': 'manifest-paths-v1',
          'result': 'passed',
        },
        {
          'path': 'Polygons/manifest.json',
          'checkId': 'manifest-paths-v1',
          'result': 'passed',
        },
        {
          'path': 'region_manifest.json',
          'checkId': 'peak-fingerprints-v1',
          'result': 'passed',
        },
      ],
      'diagnostics': <String>[],
      'validatedAtUtc': time,
    });
    final eligibility = runtimeRecord('mapping-eligibility', {
      'generationId': id,
      'inventorySha256': inventorySha,
      'sourceCompletionSha256': runtimeDigest(completion),
      'validationReportSha256': runtimeDigest(report),
      'controllerRelease': runtimeControllerRelease,
      'validationProfile': 'mapping-runtime-v1',
      'eligibleAtUtc': time,
    });
    await write('generations/$id/integrity.json', integrity);
    await write('generations/$id/completion.json', completion);
    await write('generations/$id/validation.json', report);
    await write('eligibility/$id.json', eligibility);
    await write(
      'operations/$id.json',
      runtimeRecord('mapping-operation', {
        'operationId': id,
        'parentOperationId': null,
        'owner': {
          'hostId': 'fixture',
          'bootId': id,
          'pid': 1,
          'processStartId': id,
          'ownershipToken': id,
        },
        'releaseId': runtimeControllerRelease,
        'stage': 'receipt',
        'state': 'succeeded',
        'generationId': id,
        'publicationId': id,
        'protectedExportIds': [id],
        'protectedGenerationIds': [id],
        'startedAtUtc': time,
        'progressAtUtc': time,
        'outcomeRecordSha256': runtimeDigest(eligibility),
      }),
    );
    final result = await Process.run('python3', [
      '-c',
      'import os,sys; from pathlib import Path; '
          '[(Path(root)/name).chmod(0o444) for root, _, files in os.walk(sys.argv[1]) for name in files]; '
          '[Path(root).chmod(0o555) for root, _, _ in os.walk(sys.argv[1])]',
      finalPath,
    ]);
    if (result.exitCode != 0) throw StateError('${result.stderr}');
  }

  Future<void> dispose() async {
    await Process.run('python3', [
      '-c',
      'import os,sys; from pathlib import Path; '
          '[Path(root).chmod(0o755) for root, _, _ in os.walk(sys.argv[1])]',
      base,
    ]);
    await directory.delete(recursive: true);
  }

  Future<void> rewriteEvidence(
    String id, {
    Map<String, Object?>? integrity,
    Map<String, Object?>? completion,
    Map<String, Object?>? report,
  }) async {
    final folder = 'generations/$id';
    integrity ??= await read('$folder/integrity.json');
    completion ??= await read('$folder/completion.json');
    report ??= await read('$folder/validation.json');
    completion['inventorySha256'] = runtimeDigest(integrity);
    report['inventorySha256'] = runtimeDigest(integrity);
    for (final entry in {
      'integrity': integrity,
      'completion': completion,
      'validation': report,
    }.entries) {
      final path = p.join(base, folder, '${entry.key}.json');
      await Process.run('chmod', ['u+w', path]);
      await write('$folder/${entry.key}.json', entry.value);
      await Process.run('chmod', ['u-w', path]);
    }
    final eligibility = await read('eligibility/$id.json');
    eligibility['inventorySha256'] = runtimeDigest(integrity);
    eligibility['sourceCompletionSha256'] = runtimeDigest(completion);
    eligibility['validationReportSha256'] = runtimeDigest(report);
    await write('eligibility/$id.json', eligibility);
    final operation = await read('operations/$id.json');
    operation['outcomeRecordSha256'] = runtimeDigest(eligibility);
    await write('operations/$id.json', operation);
  }
}
