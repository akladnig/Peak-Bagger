import 'dart:convert';

import 'package:crypto/crypto.dart';

typedef RegionPeakManifestTextLoader = Future<String> Function(String path);
typedef RegionPeakAssetBytesLoader = Future<List<int>> Function(String path);
typedef RegionPeakManifestWriter =
    Future<void> Function(String path, String text);

const defaultRegionPeakManifestPath = 'region_manifest.json';

Future<Map<String, dynamic>> loadRegionPeakManifest(
  String manifestPath, {
  required RegionPeakManifestTextLoader readText,
}) async {
  final loader = readText;
  final decoded = jsonDecode(await loader(manifestPath));
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Region peak manifest must be a JSON object.');
  }
  return decoded;
}

Future<Map<String, String>> computeSeedableRegionFingerprints({
  String manifestPath = defaultRegionPeakManifestPath,
  required RegionPeakManifestTextLoader readText,
  required RegionPeakAssetBytesLoader readBytes,
}) async {
  final manifest = await loadRegionPeakManifest(
    manifestPath,
    readText: readText,
  );
  final bytesLoader = readBytes;
  final fingerprints = <String, String>{};

  for (final entry in manifest.entries) {
    if (_metadata.contains(entry.key)) {
      continue;
    }
    final region = entry.value;
    if (region is! Map<String, dynamic>) {
      throw StateError('Region ${entry.key} must be a JSON object.');
    }
    if (!_isSeedableRegion(region)) {
      continue;
    }
    final peakAssets = region['peaks'];
    if (peakAssets is! List) {
      throw StateError(
        'Seedable region ${entry.key} must define a peaks list.',
      );
    }

    final bytes = <int>[];
    for (final assetPath in peakAssets.whereType<String>()) {
      bytes.addAll(await bytesLoader(assetPath));
    }
    fingerprints[entry.key] = sha256.convert(bytes).toString();
  }

  return fingerprints;
}

Future<bool> updateSeedableRegionFingerprints({
  String manifestPath = defaultRegionPeakManifestPath,
  required RegionPeakManifestTextLoader readText,
  required RegionPeakAssetBytesLoader readBytes,
  required RegionPeakManifestWriter writeText,
}) async {
  final manifest = await loadRegionPeakManifest(
    manifestPath,
    readText: readText,
  );
  final fingerprints = await computeSeedableRegionFingerprints(
    manifestPath: manifestPath,
    readText: readText,
    readBytes: readBytes,
  );
  var changed = false;

  for (final entry in manifest.entries) {
    if (_metadata.contains(entry.key)) {
      continue;
    }
    final region = entry.value;
    if (region is! Map<String, dynamic>) {
      throw StateError('Region ${entry.key} must be a JSON object.');
    }
    if (!_isSeedableRegion(region)) {
      continue;
    }
    final nextFingerprint = fingerprints[entry.key];
    if (nextFingerprint == null) {
      continue;
    }
    if (region['fingerprint'] == nextFingerprint) {
      continue;
    }
    region['fingerprint'] = nextFingerprint;
    changed = true;
  }

  if (changed) {
    final writer = writeText;
    final encoded = const JsonEncoder.withIndent('  ').convert(manifest);
    await writer(manifestPath, '$encoded\n');
  }

  return changed;
}

Future<List<String>> findStaleSeedableRegionFingerprints({
  String manifestPath = defaultRegionPeakManifestPath,
  required RegionPeakManifestTextLoader readText,
  required RegionPeakAssetBytesLoader readBytes,
}) async {
  final manifest = await loadRegionPeakManifest(
    manifestPath,
    readText: readText,
  );
  final fingerprints = await computeSeedableRegionFingerprints(
    manifestPath: manifestPath,
    readText: readText,
    readBytes: readBytes,
  );
  final staleRegions = <String>[];

  for (final entry in manifest.entries) {
    if (_metadata.contains(entry.key)) {
      continue;
    }
    final region = entry.value;
    if (region is! Map<String, dynamic>) {
      throw StateError('Region ${entry.key} must be a JSON object.');
    }
    if (!_isSeedableRegion(region)) {
      continue;
    }
    if (region['fingerprint'] != fingerprints[entry.key]) {
      staleRegions.add(entry.key);
    }
  }

  return staleRegions;
}

const _metadata = {
  'tasmap',
  'naturalFeatures',
  'demSources',
  'routingCoverages',
};

bool _isSeedableRegion(Map<String, dynamic> regionValue) {
  return regionValue['composite'] != true &&
      regionValue['seedOnStartup'] != false;
}
