import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

class GpxTrackPoint {
  const GpxTrackPoint({
    required this.location,
    required this.rawElevation,
    required this.elevation,
    required this.timeUtc,
    required this.timeLocal,
  });

  final LatLng location;
  final double? rawElevation;
  final double? elevation;
  final DateTime? timeUtc;
  final DateTime? timeLocal;
}

class GpxTrackTimeStats {
  const GpxTrackTimeStats({
    required this.startDateTime,
    required this.endDateTime,
    required this.totalTimeMillis,
    required this.movingTime,
    required this.restingTime,
    required this.pausedTime,
  });

  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final int totalTimeMillis;
  final int movingTime;
  final int restingTime;
  final int pausedTime;
}

class GpxMovingLeg {
  const GpxMovingLeg({
    required this.startPoint,
    required this.endPoint,
    required this.horizontalDistanceMeters,
    required this.distanceMeters,
    required this.duration,
  });

  final GpxTrackPoint startPoint;
  final GpxTrackPoint endPoint;
  final double horizontalDistanceMeters;
  final double distanceMeters;
  final Duration duration;

  LatLng get midpoint => LatLng(
    (startPoint.location.latitude + endPoint.location.latitude) / 2,
    (startPoint.location.longitude + endPoint.location.longitude) / 2,
  );
}

class GpxTrackMotionAnalyzer {
  static const _distance = Distance();
  static const _entryNetDisplacementMeters = 5.0;
  static const _entryMaxRadiusMeters = 10.0;
  static const _entryPathLengthMeters = 15.0;
  static const _entrySpeedMetersPerSecond = 0.12;
  static const _exitNetDisplacementMeters = 8.0;
  static const _exitMaxRadiusMeters = 12.0;
  static const _exitPathLengthMeters = 20.0;
  static const _exitSpeedMetersPerSecond = 0.3;
  static const _minimumRestDurationSeconds = 15;
  static const _exitFailureCountToClose = 2;

  const GpxTrackMotionAnalyzer();

  List<List<GpxTrackPoint>> extractSegmentsFromXml(String gpxXml) {
    return extractSegmentsFromDocument(XmlDocument.parse(gpxXml));
  }

  List<List<GpxTrackPoint>> extractSegmentsFromDocument(XmlDocument document) {
    final trackSegments = document.findAllElements('trkseg').toList(growable: false);
    if (trackSegments.isNotEmpty) {
      final segments = <List<GpxTrackPoint>>[];
      for (final segment in trackSegments) {
        final points = _extractPoints(segment.findElements('trkpt'));
        if (points.isNotEmpty) {
          segments.add(points);
        }
      }
      return segments;
    }

    final trackPoints = _extractPoints(document.findAllElements('trkpt'));
    if (trackPoints.isNotEmpty) {
      return [trackPoints];
    }

    final routePoints = _extractPoints(document.findAllElements('rtept'));
    if (routePoints.isNotEmpty) {
      return [routePoints];
    }

    return const [];
  }

  GpxTrackTimeStats calculateTimeStatsForSegments(List<List<GpxTrackPoint>> segments) {
    final parseableSegments = _parseableSegments(segments);
    if (parseableSegments.isEmpty) {
      return const GpxTrackTimeStats(
        startDateTime: null,
        endDateTime: null,
        totalTimeMillis: 0,
        movingTime: 0,
        restingTime: 0,
        pausedTime: 0,
      );
    }

    final firstSegment = parseableSegments.first;
    final lastSegment = parseableSegments.last;
    final startDateTime = firstSegment.first.timeUtc;
    final endDateTime = lastSegment.last.timeUtc;

    var totalDurationSeconds = 0;
    var restingDurationSeconds = 0;
    var pausedDurationSeconds = 0;

    for (var segmentIndex = 0; segmentIndex < parseableSegments.length; segmentIndex++) {
      final segment = parseableSegments[segmentIndex];
      if (segment.length >= 2) {
        final restingLegIndexes = _restingLegIndexes(segment);
        for (var pointIndex = 0; pointIndex < segment.length - 1; pointIndex++) {
          final current = segment[pointIndex];
          final next = segment[pointIndex + 1];
          final dtSeconds = next.timeUtc!.difference(current.timeUtc!).inSeconds;
          if (dtSeconds <= 0) {
            continue;
          }

          totalDurationSeconds += dtSeconds;
          if (restingLegIndexes.contains(pointIndex)) {
            restingDurationSeconds += dtSeconds;
          }
        }
      }

      if (segmentIndex < parseableSegments.length - 1) {
        final nextSegment = parseableSegments[segmentIndex + 1];
        final gapSeconds = nextSegment.first.timeUtc!.difference(segment.last.timeUtc!).inSeconds;
        if (gapSeconds > 0) {
          pausedDurationSeconds += gapSeconds;
        }
      }
    }

    final totalTimeMillis = totalDurationSeconds * 1000;
    final restingTime = restingDurationSeconds * 1000;
    final pausedTime = pausedDurationSeconds * 1000;

    return GpxTrackTimeStats(
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      totalTimeMillis: totalTimeMillis,
      movingTime: totalTimeMillis - restingTime,
      restingTime: restingTime,
      pausedTime: pausedTime,
    );
  }

  List<GpxMovingLeg> extractMovingLegsForSegments(List<List<GpxTrackPoint>> segments) {
    final parseableSegments = _parseableSegments(segments);
    final legs = <GpxMovingLeg>[];
    for (final segment in parseableSegments) {
      if (segment.length < 2) {
        continue;
      }

      final restingLegIndexes = _restingLegIndexes(segment);
      for (var pointIndex = 0; pointIndex < segment.length - 1; pointIndex++) {
        if (restingLegIndexes.contains(pointIndex)) {
          continue;
        }

        final current = segment[pointIndex];
        final next = segment[pointIndex + 1];
        final dtSeconds = next.timeUtc!.difference(current.timeUtc!).inSeconds;
        if (dtSeconds <= 0) {
          continue;
        }

        legs.add(
          GpxMovingLeg(
            startPoint: current,
            endPoint: next,
            horizontalDistanceMeters: _horizontalDistanceMeters(current, next),
            distanceMeters: segmentDistanceMeters(current, next),
            duration: Duration(seconds: dtSeconds),
          ),
        );
      }
    }
    return legs;
  }

  double segmentDistanceMeters(GpxTrackPoint left, GpxTrackPoint right) {
    final horizontalMeters = _horizontalDistanceMeters(left, right);
    final leftElevation = left.elevation;
    final rightElevation = right.elevation;
    if (leftElevation == null || rightElevation == null) {
      return horizontalMeters;
    }

    final elevationDelta = leftElevation - rightElevation;
    if (elevationDelta == 0) {
      return horizontalMeters;
    }

    return math.sqrt(
      horizontalMeters * horizontalMeters + elevationDelta * elevationDelta,
    );
  }

  List<List<GpxTrackPoint>> _parseableSegments(List<List<GpxTrackPoint>> segments) {
    final parseableSegments = <List<GpxTrackPoint>>[];
    for (final segment in segments) {
      final parseablePoints = segment
          .where((point) => point.timeUtc != null)
          .toList(growable: false)
        ..sort((a, b) => a.timeUtc!.compareTo(b.timeUtc!));
      if (parseablePoints.isNotEmpty) {
        parseableSegments.add(parseablePoints);
      }
    }
    return parseableSegments;
  }

  Set<int> _restingLegIndexes(List<GpxTrackPoint> segment) {
    final clusterPoints = <GpxTrackPoint>[segment.first];
    final restingLegIndexes = <int>{};
    var clusterActive = false;
    var clusterStartIndex = 0;
    var exitFailureCount = 0;

    for (var pointIndex = 0; pointIndex < segment.length - 1; pointIndex++) {
      final current = segment[pointIndex];
      final next = segment[pointIndex + 1];
      final dtSeconds = next.timeUtc!.difference(current.timeUtc!).inSeconds;
      if (dtSeconds <= 0) {
        continue;
      }

      final candidatePoints = [...clusterPoints, next];
      final candidateMetrics = _stationaryMetrics(candidatePoints);

      if (!clusterActive) {
        if (_meetsEntryThresholds(candidateMetrics)) {
          clusterPoints.add(next);
          if (candidateMetrics.durationSeconds >= _minimumRestDurationSeconds) {
            clusterActive = true;
            exitFailureCount = 0;
          }
        } else {
          clusterPoints
            ..clear()
            ..add(next);
          clusterStartIndex = pointIndex + 1;
          clusterActive = false;
          exitFailureCount = 0;
        }
        continue;
      }

      if (_meetsExitThresholds(candidateMetrics)) {
        clusterPoints.add(next);
        exitFailureCount = 0;
        continue;
      }

      exitFailureCount += 1;
      if (exitFailureCount < _exitFailureCountToClose) {
        clusterPoints.add(next);
        continue;
      }

      for (var legIndex = clusterStartIndex; legIndex < pointIndex; legIndex++) {
        restingLegIndexes.add(legIndex);
      }
      clusterPoints
        ..clear()
        ..add(next);
      clusterStartIndex = pointIndex + 1;
      clusterActive = false;
      exitFailureCount = 0;
    }

    if (clusterActive) {
      final clusterDurationSeconds = _stationaryMetrics(clusterPoints).durationSeconds;
      if (clusterDurationSeconds >= _minimumRestDurationSeconds) {
        for (var legIndex = clusterStartIndex; legIndex < segment.length - 1; legIndex++) {
          restingLegIndexes.add(legIndex);
        }
      }
    }

    return restingLegIndexes;
  }

  bool _meetsEntryThresholds(_StationaryClusterMetrics metrics) {
    return metrics.netDisplacementMeters <= _entryNetDisplacementMeters &&
        metrics.maxRadiusMeters <= _entryMaxRadiusMeters &&
        metrics.cumulativePathLengthMeters <= _entryPathLengthMeters &&
        metrics.maxSpeedMetersPerSecond <= _entrySpeedMetersPerSecond;
  }

  bool _meetsExitThresholds(_StationaryClusterMetrics metrics) {
    return metrics.netDisplacementMeters <= _exitNetDisplacementMeters &&
        metrics.maxRadiusMeters <= _exitMaxRadiusMeters &&
        metrics.cumulativePathLengthMeters <= _exitPathLengthMeters &&
        metrics.maxSpeedMetersPerSecond <= _exitSpeedMetersPerSecond;
  }

  _StationaryClusterMetrics _stationaryMetrics(List<GpxTrackPoint> points) {
    if (points.isEmpty) {
      return const _StationaryClusterMetrics(
        durationSeconds: 0,
        netDisplacementMeters: 0,
        maxRadiusMeters: 0,
        cumulativePathLengthMeters: 0,
        maxSpeedMetersPerSecond: 0,
      );
    }

    final first = points.first;
    final last = points.last;
    final durationSeconds = last.timeUtc!.difference(first.timeUtc!).inSeconds;

    var pathLengthMeters = 0.0;
    var maxSpeedMetersPerSecond = 0.0;
    var latSum = 0.0;
    var lngSum = 0.0;

    for (final point in points) {
      latSum += point.location.latitude;
      lngSum += point.location.longitude;
    }

    final centroid = LatLng(latSum / points.length, lngSum / points.length);

    var maxRadiusMeters = 0.0;
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final radiusMeters = _distance.as(
        LengthUnit.Meter,
        centroid,
        point.location,
      );
      maxRadiusMeters = math.max(maxRadiusMeters, radiusMeters);

      if (i == 0) {
        continue;
      }

      final previous = points[i - 1];
      final dtSeconds = point.timeUtc!.difference(previous.timeUtc!).inSeconds;
      if (dtSeconds <= 0) {
        continue;
      }

      final legDistanceMeters = segmentDistanceMeters(previous, point);
      pathLengthMeters += legDistanceMeters;
      maxSpeedMetersPerSecond = math.max(
        maxSpeedMetersPerSecond,
        legDistanceMeters / dtSeconds,
      );
    }

    final netDisplacementMeters = segmentDistanceMeters(first, last);

    return _StationaryClusterMetrics(
      durationSeconds: durationSeconds,
      netDisplacementMeters: netDisplacementMeters,
      maxRadiusMeters: maxRadiusMeters,
      cumulativePathLengthMeters: pathLengthMeters,
      maxSpeedMetersPerSecond: maxSpeedMetersPerSecond,
    );
  }

  double _horizontalDistanceMeters(GpxTrackPoint left, GpxTrackPoint right) {
    return _distance.as(LengthUnit.Meter, left.location, right.location);
  }

  List<GpxTrackPoint> _extractPoints(Iterable<XmlElement> elements) {
    final points = <GpxTrackPoint>[];
    for (final element in elements) {
      final lat = double.tryParse(element.getAttribute('lat') ?? '');
      final lon = double.tryParse(element.getAttribute('lon') ?? '');
      if (lat == null || lon == null) {
        continue;
      }

      final eleText = element.getElement('ele')?.innerText.trim();
      final rawElevation = eleText == null || eleText.isEmpty ? null : double.tryParse(eleText);
      final elevation = _normalizeElevation(rawElevation);

      final timeText = element.getElement('time')?.innerText.trim();
      DateTime? timeUtc;
      DateTime? timeLocal;
      if (timeText != null && timeText.isNotEmpty) {
        try {
          final parsed = DateTime.parse(timeText);
          timeUtc = parsed.toUtc();
          timeLocal = parsed.toLocal();
        } catch (_) {
          timeUtc = null;
          timeLocal = null;
        }
      }

      points.add(
        GpxTrackPoint(
          location: LatLng(lat, lon),
          rawElevation: rawElevation,
          elevation: elevation,
          timeUtc: timeUtc,
          timeLocal: timeLocal,
        ),
      );
    }
    return points;
  }

  double? _normalizeElevation(double? elevation) {
    if (elevation == null) {
      return null;
    }
    return elevation < 0 ? 0 : elevation;
  }
}

class _StationaryClusterMetrics {
  const _StationaryClusterMetrics({
    required this.durationSeconds,
    required this.netDisplacementMeters,
    required this.maxRadiusMeters,
    required this.cumulativePathLengthMeters,
    required this.maxSpeedMetersPerSecond,
  });

  final int durationSeconds;
  final double netDisplacementMeters;
  final double maxRadiusMeters;
  final double cumulativePathLengthMeters;
  final double maxSpeedMetersPerSecond;
}
