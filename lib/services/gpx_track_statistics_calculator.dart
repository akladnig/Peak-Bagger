import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';
import 'package:peak_bagger/services/geo.dart';

class GpxTrackStatistics {
  const GpxTrackStatistics({
    required this.startDateTime,
    required this.endDateTime,
    required this.totalTimeMillis,
    required this.movingTime,
    required this.restingTime,
    required this.pausedTime,
    required this.distance2d,
    required this.distance3d,
    required this.distanceToPeak,
    required this.distanceFromPeak,
    required this.lowestElevation,
    required this.highestElevation,
    required this.ascent,
    required this.descent,
    required this.startElevation,
    required this.endElevation,
    required this.elevationProfile,
    required this.averageSpeedKmh,
    required this.movingSpeedKmh,
    required this.maxSpeedKmh,
  });

  final DateTime? startDateTime;
  final DateTime? endDateTime;
  final int totalTimeMillis;
  final int movingTime;
  final int restingTime;
  final int pausedTime;
  final double distance2d;
  final double distance3d;
  final double distanceToPeak;
  final double distanceFromPeak;
  final double lowestElevation;
  final double highestElevation;
  final double ascent;
  final double descent;
  final double startElevation;
  final double endElevation;
  final String elevationProfile;
  final double? averageSpeedKmh;
  final double? movingSpeedKmh;
  final double? maxSpeedKmh;
}

class GpxTrackStatisticsCalculator {
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
  static const _defaultMaxSpeedWindow = Duration(minutes: 1);

  GpxTrackStatistics calculate(String gpxXml) {
    try {
      final document = XmlDocument.parse(gpxXml);
      return calculateDocument(document);
    } on XmlException catch (error) {
      throw FormatException('Invalid GPX XML', error);
    }
  }

  GpxTrackStatistics calculateDocument(XmlDocument document) {
    final segments = _extractSegments(document);
    if (segments.isEmpty) {
      throw FormatException('No trackpoints found');
    }

    final timeStats = _calculateTimeStats(segments);

    GpxTrackStatistics buildStats({
      required double distance2d,
      required double distance3d,
      required double distanceToPeak,
      required double distanceFromPeak,
      required double lowestElevation,
      required double highestElevation,
      required double ascent,
      required double descent,
      required double startElevation,
      required double endElevation,
      required String elevationProfile,
      required double? averageSpeedKmh,
      required double? movingSpeedKmh,
      required double? maxSpeedKmh,
    }) {
      return GpxTrackStatistics(
        startDateTime: timeStats.startDateTime,
        endDateTime: timeStats.endDateTime,
        totalTimeMillis: timeStats.totalTimeMillis,
        movingTime: timeStats.movingTime,
        restingTime: timeStats.restingTime,
        pausedTime: timeStats.pausedTime,
        distance2d: distance2d,
        distance3d: distance3d,
        distanceToPeak: distanceToPeak,
        distanceFromPeak: distanceFromPeak,
        lowestElevation: lowestElevation,
        highestElevation: highestElevation,
        ascent: ascent,
        descent: descent,
        startElevation: startElevation,
        endElevation: endElevation,
        elevationProfile: elevationProfile,
        averageSpeedKmh: averageSpeedKmh,
        movingSpeedKmh: movingSpeedKmh,
        maxSpeedKmh: maxSpeedKmh,
      );
    }

    final points = segments
        .expand((segment) => segment)
        .toList(growable: false);
    final profileEntries = <_ElevationProfileEntry>[];
    final elevationSamples = <double>[];
    double distance2d = 0;
    double distance3d = 0;
    double? startElevation;
    double? endElevation;
    double? lowestElevation;
    double? highestElevation;
    var hasMissingElevation = false;

    for (var segmentIndex = 0; segmentIndex < segments.length; segmentIndex++) {
      final segment = segments[segmentIndex];
      for (var pointIndex = 0; pointIndex < segment.length; pointIndex++) {
        final point = segment[pointIndex];
        if (point.rawElevation == null) {
          hasMissingElevation = true;
        } else {
          startElevation ??= point.elevation;
          endElevation = point.elevation;
        }

        final elevation = point.elevation;
        if (elevation != null) {
          elevationSamples.add(elevation);
          lowestElevation =
              lowestElevation == null || elevation < lowestElevation
              ? elevation
              : lowestElevation;
          highestElevation =
              highestElevation == null || elevation > highestElevation
              ? elevation
              : highestElevation;
        }

        profileEntries.add(
          _ElevationProfileEntry(
            segmentIndex: segmentIndex,
            pointIndex: pointIndex,
            distanceMeters: distance2d,
            elevationMeters: elevation,
            timeLocal: point.timeLocal,
          ),
        );

        if (pointIndex < segment.length - 1) {
          final nextPoint = segment[pointIndex + 1];
          final legDistance2d = _distance.as(
            LengthUnit.Meter,
            point.location,
            nextPoint.location,
          );
          distance2d += legDistance2d;

          if (point.elevation == null ||
              nextPoint.elevation == null ||
              point.elevation == nextPoint.elevation) {
            distance3d += legDistance2d;
          } else {
            final elevationDelta = point.elevation! - nextPoint.elevation!;
            distance3d += math.sqrt(
              legDistance2d * legDistance2d + elevationDelta * elevationDelta,
            );
          }
        }
      }
    }

    final elevationProfile = jsonEncode(
      profileEntries.map((entry) => entry.toJson()).toList(growable: false),
    );
    final averageSpeedKmh = _calculateAverageSpeedKmh(
      distance2d: distance2d,
      durationMillis: timeStats.totalTimeMillis,
    );
    final movingSpeedKmh = _calculateAverageSpeedKmh(
      distance2d: distance2d,
      durationMillis: timeStats.movingTime,
    );
    final maxSpeedKmh = _calculateMaxSpeedKmh(
      segments,
      window: _defaultMaxSpeedWindow,
    );

    if (points.length == 1) {
      return buildStats(
        distance2d: 0,
        distance3d: 0,
        distanceToPeak: 0,
        distanceFromPeak: 0,
        lowestElevation: 0,
        highestElevation: 0,
        ascent: 0,
        descent: 0,
        startElevation: 0,
        endElevation: 0,
        elevationProfile: elevationProfile,
        averageSpeedKmh: averageSpeedKmh,
        movingSpeedKmh: movingSpeedKmh,
        maxSpeedKmh: maxSpeedKmh,
      );
    }

    final elevationStats = elevationSamples.isEmpty
        ? (uphill: 0.0, downhill: 0.0)
        : calculateUphillDownhill(elevationSamples);

    final lowest = lowestElevation ?? 0;
    final highest = highestElevation ?? 0;
    final start = startElevation ?? 0;
    final end = endElevation ?? 0;
    final roundedAscent = elevationStats.uphill.roundToDouble();
    final roundedDescent = elevationStats.downhill.roundToDouble();
    final roundedStart = start.roundToDouble();
    final roundedEnd = end.roundToDouble();

    if (elevationSamples.isEmpty) {
      return buildStats(
        distance2d: distance2d,
        distance3d: distance3d.roundToDouble(),
        distanceToPeak: 0,
        distanceFromPeak: 0,
        lowestElevation: 0,
        highestElevation: 0,
        ascent: 0,
        descent: 0,
        startElevation: 0,
        endElevation: 0,
        elevationProfile: elevationProfile,
        averageSpeedKmh: averageSpeedKmh,
        movingSpeedKmh: movingSpeedKmh,
        maxSpeedKmh: maxSpeedKmh,
      );
    }

    if (hasMissingElevation) {
      return buildStats(
        distance2d: distance2d,
        distance3d: distance3d.roundToDouble(),
        distanceToPeak: 0,
        distanceFromPeak: 0,
        lowestElevation: lowest,
        highestElevation: highest,
        ascent: roundedAscent,
        descent: roundedDescent,
        startElevation: roundedStart,
        endElevation: roundedEnd,
        elevationProfile: elevationProfile,
        averageSpeedKmh: averageSpeedKmh,
        movingSpeedKmh: movingSpeedKmh,
        maxSpeedKmh: maxSpeedKmh,
      );
    }

    var distanceToPeak = 0.0;
    for (final entry in profileEntries) {
      if (entry.elevationMeters == highest) {
        distanceToPeak = entry.distanceMeters;
        break;
      }
    }

    return buildStats(
      distance2d: distance2d,
      distance3d: distance3d.roundToDouble(),
      distanceToPeak: distanceToPeak,
      distanceFromPeak: distance2d - distanceToPeak,
      lowestElevation: lowest,
      highestElevation: highest,
      ascent: roundedAscent,
      descent: roundedDescent,
      startElevation: roundedStart,
      endElevation: roundedEnd,
      elevationProfile: elevationProfile,
      averageSpeedKmh: averageSpeedKmh,
      movingSpeedKmh: movingSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
    );
  }

  double? calculateMaxSpeedKmh(
    String gpxXml, {
    Duration window = _defaultMaxSpeedWindow,
  }) {
    try {
      final document = XmlDocument.parse(gpxXml);
      return _calculateMaxSpeedKmh(_extractSegments(document), window: window);
    } on XmlException catch (error) {
      throw FormatException('Invalid GPX XML', error);
    }
  }

  _TimeStats _calculateTimeStats(List<List<_TrackPoint>> segments) {
    final parseableSegments = <List<_TrackPoint>>[];
    for (final segment in segments) {
      final parseablePoints =
          segment
              .where((point) => point.timeUtc != null)
              .toList(growable: false)
            ..sort((a, b) => a.timeUtc!.compareTo(b.timeUtc!));
      if (parseablePoints.isNotEmpty) {
        parseableSegments.add(parseablePoints);
      }
    }

    if (parseableSegments.isEmpty) {
      return const _TimeStats(
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

    for (
      var segmentIndex = 0;
      segmentIndex < parseableSegments.length;
      segmentIndex++
    ) {
      final segment = parseableSegments[segmentIndex];
      if (segment.length >= 2) {
        restingDurationSeconds += _calculateRestingDuration(segment);

        for (
          var pointIndex = 0;
          pointIndex < segment.length - 1;
          pointIndex++
        ) {
          final current = segment[pointIndex];
          final next = segment[pointIndex + 1];
          final dtSeconds = next.timeUtc!
              .difference(current.timeUtc!)
              .inSeconds;
          if (dtSeconds <= 0) {
            continue;
          }

          totalDurationSeconds += dtSeconds;
        }
      }

      if (segmentIndex < parseableSegments.length - 1) {
        final nextSegment = parseableSegments[segmentIndex + 1];
        final gapSeconds = nextSegment.first.timeUtc!
            .difference(segment.last.timeUtc!)
            .inSeconds;
        if (gapSeconds > 0) {
          pausedDurationSeconds += gapSeconds;
        }
      }
    }

    final totalTimeMillis = totalDurationSeconds * 1000;
    final restingTime = restingDurationSeconds * 1000;
    final pausedTime = pausedDurationSeconds * 1000;

    return _TimeStats(
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      totalTimeMillis: totalTimeMillis,
      movingTime: totalTimeMillis - restingTime,
      restingTime: restingTime,
      pausedTime: pausedTime,
    );
  }

  int _calculateRestingDuration(List<_TrackPoint> segment) {
    final clusterPoints = <_TrackPoint>[segment.first];
    var clusterActive = false;
    var exitFailureCount = 0;
    var restingDurationSeconds = 0;

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

      restingDurationSeconds += candidateMetrics.durationSeconds - dtSeconds;
      clusterPoints
        ..clear()
        ..add(next);
      clusterActive = false;
      exitFailureCount = 0;
    }

    if (clusterActive) {
      final clusterDurationSeconds = _stationaryMetrics(clusterPoints).durationSeconds;
      if (clusterDurationSeconds >= _minimumRestDurationSeconds) {
        restingDurationSeconds += clusterDurationSeconds;
      }
    }

    return restingDurationSeconds;
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

  _StationaryClusterMetrics _stationaryMetrics(List<_TrackPoint> points) {
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

      final legDistanceMeters = _segmentDistanceMeters(previous, point);
      pathLengthMeters += legDistanceMeters;
      maxSpeedMetersPerSecond = math.max(
        maxSpeedMetersPerSecond,
        legDistanceMeters / dtSeconds,
      );
    }

    final netDisplacementMeters = _segmentDistanceMeters(first, last);

    return _StationaryClusterMetrics(
      durationSeconds: durationSeconds,
      netDisplacementMeters: netDisplacementMeters,
      maxRadiusMeters: maxRadiusMeters,
      cumulativePathLengthMeters: pathLengthMeters,
      maxSpeedMetersPerSecond: maxSpeedMetersPerSecond,
    );
  }

  double? _calculateAverageSpeedKmh({
    required double distance2d,
    required int durationMillis,
  }) {
    if (durationMillis <= 0) {
      return null;
    }
    return distance2d * 3600 / durationMillis;
  }

  double? _calculateMaxSpeedKmh(
    List<List<_TrackPoint>> segments, {
    required Duration window,
  }) {
    final windowMillis = window.inMilliseconds;
    if (windowMillis <= 0) {
      return null;
    }

    var maxSpeedKmh = 0.0;
    var found = false;

    for (final segment in segments) {
      final runs = _buildTimedRuns(segment);
      for (final run in runs) {
        final runMax = _maxSpeedForRunKmh(run, windowMillis);
        if (runMax == null) {
          continue;
        }
        found = true;
        maxSpeedKmh = math.max(maxSpeedKmh, runMax);
      }
    }

    return found ? maxSpeedKmh : null;
  }

  List<List<_TimedDistanceSample>> _buildTimedRuns(List<_TrackPoint> segment) {
    final runs = <List<_TimedDistanceSample>>[];
    final currentRun = <_TimedDistanceSample>[];

    var cumulativeDistanceMeters = 0.0;
    _TrackPoint? previousPoint;
    DateTime? previousTimedPointTime;

    for (final point in segment) {
      if (previousPoint != null) {
        cumulativeDistanceMeters += _distance.as(
          LengthUnit.Meter,
          previousPoint.location,
          point.location,
        );
      }

      final timeUtc = point.timeUtc;
      if (timeUtc != null) {
        final sample = _TimedDistanceSample(
          timeUtc: timeUtc,
          cumulativeDistanceMeters: cumulativeDistanceMeters,
        );

        if (previousTimedPointTime != null &&
            !timeUtc.isAfter(previousTimedPointTime)) {
          if (currentRun.length >= 2) {
            runs.add(List.of(currentRun));
          }
          currentRun
            ..clear()
            ..add(sample);
        } else {
          currentRun.add(sample);
        }

        previousTimedPointTime = timeUtc;
      }

      previousPoint = point;
    }

    if (currentRun.length >= 2) {
      runs.add(List.of(currentRun));
    }

    return runs;
  }

  double? _maxSpeedForRunKmh(List<_TimedDistanceSample> run, int windowMillis) {
    if (run.length < 2) {
      return null;
    }

    var maxSpeedKmh = 0.0;
    var found = false;

    for (var endIndex = 1; endIndex < run.length; endIndex++) {
      final endSample = run[endIndex];
      final targetStartTime = endSample.timeUtc.subtract(
        Duration(milliseconds: windowMillis),
      );
      final startDistance = _interpolateDistanceAt(run, targetStartTime);
      if (startDistance == null) {
        continue;
      }

      final distanceMeters = endSample.cumulativeDistanceMeters - startDistance;
      if (distanceMeters < 0) {
        continue;
      }

      found = true;
      maxSpeedKmh = math.max(maxSpeedKmh, distanceMeters * 3600 / windowMillis);
    }

    return found ? maxSpeedKmh : null;
  }

  double? _interpolateDistanceAt(
    List<_TimedDistanceSample> run,
    DateTime targetTime,
  ) {
    if (targetTime.isBefore(run.first.timeUtc)) {
      return null;
    }

    if (targetTime.isAtSameMomentAs(run.first.timeUtc)) {
      return run.first.cumulativeDistanceMeters;
    }

    for (var index = 1; index < run.length; index++) {
      final left = run[index - 1];
      final right = run[index];

      if (targetTime.isAfter(right.timeUtc)) {
        continue;
      }

      if (targetTime.isAtSameMomentAs(right.timeUtc)) {
        return right.cumulativeDistanceMeters;
      }

      final spanMillis = right.timeUtc.difference(left.timeUtc).inMilliseconds;
      if (spanMillis <= 0) {
        return null;
      }

      final offsetMillis = targetTime.difference(left.timeUtc).inMilliseconds;
      if (offsetMillis < 0) {
        return null;
      }

      final fraction = offsetMillis / spanMillis;
      return left.cumulativeDistanceMeters +
          (right.cumulativeDistanceMeters - left.cumulativeDistanceMeters) *
              fraction;
    }

    return null;
  }

  double _segmentDistanceMeters(_TrackPoint left, _TrackPoint right) {
    final horizontalMeters = _distance.as(
      LengthUnit.Meter,
      left.location,
      right.location,
    );
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
      horizontalMeters * horizontalMeters +
          elevationDelta * elevationDelta,
    );
  }

  List<List<_TrackPoint>> _extractSegments(XmlDocument document) {
    final trackSegments = document
        .findAllElements('trkseg')
        .toList(growable: false);
    if (trackSegments.isNotEmpty) {
      final segments = <List<_TrackPoint>>[];
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

  List<_TrackPoint> _extractPoints(Iterable<XmlElement> elements) {
    final points = <_TrackPoint>[];
    for (final element in elements) {
      final lat = double.tryParse(element.getAttribute('lat') ?? '');
      final lon = double.tryParse(element.getAttribute('lon') ?? '');
      if (lat == null || lon == null) {
        continue;
      }

      final eleText = element.getElement('ele')?.innerText.trim();
      final rawElevation = eleText == null || eleText.isEmpty
          ? null
          : double.tryParse(eleText);
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
        _TrackPoint(
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

class TrackStatisticsRecalcResult {
  const TrackStatisticsRecalcResult({
    required this.updatedCount,
    required this.skippedCount,
    this.warning,
  });

  final int updatedCount;
  final int skippedCount;
  final String? warning;
}

class _TrackPoint {
  const _TrackPoint({
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

class _TimedDistanceSample {
  const _TimedDistanceSample({
    required this.timeUtc,
    required this.cumulativeDistanceMeters,
  });

  final DateTime timeUtc;
  final double cumulativeDistanceMeters;
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

class _TimeStats {
  const _TimeStats({
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

class _ElevationProfileEntry {
  const _ElevationProfileEntry({
    required this.segmentIndex,
    required this.pointIndex,
    required this.distanceMeters,
    required this.elevationMeters,
    required this.timeLocal,
  });

  final int segmentIndex;
  final int pointIndex;
  final double distanceMeters;
  final double? elevationMeters;
  final DateTime? timeLocal;

  Map<String, dynamic> toJson() {
    return {
      'segmentIndex': segmentIndex,
      'pointIndex': pointIndex,
      'distanceMeters': distanceMeters,
      'elevationMeters': elevationMeters,
      'timeLocal': timeLocal?.toIso8601String(),
    };
  }
}
