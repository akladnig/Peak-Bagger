import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/peak_source_parser.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../tool/mapping_source_dataset.dart';
import '../harness/mapping_source_fixture.dart';
import '../harness/mapping_catalog_fixture.dart';
import 'dart:convert';
import '../../tool/mapping_source_dem.dart';
import '../../tool/region_peak_fingerprint_support.dart';
import 'dart:typed_data';
import 'package:gdal_dart/gdal_dart.dart';

void main() {
  test(
    'validation aggregates identical skips without losing distinct diagnostics',
    () async {
      final created = await createMappingSourceFixture();
      final root = Directory(await created.resolveSymbolicLinks());
      addTearDown(() => root.delete(recursive: true));
      await File(
        p.join(root.path, 'Features/tasmania_natural_features.json'),
      ).writeAsString(
        jsonEncode({
          'elements': [
            {'type': 'node', 'id': 1, 'lat': -42, 'lon': 147},
            {'type': 'node', 'id': 2, 'lat': -42.001, 'lon': 147},
          ],
        }),
      );
      final integrity = await inspectMappingSource(
        rootPath: root.path,
        generationId: '00000000-0000-4000-8000-000000000001',
      );
      final report = await validateMappingSource(
        rootPath: root.path,
        integrity: integrity,
        validateDem: (_) async => {'blockCount': 1},
      );
      final diagnostics = (report['diagnostics'] as List).cast<String>();
      expect(
        diagnostics.where((message) => message.contains('Skipped ineligible')),
        [
          'Features/tasmania_natural_features.json: Skipped ineligible Natural Feature source record. (2 occurrences)',
        ],
      );
      expect(
        diagnostics.where((message) => message.contains('blockCount')),
        hasLength(3),
      );
    },
  );
  test('composite regions permit overlap between valid peak sources', () async {
    final created = await createMappingSourceFixture();
    final root = Directory(await created.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    const peak =
        '{"elements":[{"type":"node","id":1,"lat":46,"lon":12,"tags":{"natural":"peak","name":"Shared summit"}}]}';
    const paths = [
      'Peaks/italy-nord-est-peaks.json',
      'Peaks/italy-nord-ovest-peaks.json',
    ];
    await _writePeakSources(root, {for (final path in paths) path: peak});
    final integrity = await inspectMappingSource(
      rootPath: root.path,
      generationId: '00000000-0000-4000-8000-000000000001',
    );
    final report = await validateMappingSource(
      rootPath: root.path,
      integrity: integrity,
      validateDem: (_) async => {'blockCount': 1},
    );
    final checks = (report['checks'] as List).cast<Map<String, String>>();
    for (final path in paths) {
      expect(
        checks.where((check) => check['path'] == path),
        contains(
          equals({'path': path, 'checkId': 'peaks-v1', 'result': 'passed'}),
        ),
      );
    }
  });
  test('composite-only peak sources still reject duplicate identities', () async {
    final created = await createMappingSourceFixture();
    final root = Directory(await created.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    final manifestFile = File(p.join(root.path, 'region_manifest.json'));
    final manifest = jsonDecode(await manifestFile.readAsString()) as Map;
    const path = 'Peaks/composite-only.json';
    manifest['italy']['peaks'] = [path];
    await manifestFile.writeAsString(jsonEncode(manifest));
    const peak =
        '{"type":"node","id":1,"lat":46,"lon":12,"tags":{"natural":"peak","name":"Repeated summit"}}';
    await _writePeakSources(root, {path: '{"elements":[$peak,$peak]}'});
    final integrity = await inspectMappingSource(
      rootPath: root.path,
      generationId: '00000000-0000-4000-8000-000000000001',
    );
    await expectLater(
      validateMappingSource(
        rootPath: root.path,
        integrity: integrity,
        validateDem: (_) async => {'blockCount': 1},
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'duplicate dataset',
          'Duplicate peak identity: italy:$path',
        ),
      ),
    );
  });
  test('noncomposite region inputs still reject cross-file duplicates', () async {
    final created = await createMappingSourceFixture();
    final root = Directory(await created.resolveSymbolicLinks());
    addTearDown(() => root.delete(recursive: true));
    const paths = [
      'Peaks/italy-nord-est-peaks.json',
      'Peaks/italy-nord-ovest-peaks.json',
    ];
    final manifestFile = File(p.join(root.path, 'region_manifest.json'));
    final manifest = jsonDecode(await manifestFile.readAsString()) as Map;
    manifest['italy-nord-est']['peaks'] = paths;
    await manifestFile.writeAsString(jsonEncode(manifest));
    const peak =
        '{"elements":[{"type":"node","id":1,"lat":46,"lon":12,"tags":{"natural":"peak","name":"Shared summit"}}]}';
    await _writePeakSources(root, {for (final path in paths) path: peak});
    final integrity = await inspectMappingSource(
      rootPath: root.path,
      generationId: '00000000-0000-4000-8000-000000000001',
    );
    await expectLater(
      validateMappingSource(
        rootPath: root.path,
        integrity: integrity,
        validateDem: (_) async => {'blockCount': 1},
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'duplicate dataset',
          'Duplicate peak identity: italy-nord-est:${paths.last}',
        ),
      ),
    );
  });
  test(
    'catalog validation diagnostics identify the affected TasMap dataset',
    () async {
      final created = await createMappingSourceFixture();
      final root = Directory(await created.resolveSymbolicLinks());
      addTearDown(() => root.delete(recursive: true));
      await File(
        p.join(root.path, 'Maps/tasmap50k.csv'),
      ).writeAsString('Series,Name\nTQ,Broken\n');
      final integrity = await inspectMappingSource(
        rootPath: root.path,
        generationId: '00000000-0000-4000-8000-000000000001',
      );
      await expectLater(
        validateMappingSource(
          rootPath: root.path,
          integrity: integrity,
          validateDem: (_) async => {'blockCount': 1},
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'dataset path',
            contains('Maps/tasmap50k.csv'),
          ),
        ),
      );
    },
  );
  test(
    'fresh valid hashes cannot make malformed matrix payloads valid',
    () async {
      for (final entry in {
        'Peaks/tasmania-peaks.json':
            '{"elements":[{"type":"node","id":1,"tags":{"natural":"peak"}}]}',
        'Highways/tasmania-highways.json':
            '{"elements":[{"type":"way","id":1,"nodes":[999],"tags":{"highway":"path"}}]}',
        'Features/tasmania_natural_features.json': '{"elements":[42]}',
        'Maps/tasmap50k.csv': 'Series,Name\nTQ,Broken\n',
        'Polygons/display-only.poly': 'malformed display-only polygon',
      }.entries) {
        final created = await createMappingSourceFixture();
        final root = Directory(await created.resolveSymbolicLinks());
        addTearDown(() => root.delete(recursive: true));
        final file = File(p.join(root.path, entry.key));
        await file.writeAsString(entry.value);
        if (entry.key == 'Polygons/display-only.poly') {
          await File(p.join(root.path, 'Polygons/manifest.json')).writeAsString(
            jsonEncode([...testMappingCatalog.polygonDisplayPaths, entry.key]),
          );
        }
        final integrity = await inspectMappingSource(
          rootPath: root.path,
          generationId: '00000000-0000-4000-8000-000000000001',
        );
        await expectLater(
          validateMappingSource(
            rootPath: root.path,
            integrity: integrity,
            validateDem: (_) async => {'blockCount': 1},
          ),
          throwsA(isA<FormatException>()),
          reason: entry.key,
        );
      }
    },
  );

  test(
    'source profile refuses stale declared fingerprints without repairing them',
    () async {
      final created = await createMappingSourceFixture();
      final root = Directory(await created.resolveSymbolicLinks());
      addTearDown(() => root.delete(recursive: true));
      final region = File(p.join(root.path, 'region_manifest.json'));
      final original = await region.readAsString();
      await File(
        p.join(root.path, 'Peaks/tasmania-peaks.json'),
      ).writeAsString('{"elements":[],"changed":true}');
      final integrity = await inspectMappingSource(
        rootPath: root.path,
        generationId: '00000000-0000-4000-8000-000000000001',
      );
      await expectLater(
        validateMappingSource(
          rootPath: root.path,
          integrity: integrity,
          validateDem: (_) async => {'blockCount': 1},
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'region',
            contains('tasmania'),
          ),
        ),
      );
      expect(await region.readAsString(), original);
    },
  );
  test(
    'full DEM profile decodes every band-1 block and closes native resources',
    () async {
      final root = await Directory.systemTemp.createTemp('mapping-dem-native-');
      addTearDown(() => root.delete(recursive: true));
      final path = p.join(root.path, 'tiny.tif');
      final gdal = Gdal(
        libraryPath: Platform.isMacOS
            ? '/opt/homebrew/lib/libgdal.dylib'
            : null,
      );
      if (Platform.isMacOS) {
        gdal.setConfigOption('PROJ_DATA', '/opt/homebrew/share/proj');
        gdal.setConfigOption('PROJ_LIB', '/opt/homebrew/share/proj');
      }
      final writer = gdal.createGeoTiff(
        path,
        width: 17,
        height: 17,
        dataType: RasterDataType.float64,
        options: {
          'TILED': 'YES',
          'BLOCKXSIZE': '16',
          'BLOCKYSIZE': '16',
          'COMPRESS': 'DEFLATE',
        },
      );
      writer.setProjection(gdal.getOrCreateWKT('EPSG:4326'));
      writer.setGeoTransform(
        GeoTransform.fromList([147, 0.001, 0, -42, 0, -0.001]),
      );
      writer.writeAsFloat64(1, Float64List.fromList(List.filled(17 * 17, 100)));
      writer.close();
      final details = await validateSourceDem(path, gdal: gdal);
      expect(details['blockCount'], 4);
      expect(details['width'], 17);
      expect(File('$path.aux.xml').existsSync(), isFalse);
      await File(path).delete();
    },
  );
  test(
    'DEM validation rejects non-TIFF required rasters before native open',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'mapping-dem-validation-',
      );
      addTearDown(() => root.delete(recursive: true));
      final path = p.join(root.path, 'malformed.tif');
      await File(path).writeAsString('not a raster');
      await expectLater(validateSourceDem(path), throwsFormatException);
    },
  );
  test(
    'capture derives complete independent payload and validates the profile',
    () async {
      final root = await createMappingSourceFixture();
      final destination = await Directory.systemTemp.createTemp(
        'mapping-source-export-',
      );
      addTearDown(() => root.delete(recursive: true));
      addTearDown(() => destination.delete(recursive: true));
      final payload = p.join(
        await destination.resolveSymbolicLinks(),
        'payload',
      );
      final integrity = await captureMappingSource(
        rootPath: root.path,
        destination: payload,
        generationId: '00000000-0000-4000-8000-000000000001',
      );
      expect(
        (integrity['files'] as List).map((e) => e['path']).toSet(),
        testMappingCatalog.authorizedPaths,
      );
      final report = await validateMappingSource(
        rootPath: payload,
        integrity: integrity,
        validateDem: (_) async => {'blockCount': 1},
      );
      expect(
        (report['diagnostics'] as List).every(
          (e) => e.toString().contains('blockCount'),
        ),
        isTrue,
      );
      expect(
        (report['checks'] as List).every((e) => e['result'] == 'passed'),
        isTrue,
      );
      final original = File(p.join(root.path, 'Peaks/tasmania-peaks.json'));
      await original.writeAsString('changed after capture');
      expect(
        await File(p.join(payload, 'Peaks/tasmania-peaks.json')).readAsString(),
        '{"elements":[]}',
      );
    },
  );
  test('source parser rejects malformed accepted peaks before publication', () {
    expect(
      () => parsePeakSource(
        '{"elements":[{"type":"node","id":1,"lat":-42,"lon":147,"tags":{"natural":"peak"}}]}',
        regionKey: 'tasmania',
        path: 'Peaks/tasmania-peaks.json',
      ),
      throwsFormatException,
    );
    final result = parsePeakSource(
      '{"elements":[{"type":"node","id":1,"lat":-42,"lon":147,"tags":{"natural":"peak","name":" Summit ","ele":"unknown"}},{"type":"way"}]}',
      regionKey: 'tasmania',
      path: 'Peaks/tasmania-peaks.json',
    );
    expect(result.peaks.single.name, 'Summit');
    expect(result.peaks.single.elevation, isNull);
    expect(result.peaks.single.gridZoneDesignator, isNotEmpty);
    expect(result.skippedPeakCount, 1);
  });
}

Future<void> _writePeakSources(
  Directory root,
  Map<String, String> sources,
) async {
  for (final entry in sources.entries) {
    await File(p.join(root.path, entry.key)).writeAsString(entry.value);
  }
  final file = File(p.join(root.path, 'region_manifest.json'));
  final manifest = jsonDecode(await file.readAsString()) as Map;
  final fingerprints = await computeSeedableRegionFingerprints(
    readText: (path) => File(p.join(root.path, path)).readAsString(),
    readBytes: (path) => File(p.join(root.path, path)).readAsBytes(),
  );
  for (final entry in fingerprints.entries) {
    manifest[entry.key]['fingerprint'] = entry.value;
  }
  await file.writeAsString(jsonEncode(manifest));
}
