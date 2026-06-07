import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/region_peak_fingerprint_support.dart';

void main() {
  test(
    'validation reports stale fingerprints and passes current ones',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'peak-fingerprint-validation-',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final peakFile = File('${tempDir.path}/tas.json')
        ..writeAsStringSync('tas');
      final manifestFile = File('${tempDir.path}/manifest.json')
        ..writeAsStringSync(
          jsonEncode({
            'tasmania': {
              'fingerprint': 'stale',
              'peaks': [peakFile.path],
            },
          }),
        );

      expect(
        await findStaleSeedableRegionFingerprints(
          manifestPath: manifestFile.path,
        ),
        ['tasmania'],
      );

      await updateSeedableRegionFingerprints(manifestPath: manifestFile.path);

      expect(
        await findStaleSeedableRegionFingerprints(
          manifestPath: manifestFile.path,
        ),
        isEmpty,
      );
    },
  );
}
