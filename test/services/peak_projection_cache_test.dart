import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_projection_cache.dart';
import 'package:peak_bagger/widgets/map_rebuild_debug_counters.dart';

void main() {
  test('reuses cached viewport data for equivalent peak inputs', () {
    MapRebuildDebugCounters.reset();
    final cache = PeakProjectionCache();
    final camera = _camera();

    final first = cache.getOrBuild(
      peaks: [_peak(1, name: 'Peak A')],
      camera: camera,
      correlatedPeakIds: <int>{1},
      untickedPeakColours: <int, int>{},
      clusteringEnabled: false,
    );
    final initialBuilds = MapRebuildDebugCounters.peakProjectionBuilds;

    final second = cache.getOrBuild(
      peaks: [_peak(1, name: 'Peak A')],
      camera: camera,
      correlatedPeakIds: <int>{1},
      untickedPeakColours: <int, int>{},
      clusteringEnabled: false,
    );

    expect(identical(second, first), isTrue);
    expect(MapRebuildDebugCounters.peakProjectionBuilds, initialBuilds);
  });

  test('invalidates cached viewport data when a peak mutates in place', () {
    MapRebuildDebugCounters.reset();
    final cache = PeakProjectionCache();
    final camera = _camera();
    final peak = _peak(1, name: 'Peak A');
    final peaks = [peak];

    final first = cache.getOrBuild(
      peaks: peaks,
      camera: camera,
      correlatedPeakIds: <int>{1},
      untickedPeakColours: <int, int>{},
      clusteringEnabled: false,
    );
    final initialBuilds = MapRebuildDebugCounters.peakProjectionBuilds;

    peak.name = 'Peak A Updated';

    final second = cache.getOrBuild(
      peaks: peaks,
      camera: camera,
      correlatedPeakIds: <int>{1},
      untickedPeakColours: <int, int>{},
      clusteringEnabled: false,
    );

    expect(identical(second, first), isFalse);
    expect(MapRebuildDebugCounters.peakProjectionBuilds, initialBuilds + 1);
    expect(second.individualCandidates.single.peak.name, 'Peak A Updated');
  });
}

MapCamera _camera() {
  return MapCamera(
    crs: const Epsg3857(),
    center: const LatLng(-41.5, 146.5),
    zoom: 14,
    rotation: 0,
    nonRotatedSize: const Size(1000, 800),
  );
}

Peak _peak(int osmId, {required String name}) {
  return Peak(
    osmId: osmId,
    name: name,
    latitude: -41.5,
    longitude: 146.5,
    elevation: 1200,
    prominence: 250,
  );
}
