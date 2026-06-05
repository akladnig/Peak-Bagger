import 'dart:ui';

class RouteHoverCandidate {
  const RouteHoverCandidate({required this.routeId, required this.segments});

  final int routeId;
  final List<List<Offset>> segments;
}

class RouteHoverResult {
  const RouteHoverResult({this.hoveredRouteId, this.distance});

  final int? hoveredRouteId;
  final double? distance;
}

class RouteHoverCandidateMatch {
  const RouteHoverCandidateMatch({
    required this.routeId,
    required this.distance,
  });

  final int routeId;
  final double distance;
}

class RouteHoverDetector {
  static const threshold = 8.0;

  static RouteHoverResult findHoveredRoute({
    required Offset pointerPosition,
    required List<RouteHoverCandidate> candidates,
  }) {
    final matches = findHoveredRouteCandidates(
      pointerPosition: pointerPosition,
      candidates: candidates,
    );
    final hoveredRouteId = matches.isEmpty ? null : matches.first.routeId;
    final bestDistance = matches.isEmpty ? null : matches.first.distance;

    return RouteHoverResult(
      hoveredRouteId: hoveredRouteId,
      distance: bestDistance,
    );
  }

  static List<RouteHoverCandidateMatch> findHoveredRouteCandidates({
    required Offset pointerPosition,
    required List<RouteHoverCandidate> candidates,
  }) {
    final matches = <RouteHoverCandidateMatch>[];

    for (final candidate in candidates) {
      double? bestDistance;
      for (final segment in candidate.segments) {
        if (segment.length < 2) {
          continue;
        }

        for (var i = 0; i < segment.length - 1; i++) {
          final distance = _distanceToSegment(
            pointerPosition,
            segment[i],
            segment[i + 1],
          );
          if (distance > threshold) {
            continue;
          }
          if (bestDistance == null || distance < bestDistance) {
            bestDistance = distance;
          }
        }
      }

      if (bestDistance != null) {
        matches.add(
          RouteHoverCandidateMatch(
            routeId: candidate.routeId,
            distance: bestDistance,
          ),
        );
      }
    }

    matches.sort((left, right) {
      final distanceComparison = left.distance.compareTo(right.distance);
      if (distanceComparison != 0) {
        return distanceComparison;
      }
      return left.routeId.compareTo(right.routeId);
    });
    return List<RouteHoverCandidateMatch>.unmodifiable(matches);
  }

  static double _distanceToSegment(Offset point, Offset start, Offset end) {
    final delta = end - start;
    final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
    if (lengthSquared == 0) {
      return (point - start).distance;
    }

    final projection =
        ((point.dx - start.dx) * delta.dx + (point.dy - start.dy) * delta.dy) /
        lengthSquared;
    final t = projection.clamp(0.0, 1.0);
    final closest = Offset(start.dx + delta.dx * t, start.dy + delta.dy * t);
    return (point - closest).distance;
  }
}
