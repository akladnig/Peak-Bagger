import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_region_import_marker_store.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peak_source_precedence.dart';
import 'peak_source_parser.dart';

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
    final shadowedIds = <int>{};
    for (final preferredKey
        in preferredPeakSourceRegions[region.key] ?? const <String>[]) {
      final preferred = catalog.regionByKey(preferredKey);
      if (preferred != null && _isCatalogRegionSeedable(preferred)) {
        final preferredIds = <int>{};
        for (final path in preferred.peaks) {
          final result = await _loadCatalogRegionSource(
            region: preferred,
            path: path,
          );
          for (final peak in result.peaks) {
            if (!preferredIds.add(peak.osmId)) {
              throw MappingStoreOperationException(paths: preferred.peaks);
            }
          }
        }
        shadowedIds.addAll(ids.intersection(preferredIds));
      }
    }
    imported.removeWhere((peak) => shadowedIds.contains(peak.osmId));
    skipped += shadowedIds.length;
    try {
      await peakRepository.reconcileOsmRegion(
        regionKey: region.key,
        fingerprint: region.fingerprint!,
        incomingPeaks: imported,
        retainedOsmIds: shadowedIds,
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
      final result = parsePeakSource(
        source,
        regionKey: region.key,
        path: path,
        mgrsConverter: _mgrsConverter,
      );
      return _RegionAssetLoadResult(
        peaks: result.peaks,
        skippedPeakCount: result.skippedPeakCount,
      );
    } on MappingStoreOperationException {
      rethrow;
    } on Object catch (error) {
      throw MappingStoreOperationException(paths: [path], cause: error);
    }
  }

  Future<String> _readCatalogSource(String path) {
    final reader = _sourceReader;
    if (reader != null) {
      return reader(path);
    }
    return MappingStoreOperationFileAccess(
      catalog: catalog,
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
