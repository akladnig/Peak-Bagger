import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/theme.dart';

class RouteGraphTrailService {
  RouteGraphTrailService(this._queryService);

  final RouteGraphQueryService _queryService;
  String? _lastVisibleChunkKey;
  List<Polyline> _lastVisiblePolylines = const [];

  List<Polyline> buildVisibleTrails({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    required double zoom,
  }) {
    final chunks = _queryService.queryTrailDisplayChunksForBounds(
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
      zoom: zoom,
    );
    if (chunks.isEmpty) {
      _lastVisibleChunkKey = null;
      _lastVisiblePolylines = const [];
      return const [];
    }

    final visibleChunkKey = _visibleChunkKeyFor(chunks);
    if (_lastVisibleChunkKey == visibleChunkKey) {
      return _lastVisiblePolylines;
    }

    final ways = <int, Polyline>{};
    try {
      for (final chunk in chunks) {
        for (final way in chunk.decodeWays()) {
          if (way.points.length < 2) {
            continue;
          }
          ways.putIfAbsent(way.osmWayId, () => Polyline(points: way.points));
        }
      }
    } on FormatException {
      return const [];
    }

    final polylines = <Polyline>[];
    final style = _styleFor();
    for (final way in ways.values) {
      polylines.addAll([
        Polyline(
          points: way.points,
          color: style.baseColor,
          strokeWidth: style.baseWidth,
          pattern: const StrokePattern.solid(),
        ),
        Polyline(
          points: way.points,
          color: style.overlayColor,
          strokeWidth: style.overlayWidth,
          pattern: StrokePattern.dashed(
            segments: TrailDisplayTheme.overlayDashSegments,
          ),
        ),
      ]);
    }

    _lastVisibleChunkKey = visibleChunkKey;
    _lastVisiblePolylines = polylines;
    return polylines;
  }

  String _visibleChunkKeyFor(List<RouteGraphTrailDisplayChunk> chunks) {
    final keys = chunks.map((chunk) => chunk.recordKey).toList(growable: false)
      ..sort();
    return keys.join(',');
  }
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
