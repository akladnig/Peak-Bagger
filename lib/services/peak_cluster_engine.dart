import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:supercluster/supercluster.dart';

class ProjectedPeakCandidate {
  const ProjectedPeakCandidate({
    required this.peak,
    required this.screenPosition,
    required this.isTicked,
  });

  final Peak peak;
  final ui.Offset screenPosition;
  final bool isTicked;
}

class PeakCluster {
  const PeakCluster({required this.members, required this.screenPosition});

  final List<ProjectedPeakCandidate> members;
  final ui.Offset screenPosition;

  int get tickedCount => members.where((member) => member.isTicked).length;

  int get untickedCount => members.length - tickedCount;

  double get tickedFraction =>
      members.isEmpty ? 0 : tickedCount / members.length;

  double get untickedFraction =>
      members.isEmpty ? 0 : untickedCount / members.length;

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

class PeakSuperclusterPoint {
  const PeakSuperclusterPoint({required this.peak, required this.isTicked});

  final Peak peak;
  final bool isTicked;
}

class PeakSuperclusterIndex {
  const PeakSuperclusterIndex({required this.index});

  final SuperclusterImmutable<PeakSuperclusterPoint> index;
}

int comparePeakClusterSeedPriority(
  ProjectedPeakCandidate left,
  ProjectedPeakCandidate right,
) {
  final leftProminence = left.peak.prominence;
  final rightProminence = right.peak.prominence;
  if (leftProminence != null || rightProminence != null) {
    if (leftProminence == null) {
      return 1;
    }
    if (rightProminence == null) {
      return -1;
    }
    final prominenceCompare = rightProminence.compareTo(leftProminence);
    if (prominenceCompare != 0) {
      return prominenceCompare;
    }
  }

  final leftElevation = left.peak.elevation;
  final rightElevation = right.peak.elevation;
  if (leftElevation != null || rightElevation != null) {
    if (leftElevation == null) {
      return 1;
    }
    if (rightElevation == null) {
      return -1;
    }
    final elevationCompare = rightElevation.compareTo(leftElevation);
    if (elevationCompare != 0) {
      return elevationCompare;
    }
  }

  return left.peak.osmId.compareTo(right.peak.osmId);
}

PeakSuperclusterIndex buildPeakSuperclusterIndex({
  required List<Peak> peaks,
  required Set<int> correlatedPeakIds,
}) {
  final index = SuperclusterImmutable<PeakSuperclusterPoint>(
    getX: (point) => point.peak.longitude,
    getY: (point) => point.peak.latitude,
    radius: MapConstants.peakSuperclusterRadius,
    minPoints: MapConstants.peakSuperclusterMinPoints,
    maxZoom: MapConstants.peakSuperclusterMaxZoom,
  );
  index.load([
    for (final peak in peaks)
      if (peak.latitude.isFinite && peak.longitude.isFinite)
        PeakSuperclusterPoint(
          peak: peak,
          isTicked: correlatedPeakIds.contains(peak.osmId),
        ),
  ]);
  return PeakSuperclusterIndex(index: index);
}

PeakClusterViewportData buildPeakClusterViewportDataFromSuperclusterIndex({
  required PeakSuperclusterIndex index,
  required MapCamera camera,
}) {
  final size = camera.nonRotatedSize;
  if (size == MapCamera.kImpossibleSize) {
    return const PeakClusterViewportData(
      individualCandidates: [],
      clusters: [],
    );
  }

  final searchBounds = _paddedSearchBounds(camera);
  final zoom = camera.zoom.floor().clamp(
    0,
    MapConstants.peakSuperclusterMaxZoom,
  );
  final elements = index.index.search(
    searchBounds.west,
    searchBounds.south,
    searchBounds.east,
    searchBounds.north,
    zoom,
  );

  final clusters = <PeakCluster>[];
  final untickedIndividuals = <ProjectedPeakCandidate>[];
  final tickedIndividuals = <ProjectedPeakCandidate>[];

  for (final element in elements) {
    element.handle<void>(
      cluster: (cluster) {
        final members = _superclusterClusterMembers(
          index: index.index,
          cluster: cluster,
          camera: camera,
        );
        if (members.length < 2) {
          if (members.length == 1) {
            final member = members.single;
            if (member.isTicked) {
              tickedIndividuals.add(member);
            } else {
              untickedIndividuals.add(member);
            }
          }
          return;
        }

        final center = camera.latLngToScreenOffset(
          LatLng(cluster.latitude, cluster.longitude),
        );
        clusters.add(PeakCluster(members: members, screenPosition: center));
      },
      point: (point) {
        final candidate = _projectIndexedPeakPoint(point.originalPoint, camera);
        if (candidate == null) {
          return;
        }
        if (candidate.isTicked) {
          tickedIndividuals.add(candidate);
        } else {
          untickedIndividuals.add(candidate);
        }
      },
    );
  }

  clusters.sort(
    (left, right) => left.members.length.compareTo(right.members.length),
  );

  return PeakClusterViewportData(
    individualCandidates: [...untickedIndividuals, ...tickedIndividuals],
    clusters: clusters,
  );
}

PeakClusterViewportData buildPeakClusterViewportData({
  required List<Peak> peaks,
  required MapCamera camera,
  required Set<int> correlatedPeakIds,
  PeakClusterAlgorithm algorithm = MapConstants.peakClusterAlgorithm,
}) {
  final size = camera.nonRotatedSize;
  if (size == MapCamera.kImpossibleSize) {
    return const PeakClusterViewportData(
      individualCandidates: [],
      clusters: [],
    );
  }

  final paddedViewport = ui.Rect.fromLTWH(
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

  return switch (algorithm) {
    PeakClusterAlgorithm.compactCircular =>
      _buildCompactPeakClusterViewportData(projected),
    PeakClusterAlgorithm.markerClusterCompatible =>
      _buildMarkerClusterCompatibleViewportData(projected),
    PeakClusterAlgorithm.supercluster =>
      buildPeakClusterViewportDataFromSuperclusterIndex(
        index: buildPeakSuperclusterIndex(
          peaks: peaks,
          correlatedPeakIds: correlatedPeakIds,
        ),
        camera: camera,
      ),
  };
}

PeakClusterViewportData _buildCompactPeakClusterViewportData(
  List<ProjectedPeakCandidate> projected,
) {
  final seedOrder = List<int>.generate(projected.length, (index) => index)
    ..sort(
      (left, right) =>
          comparePeakClusterSeedPriority(projected[left], projected[right]),
    );
  final visited = List<bool>.filled(projected.length, false);
  final components = <List<int>>[];

  for (final seedIndex in seedOrder) {
    if (visited[seedIndex]) {
      continue;
    }

    final componentIndices = _buildCompactClusterIndices(
      seedIndex: seedIndex,
      projected: projected,
      assigned: visited,
    );
    for (final index in componentIndices) {
      visited[index] = true;
    }
    components.add(componentIndices);
  }

  final mergedComponents = _mergeCompactComponents(
    projected: projected,
    components: components,
  );

  return _buildPeakClusterViewportDataFromComponents(
    projected: projected,
    components: mergedComponents,
  );
}

PeakClusterViewportData _buildMarkerClusterCompatibleViewportData(
  List<ProjectedPeakCandidate> projected,
) {
  final clusters = <List<int>>[];
  final clusterCenters = <ui.Offset>[];
  final unclustered = <int>[];

  for (var i = 0; i < projected.length; i++) {
    final point = projected[i].screenPosition;

    var closestClusterIndex = -1;
    double? closestClusterDistance;
    for (var j = 0; j < clusters.length; j++) {
      final distance = (point - clusterCenters[j]).distance;
      if (distance > MapConstants.peakClusterRadius) {
        continue;
      }
      if (closestClusterIndex == -1 || distance < closestClusterDistance!) {
        closestClusterIndex = j;
        closestClusterDistance = distance;
      }
    }

    if (closestClusterIndex != -1) {
      clusters[closestClusterIndex].add(i);
      clusterCenters[closestClusterIndex] = _memberSetCenter(
        memberIndices: clusters[closestClusterIndex],
        projected: projected,
      );
      continue;
    }

    var closestUnclusteredListIndex = -1;
    double? closestUnclusteredDistance;
    for (var j = 0; j < unclustered.length; j++) {
      final distance =
          (point - projected[unclustered[j]].screenPosition).distance;
      if (distance > MapConstants.peakClusterRadius) {
        continue;
      }
      if (closestUnclusteredListIndex == -1 ||
          distance < closestUnclusteredDistance!) {
        closestUnclusteredListIndex = j;
        closestUnclusteredDistance = distance;
      }
    }

    if (closestUnclusteredListIndex != -1) {
      final firstIndex = unclustered.removeAt(closestUnclusteredListIndex);
      final component = [firstIndex, i];
      clusters.add(component);
      clusterCenters.add(
        _memberSetCenter(memberIndices: component, projected: projected),
      );
      continue;
    }

    unclustered.add(i);
  }

  final components = <List<int>>[
    ...clusters,
    for (final index in unclustered) [index],
  ];
  return _buildPeakClusterViewportDataFromComponents(
    projected: projected,
    components: components,
  );
}

PeakClusterViewportData _buildPeakClusterViewportDataFromComponents({
  required List<ProjectedPeakCandidate> projected,
  required List<List<int>> components,
}) {
  final clusters = <PeakCluster>[];
  final untickedIndividuals = <ProjectedPeakCandidate>[];
  final tickedIndividuals = <ProjectedPeakCandidate>[];

  for (final componentIndices in components) {
    final component = [for (final index in componentIndices) projected[index]];

    if (component.length == 1) {
      final candidate = component.single;
      if (candidate.isTicked) {
        tickedIndividuals.add(candidate);
      } else {
        untickedIndividuals.add(candidate);
      }
      continue;
    }

    final center = component.fold<ui.Offset>(
      ui.Offset.zero,
      (sum, candidate) => sum + candidate.screenPosition,
    );
    clusters.add(
      PeakCluster(
        members: component,
        screenPosition: center / component.length.toDouble(),
      ),
    );
  }

  clusters.sort(
    (left, right) => left.members.length.compareTo(right.members.length),
  );

  return PeakClusterViewportData(
    individualCandidates: [...untickedIndividuals, ...tickedIndividuals],
    clusters: clusters,
  );
}

LatLngBounds _paddedSearchBounds(MapCamera camera) {
  final size = camera.nonRotatedSize;
  final corners = [
    const ui.Offset(
      -MapConstants.peakViewportPadding,
      -MapConstants.peakViewportPadding,
    ),
    ui.Offset(
      size.width + MapConstants.peakViewportPadding,
      -MapConstants.peakViewportPadding,
    ),
    ui.Offset(
      -MapConstants.peakViewportPadding,
      size.height + MapConstants.peakViewportPadding,
    ),
    ui.Offset(
      size.width + MapConstants.peakViewportPadding,
      size.height + MapConstants.peakViewportPadding,
    ),
  ].map(camera.screenOffsetToLatLng).toList(growable: false);
  return LatLngBounds.fromPoints(corners);
}

List<ProjectedPeakCandidate> _superclusterClusterMembers({
  required SuperclusterImmutable<PeakSuperclusterPoint> index,
  required LayerCluster<PeakSuperclusterPoint> cluster,
  required MapCamera camera,
}) {
  final members = <ProjectedPeakCandidate>[];

  void visit(ImmutableLayerElement<PeakSuperclusterPoint> element) {
    element.handle<void>(
      cluster: (childCluster) {
        for (final child in index.childrenOf(childCluster)) {
          visit(child);
        }
      },
      point: (point) {
        final candidate = _projectIndexedPeakPoint(point.originalPoint, camera);
        if (candidate != null) {
          members.add(candidate);
        }
      },
    );
  }

  for (final child in index.childrenOf(cluster)) {
    visit(child);
  }

  return members;
}

ProjectedPeakCandidate? _projectIndexedPeakPoint(
  PeakSuperclusterPoint point,
  MapCamera camera,
) {
  final screenPosition = camera.latLngToScreenOffset(
    LatLng(point.peak.latitude, point.peak.longitude),
  );
  if (!screenPosition.dx.isFinite || !screenPosition.dy.isFinite) {
    return null;
  }

  return ProjectedPeakCandidate(
    peak: point.peak,
    screenPosition: screenPosition,
    isTicked: point.isTicked,
  );
}

List<int> _buildCompactClusterIndices({
  required int seedIndex,
  required List<ProjectedPeakCandidate> projected,
  required List<bool> assigned,
}) {
  final memberIndices = <int>[seedIndex];
  final memberIndexSet = <int>{seedIndex};
  var memberPositionSum = projected[seedIndex].screenPosition;
  var clusterCenter = projected[seedIndex].screenPosition;

  while (true) {
    int? bestCandidateIndex;
    ui.Offset? bestCandidateCenter;
    double? bestCandidateDistance;

    for (var i = 0; i < projected.length; i++) {
      if (assigned[i] || memberIndexSet.contains(i)) {
        continue;
      }

      final candidate = projected[i];
      final proposedCenter =
          (memberPositionSum + candidate.screenPosition) /
          (memberIndices.length + 1).toDouble();
      if (!_isCompactCluster(
        memberIndices: memberIndices,
        candidateIndex: i,
        projected: projected,
        proposedCenter: proposedCenter,
      )) {
        continue;
      }

      final distanceToCenter =
          (candidate.screenPosition - clusterCenter).distance;
      if (bestCandidateIndex == null ||
          distanceToCenter < bestCandidateDistance! ||
          (distanceToCenter == bestCandidateDistance &&
              comparePeakClusterSeedPriority(
                    candidate,
                    projected[bestCandidateIndex],
                  ) <
                  0)) {
        bestCandidateIndex = i;
        bestCandidateCenter = proposedCenter;
        bestCandidateDistance = distanceToCenter;
      }
    }

    if (bestCandidateIndex == null || bestCandidateCenter == null) {
      return memberIndices;
    }

    memberIndices.add(bestCandidateIndex);
    memberIndexSet.add(bestCandidateIndex);
    memberPositionSum += projected[bestCandidateIndex].screenPosition;
    clusterCenter = bestCandidateCenter;
  }
}

List<List<int>> _mergeCompactComponents({
  required List<ProjectedPeakCandidate> projected,
  required List<List<int>> components,
}) {
  final merged = [
    for (final component in components) [...component],
  ];

  while (true) {
    int? bestLeftIndex;
    int? bestRightIndex;
    double? bestCenterDistance;

    for (var i = 0; i < merged.length; i++) {
      for (var j = i + 1; j < merged.length; j++) {
        final union = [...merged[i], ...merged[j]];
        if (!_isCompactMemberSet(memberIndices: union, projected: projected)) {
          continue;
        }

        final centerDistance =
            (_memberSetCenter(memberIndices: merged[i], projected: projected) -
                    _memberSetCenter(
                      memberIndices: merged[j],
                      projected: projected,
                    ))
                .distance;
        if (bestLeftIndex == null || centerDistance < bestCenterDistance!) {
          bestLeftIndex = i;
          bestRightIndex = j;
          bestCenterDistance = centerDistance;
        }
      }
    }

    if (bestLeftIndex == null || bestRightIndex == null) {
      return merged;
    }

    merged[bestLeftIndex].addAll(merged[bestRightIndex]);
    merged.removeAt(bestRightIndex);
  }
}

bool _isCompactCluster({
  required List<int> memberIndices,
  required int candidateIndex,
  required List<ProjectedPeakCandidate> projected,
  required ui.Offset proposedCenter,
}) {
  return _isCompactMemberSet(
    memberIndices: [...memberIndices, candidateIndex],
    projected: projected,
    centerOverride: proposedCenter,
  );
}

bool _isCompactMemberSet({
  required List<int> memberIndices,
  required List<ProjectedPeakCandidate> projected,
  ui.Offset? centerOverride,
}) {
  final center =
      centerOverride ??
      _memberSetCenter(memberIndices: memberIndices, projected: projected);
  for (final index in memberIndices) {
    if ((projected[index].screenPosition - center).distance >
        MapConstants.peakClusterRadius) {
      return false;
    }
  }
  return true;
}

ui.Offset _memberSetCenter({
  required List<int> memberIndices,
  required List<ProjectedPeakCandidate> projected,
}) {
  final center = memberIndices.fold<ui.Offset>(
    ui.Offset.zero,
    (sum, index) => sum + projected[index].screenPosition,
  );
  return center / memberIndices.length.toDouble();
}

List<ui.Offset> peakClusterHullPoints(PeakCluster cluster) {
  if (cluster.members.length < 2) {
    return const [];
  }

  final points = [for (final member in cluster.members) member.screenPosition]
    ..sort((left, right) {
      final dx = left.dx.compareTo(right.dx);
      if (dx != 0) {
        return dx;
      }
      return left.dy.compareTo(right.dy);
    });

  final hull = _convexHull(points);
  if (hull.length < 2) {
    return const [];
  }

  if (hull.length == 2) {
    final a = hull.first;
    final b = hull.last;
    final vector = b - a;
    final normal = vector.distance == 0
        ? const ui.Offset(0, 1)
        : ui.Offset(-vector.dy, vector.dx) / vector.distance;
    final padding = normal * MapConstants.peakMarkerExclusionRadius;
    return [a + padding, b + padding, b - padding, a - padding];
  }

  final center =
      hull.reduce((left, right) => left + right) / hull.length.toDouble();
  return [
    for (final point in hull)
      point +
          ((point - center).distance == 0
              ? const ui.Offset(0, -MapConstants.peakMarkerExclusionRadius)
              : (point - center) /
                    (point - center).distance *
                    MapConstants.peakMarkerExclusionRadius),
  ];
}

ui.Path? peakClusterHullPath(PeakCluster cluster) {
  final hullPoints = peakClusterHullPoints(cluster);
  if (hullPoints.length < 3) {
    return null;
  }

  return ui.Path()..addPolygon(hullPoints, true);
}

double peakClusterVisualRadius(
  PeakCluster cluster, {
  PeakClusterAlgorithm algorithm = MapConstants.peakClusterAlgorithm,
}) {
  if (algorithm == PeakClusterAlgorithm.supercluster) {
    return peakClusterVisualRadiusForCount(cluster.members.length);
  }

  final hullPoints = peakClusterHullPoints(cluster);
  if (hullPoints.length < 2) {
    return peakClusterVisualRadiusForCount(cluster.members.length);
  }

  var midpointDistanceSum = 0.0;
  for (var i = 0; i < hullPoints.length; i++) {
    final nextIndex = (i + 1) % hullPoints.length;
    final midpoint = (hullPoints[i] + hullPoints[nextIndex]) / 2;
    midpointDistanceSum += (midpoint - cluster.screenPosition).distance;
  }

  final hullRadius = midpointDistanceSum / hullPoints.length;
  return math.max(
    peakClusterVisualRadiusForCount(cluster.members.length),
    hullRadius,
  );
}

List<ui.Offset> _convexHull(List<ui.Offset> points) {
  if (points.length <= 1) {
    return points;
  }

  final lower = <ui.Offset>[];
  for (final point in points) {
    while (lower.length >= 2 &&
        _cross(lower[lower.length - 2], lower.last, point) <= 0) {
      lower.removeLast();
    }
    lower.add(point);
  }

  final upper = <ui.Offset>[];
  for (final point in points.reversed) {
    while (upper.length >= 2 &&
        _cross(upper[upper.length - 2], upper.last, point) <= 0) {
      upper.removeLast();
    }
    upper.add(point);
  }

  lower.removeLast();
  upper.removeLast();
  return [...lower, ...upper];
}

double _cross(ui.Offset a, ui.Offset b, ui.Offset c) {
  final ab = b - a;
  final ac = c - a;
  return ab.dx * ac.dy - ab.dy * ac.dx;
}

PeakCluster? hitTestPeakCluster({
  required ui.Offset pointerPosition,
  required PeakClusterViewportData data,
}) {
  PeakCluster? bestCluster;
  double? bestDistance;

  for (final cluster in data.clusters) {
    final distance = (pointerPosition - cluster.screenPosition).distance;
    if (distance >
        peakClusterVisualRadius(cluster) + MapConstants.peakClusterTapPadding) {
      continue;
    }
    if (bestDistance == null || distance < bestDistance) {
      bestDistance = distance;
      bestCluster = cluster;
    }
  }

  return bestCluster;
}

double peakClusterVisualRadiusForCount(int count) {
  // final digits = count.toString().length;
  // (digits - 1) * MapConstants.peakClusterVisualRadiusPerDigit;
  return MapConstants.peakClusterVisualRadius +
      (math.log(count)) * MapConstants.peakClusterVisualRadiusPerDigit;
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
