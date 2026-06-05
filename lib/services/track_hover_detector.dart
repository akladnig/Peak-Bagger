import 'dart:ui';

class TrackHoverCandidate {
  const TrackHoverCandidate({required this.trackId, required this.segments});

  final int trackId;
  final List<List<Offset>> segments;
}

class TrackHoverResult {
  const TrackHoverResult({this.hoveredTrackId, this.distance});

  final int? hoveredTrackId;
  final double? distance;
}

class TrackHoverCandidateMatch {
  const TrackHoverCandidateMatch({
    required this.trackId,
    required this.distance,
  });

  final int trackId;
  final double distance;
}

class TrackHoverDetector {
  static const threshold = 8.0;

  static TrackHoverResult findHoveredTrack({
    required Offset pointerPosition,
    required List<TrackHoverCandidate> candidates,
  }) {
    final matches = findHoveredTrackCandidates(
      pointerPosition: pointerPosition,
      candidates: candidates,
    );
    final hoveredTrackId = matches.isEmpty ? null : matches.first.trackId;
    final bestDistance = matches.isEmpty ? null : matches.first.distance;

    return TrackHoverResult(
      hoveredTrackId: hoveredTrackId,
      distance: bestDistance,
    );
  }

  static List<TrackHoverCandidateMatch> findHoveredTrackCandidates({
    required Offset pointerPosition,
    required List<TrackHoverCandidate> candidates,
  }) {
    final matches = <TrackHoverCandidateMatch>[];

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
          TrackHoverCandidateMatch(
            trackId: candidate.trackId,
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
      return left.trackId.compareTo(right.trackId);
    });
    return List<TrackHoverCandidateMatch>.unmodifiable(matches);
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
