import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_refresh_result.dart';
import 'package:peak_bagger/services/peak_repository.dart';

typedef PeakMgrsConverterFn = PeakMgrsComponents Function(LatLng location);

class PeakRefreshService {
  PeakRefreshService(
    this._overpassService,
    this._peakRepository, {
    PeakMgrsConverterFn? converter,
  }) : _converter = converter ?? PeakMgrsConverter.fromLatLng;

  final OverpassService _overpassService;
  final PeakRepository _peakRepository;
  final PeakMgrsConverterFn _converter;

  Future<PeakRefreshResult> refreshPeaks() async {
    final peaks = await _overpassService.fetchTasmaniaPeaks();
    if (peaks.isEmpty) {
      throw StateError('No peaks imported');
    }

    final enrichedPeaks = <Peak>[];
    var skippedCount = 0;

    for (final peak in peaks) {
      final enrichedPeak = _enrichPeak(peak);
      if (enrichedPeak == null) {
        skippedCount += 1;
        continue;
      }
      enrichedPeaks.add(enrichedPeak);
    }

    if (enrichedPeaks.isEmpty) {
      throw StateError('No valid peaks');
    }

    await _peakRepository.replaceAll(enrichedPeaks);

    return PeakRefreshResult(
      importedCount: enrichedPeaks.length,
      skippedCount: skippedCount,
      warning: skippedCount > 0 ? '$skippedCount peaks skipped' : null,
    );
  }

  Future<bool> backfillStoredPeaks() async {
    final peaks = _peakRepository.getAllPeaks();
    if (peaks.isEmpty || peaks.every(_hasMgrsFields)) {
      return false;
    }

    final updatedPeaks = <Peak>[];
    var changed = false;

    for (final peak in peaks) {
      if (_hasMgrsFields(peak)) {
        updatedPeaks.add(peak);
        continue;
      }

      final enrichedPeak = _enrichPeak(peak);
      if (enrichedPeak == null) {
        updatedPeaks.add(peak);
        continue;
      }

      updatedPeaks.add(enrichedPeak);
      changed = true;
    }

    if (!changed) {
      return false;
    }

    await _peakRepository.replaceAll(updatedPeaks);
    return true;
  }

  Peak? _enrichPeak(Peak peak) {
    try {
      final components = _converter(LatLng(peak.latitude, peak.longitude));
      if (kDebugMode) {
        debugPrint('Peak ${peak.name}: $components');
      }
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

  bool _hasMgrsFields(Peak peak) {
    return peak.gridZoneDesignator.isNotEmpty &&
        peak.mgrs100kId.isNotEmpty &&
        peak.easting.isNotEmpty &&
        peak.northing.isNotEmpty;
  }
}
