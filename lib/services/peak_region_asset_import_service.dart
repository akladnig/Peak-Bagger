import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_region_import_marker_store.dart';
import 'package:peak_bagger/services/peak_repository.dart';

typedef PeakRegionSourceReader = Future<String> Function(String relativePath);
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

  int get importedCount => importedPeakCount;
}

class PeakRegionAssetImportService {
  PeakRegionAssetImportService({
    PeakRegionMgrsConverter? mgrsConverter,
    PeakRegionImportMarkerStore? markerStore,
    required this.catalog,
    this._sourceReader,
  }) : _mgrsConverter = mgrsConverter ?? PeakMgrsConverter.fromLatLng,
       _markerStore = markerStore ?? const PeakRegionImportMarkerStore();

  final PeakRegionMgrsConverter _mgrsConverter;
  final PeakRegionImportMarkerStore _markerStore;
  final MappingCatalog catalog;
  final PeakRegionSourceReader? _sourceReader;

  Future<PeakRegionAssetImportResult> syncOnStartup({
    required PeakRepository peakRepository,
  }) async {
    await migrateLegacyFingerprints(peakRepository: peakRepository);
    if (!peakRepository.isEmpty()) {
      return _emptyResult;
    }
    return _seedCatalogRegions(
      peakRepository: peakRepository,
      catalog: catalog,
    );
  }

  Future<PeakRegionAssetImportResult> seedIfRepositoryEmpty({
    required PeakRepository peakRepository,
  }) async {
    if (!peakRepository.isEmpty()) {
      return _emptyResult;
    }
    return _seedCatalogRegions(
      peakRepository: peakRepository,
      catalog: catalog,
    );
  }

  static const _emptyResult = PeakRegionAssetImportResult(
    importedRegions: [],
    importedPeakCount: 0,
    skippedPeakCount: 0,
  );

  List<String> changedSeedableRegionKeys({
    required PeakRepository peakRepository,
  }) {
    final fingerprints = peakRepository.regionFingerprints();
    return List.unmodifiable([
      for (final region in _seedableCatalogRegions(catalog))
        if (fingerprints[region.key] != region.fingerprint) region.key,
    ]);
  }

  List<String> seedableRegionKeys() {
    return List.unmodifiable(
      _seedableCatalogRegions(catalog).map((region) => region.key),
    );
  }

  Future<PeakRegionAssetImportResult> seedRegion({
    required PeakRepository peakRepository,
    required String regionKey,
  }) {
    return updateRegion(peakRepository: peakRepository, regionKey: regionKey);
  }

  Future<void> migrateLegacyFingerprints({
    required PeakRepository peakRepository,
  }) async {
    final legacy = await _markerStore.loadFingerprints();
    final seedableByKey = {
      for (final region in _seedableCatalogRegions(catalog)) region.key: region,
    };
    final valid = <String, String>{
      for (final entry in legacy.entries)
        if (seedableByKey.containsKey(entry.key) &&
            entry.value.trim().isNotEmpty)
          entry.key: entry.value.trim(),
    };
    if (valid.isEmpty) {
      return;
    }
    await peakRepository.migrateRegionFingerprints(valid);
    await _markerStore.removeFingerprints();
  }

  Future<PeakRegionAssetImportResult> updateRegion({
    required PeakRepository peakRepository,
    required String regionKey,
  }) async {
    final region = catalog.regionByKey(regionKey);
    if (region == null || !_isCatalogRegionSeedable(region)) {
      throw ArgumentError.value(regionKey, 'regionKey', 'is not seedable');
    }
    return _importCatalogRegion(peakRepository: peakRepository, region: region);
  }

  Future<PeakRegionAssetImportResult> _seedCatalogRegions({
    required PeakRepository peakRepository,
    required MappingCatalog catalog,
  }) async {
    final results = <PeakRegionAssetImportResult>[];
    for (final region in _seedableCatalogRegions(catalog)) {
      results.add(
        await _importCatalogRegion(
          peakRepository: peakRepository,
          region: region,
        ),
      );
    }
    return _combineResults(results);
  }

  Future<PeakRegionAssetImportResult> _importCatalogRegion({
    required PeakRepository peakRepository,
    required MappingCatalogRegion region,
  }) async {
    final paths = region.peaks;
    final imported = <Peak>[];
    var skipped = 0;
    for (final path in paths) {
      final result = await _loadCatalogRegionSource(region: region, path: path);
      imported.addAll(result.peaks);
      skipped += result.skippedPeakCount;
    }
    final ids = <int>{};
    for (final peak in imported) {
      if (!ids.add(peak.osmId)) {
        throw MappingStoreOperationException(paths: paths);
      }
    }
    try {
      await peakRepository.reconcileOsmRegion(
        regionKey: region.key,
        fingerprint: region.fingerprint!,
        incomingPeaks: imported,
        validRegionKeys: catalog.regions
            .map((candidate) => candidate.key)
            .toSet(),
      );
    } on MappingStoreOperationException {
      rethrow;
    } on Object catch (error) {
      throw MappingStoreOperationException(paths: paths, cause: error);
    }
    return PeakRegionAssetImportResult(
      importedRegions: [region.key],
      importedPeakCount: imported.length,
      skippedPeakCount: skipped,
    );
  }

  Future<_RegionAssetLoadResult> _loadCatalogRegionSource({
    required MappingCatalogRegion region,
    required String path,
  }) async {
    try {
      final source = await _readCatalogSource(path);
      final decoded = jsonDecode(source);
      if (decoded is! Map || decoded['elements'] is! List) {
        throw const FormatException(
          'Peak source must contain an elements list.',
        );
      }
      final peaks = <Peak>[];
      var skipped = 0;
      for (final element in decoded['elements'] as List) {
        if (element is! Map) {
          throw const FormatException('Peak source elements must be objects.');
        }
        final value = Map<String, dynamic>.from(element);
        final tags = value['tags'];
        final isPeak =
            value['type'] == 'node' && tags is Map && tags['natural'] == 'peak';
        if (!isPeak) {
          skipped += 1;
          continue;
        }
        peaks.add(_parseCatalogPeak(value, region: region, path: path));
      }
      return _RegionAssetLoadResult(peaks: peaks, skippedPeakCount: skipped);
    } on MappingStoreOperationException {
      rethrow;
    } on Object catch (error) {
      throw MappingStoreOperationException(paths: [path], cause: error);
    }
  }

  Peak _parseCatalogPeak(
    Map<String, dynamic> value, {
    required MappingCatalogRegion region,
    required String path,
  }) {
    final id = value['id'];
    final tags = value['tags'];
    final name = tags is Map ? tags['name'] : null;
    final lat = value['lat'];
    final lon = value['lon'];
    if (id is! int ||
        id <= 0 ||
        name is! String ||
        name.trim().isEmpty ||
        lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      throw FormatException('Invalid peak record in $path.');
    }
    final base = Peak(
      osmId: id,
      name: name.trim(),
      elevation: _parseElevation(tags['ele']),
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      region: region.key,
      sourceOfTruth: Peak.sourceOfTruthOsm,
    );
    final enriched = _enrichPeak(base);
    if (enriched == null) {
      throw FormatException('Unable to derive MGRS fields in $path.');
    }
    return enriched;
  }

  double? _parseElevation(Object? value) {
    if (value is num && value.isFinite) {
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      return parsed?.isFinite == true ? parsed : null;
    }
    return null;
  }

  Future<String> _readCatalogSource(String path) {
    final reader = _sourceReader;
    if (reader != null) {
      return reader(path);
    }
    return MappingStoreOperationFileAccess(
      rootPath: catalog.rootPath,
      fileSystem: const IoMappingStoreFileSystem(),
    ).readText(path);
  }

  List<MappingCatalogRegion> _seedableCatalogRegions(MappingCatalog catalog) {
    return List.unmodifiable(catalog.regions.where(_isCatalogRegionSeedable));
  }

  bool _isCatalogRegionSeedable(MappingCatalogRegion region) {
    return !region.composite &&
        region.seedOnStartup &&
        region.fingerprint != null &&
        region.fingerprint!.trim().isNotEmpty &&
        region.peaks.isNotEmpty;
  }

  PeakRegionAssetImportResult _combineResults(
    List<PeakRegionAssetImportResult> results,
  ) {
    if (results.isEmpty) {
      return _emptyResult;
    }
    return PeakRegionAssetImportResult(
      importedRegions: [
        for (final result in results) ...result.importedRegions,
      ],
      importedPeakCount: results.fold(
        0,
        (count, result) => count + result.importedPeakCount,
      ),
      skippedPeakCount: results.fold(
        0,
        (count, result) => count + result.skippedPeakCount,
      ),
    );
  }

  Future<bool> backfillStoredPeaks({
    required PeakRepository peakRepository,
  }) async {
    final peaks = peakRepository.getAllPeaks();
    if (peaks.isEmpty || peaks.every(_hasMgrsFields)) {
      return false;
    }
    final updated = <Peak>[];
    var changed = false;
    for (final peak in peaks) {
      if (_hasMgrsFields(peak)) {
        updated.add(peak);
        continue;
      }
      final enriched = _enrichPeak(peak);
      if (enriched == null) {
        updated.add(peak);
        continue;
      }
      updated.add(enriched);
      changed = true;
    }
    if (changed) {
      await peakRepository.replaceAll(updated);
    }
    return changed;
  }

  bool _hasMgrsFields(Peak peak) {
    return peak.gridZoneDesignator.isNotEmpty &&
        peak.mgrs100kId.isNotEmpty &&
        peak.easting.isNotEmpty &&
        peak.northing.isNotEmpty;
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

class _RegionAssetLoadResult {
  const _RegionAssetLoadResult({
    required this.peaks,
    required this.skippedPeakCount,
  });

  final List<Peak> peaks;
  final int skippedPeakCount;
}
