import 'dart:ui';

class PeakHoverCandidate {
  const PeakHoverCandidate({
    required this.peakId,
    required this.screenPosition,
  });

  final int peakId;
  final Offset screenPosition;
}

class PeakHoverResult {
  const PeakHoverResult({this.hoveredPeakId, this.distance});

  final int? hoveredPeakId;
  final double? distance;
}

class PeakHoverDetector {
  static const threshold = 10.0;

  static PeakHoverResult findHoveredPeak({
    required Offset pointerPosition,
    required List<PeakHoverCandidate> candidates,
  }) {
    int? hoveredPeakId;
    double? bestDistance;

    for (final candidate in candidates) {
      final distance = (pointerPosition - candidate.screenPosition).distance;
      if (distance > threshold) {
        continue;
      }
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        hoveredPeakId = candidate.peakId;
      }
    }

    return PeakHoverResult(
      hoveredPeakId: hoveredPeakId,
      distance: bestDistance,
    );
  }
}
