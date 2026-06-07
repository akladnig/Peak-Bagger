import 'dart:io';

import 'region_peak_fingerprint_support.dart';

Future<void> main(List<String> args) async {
  final updated = await updateSeedableRegionFingerprints();
  stdout.writeln(
    updated
        ? 'Updated region peak fingerprints.'
        : 'Region peak fingerprints already current.',
  );
}
