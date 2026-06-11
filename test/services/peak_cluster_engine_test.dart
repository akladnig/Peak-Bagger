import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';
import 'package:peak_bagger/services/peak_projection_cache.dart';

void main() {
  final closeA = Peak(
    osmId: 1,
    name: 'A',
    latitude: -43.0,
    longitude: 147.0,
  );
  final closeB = Peak(
    osmId: 2,
    name: 'B',
    latitude: -43.0,
    longitude: 147.01,
  );

  test('close peaks cluster at low zoom with expected fractions', () {
    final camera = _camera(zoom: 8);
    final data = buildPeakClusterViewportData(
      peaks: [closeA, closeB],
      camera: camera,
      correlatedPeakIds: {2},
    );

    expect(data.clusters, hasLength(1));
    expect(data.individualCandidates, isEmpty);
    expect(data.clusters.single.untickedCount, 1);
    expect(data.clusters.single.tickedCount, 1);
    expect(data.clusters.single.untickedFraction, 0.5);
    expect(data.clusters.single.tickedFraction, 0.5);
  });

  test('close peaks dissolve into individuals at higher zoom', () {
    final camera = _camera(zoom: 15);
    final data = buildPeakClusterViewportData(
      peaks: [closeA, closeB],
      camera: camera,
      correlatedPeakIds: const {},
    );

    expect(data.clusters, isEmpty);
    expect(data.individualCandidates.map((candidate) => candidate.peak.osmId), [1, 2]);
  });

  test('invalid coordinates are skipped safely', () {
    final invalid = Peak(
      osmId: 3,
      name: 'Invalid',
      latitude: double.nan,
      longitude: 147.0,
    );
    final camera = _camera(zoom: 15);
    final data = buildPeakClusterViewportData(
      peaks: [closeA, invalid],
      camera: camera,
      correlatedPeakIds: const {},
    );

    expect(data.clusters, isEmpty);
    expect(data.individualCandidates.map((candidate) => candidate.peak.osmId), [1]);
  });

  test('cluster representative uses projected centroid', () {
    final camera = _camera(zoom: 8);
    final data = buildPeakClusterViewportData(
      peaks: [closeA, closeB],
      camera: camera,
      correlatedPeakIds: const {},
    );
    final cluster = data.clusters.single;
    final expected = [closeA, closeB]
        .map((peak) => camera.latLngToScreenOffset(LatLng(peak.latitude, peak.longitude)))
        .reduce((left, right) => left + right) /
        2;

    expect(cluster.screenPosition.dx, closeTo(expected.dx, 0.001));
    expect(cluster.screenPosition.dy, closeTo(expected.dy, 0.001));
  });

  test('projection cache invalidates on zoom and correlation changes', () {
    final cache = PeakProjectionCache();
    final base = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: _camera(zoom: 8),
      correlatedPeakIds: const {},
    );
    final same = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: _camera(zoom: 8),
      correlatedPeakIds: const {},
    );
    final changedZoom = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: _camera(zoom: 9),
      correlatedPeakIds: const {},
    );
    final changedCorrelation = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: _camera(zoom: 9),
      correlatedPeakIds: {2},
    );

    expect(identical(base, same), isTrue);
    expect(identical(base, changedZoom), isFalse);
    expect(
      changedCorrelation.individualCandidates.any((candidate) => candidate.isTicked) ||
          changedCorrelation.clusters.any((cluster) => cluster.tickedCount > 0),
      isTrue,
    );
  });
}

MapCamera _camera({required double zoom}) {
  return MapCamera(
    crs: const Epsg3857(),
    center: const LatLng(-43.0, 147.0),
    zoom: zoom,
    rotation: 0,
    nonRotatedSize: const Size(1000, 800),
  );
}
