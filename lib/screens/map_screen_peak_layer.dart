import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';
import 'package:peak_bagger/services/peak_label_layout.dart';
import 'package:peak_bagger/theme.dart';

class MapScreenPeakLayer extends StatelessWidget {
  const MapScreenPeakLayer({
    required this.zoom,
    required this.showPeakInfo,
    required this.hoveredPeakId,
    required this.viewportData,
    required this.popupPeakId,
    super.key,
  });

  final double zoom;
  final bool showPeakInfo;
  final int? hoveredPeakId;
  final PeakClusterViewportData viewportData;
  final int? popupPeakId;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final size = camera.nonRotatedSize;
    if (size == MapCamera.kImpossibleSize) {
      return const SizedBox.shrink();
    }

    ProjectedPeakCandidate? hoveredCandidate;
    if (hoveredPeakId != null) {
      for (final candidate in viewportData.individualCandidates) {
        if (candidate.peak.osmId == hoveredPeakId) {
          hoveredCandidate = candidate;
          break;
        }
      }
    }
    final suppressedLabelIds = {
      for (final peakId in [hoveredPeakId, popupPeakId].whereType<int>())
        peakId,
    };
    final labelPlacements = showPeakInfo
        ? layoutPeakLabels(
            context: context,
            candidates: viewportData.individualCandidates.where(
              (candidate) => !suppressedLabelIds.contains(candidate.peak.osmId),
            ),
          )
        : const <PeakLabelPlacement>[];

    return MobileLayerTransformer(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          key: const Key('peak-marker-layer'),
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PeakViewportPainter(
                    individuals: viewportData.individualCandidates,
                    clusters: viewportData.clusters,
                  ),
                ),
              ),
            ),
            if (viewportData.clusters.isNotEmpty)
              Stack(
                key: const Key('peak-cluster-layer'),
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < viewportData.clusters.length; i++)
                    _PeakClusterCount(
                      cluster: viewportData.clusters[i],
                      index: i,
                    ),
                ],
              ),
            if (hoveredCandidate != null)
              _PeakHoverOverlay(candidate: hoveredCandidate),
            if (labelPlacements.isNotEmpty)
              Stack(
                key: const Key('peak-label-layer'),
                clipBehavior: Clip.none,
                children: [
                  for (final placement in labelPlacements)
                    _PeakMarkerLabelsOverlay(placement: placement),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PeakViewportPainter extends CustomPainter {
  const _PeakViewportPainter({
    required this.individuals,
    required this.clusters,
  });

  final List<ProjectedPeakCandidate> individuals;
  final List<PeakCluster> clusters;

  @override
  void paint(Canvas canvas, Size size) {
    final untickedFill = Paint()..color = untickedColour;
    final tickedFill = Paint()..color = tickedColour;
    final debugHullStroke = Paint()
      ..color = polygonColour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final markerStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final clusterFillColor =
        MapConstants.peakClusterAlgorithm ==
            PeakClusterAlgorithm.markerClusterCompatible
        ? clusterFillColourSecondary
        : clusterFillColourPrimary;
    final clusterFill = Paint()
      ..color = clusterFillColor.withValues(alpha: 0.4);
    final untickedRing = Paint()
      ..color = untickedColour
      ..style = PaintingStyle.stroke
      ..strokeWidth = MapConstants.peakClusterRingWidth
      ..strokeCap = StrokeCap.butt;
    final tickedRing = Paint()
      ..color = tickedColour
      ..style = PaintingStyle.stroke
      ..strokeWidth = MapConstants.peakClusterRingWidth
      ..strokeCap = StrokeCap.butt;
    final ringBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = MapConstants.peakClusterRingBorderWidth;

    for (final candidate in individuals) {
      final center = candidate.screenPosition;
      final path = Path()
        ..moveTo(center.dx, center.dy - 9)
        ..lineTo(center.dx - 7, center.dy + 7)
        ..lineTo(center.dx + 7, center.dy + 7)
        ..close();
      canvas.drawPath(path, candidate.isTicked ? tickedFill : untickedFill);
      canvas.drawPath(path, markerStroke);
    }

    for (final cluster in clusters) {
      final hull =
          MapConstants.peakClusterShowDebugHulls &&
              MapConstants.peakClusterAlgorithm !=
                  PeakClusterAlgorithm.supercluster &&
              cluster.members.length >= 3
          ? peakClusterHullPath(cluster)
          : null;
      if (hull != null) {
        canvas.drawPath(hull, debugHullStroke);
      }

      final radius = peakClusterVisualRadius(
        cluster,
        algorithm: MapConstants.peakClusterAlgorithm,
      );
      final ringHalfWidth = MapConstants.peakClusterRingWidth / 2;
      final innerRingBorderRadius = radius - ringHalfWidth;
      final ringRect = Rect.fromCircle(
        center: cluster.screenPosition,
        radius: radius,
      );
      final startAngle = -math.pi / 2;
      canvas.drawArc(
        ringRect,
        startAngle,
        math.pi * 2 * cluster.untickedFraction,
        false,
        untickedRing,
      );
      canvas.drawArc(
        ringRect,
        startAngle + math.pi * 2 * cluster.untickedFraction,
        math.pi * 2 * cluster.tickedFraction,
        false,
        tickedRing,
      );
      canvas.drawCircle(
        cluster.screenPosition,
        innerRingBorderRadius,
        clusterFill,
      );
      canvas.drawCircle(
        cluster.screenPosition,
        radius + ringHalfWidth,
        ringBorder,
      );
      canvas.drawCircle(
        cluster.screenPosition,
        innerRingBorderRadius,
        ringBorder,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PeakViewportPainter oldDelegate) {
    return oldDelegate.individuals != individuals ||
        oldDelegate.clusters != clusters;
  }
}

class _PeakClusterCount extends StatelessWidget {
  const _PeakClusterCount({required this.cluster, required this.index});

  final PeakCluster cluster;
  final int index;

  @override
  Widget build(BuildContext context) {
    final radius = peakClusterVisualRadius(
      cluster,
      algorithm: MapConstants.peakClusterAlgorithm,
    );
    return Positioned(
      left: cluster.screenPosition.dx - radius,
      top: cluster.screenPosition.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: IgnorePointer(
        child: Center(
          child: Text(
            '${cluster.members.length}',
            key: Key('peak-cluster-count-$index'),
            style: clusterCountTextStyle(),
          ),
        ),
      ),
    );
  }
}

class _PeakHoverOverlay extends StatelessWidget {
  const _PeakHoverOverlay({required this.candidate});

  final ProjectedPeakCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final center = candidate.screenPosition;
    return Positioned(
      key: Key('peak-marker-hover-${candidate.peak.osmId}'),
      left: center.dx - 16,
      top: center.dy - 16,
      width: 32,
      height: 32,
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber, width: 3),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeakMarkerLabelsOverlay extends StatelessWidget {
  const _PeakMarkerLabelsOverlay({required this.placement});

  final PeakLabelPlacement placement;

  @override
  Widget build(BuildContext context) {
    final candidate = placement.candidate;
    final name = candidate.peak.name.trim().isEmpty
        ? '—'
        : candidate.peak.name.trim();
    final height = candidate.peak.elevation == null
        ? '—'
        : formatElevation(candidate.peak.elevation!.round(), showUnits: false);
    final style = peakMarkerLabelTextStyle(context);

    return Positioned(
      top: placement.rect.top,
      left: placement.rect.left,
      width: placement.rect.width,
      child: IgnorePointer(
        child: ConstrainedBox(
          key: Key('peak-marker-labels-${candidate.peak.osmId}'),
          constraints: BoxConstraints(maxWidth: placement.rect.width),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              OutlinedText(
                key: Key('peak-marker-name-${candidate.peak.osmId}'),
                text: name,
                style: style,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              OutlinedText(
                key: Key('peak-marker-height-${candidate.peak.osmId}'),
                text: height,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
