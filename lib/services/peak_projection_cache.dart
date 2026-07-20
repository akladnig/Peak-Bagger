import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_ownership_ring_segment.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';
import 'package:peak_bagger/widgets/map_rebuild_debug_counters.dart';

class PeakProjectionCache {
  _PeakProjectionCacheKey? _key;
  PeakClusterViewportData? _data;
  _PeakSuperclusterIndexKey? _superclusterKey;
  PeakSuperclusterIndex? _superclusterIndex;
  final _correlatedPeakIdsCache = _IntSetFingerprintCache();
  final _untickedPeakColoursCache = _IntMapFingerprintCache();
  final _activeOwnershipSegmentsCache = _OwnershipSegmentsMapFingerprintCache();
  final _ownershipRingSegmentsCache = _OwnershipSegmentsMapFingerprintCache();
  Expando<_PeakRenderFingerprintCacheEntry> _peakFingerprintEntries =
      Expando<_PeakRenderFingerprintCacheEntry>();
  Expando<String> _ownershipRingFingerprintEntries = Expando<String>();

  PeakClusterViewportData getOrBuild({
    required List<Peak> peaks,
    required MapCamera camera,
    required Set<int> correlatedPeakIds,
    required Map<int, int> untickedPeakColours,
    Map<int, List<PeakOwnershipRingSegment>> activeOwnershipSegments =
        const <int, List<PeakOwnershipRingSegment>>{},
    Map<int, List<PeakOwnershipRingSegment>> ownershipRingSegments =
        const <int, List<PeakOwnershipRingSegment>>{},
    bool clusteringEnabled = true,
    PeakClusterAlgorithm algorithm = MapConstants.peakClusterAlgorithm,
  }) {
    final peakFingerprints = _peakRenderFingerprints(peaks);
    final sortedCorrelatedPeakIds = _correlatedPeakIdsCache.getOrBuild(
      correlatedPeakIds,
    );
    final sortedUntickedPeakColours = _untickedPeakColoursCache.getOrBuild(
      untickedPeakColours,
    );
    final sortedActiveOwnershipSegments = _activeOwnershipSegmentsCache
        .getOrBuild(activeOwnershipSegments, _ownershipRingSegmentsFingerprint);
    final sortedOwnershipRingSegments = _ownershipRingSegmentsCache.getOrBuild(
      ownershipRingSegments,
      _ownershipRingSegmentsFingerprint,
    );

    final key = _PeakProjectionCacheKey(
      center: camera.center,
      zoom: camera.zoom,
      size: camera.nonRotatedSize,
      peakFingerprints: peakFingerprints,
      correlatedPeakIds: sortedCorrelatedPeakIds,
      untickedPeakColours: sortedUntickedPeakColours,
      activeOwnershipSegments: sortedActiveOwnershipSegments,
      ownershipRingSegments: sortedOwnershipRingSegments,
      clusteringEnabled: clusteringEnabled,
      algorithm: algorithm,
    );
    if (_key == key && _data != null) {
      return _data!;
    }

    MapRebuildDebugCounters.recordPeakProjectionBuild();
    final data = clusteringEnabled
        ? switch (algorithm) {
            PeakClusterAlgorithm.supercluster => _buildSuperclusterViewportData(
              peaks: peaks,
              camera: camera,
              peakFingerprints: peakFingerprints,
              sortedCorrelatedPeakIds: sortedCorrelatedPeakIds,
              sortedUntickedPeakColours: sortedUntickedPeakColours,
              sortedActiveOwnershipSegments: sortedActiveOwnershipSegments,
              sortedOwnershipRingSegments: sortedOwnershipRingSegments,
              correlatedPeakIds: correlatedPeakIds,
              untickedPeakColours: untickedPeakColours,
              activeOwnershipSegments: activeOwnershipSegments,
              ownershipRingSegments: ownershipRingSegments,
            ),
            _ => buildPeakClusterViewportData(
              peaks: peaks,
              camera: camera,
              correlatedPeakIds: correlatedPeakIds,
              untickedPeakColours: untickedPeakColours,
              activeOwnershipSegments: activeOwnershipSegments,
              ownershipRingSegments: ownershipRingSegments,
              algorithm: algorithm,
            ),
          }
        : buildUnclusteredPeakViewportData(
            peaks: peaks,
            camera: camera,
            correlatedPeakIds: correlatedPeakIds,
            untickedPeakColours: untickedPeakColours,
            activeOwnershipSegments: activeOwnershipSegments,
            ownershipRingSegments: ownershipRingSegments,
          );
    _key = key;
    _data = data;
    return data;
  }

  PeakClusterViewportData _buildSuperclusterViewportData({
    required List<Peak> peaks,
    required MapCamera camera,
    required List<String> peakFingerprints,
    required List<int> sortedCorrelatedPeakIds,
    required List<(int, int)> sortedUntickedPeakColours,
    required List<(int, String)> sortedActiveOwnershipSegments,
    required List<(int, String)> sortedOwnershipRingSegments,
    required Set<int> correlatedPeakIds,
    required Map<int, int> untickedPeakColours,
    required Map<int, List<PeakOwnershipRingSegment>> activeOwnershipSegments,
    required Map<int, List<PeakOwnershipRingSegment>> ownershipRingSegments,
  }) {
    final key = _PeakSuperclusterIndexKey(
      peakFingerprints: peakFingerprints,
      correlatedPeakIds: sortedCorrelatedPeakIds,
      untickedPeakColours: sortedUntickedPeakColours,
      activeOwnershipSegments: sortedActiveOwnershipSegments,
      ownershipRingSegments: sortedOwnershipRingSegments,
    );
    if (_superclusterKey != key || _superclusterIndex == null) {
      _superclusterKey = key;
      _superclusterIndex = buildPeakSuperclusterIndex(
        peaks: peaks,
        correlatedPeakIds: correlatedPeakIds,
        untickedPeakColours: untickedPeakColours,
        activeOwnershipSegments: activeOwnershipSegments,
        ownershipRingSegments: ownershipRingSegments,
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
    _correlatedPeakIdsCache.clear();
    _untickedPeakColoursCache.clear();
    _activeOwnershipSegmentsCache.clear();
    _ownershipRingSegmentsCache.clear();
    _peakFingerprintEntries = Expando<_PeakRenderFingerprintCacheEntry>();
    _ownershipRingFingerprintEntries = Expando<String>();
  }

  List<String> _peakRenderFingerprints(List<Peak> peaks) {
    return [for (final peak in peaks) _peakRenderFingerprint(peak)];
  }

  String _peakRenderFingerprint(Peak peak) {
    final cached = _peakFingerprintEntries[peak];
    if (cached != null && cached.matches(peak)) {
      return cached.fingerprint;
    }

    final fingerprint = [
      peak.osmId,
      peak.latitude,
      peak.longitude,
      peak.name,
      peak.elevation,
      peak.prominence,
    ].join('|');
    _peakFingerprintEntries[peak] = _PeakRenderFingerprintCacheEntry(
      osmId: peak.osmId,
      latitude: peak.latitude,
      longitude: peak.longitude,
      name: peak.name,
      elevation: peak.elevation,
      prominence: peak.prominence,
      fingerprint: fingerprint,
    );
    return fingerprint;
  }

  String _ownershipRingSegmentsFingerprint(
    List<PeakOwnershipRingSegment> segments,
  ) {
    final cached = _ownershipRingFingerprintEntries[segments];
    if (cached != null) {
      return cached;
    }

    final fingerprint = segments
        .map((segment) => '${segment.peakListId}:${segment.colourValue}')
        .join(',');
    _ownershipRingFingerprintEntries[segments] = fingerprint;
    return fingerprint;
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
    required this.activeOwnershipSegments,
    required this.ownershipRingSegments,
    required this.clusteringEnabled,
    required this.algorithm,
  });

  final LatLng center;
  final double zoom;
  final Size size;
  final List<String> peakFingerprints;
  final List<int> correlatedPeakIds;
  final List<(int, int)> untickedPeakColours;
  final List<(int, String)> activeOwnershipSegments;
  final List<(int, String)> ownershipRingSegments;
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
            _listEquals(other.untickedPeakColours, untickedPeakColours) &&
            _listEquals(
              other.activeOwnershipSegments,
              activeOwnershipSegments,
            ) &&
            _listEquals(other.ownershipRingSegments, ownershipRingSegments);
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
    Object.hashAll(activeOwnershipSegments),
    Object.hashAll(ownershipRingSegments),
  );
}

class _PeakSuperclusterIndexKey {
  const _PeakSuperclusterIndexKey({
    required this.peakFingerprints,
    required this.correlatedPeakIds,
    required this.untickedPeakColours,
    required this.activeOwnershipSegments,
    required this.ownershipRingSegments,
  });

  final List<String> peakFingerprints;
  final List<int> correlatedPeakIds;
  final List<(int, int)> untickedPeakColours;
  final List<(int, String)> activeOwnershipSegments;
  final List<(int, String)> ownershipRingSegments;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _PeakSuperclusterIndexKey &&
            _listEquals(other.peakFingerprints, peakFingerprints) &&
            _listEquals(other.correlatedPeakIds, correlatedPeakIds) &&
            _listEquals(other.untickedPeakColours, untickedPeakColours) &&
            _listEquals(
              other.activeOwnershipSegments,
              activeOwnershipSegments,
            ) &&
            _listEquals(other.ownershipRingSegments, ownershipRingSegments);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(peakFingerprints),
    Object.hashAll(correlatedPeakIds),
    Object.hashAll(untickedPeakColours),
    Object.hashAll(activeOwnershipSegments),
    Object.hashAll(ownershipRingSegments),
  );
}

class _IntSetFingerprintCache {
  Set<int>? _source;
  List<int>? _value;

  List<int> getOrBuild(Set<int> source) {
    if (identical(_source, source) && _value != null) {
      return _value!;
    }

    final value = source.toList(growable: false)..sort();
    _source = source;
    _value = value;
    return value;
  }

  void clear() {
    _source = null;
    _value = null;
  }
}

class _IntMapFingerprintCache {
  Map<int, int>? _source;
  List<(int, int)>? _value;

  List<(int, int)> getOrBuild(Map<int, int> source) {
    if (identical(_source, source) && _value != null) {
      return _value!;
    }

    final value =
        source.entries
            .map((entry) => (entry.key, entry.value))
            .toList(growable: false)
          ..sort((left, right) => left.$1.compareTo(right.$1));
    _source = source;
    _value = value;
    return value;
  }

  void clear() {
    _source = null;
    _value = null;
  }
}

class _OwnershipSegmentsMapFingerprintCache {
  Map<int, List<PeakOwnershipRingSegment>>? _source;
  List<(int, String)>? _value;

  List<(int, String)> getOrBuild(
    Map<int, List<PeakOwnershipRingSegment>> source,
    String Function(List<PeakOwnershipRingSegment>) fingerprintFor,
  ) {
    if (identical(_source, source) && _value != null) {
      return _value!;
    }

    final value =
        source.entries
            .map((entry) => (entry.key, fingerprintFor(entry.value)))
            .toList(growable: false)
          ..sort((left, right) => left.$1.compareTo(right.$1));
    _source = source;
    _value = value;
    return value;
  }

  void clear() {
    _source = null;
    _value = null;
  }
}

class _PeakRenderFingerprintCacheEntry {
  const _PeakRenderFingerprintCacheEntry({
    required this.osmId,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.elevation,
    required this.prominence,
    required this.fingerprint,
  });

  final int osmId;
  final double latitude;
  final double longitude;
  final String name;
  final double? elevation;
  final double? prominence;
  final String fingerprint;

  bool matches(Peak peak) {
    return peak.osmId == osmId &&
        peak.latitude == latitude &&
        peak.longitude == longitude &&
        peak.name == name &&
        peak.elevation == elevation &&
        peak.prominence == prominence;
  }
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
