import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/route_hover_detector.dart';

enum RouteGraphDriveEtaHitStatus { hit, noHit, unavailable }

class RouteGraphDriveEtaHitResult {
  const RouteGraphDriveEtaHitResult._({
    required this.status,
    this.snappedPoint,
    this.matchedWayId,
    this.wayName,
    this.message,
  });

  const RouteGraphDriveEtaHitResult.hit({
    required LatLng snappedPoint,
    required int matchedWayId,
    required String? wayName,
  }) : this._(
         status: RouteGraphDriveEtaHitStatus.hit,
         snappedPoint: snappedPoint,
         matchedWayId: matchedWayId,
         wayName: wayName,
       );

  const RouteGraphDriveEtaHitResult.noHit()
    : this._(status: RouteGraphDriveEtaHitStatus.noHit);

  const RouteGraphDriveEtaHitResult.unavailable([String? message])
    : this._(
         status: RouteGraphDriveEtaHitStatus.unavailable,
         message: message ?? 'Route graph data is unavailable.',
       );

  final RouteGraphDriveEtaHitStatus status;
  final LatLng? snappedPoint;
  final int? matchedWayId;
  final String? wayName;
  final String? message;
}

class RouteGraphDriveEtaHitService {
  RouteGraphDriveEtaHitService(this._queryService);

  final RouteGraphQueryService _queryService;
  int? _cachedGeneration;
  String? _cachedVisibleChunkKey;
  List<_DriveEtaWayGeometry>? _cachedVisibleWays;

  @visibleForTesting
  String? get debugCachedVisibleChunkKey => _cachedVisibleChunkKey;

  @visibleForTesting
  Object? get debugCachedVisibleWaysIdentity => _cachedVisibleWays;

  RouteGraphDriveEtaHitResult hitTest({
    required Offset pointerPosition,
    required MapCamera camera,
    required LatLng tappedLocation,
  }) {
    if (camera.zoom < MapConstants.driveEtaMinZoom) {
      return const RouteGraphDriveEtaHitResult.noHit();
    }

    final chunks = _queryService.queryChunksForBounds(
      minLat: camera.visibleBounds.south,
      minLon: camera.visibleBounds.west,
      maxLat: camera.visibleBounds.north,
      maxLon: camera.visibleBounds.east,
    );
    if (chunks.isEmpty) {
      return const RouteGraphDriveEtaHitResult.unavailable();
    }

    final visibleChunkKeys = chunks.map((chunk) => chunk.chunkKey).toSet();
    final rows = _queryService
        .queryDriveEtaWaysForBounds(
          minLat: camera.visibleBounds.south,
          minLon: camera.visibleBounds.west,
          maxLat: camera.visibleBounds.north,
          maxLon: camera.visibleBounds.east,
        )
        .where((row) => visibleChunkKeys.contains(row.chunkKey))
        .toList(growable: false);
    if (rows.isEmpty) {
      return const RouteGraphDriveEtaHitResult.noHit();
    }

    final ways = _visibleWaysFor(chunks: chunks, rows: rows);
    if (ways.isEmpty) {
      return const RouteGraphDriveEtaHitResult.noHit();
    }

    _HitCandidate? bestCandidate;
    for (final way in ways) {
      for (var index = 0; index < way.points.length - 1; index++) {
        final startPoint = way.points[index];
        final endPoint = way.points[index + 1];
        final startOffset = camera.latLngToScreenOffset(startPoint);
        final endOffset = camera.latLngToScreenOffset(endPoint);
        final projection = _project(pointerPosition, startOffset, endOffset);
        if (projection.distance > RouteHoverDetector.threshold) {
          continue;
        }

        if (bestCandidate == null || projection.distance < bestCandidate.distance) {
          bestCandidate = _HitCandidate(
            distance: projection.distance,
            snappedPoint: _interpolateLatLng(startPoint, endPoint, projection.t),
            way: way,
          );
        }
      }
    }

    if (bestCandidate == null) {
      return const RouteGraphDriveEtaHitResult.noHit();
    }

    return RouteGraphDriveEtaHitResult.hit(
      snappedPoint: bestCandidate.snappedPoint,
      matchedWayId: bestCandidate.way.osmWayId,
      wayName: bestCandidate.way.name,
    );
  }

  List<_DriveEtaWayGeometry> _visibleWaysFor({
    required List<RouteGraphChunk> chunks,
    required List<RouteGraphWayIndex> rows,
  }) {
    final generation = rows.first.generation;
    final visibleChunkKey = chunks.map((chunk) => chunk.recordKey).toList()..sort();
    final joinedVisibleChunkKey = visibleChunkKey.join(',');
    if (_cachedGeneration == generation &&
        _cachedVisibleChunkKey == joinedVisibleChunkKey &&
        _cachedVisibleWays != null) {
      return _cachedVisibleWays!;
    }

    final rowsByWayId = <int, RouteGraphWayIndex>{
      for (final row in rows) row.osmWayId: row,
    };
    final nodeById = <int, LatLng>{};
    final ways = <int, _DriveEtaWayGeometry>{};

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
        final typed = Map<String, dynamic>.from(element.cast<String, dynamic>());
        if (typed['type'] == 'node') {
          final id = typed['id'];
          final lat = typed['lat'];
          final lon = typed['lon'];
          if (id is int && lat is num && lon is num) {
            nodeById[id] = LatLng(lat.toDouble(), lon.toDouble());
          }
        }
      }

      for (final element in elements) {
        if (element is! Map) {
          continue;
        }
        final typed = Map<String, dynamic>.from(element.cast<String, dynamic>());
        if (typed['type'] != 'way') {
          continue;
        }
        final wayId = typed['id'];
        final row = wayId is int ? rowsByWayId[wayId] : null;
        if (row == null || ways.containsKey(row.osmWayId)) {
          continue;
        }
        final nodeIds = typed['nodes'];
        if (nodeIds is! List) {
          continue;
        }
        final points = <LatLng>[];
        for (final nodeId in nodeIds) {
          if (nodeId is! int) {
            continue;
          }
          final point = nodeById[nodeId];
          if (point != null) {
            points.add(point);
          }
        }
        if (points.length < 2) {
          continue;
        }
        ways[row.osmWayId] = _DriveEtaWayGeometry(
          osmWayId: row.osmWayId,
          name: row.name?.trim().isEmpty ?? true ? null : row.name?.trim(),
          points: points,
        );
      }
    }

    final visibleWays = ways.values.toList(growable: false);
    _cachedGeneration = generation;
    _cachedVisibleChunkKey = joinedVisibleChunkKey;
    _cachedVisibleWays = visibleWays;
    return visibleWays;
  }
}

class _DriveEtaWayGeometry {
  const _DriveEtaWayGeometry({
    required this.osmWayId,
    required this.name,
    required this.points,
  });

  final int osmWayId;
  final String? name;
  final List<LatLng> points;
}

class _HitCandidate {
  const _HitCandidate({
    required this.distance,
    required this.snappedPoint,
    required this.way,
  });

  final double distance;
  final LatLng snappedPoint;
  final _DriveEtaWayGeometry way;
}

class _ProjectionResult {
  const _ProjectionResult({required this.distance, required this.t});

  final double distance;
  final double t;
}

_ProjectionResult _project(Offset point, Offset start, Offset end) {
  final delta = end - start;
  final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
  if (lengthSquared == 0) {
    return _ProjectionResult(distance: (point - start).distance, t: 0);
  }

  final projection =
      ((point.dx - start.dx) * delta.dx + (point.dy - start.dy) * delta.dy) /
      lengthSquared;
  final t = projection.clamp(0.0, 1.0);
  final closest = Offset(start.dx + delta.dx * t, start.dy + delta.dy * t);
  return _ProjectionResult(distance: (point - closest).distance, t: t);
}

LatLng _interpolateLatLng(LatLng start, LatLng end, double t) {
  return LatLng(
    start.latitude + (end.latitude - start.latitude) * t,
    start.longitude + (end.longitude - start.longitude) * t,
  );
}
