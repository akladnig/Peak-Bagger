import 'dart:ui' as ui;

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/services/elevation_profile_series_builder.dart';
import 'package:peak_bagger/services/gpx_track_geometry.dart';
import 'package:peak_bagger/widgets/elevation_profile_chart.dart';

class MapChartHoverResolver {
  const MapChartHoverResolver({GpxTrackGeometryParser? trackGeometryParser})
      : _trackGeometryParser = trackGeometryParser ?? const GpxTrackGeometryParser();

  final GpxTrackGeometryParser _trackGeometryParser;

  LatLng? resolveRouteHover({
    required app_route.Route route,
    required ElevationProfileChartHoverSample hoverSample,
  }) {
    return _resolveAlongPolyline(
      points: route.gpxRoute,
      targetDistanceMeters: hoverSample.xValue,
    );
  }

  LatLng? resolveTrackHover({
    required GpxTrack track,
    required ElevationProfileChartHoverSample hoverSample,
  }) {
    final xml = track.gpxFileRepaired.isNotEmpty ? track.gpxFileRepaired : track.gpxFile;
    if (xml.isEmpty) {
      return null;
    }

    final segments = _trackGeometryParser.extractSegments(xml);
    return switch (hoverSample.axisMode) {
      ElevationProfileAxisMode.distance => _resolveTrackByDistance(
        segments: segments,
        targetDistanceMeters: hoverSample.xValue,
      ),
      ElevationProfileAxisMode.time => _resolveTrackByTime(
        track: track,
        segments: segments,
        targetTimeMillis: hoverSample.xValue,
      ),
    };
  }

  static const _distance = Distance();

  LatLng? _resolveAlongPolyline({
    required List<LatLng> points,
    required double targetDistanceMeters,
  }) {
    if (points.isEmpty) {
      return null;
    }
    if (points.length == 1) {
      return points.first;
    }

    final geometry = <_GeometryPoint>[];
    var distanceMeters = 0.0;
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      geometry.add(_GeometryPoint(point: point, distanceMeters: distanceMeters));
      if (index < points.length - 1) {
        distanceMeters += _distance.as(
          LengthUnit.Meter,
          point,
          points[index + 1],
        );
      }
    }

    return _resolveAlongGeometry(
      geometry: geometry,
      targetDistanceMeters: targetDistanceMeters,
    );
  }

  LatLng? _resolveTrackByDistance({
    required List<List<LatLng>> segments,
    required double targetDistanceMeters,
  }) {
    final geometry = _buildTrackGeometryPoints(segments);
    if (geometry.isEmpty) {
      return null;
    }

    return _resolveAlongTrackGeometry(
      geometry: geometry,
      targetDistanceMeters: targetDistanceMeters,
    );
  }

  LatLng? _resolveTrackByTime({
    required GpxTrack track,
    required List<List<LatLng>> segments,
    required double targetTimeMillis,
  }) {
    final series = ElevationProfileSeriesBuilder.fromTrackProfileJson(
      track.elevationProfile,
    );
    if (series.samples.isEmpty) {
      return null;
    }

    final timedPoints = <_TimedTrackGeometryPoint>[];
    for (final sample in series.samples) {
      final timeLocal = sample.timeLocal;
      final segmentIndex = sample.segmentIndex;
      final pointIndex = sample.pointIndex;
      if (timeLocal == null || segmentIndex == null || pointIndex == null) {
        continue;
      }

      final point = _pointAt(segments, segmentIndex, pointIndex);
      if (point == null) {
        continue;
      }

      timedPoints.add(
        _TimedTrackGeometryPoint(
          point: point,
          timeMillis: timeLocal.millisecondsSinceEpoch.toDouble(),
        ),
      );
    }

    if (timedPoints.isEmpty) {
      return null;
    }

    return _resolveAlongTimedGeometry(
      geometry: timedPoints,
      targetTimeMillis: targetTimeMillis,
    );
  }

  LatLng? _resolveAlongGeometry({
    required List<_GeometryPoint> geometry,
    required double targetDistanceMeters,
  }) {
    if (geometry.isEmpty) {
      return null;
    }
    if (geometry.length == 1) {
      return geometry.first.point;
    }

    if (!targetDistanceMeters.isFinite) {
      return geometry.first.point;
    }

    final firstDistance = geometry.first.distanceMeters;
    final lastDistance = geometry.last.distanceMeters;
    if (targetDistanceMeters <= firstDistance) {
      return geometry.first.point;
    }
    if (targetDistanceMeters >= lastDistance) {
      return geometry.last.point;
    }

    for (var index = 1; index < geometry.length; index++) {
      final upper = geometry[index];
      if (upper.distanceMeters < targetDistanceMeters) {
        continue;
      }

      final lower = geometry[index - 1];
      final span = upper.distanceMeters - lower.distanceMeters;
      if (span <= 0) {
        return upper.point;
      }

      final t = (targetDistanceMeters - lower.distanceMeters) / span;
      return LatLng(
        ui.lerpDouble(lower.point.latitude, upper.point.latitude, t)!,
        ui.lerpDouble(lower.point.longitude, upper.point.longitude, t)!,
      );
    }

    return geometry.last.point;
  }

  LatLng? _resolveAlongTrackGeometry({
    required List<_TrackGeometryPoint> geometry,
    required double targetDistanceMeters,
  }) {
    if (geometry.isEmpty) {
      return null;
    }
    if (geometry.length == 1) {
      return geometry.first.point;
    }

    if (!targetDistanceMeters.isFinite) {
      return geometry.first.point;
    }

    final firstDistance = geometry.first.distanceMeters;
    final lastDistance = geometry.last.distanceMeters;
    if (targetDistanceMeters <= firstDistance) {
      return geometry.first.point;
    }
    if (targetDistanceMeters >= lastDistance) {
      return geometry.last.point;
    }

    for (var index = 1; index < geometry.length; index++) {
      final upper = geometry[index];
      if (upper.distanceMeters < targetDistanceMeters) {
        continue;
      }

      final lower = geometry[index - 1];
      final span = upper.distanceMeters - lower.distanceMeters;
      if (span <= 0) {
        return upper.point;
      }

      final t = (targetDistanceMeters - lower.distanceMeters) / span;
      return LatLng(
        ui.lerpDouble(lower.point.latitude, upper.point.latitude, t)!,
        ui.lerpDouble(lower.point.longitude, upper.point.longitude, t)!,
      );
    }

    return geometry.last.point;
  }

  LatLng? _resolveAlongTimedGeometry({
    required List<_TimedTrackGeometryPoint> geometry,
    required double targetTimeMillis,
  }) {
    if (geometry.isEmpty) {
      return null;
    }
    if (geometry.length == 1) {
      return geometry.first.point;
    }

    if (!targetTimeMillis.isFinite) {
      return geometry.first.point;
    }

    final firstTime = geometry.first.timeMillis;
    final lastTime = geometry.last.timeMillis;
    if (targetTimeMillis <= firstTime) {
      return geometry.first.point;
    }
    if (targetTimeMillis >= lastTime) {
      return geometry.last.point;
    }

    for (var index = 1; index < geometry.length; index++) {
      final upper = geometry[index];
      if (upper.timeMillis < targetTimeMillis) {
        continue;
      }

      final lower = geometry[index - 1];
      final span = upper.timeMillis - lower.timeMillis;
      if (span <= 0) {
        return upper.point;
      }

      final t = (targetTimeMillis - lower.timeMillis) / span;
      return LatLng(
        ui.lerpDouble(lower.point.latitude, upper.point.latitude, t)!,
        ui.lerpDouble(lower.point.longitude, upper.point.longitude, t)!,
      );
    }

    return geometry.last.point;
  }

  List<_TrackGeometryPoint> _buildTrackGeometryPoints(
    List<List<LatLng>> segments,
  ) {
    final geometry = <_TrackGeometryPoint>[];
    var distanceMeters = 0.0;
    for (var segmentIndex = 0; segmentIndex < segments.length; segmentIndex++) {
      final segment = segments[segmentIndex];
      if (segment.isEmpty) {
        continue;
      }

      for (var pointIndex = 0; pointIndex < segment.length; pointIndex++) {
        final point = segment[pointIndex];
        geometry.add(
          _TrackGeometryPoint(
            point: point,
            distanceMeters: distanceMeters,
            segmentIndex: segmentIndex,
            pointIndex: pointIndex,
          ),
        );

        if (pointIndex < segment.length - 1) {
          distanceMeters += _distance.as(
            LengthUnit.Meter,
            point,
            segment[pointIndex + 1],
          );
        }
      }
    }

    return geometry;
  }

  LatLng? _pointAt(List<List<LatLng>> segments, int segmentIndex, int pointIndex) {
    if (segmentIndex < 0 || segmentIndex >= segments.length) {
      return null;
    }

    final segment = segments[segmentIndex];
    if (pointIndex < 0 || pointIndex >= segment.length) {
      return null;
    }

    return segment[pointIndex];
  }
}

class _GeometryPoint {
  const _GeometryPoint({
    required this.point,
    required this.distanceMeters,
  });

  final LatLng point;
  final double distanceMeters;
}

class _TrackGeometryPoint {
  const _TrackGeometryPoint({
    required this.point,
    required this.distanceMeters,
    required this.segmentIndex,
    required this.pointIndex,
  });

  final LatLng point;
  final double distanceMeters;
  final int segmentIndex;
  final int pointIndex;
}

class _TimedTrackGeometryPoint {
  const _TimedTrackGeometryPoint({
    required this.point,
    required this.timeMillis,
  });

  final LatLng point;
  final double timeMillis;
}
