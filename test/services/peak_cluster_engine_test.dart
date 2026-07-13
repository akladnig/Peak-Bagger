import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_ownership_ring_segment.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';
import 'package:peak_bagger/services/peak_projection_cache.dart';

void main() {
  final closeA = Peak(osmId: 1, name: 'A', latitude: -43.0, longitude: 147.0);
  final closeB = Peak(osmId: 2, name: 'B', latitude: -43.0, longitude: 147.01);

  test('close peaks cluster at low zoom with expected fractions', () {
    final camera = _camera(zoom: 8);
    final data = buildPeakClusterViewportData(
      peaks: [closeA, closeB],
      camera: camera,
      correlatedPeakIds: {2},
      activeOwnershipSegments: const {
        1: [PeakOwnershipRingSegment(peakListId: 7, colourValue: 0xFF4C8BF5)],
      },
    );

    expect(data.clusters, hasLength(1));
    expect(data.individualCandidates, isEmpty);
    expect(data.clusters.single.untickedCount, 1);
    expect(data.clusters.single.tickedCount, 1);
    expect(data.clusters.single.untickedFraction, 0.5);
    expect(data.clusters.single.tickedFraction, 0.5);
    expect(
      data.clusters.single.untickedOwnershipRingSegments.map(
        (segment) => segment.peakListId,
      ),
      [7],
    );
  });

  test(
    'cluster unticked ownership ring segments stay equal by selected list',
    () {
      final camera = _camera(zoom: 8);
      final data = buildPeakClusterViewportData(
        peaks: [closeA, closeB],
        camera: camera,
        correlatedPeakIds: const {},
        activeOwnershipSegments: const {
          1: [
            PeakOwnershipRingSegment(peakListId: 7, colourValue: 0xFF4C8BF5),
            PeakOwnershipRingSegment(peakListId: 8, colourValue: 0xFF12B886),
          ],
          2: [PeakOwnershipRingSegment(peakListId: 8, colourValue: 0xFF12B886)],
        },
      );

      expect(data.clusters, hasLength(1));
      expect(data.clusters.single.tickedFraction, 0);
      expect(data.clusters.single.untickedFraction, 1);
      expect(
        data.clusters.single.untickedOwnershipRingSegments.map(
          (segment) => segment.peakListId,
        ),
        [7, 8],
      );
    },
  );

  test('cluster ring becomes fully green when no unticked peaks remain', () {
    final camera = _camera(zoom: 8);
    final data = buildPeakClusterViewportData(
      peaks: [closeA, closeB],
      camera: camera,
      correlatedPeakIds: const {1, 2},
      activeOwnershipSegments: const {
        1: [PeakOwnershipRingSegment(peakListId: 7, colourValue: 0xFF4C8BF5)],
        2: [PeakOwnershipRingSegment(peakListId: 8, colourValue: 0xFF12B886)],
      },
    );

    expect(data.clusters.single.tickedFraction, 1);
    expect(data.clusters.single.untickedFraction, 0);
    expect(data.clusters.single.untickedOwnershipRingSegments, isEmpty);
  });

  test('close peaks dissolve into individuals at higher zoom', () {
    final camera = _camera(zoom: 15);
    final data = buildPeakClusterViewportData(
      peaks: [closeA, closeB],
      camera: camera,
      correlatedPeakIds: const {},
      untickedPeakColours: const {1: 0xFF4C8BF5},
    );

    expect(data.clusters, isEmpty);
    expect(data.individualCandidates.map((candidate) => candidate.peak.osmId), [
      1,
      2,
    ]);
    expect(data.individualCandidates.first.untickedColourValue, 0xFF4C8BF5);
    expect(data.individualCandidates.last.untickedColourValue, isNull);
  });

  test('individual peaks carry ordered ownership ring segments', () {
    final camera = _camera(zoom: 15);
    final data = buildPeakClusterViewportData(
      peaks: [closeA],
      camera: camera,
      correlatedPeakIds: const {},
      untickedPeakColours: const {1: 0xFF4C8BF5},
      ownershipRingSegments: const {
        1: [
          PeakOwnershipRingSegment(peakListId: 7, colourValue: 0xFF4C8BF5),
          PeakOwnershipRingSegment(peakListId: 8, colourValue: 0xFF12B886),
        ],
      },
    );

    expect(data.clusters, isEmpty);
    expect(data.individualCandidates.single.untickedColourValue, 0xFF4C8BF5);
    expect(
      data.individualCandidates.single.ownershipRingSegments.map(
        (segment) => segment.peakListId,
      ),
      [7, 8],
    );
  });

  test(
    'ticked individual peaks stay green while keeping ownership ring data',
    () {
      final camera = _camera(zoom: 15);
      final data = buildPeakClusterViewportData(
        peaks: [closeA],
        camera: camera,
        correlatedPeakIds: const {1},
        ownershipRingSegments: const {
          1: [
            PeakOwnershipRingSegment(peakListId: 7, colourValue: 0xFF4C8BF5),
            PeakOwnershipRingSegment(peakListId: 8, colourValue: 0xFF12B886),
          ],
        },
      );

      expect(data.individualCandidates.single.isTicked, isTrue);
      expect(
        data.individualCandidates.single.ownershipRingSegments,
        hasLength(2),
      );
    },
  );

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
    expect(data.individualCandidates.map((candidate) => candidate.peak.osmId), [
      1,
    ]);
  });

  test('cluster representative uses projected centroid', () {
    final camera = _camera(zoom: 8);
    final data = buildPeakClusterViewportData(
      peaks: [closeA, closeB],
      camera: camera,
      correlatedPeakIds: const {},
    );
    final cluster = data.clusters.single;
    final expected =
        [closeA, closeB]
            .map(
              (peak) => camera.latLngToScreenOffset(
                LatLng(peak.latitude, peak.longitude),
              ),
            )
            .reduce((left, right) => left + right) /
        2;

    expect(cluster.screenPosition.dx, closeTo(expected.dx, 0.001));
    expect(cluster.screenPosition.dy, closeTo(expected.dy, 0.001));
  });

  test('compact clustering keeps chain-linked groups separate', () {
    final camera = _camera(zoom: 13);
    final peaks = [
      _peakAtScreen(camera, osmId: 10, screenPosition: const Offset(492, 400)),
      _peakAtScreen(camera, osmId: 11, screenPosition: const Offset(506, 386)),
      _peakAtScreen(camera, osmId: 12, screenPosition: const Offset(506, 414)),
      _peakAtScreen(camera, osmId: 13, screenPosition: const Offset(520, 400)),
      _peakAtScreen(camera, osmId: 14, screenPosition: const Offset(506, 400)),
      _peakAtScreen(camera, osmId: 20, screenPosition: const Offset(544, 400)),
      _peakAtScreen(camera, osmId: 21, screenPosition: const Offset(558, 401)),
    ];
    final data = buildPeakClusterViewportData(
      peaks: peaks,
      camera: camera,
      correlatedPeakIds: const {},
      algorithm: PeakClusterAlgorithm.compactCircular,
    );

    expect(data.clusters.map((cluster) => cluster.members.length), [2, 5]);
    expect(data.individualCandidates, isEmpty);
    expect({
      for (final cluster in data.clusters)
        for (final member in cluster.members) member.peak.osmId,
    }, hasLength(peaks.length));
  });

  test(
    'marker cluster compatible mode keeps current compact mode selectable',
    () {
      final camera = _camera(zoom: 13);
      final peaks = [
        _peakAtScreen(
          camera,
          osmId: 50,
          screenPosition: const Offset(500, 400),
        ),
        _peakAtScreen(
          camera,
          osmId: 51,
          screenPosition: const Offset(520, 400),
        ),
        _peakAtScreen(
          camera,
          osmId: 52,
          screenPosition: const Offset(530, 400),
        ),
        _peakAtScreen(
          camera,
          osmId: 53,
          screenPosition: const Offset(544, 400),
        ),
        _peakAtScreen(
          camera,
          osmId: 54,
          screenPosition: const Offset(551, 400),
        ),
      ];

      final compactData = buildPeakClusterViewportData(
        peaks: peaks,
        camera: camera,
        correlatedPeakIds: const {},
        algorithm: PeakClusterAlgorithm.compactCircular,
      );
      final markerClusterCompatibleData = buildPeakClusterViewportData(
        peaks: peaks,
        camera: camera,
        correlatedPeakIds: const {},
        algorithm: PeakClusterAlgorithm.markerClusterCompatible,
      );

      expect(
        MapConstants.peakClusterAlgorithm,
        PeakClusterAlgorithm.supercluster,
      );
      expect(compactData.clusters.map((cluster) => cluster.members.length), [
        4,
      ]);
      expect(
        compactData.individualCandidates.map(
          (candidate) => candidate.peak.osmId,
        ),
        [54],
      );
      expect(
        markerClusterCompatibleData.clusters.map(
          (cluster) => cluster.members.length,
        ),
        [5],
      );
      expect(markerClusterCompatibleData.individualCandidates, isEmpty);
    },
  );

  test('supercluster mode returns stable aggregated clusters', () {
    final camera = _camera(zoom: 8);
    final data = buildPeakClusterViewportData(
      peaks: [closeA, closeB],
      camera: camera,
      correlatedPeakIds: {2},
      algorithm: PeakClusterAlgorithm.supercluster,
    );

    expect(data.clusters, hasLength(1));
    expect(data.clusters.single.members.length, 2);
    expect(data.clusters.single.tickedCount, 1);
    expect(data.individualCandidates, isEmpty);
  });

  test('cluster visual radius follows hull edge geometry', () {
    final cluster = PeakCluster(
      members: [
        _candidate(osmId: 40, screenPosition: const Offset(470, 400)),
        _candidate(osmId: 41, screenPosition: const Offset(530, 400)),
      ],
      screenPosition: const Offset(500, 400),
    );

    expect(
      peakClusterVisualRadius(
        cluster,
        algorithm: PeakClusterAlgorithm.compactCircular,
      ),
      closeTo(22, 0.001),
    );
  });

  test('seed priority prefers prominence before elevation fallback', () {
    final highProminence = _candidate(
      osmId: 30,
      prominence: 120,
      elevation: 800,
    );
    final highElevation = _candidate(osmId: 31, elevation: 1500);
    final lowerElevation = _candidate(osmId: 32, elevation: 1200);

    expect(
      comparePeakClusterSeedPriority(highProminence, highElevation),
      lessThan(0),
    );
    expect(
      comparePeakClusterSeedPriority(highElevation, lowerElevation),
      lessThan(0),
    );
  });

  test('projection cache invalidates on zoom and correlation changes', () {
    final cache = PeakProjectionCache();
    final base = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: _camera(zoom: 8),
      correlatedPeakIds: const {},
      untickedPeakColours: const {},
      algorithm: PeakClusterAlgorithm.compactCircular,
    );
    final same = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: _camera(zoom: 8),
      correlatedPeakIds: const {},
      untickedPeakColours: const {},
      algorithm: PeakClusterAlgorithm.compactCircular,
    );
    final changedZoom = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: _camera(zoom: 9),
      correlatedPeakIds: const {},
      untickedPeakColours: const {},
      algorithm: PeakClusterAlgorithm.compactCircular,
    );
    final changedCorrelation = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: _camera(zoom: 9),
      correlatedPeakIds: {2},
      untickedPeakColours: const {},
      algorithm: PeakClusterAlgorithm.compactCircular,
    );
    final changedUntickedColours = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: _camera(zoom: 9),
      correlatedPeakIds: {2},
      untickedPeakColours: const {1: 0xFF4C8BF5},
      algorithm: PeakClusterAlgorithm.compactCircular,
    );
    final changedAlgorithm = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: _camera(zoom: 9),
      correlatedPeakIds: {2},
      untickedPeakColours: const {1: 0xFF4C8BF5},
      algorithm: PeakClusterAlgorithm.supercluster,
    );
    final changedOwnershipRingSegments = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: _camera(zoom: 9),
      correlatedPeakIds: {2},
      untickedPeakColours: const {1: 0xFF4C8BF5},
      ownershipRingSegments: const {
        1: [
          PeakOwnershipRingSegment(peakListId: 7, colourValue: 0xFF4C8BF5),
          PeakOwnershipRingSegment(peakListId: 8, colourValue: 0xFF12B886),
        ],
      },
      algorithm: PeakClusterAlgorithm.supercluster,
    );
    final changedActiveOwnershipSegments = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: _camera(zoom: 9),
      correlatedPeakIds: {2},
      untickedPeakColours: const {1: 0xFF4C8BF5},
      activeOwnershipSegments: const {
        1: [PeakOwnershipRingSegment(peakListId: 7, colourValue: 0xFF4C8BF5)],
      },
      ownershipRingSegments: const {
        1: [
          PeakOwnershipRingSegment(peakListId: 7, colourValue: 0xFF4C8BF5),
          PeakOwnershipRingSegment(peakListId: 8, colourValue: 0xFF12B886),
        ],
      },
      algorithm: PeakClusterAlgorithm.supercluster,
    );

    expect(identical(base, same), isTrue);
    expect(identical(base, changedZoom), isFalse);
    expect(identical(changedCorrelation, changedUntickedColours), isFalse);
    expect(identical(changedCorrelation, changedAlgorithm), isFalse);
    expect(identical(changedAlgorithm, changedOwnershipRingSegments), isFalse);
    expect(
      identical(changedOwnershipRingSegments, changedActiveOwnershipSegments),
      isFalse,
    );
    expect(
      changedCorrelation.individualCandidates.any(
            (candidate) => candidate.isTicked,
          ) ||
          changedCorrelation.clusters.any((cluster) => cluster.tickedCount > 0),
      isTrue,
    );
  });

  test('projection cache invalidates when peak render fields change', () {
    final cache = PeakProjectionCache();
    final camera = _camera(zoom: 15);
    final base = cache.getOrBuild(
      peaks: [closeA, closeB],
      camera: camera,
      correlatedPeakIds: const {},
      untickedPeakColours: const {},
      algorithm: PeakClusterAlgorithm.compactCircular,
    );
    final relocatedPeak = closeA.copyWith(latitude: -43.01, longitude: 147.02);
    final relocated = cache.getOrBuild(
      peaks: [relocatedPeak, closeB],
      camera: camera,
      correlatedPeakIds: const {},
      untickedPeakColours: const {},
      algorithm: PeakClusterAlgorithm.compactCircular,
    );
    final rewordedPeak = relocatedPeak.copyWith(name: 'A+', elevation: 1234);
    final reworded = cache.getOrBuild(
      peaks: [rewordedPeak, closeB],
      camera: camera,
      correlatedPeakIds: const {},
      untickedPeakColours: const {},
      algorithm: PeakClusterAlgorithm.compactCircular,
    );

    expect(identical(base, relocated), isFalse);
    expect(
      relocated.individualCandidates
          .firstWhere((candidate) => candidate.peak.osmId == 1)
          .screenPosition,
      isNot(
        equals(
          base.individualCandidates
              .firstWhere((candidate) => candidate.peak.osmId == 1)
              .screenPosition,
        ),
      ),
    );
    expect(identical(relocated, reworded), isFalse);
    final updatedCandidate = reworded.individualCandidates.firstWhere(
      (candidate) => candidate.peak.osmId == 1,
    );
    expect(updatedCandidate.peak.name, 'A+');
    expect(updatedCandidate.peak.elevation, 1234);
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

Peak _peakAtScreen(
  MapCamera camera, {
  required int osmId,
  required Offset screenPosition,
  double? elevation,
  double? prominence,
}) {
  final point = camera.screenOffsetToLatLng(screenPosition);
  return Peak(
    osmId: osmId,
    name: 'Peak $osmId',
    latitude: point.latitude,
    longitude: point.longitude,
    elevation: elevation,
    prominence: prominence,
  );
}

ProjectedPeakCandidate _candidate({
  required int osmId,
  Offset screenPosition = Offset.zero,
  double? elevation,
  double? prominence,
}) {
  return ProjectedPeakCandidate(
    peak: Peak(
      osmId: osmId,
      name: 'Peak $osmId',
      latitude: -43,
      longitude: 147,
      elevation: elevation,
      prominence: prominence,
    ),
    screenPosition: screenPosition,
    isTicked: false,
  );
}
