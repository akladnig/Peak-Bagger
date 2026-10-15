import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_store_core.dart';

import '../../tool/mapping_runtime_inventory.dart';
import '../../tool/region_peak_fingerprint_support.dart';
import '../harness/mapping_catalog_fixture.dart';

void main() {
  late Directory root;
  late Map<String, dynamic> manifest;

  Future<void> write(String path, String text) async {
    final file = File(p.join(root.path, path));
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mapping-runtime-inventory-');
    manifest =
        jsonDecode(
              File(
                'test/fixtures/mapping_store/v1/region_manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final path in testMappingCatalog.authorizedPaths) {
      await write(
        path,
        path.endsWith('.poly')
            ? 'fixture\n1\n0 0\n1 0\n0 1\nEND\nEND\n'
            : '{"elements":[]}',
      );
    }
    await write('region_manifest.json', jsonEncode(manifest));
    final fingerprints = await computeSeedableRegionFingerprints(
      readText: (path) => File(p.join(root.path, path)).readAsString(),
      readBytes: (path) => File(p.join(root.path, path)).readAsBytes(),
    );
    for (final entry in fingerprints.entries) {
      manifest[entry.key]['fingerprint'] = entry.value;
    }
    await write('region_manifest.json', jsonEncode(manifest));
    await write(
      'Polygons/manifest.json',
      jsonEncode(testMappingCatalog.polygonDisplayPaths.toList()),
    );
    await write('unrelated.json', 'not an app dependency');
  });

  tearDown(() => root.delete(recursive: true));

  test('audits the complete manifest set, bytes and access roles', () async {
    final report = await auditMappingRuntime(rootPath: root.path);
    final files = report['files']! as List<Map<String, Object?>>;
    expect(
      files.map((file) => file['path']),
      orderedEquals(testMappingCatalog.authorizedPaths.toList()..sort()),
    );
    final dem = files.singleWhere(
      (file) => file['path'] == 'DEM/Elvis/elvis_runtime_10m.tif',
    );
    expect(dem['size'], utf8.encode('{"elements":[]}').length);
    expect(
      dem['sha256'],
      sha256.convert(utf8.encode('{"elements":[]}')).toString(),
    );
    expect(dem['startupCheck'], isTrue);
    expect(dem['startupContent'], isFalse);
    expect(dem['startupReaders'], ['lib/services/mapping_store_core.dart']);
    expect(dem['latencySensitive'], isTrue);
    expect(
      dem['liveRuntime'],
      contains('lib/services/route_elevation_sampler.dart'),
    );
    expect(report['stalePeakFingerprints'], isEmpty);
    expect(
      report['totalBytes'],
      files.fold<int>(0, (sum, file) => sum + (file['size']! as int)),
    );
    expect(
      File(p.join(root.path, 'unrelated.json')).readAsStringSync(),
      'not an app dependency',
    );
  });

  test(
    'includes display-only and coverage references once without changing startup rules',
    () async {
      const display = 'Polygons/display-only.poly';
      const coverage = 'Polygons/coverage-only.poly';
      await write(display, 'fixture\n1\n0 0\n1 0\n0 1\nEND\nEND\n');
      await write(coverage, 'fixture\n1\n0 0\n1 0\n0 1\nEND\nEND\n');
      manifest['tasmania']['poly'].add('Polygons/tasmania.poly');
      for (final region in manifest.values.whereType<Map<String, dynamic>>()) {
        for (final map in (region['maps'] as List? ?? const [])) {
          if (map['key'] == 'openstreetmap') map['coveragePoly'] = [coverage];
        }
      }
      await write('region_manifest.json', jsonEncode(manifest));
      await write(
        'Polygons/manifest.json',
        jsonEncode([
          ...testMappingCatalog.polygonDisplayPaths,
          display,
          coverage,
        ]),
      );
      final report = await auditMappingRuntime(rootPath: root.path);
      final files = report['files']! as List<Map<String, Object?>>;
      expect(files.length, testMappingCatalog.authorizedPaths.length + 2);
      expect(
        files.singleWhere((file) => file['path'] == display)['startupCheck'],
        isFalse,
      );
      expect(
        files.singleWhere((file) => file['path'] == coverage)['startupContent'],
        isTrue,
      );
    },
  );

  test(
    'rejects invalid schema, escaping paths and escaping display symlinks',
    () async {
      final original = jsonEncode(manifest);
      for (final path in [
        '../outside.json',
        '/outside.json',
        'tool_manifest.json',
      ]) {
        manifest['tasmania']['peaks'] = [path];
        await write('region_manifest.json', jsonEncode(manifest));
        await expectLater(
          auditMappingRuntime(rootPath: root.path),
          throwsA(isA<MappingStoreFailure>()),
        );
      }
      await write('region_manifest.json', original);
      const display = 'Polygons/escape.poly';
      await write(
        'Polygons/manifest.json',
        jsonEncode([...testMappingCatalog.polygonDisplayPaths, display]),
      );
      final outside = await Directory.systemTemp.createTemp('mapping-outside-');
      addTearDown(() => outside.delete(recursive: true));
      final outsideFile = File(p.join(outside.path, 'outside.poly'));
      await outsideFile.writeAsString('fixture\n1\n0 0\n1 0\n0 1\nEND\nEND\n');
      await Link(p.join(root.path, display)).create(outsideFile.path);
      await expectLater(
        auditMappingRuntime(rootPath: root.path),
        throwsA(isA<MappingStoreFailure>()),
      );
    },
  );

  test(
    'checks raw-byte fingerprints in declared peak source order without repairing them',
    () async {
      const second = 'Peaks/tasmania-second.json';
      await write(second, '{"elements":[],"note":"second"}\n');
      manifest['tasmania']['peaks'].add(second);
      await write('region_manifest.json', jsonEncode(manifest));
      final stale = await auditMappingRuntime(rootPath: root.path);
      expect(stale['stalePeakFingerprints'], ['tasmania']);
      expect(
        jsonDecode(
          await File(p.join(root.path, 'region_manifest.json')).readAsString(),
        ),
        manifest,
      );
      final bytes = <int>[
        ...await File(
          p.join(root.path, 'Peaks/tasmania-peaks.json'),
        ).readAsBytes(),
        ...await File(p.join(root.path, second)).readAsBytes(),
      ];
      manifest['tasmania']['fingerprint'] = sha256.convert(bytes).toString();
      await write('region_manifest.json', jsonEncode(manifest));
      expect(
        (await auditMappingRuntime(
          rootPath: root.path,
        ))['stalePeakFingerprints'],
        isEmpty,
      );
    },
  );

  test(
    'rejects an observation when manifests change during the audit',
    () async {
      var changed = false;
      await expectLater(
        auditMappingRuntime(
          rootPath: root.path,
          inspectFile: (path) async {
            final result = await const IoMappingStoreFileSystem()
                .inspectIntegrity(path);
            if (!changed) {
              changed = true;
              manifest['tasmania']['name'] = 'Changed during audit';
              await write('region_manifest.json', jsonEncode(manifest));
            }
            return result;
          },
        ),
        throwsA(isA<MappingStoreFailure>()),
      );
    },
  );
}
