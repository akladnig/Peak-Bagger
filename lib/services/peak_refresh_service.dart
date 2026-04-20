import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_refresh_result.dart';
import 'package:peak_bagger/services/peak_repository.dart';

typedef PeakMgrsConverterFn = PeakMgrsComponents Function(LatLng location);

class PeakRefreshService {
  static const _syntheticOsmMatchDistanceMeters = 2000.0;

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

    final existingPeaks = _peakRepository.getAllPeaks();
    final existingPeaksByOsmId = <int, Peak>{
      for (final peak in existingPeaks)
        if (peak.osmId != 0) peak.osmId: peak,
    };
    final syntheticProtectedMatchesByOsmId = _matchSyntheticProtectedPeaks(
      existingPeaks: existingPeaks,
      refreshedPeaks: peaks,
      existingPeaksByOsmId: existingPeaksByOsmId,
    );
    final refreshedPeaks = <Peak>[];
    final seenExistingOsmIds = <int>{};
    var skippedCount = 0;

    for (final peak in peaks) {
      final existingPeak = existingPeaksByOsmId[peak.osmId];
      if (existingPeak != null && !_isRefreshEligible(existingPeak)) {
        refreshedPeaks.add(_preparePreservedPeak(existingPeak));
        seenExistingOsmIds.add(existingPeak.osmId);
        continue;
      }

      final matchedSyntheticPeak = syntheticProtectedMatchesByOsmId[peak.osmId];
      if (matchedSyntheticPeak != null) {
        refreshedPeaks.add(
          _preparePreservedPeak(
            matchedSyntheticPeak,
          ).copyWith(osmId: peak.osmId),
        );
        seenExistingOsmIds.add(matchedSyntheticPeak.osmId);
        continue;
      }

      final enrichedPeak = _enrichPeak(
        peak.copyWith(sourceOfTruth: Peak.sourceOfTruthOsm),
      );
      if (enrichedPeak == null) {
        skippedCount += 1;
        continue;
      }
      refreshedPeaks.add(enrichedPeak);
      final matchedExistingPeak = existingPeaksByOsmId[enrichedPeak.osmId];
      if (matchedExistingPeak != null) {
        seenExistingOsmIds.add(matchedExistingPeak.osmId);
      }
    }

    for (final peak in existingPeaks) {
      if (seenExistingOsmIds.contains(peak.osmId)) {
        continue;
      }
      refreshedPeaks.add(_preparePreservedPeak(peak));
    }

    if (refreshedPeaks.isEmpty) {
      throw StateError('No valid peaks');
    }

    final renumberedPeaks = _renumberRefreshPeaks(refreshedPeaks);

    await _peakRepository.replaceAll(
      renumberedPeaks,
      preserveExistingIds: false,
    );

    return PeakRefreshResult(
      importedCount: renumberedPeaks.length,
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

  bool _isRefreshEligible(Peak peak) {
    return peak.sourceOfTruth.isEmpty ||
        peak.sourceOfTruth == Peak.sourceOfTruthOsm;
  }

  Map<int, Peak> _matchSyntheticProtectedPeaks({
    required List<Peak> existingPeaks,
    required List<Peak> refreshedPeaks,
    required Map<int, Peak> existingPeaksByOsmId,
  }) {
    final protectedSyntheticPeaks = existingPeaks
        .where((peak) {
          return peak.osmId < 0 && peak.sourceOfTruth == Peak.sourceOfTruthHwc;
        })
        .toList(growable: false);
    final matches = <int, Peak>{};
    final matchedSyntheticOsmIds = <int>{};

    for (final refreshedPeak in refreshedPeaks) {
      if (refreshedPeak.osmId <= 0 ||
          existingPeaksByOsmId.containsKey(refreshedPeak.osmId)) {
        continue;
      }

      final candidates = protectedSyntheticPeaks
          .where((peak) {
            if (matchedSyntheticOsmIds.contains(peak.osmId)) {
              return false;
            }

            return _normalizeName(peak.name) ==
                    _normalizeName(refreshedPeak.name) &&
                haversineDistance(
                      peak.latitude,
                      peak.longitude,
                      refreshedPeak.latitude,
                      refreshedPeak.longitude,
                    ) <=
                    _syntheticOsmMatchDistanceMeters;
          })
          .toList(growable: false);

      if (candidates.length != 1) {
        continue;
      }

      final matchedPeak = candidates.single;
      matches[refreshedPeak.osmId] = matchedPeak;
      matchedSyntheticOsmIds.add(matchedPeak.osmId);
    }

    return matches;
  }

  String _normalizeName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Peak _preparePreservedPeak(Peak peak) {
    return Peak(
      id: peak.id,
      osmId: peak.osmId,
      name: peak.name,
      elevation: peak.elevation,
      latitude: peak.latitude,
      longitude: peak.longitude,
      area: peak.area,
      gridZoneDesignator: peak.gridZoneDesignator,
      mgrs100kId: peak.mgrs100kId,
      easting: peak.easting,
      northing: peak.northing,
      sourceOfTruth: peak.sourceOfTruth,
    );
  }

  List<Peak> _renumberRefreshPeaks(List<Peak> peaks) {
    final idsByOsmId = <int, int>{};
    var nextId = 1;

    for (final peak in peaks) {
      if (peak.sourceOfTruth == Peak.sourceOfTruthHwc) {
        idsByOsmId[peak.osmId] = nextId++;
      }
    }
    for (final peak in peaks) {
      idsByOsmId.putIfAbsent(peak.osmId, () => nextId++);
    }

    return peaks
        .map((peak) {
          return _clonePeakWithId(peak, idsByOsmId[peak.osmId]!);
        })
        .toList(growable: false);
  }

  Peak _clonePeakWithId(Peak peak, int id) {
    return Peak(
      id: id,
      osmId: peak.osmId,
      name: peak.name,
      elevation: peak.elevation,
      latitude: peak.latitude,
      longitude: peak.longitude,
      area: peak.area,
      gridZoneDesignator: peak.gridZoneDesignator,
      mgrs100kId: peak.mgrs100kId,
      easting: peak.easting,
      northing: peak.northing,
      sourceOfTruth: peak.sourceOfTruth,
    );
  }
}
