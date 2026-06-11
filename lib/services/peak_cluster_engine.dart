import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/peak.dart';

class ProjectedPeakCandidate {
  const ProjectedPeakCandidate({
    required this.peak,
    required this.screenPosition,
    required this.isTicked,
  });

  final Peak peak;
  final Offset screenPosition;
  final bool isTicked;
}

class PeakCluster {
  const PeakCluster({required this.members, required this.screenPosition});

  final List<ProjectedPeakCandidate> members;
  final Offset screenPosition;

  int get tickedCount => members.where((member) => member.isTicked).length;

  int get untickedCount => members.length - tickedCount;

  List<LatLng> get points => [
    for (final member in members)
      LatLng(member.peak.latitude, member.peak.longitude),
  ];
}

class PeakClusterViewportData {
  const PeakClusterViewportData({
    required this.individualCandidates,
    required this.clusters,
  });

  final List<ProjectedPeakCandidate> individualCandidates;
  final List<PeakCluster> clusters;

  List<Peak> get individualPeaks => [
    for (final candidate in individualCandidates) candidate.peak,
  ];
}

PeakClusterViewportData buildPeakClusterViewportData({
  required List<Peak> peaks,
  required MapCamera camera,
  required Set<int> correlatedPeakIds,
}) {
  final size = camera.nonRotatedSize;
  if (size == MapCamera.kImpossibleSize) {
    return const PeakClusterViewportData(
      individualCandidates: [],
      clusters: [],
    );
  }

  final paddedViewport = Rect.fromLTWH(
    -MapConstants.peakViewportPadding,
    -MapConstants.peakViewportPadding,
    size.width + MapConstants.peakViewportPadding * 2,
    size.height + MapConstants.peakViewportPadding * 2,
  );

  final projected = <ProjectedPeakCandidate>[];
  for (final peak in peaks) {
    if (!peak.latitude.isFinite || !peak.longitude.isFinite) {
      continue;
    }
    final screenPosition = camera.latLngToScreenOffset(
      LatLng(peak.latitude, peak.longitude),
    );
    if (!screenPosition.dx.isFinite || !screenPosition.dy.isFinite) {
      continue;
    }
    if (!paddedViewport.contains(screenPosition)) {
      continue;
    }
    projected.add(
      ProjectedPeakCandidate(
        peak: peak,
        screenPosition: screenPosition,
        isTicked: correlatedPeakIds.contains(peak.osmId),
      ),
    );
  }

  final visited = List<bool>.filled(projected.length, false);
  final clusters = <PeakCluster>[];
  final untickedIndividuals = <ProjectedPeakCandidate>[];
  final tickedIndividuals = <ProjectedPeakCandidate>[];

  for (var i = 0; i < projected.length; i++) {
    if (visited[i]) {
      continue;
    }
    visited[i] = true;
    final component = <ProjectedPeakCandidate>[];
    final queue = <int>[i];

    while (queue.isNotEmpty) {
      final index = queue.removeLast();
      final candidate = projected[index];
      component.add(candidate);

      for (var j = 0; j < projected.length; j++) {
        if (visited[j]) {
          continue;
        }
        final other = projected[j];
        if ((candidate.screenPosition - other.screenPosition).distance <=
            MapConstants.peakClusterRadius) {
          visited[j] = true;
          queue.add(j);
        }
      }
    }

    if (component.length == 1) {
      final candidate = component.single;
      if (candidate.isTicked) {
        tickedIndividuals.add(candidate);
      } else {
        untickedIndividuals.add(candidate);
      }
      continue;
    }

    final center = component.fold<Offset>(
      Offset.zero,
      (sum, candidate) => sum + candidate.screenPosition,
    );
    clusters.add(
      PeakCluster(
        members: component,
        screenPosition: center / component.length.toDouble(),
      ),
    );
  }

  clusters.sort((left, right) => left.members.length.compareTo(right.members.length));

  return PeakClusterViewportData(
    individualCandidates: [...untickedIndividuals, ...tickedIndividuals],
    clusters: clusters,
  );
}

PeakCluster? hitTestPeakCluster({
  required Offset pointerPosition,
  required PeakClusterViewportData data,
}) {
  PeakCluster? bestCluster;
  double? bestDistance;

  for (final cluster in data.clusters) {
    final distance = (pointerPosition - cluster.screenPosition).distance;
    if (distance > MapConstants.peakClusterTapRadius) {
      continue;
    }
    if (bestDistance == null || distance < bestDistance) {
      bestDistance = distance;
      bestCluster = cluster;
    }
  }

  return bestCluster;
}

bool peakClusterNeedsZoomFallback(List<LatLng> points) {
  if (points.isEmpty) {
    return true;
  }
  final first = points.first;
  return points.every(
    (point) =>
        math.max(
          (point.latitude - first.latitude).abs(),
          (point.longitude - first.longitude).abs(),
        ) <=
        MapConstants.cameraEpsilon,
  );
}
