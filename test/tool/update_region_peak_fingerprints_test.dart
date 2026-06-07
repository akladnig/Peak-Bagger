import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/region_peak_fingerprint_support.dart';

void main() {
  test('update tool rewrites stale fingerprints deterministically', () async {
    final tempDir = await Directory.systemTemp.createTemp('peak-fingerprints-');
    addTearDown(() => tempDir.delete(recursive: true));

    final peakFile = File('${tempDir.path}/tas.json')..writeAsStringSync('tas');
    final compositePeakFile = File('${tempDir.path}/italy.json')
      ..writeAsStringSync('italy');
    final manifestFile = File('${tempDir.path}/manifest.json')
      ..writeAsStringSync(
        jsonEncode({
          'tasmania': {
            'fingerprint': 'stale',
            'peaks': [peakFile.path],
          },
          'italy': {
            'composite': true,
            'peaks': [compositePeakFile.path],
          },
        }),
      );

    final changed = await updateSeedableRegionFingerprints(
      manifestPath: manifestFile.path,
    );

    final updatedManifest =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    expect(changed, isTrue);
    expect(updatedManifest['tasmania']['fingerprint'], isNot('stale'));
    expect(updatedManifest['italy']['fingerprint'], isNull);
  });
}
