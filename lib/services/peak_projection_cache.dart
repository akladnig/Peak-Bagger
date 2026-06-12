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
    PeakClusterAlgorithm algorithm = MapConstants.peakClusterAlgorithm,
  }) {
    final key = _PeakProjectionCacheKey(
      center: camera.center,
      zoom: camera.zoom,
      size: camera.nonRotatedSize,
      peakIds: [for (final peak in peaks) peak.osmId],
      correlatedPeakIds: correlatedPeakIds.toList(growable: false)..sort(),
      algorithm: algorithm,
    );
    if (_key == key && _data != null) {
      return _data!;
    }

    final data = switch (algorithm) {
      PeakClusterAlgorithm.supercluster => _buildSuperclusterViewportData(
        peaks: peaks,
        camera: camera,
        correlatedPeakIds: correlatedPeakIds,
      ),
      _ => buildPeakClusterViewportData(
        peaks: peaks,
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
    final key = _PeakSuperclusterIndexKey(
      peakIds: [for (final peak in peaks) peak.osmId],
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
  }
}

class _PeakProjectionCacheKey {
  const _PeakProjectionCacheKey({
    required this.center,
    required this.zoom,
    required this.size,
    required this.peakIds,
    required this.correlatedPeakIds,
    required this.algorithm,
  });

  final LatLng center;
  final double zoom;
  final Size size;
  final List<int> peakIds;
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
            _listEquals(other.peakIds, peakIds) &&
            _listEquals(other.correlatedPeakIds, correlatedPeakIds);
  }

  @override
  int get hashCode => Object.hash(
    center,
    zoom,
    size,
    algorithm,
    Object.hashAll(peakIds),
    Object.hashAll(correlatedPeakIds),
  );
}

class _PeakSuperclusterIndexKey {
  const _PeakSuperclusterIndexKey({
    required this.peakIds,
    required this.correlatedPeakIds,
  });

  final List<int> peakIds;
  final List<int> correlatedPeakIds;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _PeakSuperclusterIndexKey &&
            _listEquals(other.peakIds, peakIds) &&
            _listEquals(other.correlatedPeakIds, correlatedPeakIds);
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(peakIds), Object.hashAll(correlatedPeakIds));
}

bool _listEquals(List<int> left, List<int> right) {
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
