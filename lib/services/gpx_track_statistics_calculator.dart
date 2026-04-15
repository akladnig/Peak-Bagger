import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';
import 'package:peak_bagger/services/geo.dart';

class GpxTrackStatistics {
  const GpxTrackStatistics({
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
        } else if (point.rawElevation! > -100) {
          startElevation ??= point.rawElevation;
          endElevation = point.rawElevation;
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
      return GpxTrackStatistics(
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

    if (elevationSamples.isEmpty) {
      return GpxTrackStatistics(
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
      return GpxTrackStatistics(
        distance2d: distance2d,
        distance3d: distance3d.roundToDouble(),
        distanceToPeak: 0,
        distanceFromPeak: 0,
        lowestElevation: lowest,
        highestElevation: highest,
        ascent: elevationStats.uphill,
        descent: elevationStats.downhill,
        startElevation: start,
        endElevation: end,
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

    return GpxTrackStatistics(
      distance2d: distance2d,
      distance3d: distance3d.roundToDouble(),
      distanceToPeak: distanceToPeak,
      distanceFromPeak: distance2d - distanceToPeak,
      lowestElevation: lowest,
      highestElevation: highest,
      ascent: elevationStats.uphill,
      descent: elevationStats.downhill,
      startElevation: start,
      endElevation: end,
      elevationProfile: elevationProfile,
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
      DateTime? timeLocal;
      if (timeText != null && timeText.isNotEmpty) {
        try {
          timeLocal = DateTime.parse(timeText).toLocal();
        } catch (_) {
          timeLocal = null;
        }
      }

      points.add(
        _TrackPoint(
          location: LatLng(lat, lon),
          rawElevation: rawElevation,
          elevation: elevation,
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
    return elevation < -100 ? 0 : elevation;
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
    required this.timeLocal,
  });

  final LatLng location;
  final double? rawElevation;
  final double? elevation;
  final DateTime? timeLocal;
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
