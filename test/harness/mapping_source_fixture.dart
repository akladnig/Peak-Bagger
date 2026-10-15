import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'mapping_catalog_fixture.dart';
import '../../tool/region_peak_fingerprint_support.dart';

Future<Directory> createMappingSourceFixture() async {
  final root = await Directory.systemTemp.createTemp('mapping-source-fixture-');
  for (final path in testMappingCatalog.authorizedPaths) {
    final file = File(p.join(root.path, path));
    await file.parent.create(recursive: true);
    await file.writeAsString(
      path.endsWith('.poly')
          ? 'fixture\n1\n0 0\n1 0\n0 1\nEND\nEND\n'
          : path.startsWith('Highways/')
          ? '{"elements":[{"type":"node","id":1,"lat":-42,"lon":147},{"type":"node","id":2,"lat":-42.001,"lon":147.001},{"type":"way","id":3,"nodes":[1,2],"tags":{"highway":"path"}}]}'
          : '{"elements":[]}',
    );
  }
  final manifest =
      jsonDecode(
            await File(
              'test/fixtures/mapping_store/v1/region_manifest.json',
            ).readAsString(),
          )
          as Map;
  final regionFile = File(p.join(root.path, 'region_manifest.json'));
  await regionFile.writeAsString(jsonEncode(manifest));
  for (final entry in (await computeSeedableRegionFingerprints(
    readText: (path) => File(p.join(root.path, path)).readAsString(),
    readBytes: (path) => File(p.join(root.path, path)).readAsBytes(),
  )).entries) {
    manifest[entry.key]['fingerprint'] = entry.value;
  }
  await regionFile.writeAsString(jsonEncode(manifest));
  await File(
    p.join(root.path, 'Polygons/manifest.json'),
  ).writeAsString(jsonEncode(testMappingCatalog.polygonDisplayPaths.toList()));
  await File(
    p.join(root.path, 'Maps/tasmap50k.csv'),
  ).writeAsString(await File('test/fixtures/tasmap50k.csv').readAsString());
  return root;
}
