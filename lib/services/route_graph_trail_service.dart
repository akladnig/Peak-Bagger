import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/theme.dart';

class RouteGraphTrailService {
  RouteGraphTrailService(this._queryService);

  final RouteGraphQueryService _queryService;

  List<Polyline> buildVisibleTrails({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  }) {
    final wayRows = _queryService.queryTrailWays();
    final trailWayIds = wayRows.map((row) => row.osmWayId).toSet();
    if (trailWayIds.isEmpty) {
      return const [];
    }
    final chunks = _queryService.queryTrailChunksForBounds(
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
    );
    if (chunks.isEmpty) {
      return const [];
    }

    final nodes = <int, LatLng>{};
    final ways = <int, _TrailWay>{};

    for (final chunk in chunks) {
      final payload = chunk.decodePayload();
      final elements = payload['elements'];
      if (elements is! List) {
        continue;
      }

      for (final element in elements) {
        if (element is! Map) {
          continue;
        }

        final typed = Map<String, dynamic>.from(element);
        final type = typed['type'];
        final id = typed['id'];
        if (type is! String || id is! int) {
          continue;
        }

        if (type == 'node') {
          final lat = typed['lat'];
          final lon = typed['lon'];
          if (lat is! num || lon is! num) {
            continue;
          }
          nodes.putIfAbsent(id, () => LatLng(lat.toDouble(), lon.toDouble()));
        } else if (type == 'way' && trailWayIds.contains(id)) {
          final tags = typed['tags'];
          final nodeIds = typed['nodes'];
          if (tags is! Map || nodeIds is! List) {
            continue;
          }

          ways.putIfAbsent(
            id,
            () => _TrailWay(
              nodeIds: nodeIds
                  .map((nodeId) => nodeId is int ? nodeId : null)
                  .whereType<int>()
                  .toList(growable: false),
            ),
          );
        }
      }
    }

    final polylines = <Polyline>[];
    for (final way in ways.values) {
      final points = way.nodeIds
          .map((nodeId) => nodes[nodeId])
          .whereType<LatLng>()
          .toList(growable: false);
      if (points.length < 2) {
        continue;
      }

      final style = _styleFor();
      polylines.addAll([
        Polyline(
          points: points,
          color: style.baseColor,
          strokeWidth: style.baseWidth,
          pattern: const StrokePattern.solid(),
        ),
        Polyline(
          points: points,
          color: style.overlayColor,
          strokeWidth: style.overlayWidth,
          pattern: StrokePattern.dashed(
            segments: TrailDisplayTheme.overlayDashSegments,
          ),
        ),
      ]);
    }

    return polylines;
  }
}

class _TrailWay {
  const _TrailWay({
    required this.nodeIds,
  });

  final List<int> nodeIds;
}

class _TrailStyle {
  const _TrailStyle({
    required this.baseColor,
    required this.overlayColor,
    required this.baseWidth,
    required this.overlayWidth,
  });

  final Color baseColor;
  final Color overlayColor;
  final double baseWidth;
  final double overlayWidth;
}

_TrailStyle _styleFor() {
  return const _TrailStyle(
    baseColor: TrailDisplayTheme.baseColor,
    overlayColor: TrailDisplayTheme.overlayColor,
    baseWidth: TrailDisplayTheme.baseStrokeWidth,
    overlayWidth: TrailDisplayTheme.overlayStrokeWidth,
  );
}
