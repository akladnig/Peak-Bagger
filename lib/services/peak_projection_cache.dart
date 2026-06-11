import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';

class PeakProjectionCache {
  _PeakProjectionCacheKey? _key;
  PeakClusterViewportData? _data;

  PeakClusterViewportData getOrBuild({
    required List<Peak> peaks,
    required MapCamera camera,
    required Set<int> correlatedPeakIds,
  }) {
    final key = _PeakProjectionCacheKey(
      center: camera.center,
      zoom: camera.zoom,
      size: camera.nonRotatedSize,
      peakIds: [for (final peak in peaks) peak.osmId],
      correlatedPeakIds: correlatedPeakIds.toList(growable: false)..sort(),
    );
    if (_key == key && _data != null) {
      return _data!;
    }

    final data = buildPeakClusterViewportData(
      peaks: peaks,
      camera: camera,
      correlatedPeakIds: correlatedPeakIds,
    );
    _key = key;
    _data = data;
    return data;
  }

  void clear() {
    _key = null;
    _data = null;
  }
}

class _PeakProjectionCacheKey {
  const _PeakProjectionCacheKey({
    required this.center,
    required this.zoom,
    required this.size,
    required this.peakIds,
    required this.correlatedPeakIds,
  });

  final LatLng center;
  final double zoom;
  final Size size;
  final List<int> peakIds;
  final List<int> correlatedPeakIds;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _PeakProjectionCacheKey &&
            other.center == center &&
            other.zoom == zoom &&
            other.size == size &&
            _listEquals(other.peakIds, peakIds) &&
            _listEquals(other.correlatedPeakIds, correlatedPeakIds);
  }

  @override
  int get hashCode => Object.hash(
    center,
    zoom,
    size,
    Object.hashAll(peakIds),
    Object.hashAll(correlatedPeakIds),
  );
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
