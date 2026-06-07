import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_region_import_marker_store.dart';
import 'package:peak_bagger/services/peak_repository.dart';

typedef PeakRegionAssetLoader = Future<String> Function(String assetPath);
typedef PeakRegionMgrsConverter = PeakMgrsComponents Function(LatLng location);

class PeakRegionAssetImportResult {
  const PeakRegionAssetImportResult({
    required this.importedRegions,
    required this.importedPeakCount,
    required this.skippedPeakCount,
  });

  final List<String> importedRegions;
  final int importedPeakCount;
  final int skippedPeakCount;

  bool get hasChanges => importedRegions.isNotEmpty;
}

class PeakRegionAssetImportService {
  PeakRegionAssetImportService({
    PeakRegionAssetLoader? assetLoader,
    PeakRegionMgrsConverter? mgrsConverter,
    PeakRegionImportMarkerStore? markerStore,
  }) : _assetLoader = assetLoader ?? rootBundle.loadString,
       _mgrsConverter = mgrsConverter ?? PeakMgrsConverter.fromLatLng,
       _markerStore = markerStore ?? const PeakRegionImportMarkerStore();

  static const manifestAssetPath = 'assets/region_manifest.json';

  final PeakRegionAssetLoader _assetLoader;
  final PeakRegionMgrsConverter _mgrsConverter;
  final PeakRegionImportMarkerStore _markerStore;

  Future<PeakRegionAssetImportResult> seedIfRepositoryEmpty({
    required PeakRepository peakRepository,
  }) async {
    if (!peakRepository.isEmpty()) {
      return const PeakRegionAssetImportResult(
        importedRegions: [],
        importedPeakCount: 0,
        skippedPeakCount: 0,
      );
    }

    final manifest = await _loadManifest();
    final importedRegions = <String>[];
    final fingerprints = <String, String>{};
    final peaksByOsmId = <int, Peak>{};
    var skippedPeakCount = 0;

    for (final region in manifest) {
      importedRegions.add(region.key);
      fingerprints[region.key] = region.fingerprint;
      for (final assetPath in region.peakAssetPaths) {
        final assetResult = await _loadRegionPeaks(
          regionKey: region.key,
          assetPath: assetPath,
        );
        skippedPeakCount += assetResult.skippedPeakCount;
        for (final peak in assetResult.peaks) {
          peaksByOsmId[peak.osmId] = peak;
        }
      }
    }

    if (peaksByOsmId.isEmpty) {
      throw StateError('No bundled peaks imported');
    }

    await peakRepository.replaceAll(
      peaksByOsmId.values.toList(growable: false),
    );
    await _markerStore.saveFingerprints(fingerprints);

    return PeakRegionAssetImportResult(
      importedRegions: List<String>.unmodifiable(importedRegions),
      importedPeakCount: peaksByOsmId.length,
      skippedPeakCount: skippedPeakCount,
    );
  }

  Future<List<_ManifestRegion>> _loadManifest() async {
    final manifestText = await _assetLoader(manifestAssetPath);
    final decoded = jsonDecode(manifestText);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Peak region manifest must be a JSON object.');
    }

    final regions = <_ManifestRegion>[];
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) {
        throw StateError('Region ${entry.key} must be a JSON object.');
      }
      final composite = value['composite'] == true;
      if (composite) {
        continue;
      }
      final fingerprint = value['fingerprint'];
      final peakAssets = value['peaks'];
      if (fingerprint is! String || fingerprint.isEmpty) {
        throw StateError(
          'Seedable region ${entry.key} is missing a fingerprint.',
        );
      }
      if (peakAssets is! List) {
        throw StateError(
          'Seedable region ${entry.key} must define peak assets.',
        );
      }
      regions.add(
        _ManifestRegion(
          key: entry.key,
          fingerprint: fingerprint,
          peakAssetPaths: peakAssets.whereType<String>().toList(
            growable: false,
          ),
        ),
      );
    }
    return regions;
  }

  Future<_RegionAssetLoadResult> _loadRegionPeaks({
    required String regionKey,
    required String assetPath,
  }) async {
    final assetText = await _assetLoader(assetPath);
    final decoded = jsonDecode(assetText);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Peak asset $assetPath must be a JSON object.');
    }
    final elements = decoded['elements'];
    if (elements is! List) {
      throw StateError('Peak asset $assetPath must contain an elements list.');
    }

    final peaks = <Peak>[];
    var skippedPeakCount = 0;
    for (final element in elements) {
      if (element is! Map) {
        skippedPeakCount += 1;
        continue;
      }
      try {
        final peak = Peak.fromOverpass(
          Map<String, dynamic>.from(element),
        ).copyWith(region: regionKey);
        if (peak.name == 'Unknown') {
          skippedPeakCount += 1;
          continue;
        }
        final enrichedPeak = _enrichPeak(peak);
        if (enrichedPeak == null) {
          skippedPeakCount += 1;
          continue;
        }
        peaks.add(enrichedPeak);
      } catch (error, stackTrace) {
        developer.log(
          'Skipping malformed peak row in $assetPath.',
          error: error,
          stackTrace: stackTrace,
          name: 'PeakRegionAssetImportService',
        );
        skippedPeakCount += 1;
      }
    }

    return _RegionAssetLoadResult(
      peaks: List<Peak>.unmodifiable(peaks),
      skippedPeakCount: skippedPeakCount,
    );
  }

  Peak? _enrichPeak(Peak peak) {
    try {
      final components = _mgrsConverter(LatLng(peak.latitude, peak.longitude));
      return peak.copyWith(
        gridZoneDesignator: components.gridZoneDesignator,
        mgrs100kId: components.mgrs100kId,
        easting: components.easting,
        northing: components.northing,
      );
    } catch (_) {
      return null;
    }
  }
}

class _ManifestRegion {
  const _ManifestRegion({
    required this.key,
    required this.fingerprint,
    required this.peakAssetPaths,
  });

  final String key;
  final String fingerprint;
  final List<String> peakAssetPaths;
}

class _RegionAssetLoadResult {
  const _RegionAssetLoadResult({
    required this.peaks,
    required this.skippedPeakCount,
  });

  final List<Peak> peaks;
  final int skippedPeakCount;
}
