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
}

class GpxTrackStatisticsCalculator {
  static const _distance = Distance();

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
    );
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
        var inRestCluster = false;
        var restClusterSeconds = 0;

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

          final distanceMeters = _distance.as(
            LengthUnit.Meter,
            current.location,
            next.location,
          );
          final speedMetersPerSecond = distanceMeters / dtSeconds;
          final isRestCandidate = inRestCluster
              ? speedMetersPerSecond <= 0.5 && distanceMeters <= 10
              : speedMetersPerSecond <= 0.3 && distanceMeters <= 10;

          if (isRestCandidate) {
            inRestCluster = true;
            restClusterSeconds += dtSeconds;
            continue;
          }

          if (inRestCluster) {
            if (restClusterSeconds >= 60) {
              restingDurationSeconds += restClusterSeconds;
            }
            restClusterSeconds = 0;
            inRestCluster = false;
          }
        }

        if (inRestCluster && restClusterSeconds >= 60) {
          restingDurationSeconds += restClusterSeconds;
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
