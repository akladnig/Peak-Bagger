import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gdal_dart/gdal_dart.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_replica_records.dart';

import '../../tool/mapping_source_dataset.dart';
import '../harness/mapping_catalog_fixture.dart';
import '../harness/mapping_source_fixture.dart';

void main() {
  test(
    'local pipeline runs the real matrix and publishes a complete independent generation',
    () async {
      const generation = '00000000-0000-4000-8000-000000000001';
      final source = await createMappingSourceFixture();
      final temporary = await Directory.systemTemp.createTemp(
        'mapping-replica-',
      );
      final base = await temporary.resolveSymbolicLinks();
      addTearDown(() async {
        await source.delete(recursive: true);
        await Process.run('python3', [
          '-c',
          'import os,sys; from pathlib import Path; '
              '[Path(root).chmod(0o755) for root, _, _ in os.walk(sys.argv[1])]',
          base,
        ]);
        await temporary.delete(recursive: true);
      });
      final export = p.join(base, 'incoming', generation);
      final payload = p.join(export, 'payload');
      await captureMappingSource(
        rootPath: source.path,
        destination: payload,
        generationId: generation,
      );
      final gdal = Gdal(
        libraryPath: Platform.isMacOS
            ? '/opt/homebrew/lib/libgdal.dylib'
            : null,
      );
      if (Platform.isMacOS) {
        gdal.setConfigOption('PROJ_DATA', '/opt/homebrew/share/proj');
        gdal.setConfigOption('PROJ_LIB', '/opt/homebrew/share/proj');
      }
      for (final path in testMappingCatalog.demSources.values.toSet()) {
        final writer = gdal.createGeoTiff(
          p.join(payload, path),
          width: 2,
          height: 2,
          dataType: RasterDataType.float64,
        );
        writer.setProjection(gdal.getOrCreateWKT('EPSG:4326'));
        writer.setGeoTransform(
          GeoTransform.fromList([147, .001, 0, -42, 0, -.001]),
        );
        writer.writeAsFloat64(1, Float64List.fromList([100, 101, 102, 103]));
        writer.close();
      }
      final integrity = await inspectMappingSource(
        rootPath: payload,
        generationId: generation,
      );
      await File(
        p.join(export, 'integrity.json'),
      ).writeAsString(jsonEncode(integrity));
      final inventorySha = sha256
          .convert(utf8.encode(jsonEncode(integrity)))
          .toString();
      final python = '''
import sys, json
sys.path.insert(0, 'tool')
import mapping_replica as r
import mapping_source as s
from pathlib import Path
base=Path(sys.argv[1]); generation=sys.argv[2]
s.atomic_json(base/'incoming'/generation/'completion.json', s.record('mapping-source-completion',
    generationId=generation, inventorySha256=sys.argv[3], operationId='00000000-0000-4000-8000-000000000002',
    publicationId='00000000-0000-4000-8000-000000000003', sourcePreparerRelease=s.DEVELOPMENT_RELEASE_ID,
    validationProfile=s.PROFILE, validatedAtUtc=s.utc()))
controller=r.Replica(base)
controller.capture(generation, transfer_complete=True)
print(json.dumps(controller.eligible(generation)))
''';
      final result = await Process.run('python3', [
        '-c',
        python,
        base,
        generation,
        inventorySha,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final eligibility = jsonDecode(result.stdout as String) as Map;
      expect(eligibility['inventorySha256'], inventorySha);
      final captured = p.join(base, 'generations', generation);
      final readable = await MappingReplicaRecords(base).eligible(generation);
      expect(readable.rootPath, p.join(captured, 'payload'));
      expect(readable.inventorySha256, inventorySha);
      final report =
          jsonDecode(
                await File(p.join(captured, 'validation.json')).readAsString(),
              )
              as Map;
      expect(
        (report['checks'] as List).map((e) => e['checkId']).toSet(),
        containsAll([
          'manifest-paths-v1',
          'sha256-v1',
          'polygon-v1',
          'peaks-v1',
          'peak-fingerprints-v1',
          'highway-envelope-v1',
          'coverage-generation-v1',
          'natural-features-v1',
          'tasmap-v1',
          'dem-full-band1-v1',
        ]),
      );
      expect(
        (await inspectMappingSource(
          rootPath: p.join(captured, 'payload'),
          generationId: generation,
        ))['files'],
        integrity['files'],
      );
      expect(
        File(p.join(base, 'receipts', '$generation.json')).existsSync(),
        isTrue,
      );

      // Each corrupt upstream export has matching raw-byte digests. The real
      // profile, rather than transfer integrity alone, must reject it and retain
      // the previous independently validated generation.
      var index = 10;
      for (final entry in {
        'Peaks/tasmania-peaks.json':
            '{"elements":[{"type":"node","id":1,"tags":{"natural":"peak"}}]}',
        'Highways/tasmania-highways.json':
            '{"elements":[{"type":"way","id":1,"nodes":[999],"tags":{"highway":"path"}}]}',
        'Features/tasmania_natural_features.json': '{"elements":[42]}',
        'Maps/tasmap50k.csv': 'Series,Name\nTQ,Broken\n',
        'Polygons/tasmania.poly': 'malformed required polygon',
        'Polygons/display-only.poly': 'malformed display polygon',
        'DEM/Elvis/elvis_runtime_10m.tif': 'not a raster',
        'DEM/tasmania_dem_25m.tif': 'not a raster',
        'DEM/cop30_hh.tif': 'not a raster',
        'region_manifest.json': '{}',
        'Polygons/manifest.json': '["../outside.poly"]',
        'peak-fingerprint': '{"elements":[],"changed":true}',
      }.entries) {
        final rejectedGeneration =
            '00000000-0000-4000-8000-${(index++).toString().padLeft(12, '0')}';
        final rejectedExport = p.join(base, 'incoming', rejectedGeneration);
        final rejectedPayload = p.join(rejectedExport, 'payload');
        for (final file in (integrity['files'] as List).cast<Map>()) {
          final target = File(p.join(rejectedPayload, file['path'] as String));
          await target.parent.create(recursive: true);
          await File(p.join(payload, file['path'] as String)).copy(target.path);
        }
        final changedPath = entry.key == 'peak-fingerprint'
            ? 'Peaks/tasmania-peaks.json'
            : entry.key;
        await File(
          p.join(rejectedPayload, changedPath),
        ).writeAsString(entry.value);
        final paths = (integrity['files'] as List)
            .map((e) => e['path'] as String)
            .toSet();
        if (entry.key == 'Polygons/display-only.poly') {
          paths.add(entry.key);
          await File(
            p.join(rejectedPayload, 'Polygons/manifest.json'),
          ).writeAsString(
            jsonEncode([...testMappingCatalog.polygonDisplayPaths, entry.key]),
          );
        }
        final changedIntegrity = <String, Object?>{
          'kind': 'mapping-integrity',
          'schemaVersion': 1,
          'generationId': rejectedGeneration,
          'files': [
            for (final path in paths.toList()..sort())
              {
                'path': path,
                'size': await File(p.join(rejectedPayload, path)).length(),
                'sha256': sha256
                    .convert(
                      await File(p.join(rejectedPayload, path)).readAsBytes(),
                    )
                    .toString(),
              },
          ],
        };
        await File(
          p.join(rejectedExport, 'integrity.json'),
        ).writeAsString(jsonEncode(changedIntegrity));
        final rejectingPython = python.replaceAll(
          'controller.capture(generation, transfer_complete=True)',
          '''try:
    controller.capture(generation, transfer_complete=True)
except Exception as error:
    print(error, file=sys.stderr)
    assert controller.eligible('$generation')['inventorySha256'] == '$inventorySha'
    sys.exit(1)''',
        );
        final rejected = await Process.run('python3', [
          '-c',
          rejectingPython,
          base,
          rejectedGeneration,
          sha256.convert(utf8.encode(jsonEncode(changedIntegrity))).toString(),
        ]);
        expect(
          rejected.exitCode,
          1,
          reason: '${entry.key}: ${rejected.stdout}\n${rejected.stderr}',
        );
        expect(rejected.stderr, contains('stage=validate'), reason: entry.key);
        expect(
          File(
            p.join(base, 'eligibility', '$rejectedGeneration.json'),
          ).existsSync(),
          isFalse,
        );
        expect(
          File(
            p.join(base, 'receipts', '$rejectedGeneration.json'),
          ).existsSync(),
          isFalse,
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
