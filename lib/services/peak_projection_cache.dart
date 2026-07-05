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

  PeakClusterViewportData getOrBuild({
    required List<Peak> peaks,
    required MapCamera camera,
    required Set<int> correlatedPeakIds,
    required Map<int, int> untickedPeakColours,
    bool clusteringEnabled = true,
    PeakClusterAlgorithm algorithm = MapConstants.peakClusterAlgorithm,
  }) {
    final peakFingerprints = _peakRenderFingerprints(peaks);
    final key = _PeakProjectionCacheKey(
      center: camera.center,
      zoom: camera.zoom,
      size: camera.nonRotatedSize,
      peakFingerprints: peakFingerprints,
      correlatedPeakIds: correlatedPeakIds.toList(growable: false)..sort(),
      untickedPeakColours: untickedPeakColours.entries
          .map((entry) => (entry.key, entry.value))
          .toList(growable: false)
        ..sort((left, right) => left.$1.compareTo(right.$1)),
      clusteringEnabled: clusteringEnabled,
      algorithm: algorithm,
    );
    if (_key == key && _data != null) {
      return _data!;
    }

    final data = clusteringEnabled
        ? switch (algorithm) {
            PeakClusterAlgorithm.supercluster => _buildSuperclusterViewportData(
              peaks: peaks,
              camera: camera,
              correlatedPeakIds: correlatedPeakIds,
              untickedPeakColours: untickedPeakColours,
            ),
            _ => buildPeakClusterViewportData(
              peaks: peaks,
              camera: camera,
              correlatedPeakIds: correlatedPeakIds,
              untickedPeakColours: untickedPeakColours,
              algorithm: algorithm,
            ),
          }
        : buildUnclusteredPeakViewportData(
            peaks: peaks,
            camera: camera,
            correlatedPeakIds: correlatedPeakIds,
            untickedPeakColours: untickedPeakColours,
          );
    _key = key;
    _data = data;
    return data;
  }

  PeakClusterViewportData _buildSuperclusterViewportData({
    required List<Peak> peaks,
    required MapCamera camera,
    required Set<int> correlatedPeakIds,
    required Map<int, int> untickedPeakColours,
  }) {
    final peakFingerprints = _peakRenderFingerprints(peaks);
    final key = _PeakSuperclusterIndexKey(
      peakFingerprints: peakFingerprints,
      correlatedPeakIds: correlatedPeakIds.toList(growable: false)..sort(),
      untickedPeakColours: untickedPeakColours.entries
          .map((entry) => (entry.key, entry.value))
          .toList(growable: false)
        ..sort((left, right) => left.$1.compareTo(right.$1)),
    );
    if (_superclusterKey != key || _superclusterIndex == null) {
      _superclusterKey = key;
      _superclusterIndex = buildPeakSuperclusterIndex(
        peaks: peaks,
        correlatedPeakIds: correlatedPeakIds,
        untickedPeakColours: untickedPeakColours,
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
  }
}

class _PeakProjectionCacheKey {
  const _PeakProjectionCacheKey({
    required this.center,
    required this.zoom,
    required this.size,
    required this.peakFingerprints,
    required this.correlatedPeakIds,
    required this.untickedPeakColours,
    required this.clusteringEnabled,
    required this.algorithm,
  });

  final LatLng center;
  final double zoom;
  final Size size;
  final List<String> peakFingerprints;
  final List<int> correlatedPeakIds;
  final List<(int, int)> untickedPeakColours;
  final bool clusteringEnabled;
  final PeakClusterAlgorithm algorithm;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _PeakProjectionCacheKey &&
            other.center == center &&
            other.zoom == zoom &&
            other.size == size &&
            other.clusteringEnabled == clusteringEnabled &&
            other.algorithm == algorithm &&
            _listEquals(other.peakFingerprints, peakFingerprints) &&
            _listEquals(other.correlatedPeakIds, correlatedPeakIds) &&
            _listEquals(other.untickedPeakColours, untickedPeakColours);
  }

  @override
  int get hashCode => Object.hash(
    center,
      zoom,
      size,
      clusteringEnabled,
      algorithm,
      Object.hashAll(peakFingerprints),
      Object.hashAll(correlatedPeakIds),
      Object.hashAll(untickedPeakColours),
    );
}

class _PeakSuperclusterIndexKey {
  const _PeakSuperclusterIndexKey({
    required this.peakFingerprints,
    required this.correlatedPeakIds,
    required this.untickedPeakColours,
  });

  final List<String> peakFingerprints;
  final List<int> correlatedPeakIds;
  final List<(int, int)> untickedPeakColours;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _PeakSuperclusterIndexKey &&
            _listEquals(other.peakFingerprints, peakFingerprints) &&
            _listEquals(other.correlatedPeakIds, correlatedPeakIds) &&
            _listEquals(other.untickedPeakColours, untickedPeakColours);
  }

  @override
  int get hashCode =>
      Object.hash(
        Object.hashAll(peakFingerprints),
        Object.hashAll(correlatedPeakIds),
        Object.hashAll(untickedPeakColours),
      );
}

List<String> _peakRenderFingerprints(Iterable<Peak> peaks) {
  return [for (final peak in peaks) _peakRenderFingerprint(peak)];
}

String _peakRenderFingerprint(Peak peak) {
  return [
    peak.osmId,
    peak.latitude,
    peak.longitude,
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
