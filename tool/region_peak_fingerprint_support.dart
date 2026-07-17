import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

typedef RegionPeakManifestTextLoader = Future<String> Function(String path);
typedef RegionPeakAssetBytesLoader = Future<List<int>> Function(String path);
typedef RegionPeakManifestWriter =
    Future<void> Function(String path, String text);

const defaultRegionPeakManifestPath = 'assets/region_manifest.json';

Future<Map<String, dynamic>> loadRegionPeakManifest(
  String manifestPath, {
  RegionPeakManifestTextLoader? readText,
}) async {
  final loader = readText ?? _readText;
  final decoded = jsonDecode(await loader(manifestPath));
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Region peak manifest must be a JSON object.');
  }
  return decoded;
}

Future<Map<String, String>> computeSeedableRegionFingerprints({
  String manifestPath = defaultRegionPeakManifestPath,
  RegionPeakManifestTextLoader? readText,
  RegionPeakAssetBytesLoader? readBytes,
}) async {
  final manifest = await loadRegionPeakManifest(
    manifestPath,
    readText: readText,
  );
  final bytesLoader = readBytes ?? _readBytes;
  final fingerprints = <String, String>{};

  for (final entry in manifest.entries) {
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
  RegionPeakManifestTextLoader? readText,
  RegionPeakAssetBytesLoader? readBytes,
  RegionPeakManifestWriter? writeText,
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
    final region = entry.value;
    if (region is! Map<String, dynamic>) {
      continue;
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
    final writer = writeText ?? _writeText;
    final encoded = const JsonEncoder.withIndent('  ').convert(manifest);
    await writer(manifestPath, '$encoded\n');
  }

  return changed;
}

Future<List<String>> findStaleSeedableRegionFingerprints({
  String manifestPath = defaultRegionPeakManifestPath,
  RegionPeakManifestTextLoader? readText,
  RegionPeakAssetBytesLoader? readBytes,
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
    final region = entry.value;
    if (region is! Map<String, dynamic>) {
      staleRegions.add(entry.key);
      continue;
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

Future<String> _readText(String path) async {
  return File(path).readAsString();
}

Future<List<int>> _readBytes(String path) async {
  return File(path).readAsBytes();
}

Future<void> _writeText(String path, String text) async {
  await File(path).writeAsString(text);
}

bool _isSeedableRegion(Map<String, dynamic> regionValue) {
  return regionValue['composite'] != true &&
      regionValue['seedOnStartup'] != false;
}
