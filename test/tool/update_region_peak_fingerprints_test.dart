import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/region_peak_fingerprint_support.dart';

void main() {
  test(
    'fingerprint update skips all metadata, composites and supporting regions',
    () async {
      var manifest = jsonEncode({
        'tasmap': {'catalog': 'Maps/test.csv'},
        'naturalFeatures': {'catalog': 'Features/test.json'},
        'demSources': {'elvisRuntime': 'DEM/runtime.tif'},
        'routingCoverages': {
          'tasmania': {'displayName': 'Tasmania'},
        },
        'tasmania': {
          'fingerprint': 'stale',
          'peaks': ['Peaks/tasmania-peaks.json'],
        },
        'italy': {
          'composite': true,
          'peaks': ['Peaks/italy-peaks.json'],
        },
        'fvg': {'seedOnStartup': false},
      });
      final reads = <String>[];
      Future<List<int>> readBytes(String path) async {
        reads.add(path);
        return utf8.encode('tas');
      }

      var writes = 0;
      Future<void> write(String path, String text) async {
        expect(path, 'region_manifest.json');
        writes++;
        manifest = text;
      }

      expect(
        await updateSeedableRegionFingerprints(
          readText: (_) async => manifest,
          readBytes: readBytes,
          writeText: write,
        ),
        isTrue,
      );
      expect(reads, ['Peaks/tasmania-peaks.json']);
      final decoded = jsonDecode(manifest) as Map;
      expect(decoded['tasmania']['fingerprint'], isNot('stale'));
      expect(decoded['italy']['fingerprint'], isNull);
      expect(decoded['fvg']['fingerprint'], isNull);
      expect(
        await updateSeedableRegionFingerprints(
          readText: (_) async => manifest,
          readBytes: readBytes,
          writeText: write,
        ),
        isFalse,
      );
      expect(writes, 1);
    },
  );
}
