import 'package:flutter/material.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';
import 'package:peak_bagger/theme.dart';

class PeakLabelPlacement {
  const PeakLabelPlacement({required this.candidate, required this.rect});

  final ProjectedPeakCandidate candidate;
  final Rect rect;
}

List<PeakLabelPlacement> layoutPeakLabels({
  required BuildContext context,
  required Iterable<ProjectedPeakCandidate> candidates,
}) {
  final maxWidth = peakMarkerLabelMaxWidth(context);
  final style = peakMarkerLabelTextStyle(context);
  final direction = Directionality.of(context);
  final measured = <PeakLabelPlacement>[];
  final markerRects = <int, Rect>{};
  final visibleCandidates = candidates.toList(growable: false);

  for (final candidate in visibleCandidates) {
    markerRects[candidate.peak.osmId] = Rect.fromCircle(
      center: candidate.screenPosition,
      radius: MapConstants.peakMarkerExclusionRadius,
    );
    final name = candidate.peak.name.trim().isEmpty
        ? '—'
        : candidate.peak.name.trim();
    final height = candidate.peak.elevation == null
        ? '—'
        : formatElevation(candidate.peak.elevation!.round(), showUnits: false);
    final nameSize = _measureText(
      text: name,
      style: style,
      maxLines: 2,
      maxWidth: maxWidth,
      direction: direction,
    );
    final heightSize = _measureText(
      text: height,
      style: style,
      maxLines: 1,
      maxWidth: maxWidth,
      direction: direction,
    );
    final width = nameSize.width > heightSize.width
        ? nameSize.width
        : heightSize.width;
    final rect = Rect.fromLTWH(
      candidate.screenPosition.dx - width / 2,
      candidate.screenPosition.dy + 10,
      width,
      nameSize.height + heightSize.height,
    );
    measured.add(PeakLabelPlacement(candidate: candidate, rect: rect));
  }

  measured.sort(
    (left, right) => right.candidate.screenPosition.dy.compareTo(
      left.candidate.screenPosition.dy,
    ),
  );

  final accepted = <PeakLabelPlacement>[];
  for (final placement in measured) {
    if (accepted.any(
      (acceptedPlacement) => acceptedPlacement.rect.overlaps(placement.rect),
    )) {
      continue;
    }
    final overlapsMarker = visibleCandidates.any((candidate) {
      if (candidate.peak.osmId == placement.candidate.peak.osmId) {
        return false;
      }
      return markerRects[candidate.peak.osmId]!.overlaps(placement.rect);
    });
    if (overlapsMarker) {
      continue;
    }
    accepted.add(placement);
  }

  return accepted;
}

Size _measureText({
  required String text,
  required TextStyle style,
  required int maxLines,
  required double maxWidth,
  required TextDirection direction,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textAlign: TextAlign.center,
    maxLines: maxLines,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  return painter.size;
}
