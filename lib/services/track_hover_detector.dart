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

class TrackHoverDetector {
  static const threshold = 8.0;

  static TrackHoverResult findHoveredTrack({
    required Offset pointerPosition,
    required List<TrackHoverCandidate> candidates,
  }) {
    int? hoveredTrackId;
    double? bestDistance;

    for (final candidate in candidates) {
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
            hoveredTrackId = candidate.trackId;
          }
        }
      }
    }

    return TrackHoverResult(
      hoveredTrackId: hoveredTrackId,
      distance: bestDistance,
    );
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
