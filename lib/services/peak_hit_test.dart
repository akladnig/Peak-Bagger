import 'dart:ui';

import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';
import 'package:peak_bagger/services/peak_hover_detector.dart';

List<PeakHoverCandidate> buildPeakHoverCandidatesFromViewportData(
  PeakClusterViewportData data,
) {
  return [
    for (final candidate in data.individualCandidates)
      PeakHoverCandidate(
        peakId: candidate.peak.osmId,
        screenPosition: candidate.screenPosition,
      ),
  ];
}

Peak? hitTestPeakFromViewportData({
  required Offset pointerPosition,
  required PeakClusterViewportData data,
}) {
  final hoverCandidates = buildPeakHoverCandidatesFromViewportData(data);
  if (hoverCandidates.isEmpty) {
    return null;
  }

  final result = PeakHoverDetector.findHoveredPeak(
    pointerPosition: pointerPosition,
    candidates: hoverCandidates,
  );
  final peakId = result.hoveredPeakId;
  if (peakId == null) {
    return null;
  }

  for (final candidate in data.individualCandidates) {
    if (candidate.peak.osmId == peakId) {
      return candidate.peak;
    }
  }
  return null;
}
