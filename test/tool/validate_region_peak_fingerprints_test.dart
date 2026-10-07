import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/region_peak_fingerprint_support.dart';

void main() {
  test(
    'validation detects stale markers then accepts the published fingerprint',
    () async {
      var manifest = jsonEncode({
        'tasmania': {
          'fingerprint': 'stale',
          'peaks': ['Peaks/tasmania-peaks.json'],
        },
      });
      Future<String> readText(String path) async => manifest;
      Future<List<int>> readBytes(String path) async => utf8.encode('tas');
      expect(
        await findStaleSeedableRegionFingerprints(
          readText: readText,
          readBytes: readBytes,
        ),
        ['tasmania'],
      );
      await updateSeedableRegionFingerprints(
        readText: readText,
        readBytes: readBytes,
        writeText: (_, text) async {
          manifest = text;
        },
      );
      expect(
        await findStaleSeedableRegionFingerprints(
          readText: readText,
          readBytes: readBytes,
        ),
        isEmpty,
      );
    },
  );
}
