import 'dart:io';

import 'region_peak_fingerprint_support.dart';

Future<void> main(List<String> args) async {
  final staleRegions = await findStaleSeedableRegionFingerprints();
  if (staleRegions.isEmpty) {
    stdout.writeln('Region peak fingerprints are current.');
    return;
  }

  stderr.writeln('Stale region peak fingerprints: ${staleRegions.join(', ')}');
  exitCode = 1;
}
