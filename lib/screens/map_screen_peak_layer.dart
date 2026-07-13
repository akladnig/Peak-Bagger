import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';
import 'package:peak_bagger/services/peak_label_layout.dart';
import 'package:peak_bagger/theme.dart';

enum PeakClusterRingStyle { ownershipHybrid, proportionalTickedUnticked }

class MapScreenPeakLayer extends StatelessWidget {
  const MapScreenPeakLayer({
    required this.zoom,
    required this.showPeakInfo,
    required this.hoveredPeakId,
    required this.viewportData,
    required this.popupPeakId,
    this.clusterRingStyle = PeakClusterRingStyle.ownershipHybrid,
    super.key,
  });

  final double zoom;
  final bool showPeakInfo;
  final int? hoveredPeakId;
  final PeakClusterViewportData viewportData;
  final int? popupPeakId;
  final PeakClusterRingStyle clusterRingStyle;

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
                  key: const Key('peak-marker-paint'),
                  painter: PeakViewportPainter(
                    individuals: viewportData.individualCandidates,
                    clusters: viewportData.clusters,
                    clusterRingStyle: clusterRingStyle,
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

class PeakViewportPainter extends CustomPainter {
  const PeakViewportPainter({
    required this.individuals,
    required this.clusters,
    this.clusterRingStyle = PeakClusterRingStyle.ownershipHybrid,
  });

  final List<ProjectedPeakCandidate> individuals;
  final List<PeakCluster> clusters;
  final PeakClusterRingStyle clusterRingStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final untickedFill = Paint()..color = untickedColour;
    final tickedFill = Paint()..color = tickedColour;
    final individualRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.butt;
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
    final clusterOwnershipRingPaint = Paint()
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
      if (candidate.ownershipRingSegments.isNotEmpty) {
        final ringRect = Rect.fromCircle(center: center, radius: 11);
        final sweepAngle = (math.pi * 2) / candidate.ownershipRingSegments.length;
        var startAngle = -math.pi / 2;
        for (final segment in candidate.ownershipRingSegments) {
          individualRingPaint.color = Color(segment.colourValue);
          canvas.drawArc(
            ringRect,
            startAngle,
            sweepAngle,
            false,
            individualRingPaint,
          );
          startAngle += sweepAngle;
        }
      }

      final path = Path()
        ..moveTo(center.dx, center.dy - 9)
        ..lineTo(center.dx - 7, center.dy + 7)
        ..lineTo(center.dx + 7, center.dy + 7)
        ..close();
      canvas.drawPath(
        path,
        candidate.isTicked
            ? tickedFill
            : (candidate.untickedColourValue == null
                  ? untickedFill
                  : (Paint()..color = Color(candidate.untickedColourValue!))),
      );
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
      final totalSweep = math.pi * 2;
      const startAngle = -math.pi / 2;
      if (clusterRingStyle == PeakClusterRingStyle.proportionalTickedUnticked) {
        canvas.drawArc(
          ringRect,
          startAngle,
          totalSweep * cluster.untickedFraction,
          false,
          clusterOwnershipRingPaint..color = untickedColour,
        );
        canvas.drawArc(
          ringRect,
          startAngle + totalSweep * cluster.untickedFraction,
          totalSweep * cluster.tickedFraction,
          false,
          tickedRing,
        );
      } else {
        final untickedSegments = cluster.untickedOwnershipRingSegments;
        var segmentStartAngle = startAngle;
        if (untickedSegments.isEmpty) {
          canvas.drawArc(
            ringRect,
            startAngle,
            totalSweep,
            false,
            tickedRing,
          );
        } else {
          final untickedSweep = totalSweep * cluster.untickedFraction;
          final perSegmentSweep = untickedSweep / untickedSegments.length;
          for (final segment in untickedSegments) {
            clusterOwnershipRingPaint.color = Color(segment.colourValue);
            canvas.drawArc(
              ringRect,
              segmentStartAngle,
              perSegmentSweep,
              false,
              clusterOwnershipRingPaint,
            );
            segmentStartAngle += perSegmentSweep;
          }
          if (cluster.tickedFraction > 0) {
            canvas.drawArc(
              ringRect,
              segmentStartAngle,
              totalSweep * cluster.tickedFraction,
              false,
              tickedRing,
            );
          }
        }
      }
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
  bool shouldRepaint(covariant PeakViewportPainter oldDelegate) {
    return oldDelegate.individuals != individuals ||
        oldDelegate.clusters != clusters ||
        oldDelegate.clusterRingStyle != clusterRingStyle;
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
              ),
              OutlinedText(
                key: Key('peak-marker-height-${candidate.peak.osmId}'),
                text: height,
                style: style,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
