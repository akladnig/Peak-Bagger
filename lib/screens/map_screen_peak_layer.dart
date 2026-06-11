import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';
import 'package:peak_bagger/theme.dart';

class MapScreenPeakLayer extends StatelessWidget {
  const MapScreenPeakLayer({
    required this.zoom,
    required this.showPeakInfo,
    required this.hoveredPeakId,
    required this.viewportData,
    super.key,
  });

  final double zoom;
  final bool showPeakInfo;
  final int? hoveredPeakId;
  final PeakClusterViewportData viewportData;

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
            if (showPeakInfo && zoom >= MapConstants.peakInfoMinZoom)
              for (final candidate in viewportData.individualCandidates)
                if (candidate.peak.osmId != hoveredPeakId)
                  _PeakMarkerLabelsOverlay(candidate: candidate),
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
    final untickedFill = Paint()..color = const Color(0xFFD66A6D);
    final tickedFill = Paint()..color = const Color(0xFF3F8F5B);
    final markerStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final clusterFill = Paint()..color = Colors.white.withValues(alpha: 0.95);
    final clusterStroke = Paint()
      ..color = const Color(0xFF3B4A6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

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
      canvas.drawCircle(
        cluster.screenPosition,
        MapConstants.peakClusterVisualRadius,
        clusterFill,
      );
      canvas.drawCircle(
        cluster.screenPosition,
        MapConstants.peakClusterVisualRadius,
        clusterStroke,
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
    final radius = MapConstants.peakClusterVisualRadius;
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
            style: const TextStyle(
              color: Color(0xFF1E2A44),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
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
  const _PeakMarkerLabelsOverlay({required this.candidate});

  final ProjectedPeakCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final maxWidth = peakMarkerLabelMaxWidth(context);
    final name = candidate.peak.name.trim().isEmpty
        ? '—'
        : candidate.peak.name.trim();
    final height = candidate.peak.elevation == null
        ? '—'
        : formatElevation(candidate.peak.elevation!.round(), showUnits: false);
    final style = peakMarkerLabelTextStyle(context);

    return Positioned(
      top: candidate.screenPosition.dy + 10,
      left: candidate.screenPosition.dx - maxWidth / 2,
      width: maxWidth,
      child: IgnorePointer(
        child: ConstrainedBox(
          key: Key('peak-marker-labels-${candidate.peak.osmId}'),
          constraints: BoxConstraints(maxWidth: maxWidth),
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
