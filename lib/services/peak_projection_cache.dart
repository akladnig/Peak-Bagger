import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';

class PeakProjectionCache {
  _PeakProjectionCacheKey? _key;
  PeakClusterViewportData? _data;
  _PeakSuperclusterIndexKey? _superclusterKey;
  PeakSuperclusterIndex? _superclusterIndex;
  final Map<int, LatLng> _stablePeakLocationsById = {};

  PeakClusterViewportData getOrBuild({
    required List<Peak> peaks,
    required MapCamera camera,
    required Set<int> correlatedPeakIds,
    PeakClusterAlgorithm algorithm = MapConstants.peakClusterAlgorithm,
  }) {
    final stablePeaks = _stablePeaks(peaks);
    final peakFingerprints = _peakRenderFingerprints(stablePeaks);
    final key = _PeakProjectionCacheKey(
      center: camera.center,
      zoom: camera.zoom,
      size: camera.nonRotatedSize,
      peakFingerprints: peakFingerprints,
      correlatedPeakIds: correlatedPeakIds.toList(growable: false)..sort(),
      algorithm: algorithm,
    );
    if (_key == key && _data != null) {
      return _data!;
    }

    final data = switch (algorithm) {
      PeakClusterAlgorithm.supercluster => _buildSuperclusterViewportData(
        peaks: stablePeaks,
        camera: camera,
        correlatedPeakIds: correlatedPeakIds,
      ),
      _ => buildPeakClusterViewportData(
        peaks: stablePeaks,
        camera: camera,
        correlatedPeakIds: correlatedPeakIds,
        algorithm: algorithm,
      ),
    };
    _key = key;
    _data = data;
    return data;
  }

  PeakClusterViewportData _buildSuperclusterViewportData({
    required List<Peak> peaks,
    required MapCamera camera,
    required Set<int> correlatedPeakIds,
  }) {
    final peakFingerprints = _peakRenderFingerprints(peaks);
    final key = _PeakSuperclusterIndexKey(
      peakFingerprints: peakFingerprints,
      correlatedPeakIds: correlatedPeakIds.toList(growable: false)..sort(),
    );
    if (_superclusterKey != key || _superclusterIndex == null) {
      _superclusterKey = key;
      _superclusterIndex = buildPeakSuperclusterIndex(
        peaks: peaks,
        correlatedPeakIds: correlatedPeakIds,
      );
    }

    return buildPeakClusterViewportDataFromSuperclusterIndex(
      index: _superclusterIndex!,
      camera: camera,
    );
  }

  void clear() {
    _key = null;
    _data = null;
    _superclusterKey = null;
    _superclusterIndex = null;
    _stablePeakLocationsById.clear();
  }

  List<Peak> _stablePeaks(List<Peak> peaks) {
    return [for (final peak in peaks) _stablePeakFor(peak)];
  }

  Peak _stablePeakFor(Peak peak) {
    final stableLocation = _stablePeakLocationsById[peak.osmId];
    if (stableLocation == null) {
      _stablePeakLocationsById[peak.osmId] = LatLng(
        peak.latitude,
        peak.longitude,
      );
      return peak;
    }

    if (peak.latitude == stableLocation.latitude &&
        peak.longitude == stableLocation.longitude) {
      return peak;
    }

    return peak.copyWith(
      latitude: stableLocation.latitude,
      longitude: stableLocation.longitude,
    );
  }
}

class _PeakProjectionCacheKey {
  const _PeakProjectionCacheKey({
    required this.center,
    required this.zoom,
    required this.size,
    required this.peakFingerprints,
    required this.correlatedPeakIds,
    required this.algorithm,
  });

  final LatLng center;
  final double zoom;
  final Size size;
  final List<String> peakFingerprints;
  final List<int> correlatedPeakIds;
  final PeakClusterAlgorithm algorithm;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _PeakProjectionCacheKey &&
            other.center == center &&
            other.zoom == zoom &&
            other.size == size &&
            other.algorithm == algorithm &&
            _listEquals(other.peakFingerprints, peakFingerprints) &&
            _listEquals(other.correlatedPeakIds, correlatedPeakIds);
  }

  @override
  int get hashCode => Object.hash(
    center,
    zoom,
    size,
    algorithm,
    Object.hashAll(peakFingerprints),
    Object.hashAll(correlatedPeakIds),
  );
}

class _PeakSuperclusterIndexKey {
  const _PeakSuperclusterIndexKey({
    required this.peakFingerprints,
    required this.correlatedPeakIds,
  });

  final List<String> peakFingerprints;
  final List<int> correlatedPeakIds;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _PeakSuperclusterIndexKey &&
            _listEquals(other.peakFingerprints, peakFingerprints) &&
            _listEquals(other.correlatedPeakIds, correlatedPeakIds);
  }

  @override
  int get hashCode =>
      Object.hash(
        Object.hashAll(peakFingerprints),
        Object.hashAll(correlatedPeakIds),
      );
}

List<String> _peakRenderFingerprints(Iterable<Peak> peaks) {
  return [for (final peak in peaks) _peakRenderFingerprint(peak)];
}

String _peakRenderFingerprint(Peak peak) {
  return [
    peak.osmId,
    peak.name,
    peak.elevation,
    peak.prominence,
  ].join('|');
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}
