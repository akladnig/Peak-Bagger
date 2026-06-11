import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';

class MapScreenPeakLayer extends StatelessWidget {
  const MapScreenPeakLayer({
    required this.peaks,
    required this.zoom,
    required this.showPeakInfo,
    required this.correlatedPeakIds,
    required this.tickedPeakMarker,
    required this.untickedPeakMarker,
    required this.hoveredPeakId,
    super.key,
  });

  final List<Peak> peaks;
  final double zoom;
  final bool showPeakInfo;
  final Set<int> correlatedPeakIds;
  final SvgPicture tickedPeakMarker;
  final SvgPicture untickedPeakMarker;
  final int? hoveredPeakId;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final size = camera.nonRotatedSize;
    if (size == MapCamera.kImpossibleSize) {
      return const SizedBox.shrink();
    }

    final viewportData = buildPeakClusterViewportData(
      peaks: peaks,
      camera: camera,
      correlatedPeakIds: correlatedPeakIds,
    );
    if (viewportData.clusters.isEmpty) {
      return MarkerLayer(
        key: const Key('peak-marker-layer'),
        markers: buildPeakMarkers(
          peaks: peaks,
          zoom: zoom,
          showPeakInfo: showPeakInfo,
          correlatedPeakIds: correlatedPeakIds,
          tickedPeakMarker: tickedPeakMarker,
          untickedPeakMarker: untickedPeakMarker,
          hoveredPeakId: hoveredPeakId,
        ),
      );
    }

    final markerPeaks = viewportData.individualPeaks;

    return Stack(
      key: const Key('peak-marker-layer'),
      children: [
        if (markerPeaks.isNotEmpty)
          MarkerLayer(
            markers: buildPeakMarkers(
              peaks: markerPeaks,
              zoom: zoom,
              showPeakInfo: showPeakInfo,
              correlatedPeakIds: correlatedPeakIds,
              tickedPeakMarker: tickedPeakMarker,
              untickedPeakMarker: untickedPeakMarker,
              hoveredPeakId: hoveredPeakId,
              suppressBelowZoom: false,
            ),
          ),
        if (viewportData.clusters.isNotEmpty)
          MobileLayerTransformer(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                key: const Key('peak-cluster-layer'),
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _PeakClusterPainter(clusters: viewportData.clusters),
                      ),
                    ),
                  ),
                  for (var i = 0; i < viewportData.clusters.length; i++)
                    _PeakClusterCount(
                      cluster: viewportData.clusters[i],
                      index: i,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PeakClusterPainter extends CustomPainter {
  const _PeakClusterPainter({required this.clusters});

  final List<PeakCluster> clusters;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = Colors.white.withValues(alpha: 0.95);
    final borderPaint = Paint()
      ..color = const Color(0xFF3B4A6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final cluster in clusters) {
      canvas.drawCircle(
        cluster.screenPosition,
        MapConstants.peakClusterVisualRadius,
        fillPaint,
      );
      canvas.drawCircle(
        cluster.screenPosition,
        MapConstants.peakClusterVisualRadius,
        borderPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PeakClusterPainter oldDelegate) {
    return oldDelegate.clusters != clusters;
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
