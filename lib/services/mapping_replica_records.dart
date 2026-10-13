import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'mapping_runtime_io.dart';

class MappingReplicaGeneration {
  const MappingReplicaGeneration({
    required this.rootPath,
    required this.entry,
    required this.paths,
  });
  final String rootPath;
  final Map<String, Object?> entry;
  final Set<String> paths;
  String get generationId => entry['generationId'] as String;
  String get inventorySha256 => entry['inventorySha256'] as String;
}

class MappingReplicaRecords {
  MappingReplicaRecords(
    this.base, {
    this.sourceReleases = const {'36363ecc-d359-5591-ba2a-a6a7ffff0e60'},
    this.controllerReleases = const {'fb5e6371-026c-5381-8994-eb5d74a17321'},
  });
  final String base;
  final Set<String> sourceReleases;
  final Set<String> controllerReleases;

  Future<MappingReplicaGeneration> eligible(String generation) async {
    requireRuntimeUuid(generation);
    final io = MappingRuntimeIo();
    final eligibility = await io.readMetadata(
      p.join(base, 'eligibility', '$generation.json'),
    );
    final bytes = eligibility.bytes;
    final value = runtimeRecord(
      eligibility.value,
      'mapping-eligibility',
      'generationId inventorySha256 sourceCompletionSha256 validationReportSha256 controllerRelease validationProfile eligibleAtUtc',
    );
    final finalPath = p.join(base, 'generations', generation);
    final inventory = runtimeRecord(
      (await io.readMetadata(p.join(finalPath, 'integrity.json'))).value,
      'mapping-integrity',
      'generationId files',
    );
    final paths = validateRuntimeInventory(inventory);
    final completionMetadata = await io.readMetadata(
      p.join(finalPath, 'completion.json'),
    );
    final reportMetadata = await io.readMetadata(
      p.join(finalPath, 'validation.json'),
    );
    final completionBytes = completionMetadata.bytes;
    final reportBytes = reportMetadata.bytes;
    final completion = runtimeRecord(
      completionMetadata.value,
      'mapping-source-completion',
      'generationId inventorySha256 operationId publicationId sourcePreparerRelease validationProfile validatedAtUtc',
    );
    final report = runtimeRecord(
      reportMetadata.value,
      'mapping-validation-report',
      'generationId inventorySha256 operationId validationProfile validatorRelease state checks diagnostics validatedAtUtc',
    );
    if (value['generationId'] != generation ||
        inventory['generationId'] != generation ||
        completion['generationId'] != generation ||
        report['generationId'] != generation ||
        value['inventorySha256'] != runtimeDigest(inventory) ||
        completion['inventorySha256'] != value['inventorySha256'] ||
        report['inventorySha256'] != value['inventorySha256']) {
      throw const FormatException('Eligibility inventory identity mismatch');
    }
    if (value['sourceCompletionSha256'] !=
            sha256.convert(completionBytes).toString() ||
        value['validationReportSha256'] !=
            sha256.convert(reportBytes).toString() ||
        report['state'] != 'passed' ||
        !sourceReleases.contains(completion['sourcePreparerRelease']) ||
        !controllerReleases.contains(value['controllerRelease']) ||
        !controllerReleases.contains(report['validatorRelease']) ||
        [
          value,
          completion,
          report,
        ].any((r) => r['validationProfile'] != 'mapping-runtime-v1')) {
      throw const FormatException(
        'Unsupported or mismatched eligibility/completion/validation evidence',
      );
    }
    validateRuntimeChecks(report, paths);
    final operation = runtimeRecord(
      (await io.readMetadata(
        p.join(base, 'operations', '${report['operationId']}.json'),
      )).value,
      'mapping-operation',
      'operationId parentOperationId owner releaseId stage state generationId publicationId protectedExportIds protectedGenerationIds startedAtUtc progressAtUtc outcomeRecordSha256',
    );
    if (operation['operationId'] != report['operationId'] ||
        operation['releaseId'] != report['validatorRelease'] ||
        operation['state'] != 'succeeded' ||
        operation['generationId'] != generation ||
        operation['outcomeRecordSha256'] != runtimeDigest(value)) {
      throw const FormatException(
        'No successful durable publication outcome for eligibility',
      );
    }
    await io.requireImmutable(finalPath);
    return MappingReplicaGeneration(
      rootPath: p.join(base, 'generations', generation, 'payload'),
      entry: {
        'generationId': generation,
        'inventorySha256': value['inventorySha256'],
        'eligibilitySha256': sha256.convert(bytes).toString(),
      },
      paths: paths,
    );
  }
}

Set<String> validateRuntimeInventory(Map<String, Object?> inventory) {
  if (inventory.keys.join(' ') != 'kind schemaVersion generationId files' ||
      inventory['files'] is! List) {
    throw const FormatException('Noncanonical integrity object');
  }
  final paths = <String>{};
  String? prior;
  for (final value in inventory['files'] as List) {
    if (value is! Map ||
        value.keys.join(' ') != 'path size sha256' ||
        value['path'] is! String ||
        value['size'] is! int ||
        (value['size'] as int) < 0 ||
        value['sha256'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(value['sha256'] as String)) {
      throw const FormatException('Invalid integrity entry');
    }
    final path = value['path'] as String;
    if (path.startsWith('/') ||
        path.contains(RegExp(r'[\\:\x00]')) ||
        path.split('/').any((part) => {'', '.', '..'}.contains(part)) ||
        prior != null && prior.compareTo(path) >= 0) {
      throw const FormatException('Unsafe/unordered/duplicate integrity path');
    }
    paths.add(path);
    prior = path;
  }
  if (!paths.containsAll({'region_manifest.json', 'Polygons/manifest.json'})) {
    throw const FormatException('Integrity omitted manifest pair');
  }
  return Set.unmodifiable(paths);
}

void validateRuntimeChecks(Map<String, Object?> report, Set<String> paths) {
  if (report['checks'] is! List ||
      report['diagnostics'] is! List ||
      (report['diagnostics'] as List).any((v) => v is! String)) {
    throw const FormatException('Invalid validation checks/diagnostics');
  }
  final passed = <String>{};
  for (final check in report['checks'] as List) {
    if (check is! Map ||
        check.length != 3 ||
        !check.keys.toSet().containsAll({'path', 'checkId', 'result'}) ||
        check['path'] is! String ||
        check['checkId'] is! String ||
        check['result'] != 'passed' ||
        !paths.contains(check['path'])) {
      throw const FormatException('Invalid/failed/skipped validation check');
    }
    passed.add('${check['path']}:${check['checkId']}');
  }
  if (!passed.containsAll({
    'region_manifest.json:manifest-paths-v1',
    'Polygons/manifest.json:manifest-paths-v1',
    'region_manifest.json:peak-fingerprints-v1',
    for (final path in paths) '$path:sha256-v1',
  })) {
    throw const FormatException('Omitted required validation checks');
  }
}

String runtimeDigest(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

void requireRuntimeUuid(Object? value) {
  if (value is! String ||
      !RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      ).hasMatch(value)) {
    throw const FormatException('Expected lowercase UUID');
  }
}

Map<String, Object?> runtimeRecord(Object? value, String kind, String fields) {
  final keys = {'kind', 'schemaVersion', ...fields.split(' ')};
  if (value is! Map<String, dynamic> ||
      value['kind'] != kind ||
      value['schemaVersion'] is! int ||
      value['schemaVersion'] != 1 ||
      value.length != keys.length ||
      !keys.every(value.containsKey)) {
    throw FormatException('Unsupported $kind metadata kind/version/fields');
  }
  for (final entry in value.entries) {
    if (entry.value == null) {
      final nullable = switch (kind) {
        'mapping-operation' => {
          'parentOperationId',
          'publicationId',
          'generationId',
          'outcomeRecordSha256',
        },
        'mapping-selection' => {'recovery'},
        'mapping-selection-transaction' => {'priorSelection'},
        _ => <String>{},
      };
      if (!nullable.contains(entry.key)) {
        throw FormatException('Missing required $kind field: ${entry.key}');
      }
      continue;
    }
    if (entry.key == 'owner') {
      final owner = entry.value;
      if (owner is! Map ||
          owner.length != 5 ||
          !owner.keys.toSet().containsAll({
            'hostId',
            'bootId',
            'pid',
            'processStartId',
            'ownershipToken',
          }) ||
          owner['pid'] is! int ||
          (owner['pid'] as int) <= 0 ||
          ['hostId', 'bootId', 'processStartId'].any(
            (key) => owner[key] is! String || (owner[key] as String).isEmpty,
          )) {
        throw const FormatException('Invalid process ownership identity');
      }
      requireRuntimeUuid(owner['ownershipToken']);
    }
    if (entry.key == 'protectedExportIds' ||
        entry.key == 'protectedGenerationIds') {
      final ids = entry.value;
      if (ids is! List) {
        throw const FormatException('Invalid protected identities');
      }
      for (final id in ids) {
        requireRuntimeUuid(id);
      }
    }
    if (entry.key == 'stage' &&
        !{
          'prepare',
          'transfer',
          'capture',
          'validate',
          'receipt',
          'cleanup',
        }.contains(entry.value)) {
      throw const FormatException('Unsupported operation stage');
    }
    if (entry.key.endsWith('Sha256') &&
        (entry.value is! String ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(entry.value as String))) {
      throw FormatException('Invalid metadata digest: ${entry.key}');
    }
    if (entry.key.endsWith('Id') || entry.key.endsWith('Release')) {
      requireRuntimeUuid(entry.value);
    }
    if (entry.key.endsWith('AtUtc')) {
      final time = entry.value;
      if (time is! String ||
          !RegExp(
            r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?Z$',
          ).hasMatch(time) ||
          DateTime.tryParse(time)?.toIso8601String().substring(0, 19) !=
              time.substring(0, 19)) {
        throw FormatException('Invalid UTC timestamp: ${entry.key}');
      }
    }
  }
  return value.cast<String, Object?>();
}
