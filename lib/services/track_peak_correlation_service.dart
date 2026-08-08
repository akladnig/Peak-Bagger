import 'dart:math' as math;

import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/gpx_track_geometry.dart';

class TrackPeakCorrelationService {
  TrackPeakCorrelationService({
    required List<Peak> peaks,
    required this.thresholdMeters,
    this.elevationThresholdMeters = 10,
    GpxTrackGeometryParser? geometryParser,
  }) : _peaks = List<Peak>.unmodifiable(peaks),
       _geometryParser = geometryParser ?? const GpxTrackGeometryParser();

  final List<Peak> _peaks;
  final int thresholdMeters;
  final int elevationThresholdMeters;
  final GpxTrackGeometryParser _geometryParser;

  List<Peak> matchPeaks(String rawGpxXml) {
    final segments = _geometryParser.extractElevationSegments(rawGpxXml);
    if (segments.every((segment) => segment.isEmpty)) {
      return const [];
    }
    final bounds = _boundsFor(segments);
    final candidates = _peaks.where((peak) => _isWithinBounds(peak, bounds));

    final matched = <Peak>[];
    final matchedIds = <int>{};
    for (final peak in candidates) {
      if (matchedIds.contains(peak.osmId)) {
        continue;
      }

      final peakLocation = Location(peak.latitude, peak.longitude);
      if (_isWithinThreshold(peak, peakLocation, segments)) {
        matchedIds.add(peak.osmId);
        matched.add(peak);
      }
    }

    return matched;
  }

  ({double minLat, double maxLat, double minLon, double maxLon}) _boundsFor(
    List<List<GpxTrackPoint>> segments,
  ) {
    var minLat = double.infinity;
    var maxLat = double.negativeInfinity;
    var minLon = double.infinity;
    var maxLon = double.negativeInfinity;

    for (final segment in segments) {
      for (final point in segment) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLon = math.min(minLon, point.longitude);
        maxLon = math.max(maxLon, point.longitude);
      }
    }

    final latDelta = _metersToDegrees(thresholdMeters);
    final lonDelta = _metersToDegrees(
      thresholdMeters,
      meanLatitudeRadians: _meanLatitudeRadians(segments),
    );
    return (
      minLat: minLat - latDelta,
      maxLat: maxLat + latDelta,
      minLon: minLon - lonDelta,
      maxLon: maxLon + lonDelta,
    );
  }

  bool _isWithinBounds(
    Peak peak,
    ({double minLat, double maxLat, double minLon, double maxLon}) bounds,
  ) {
    return peak.latitude >= bounds.minLat &&
        peak.latitude <= bounds.maxLat &&
        peak.longitude >= bounds.minLon &&
        peak.longitude <= bounds.maxLon;
  }

  bool _isWithinThreshold(
    Peak peak,
    Location peakLocation,
    List<List<GpxTrackPoint>> segments,
  ) {
    final peakElevation = peak.elevation;
    if (peakElevation == null || !peakElevation.isFinite) {
      return false;
    }

    var closestDistance = double.infinity;
    final closestElevations = <double?>[];
    for (final segment in segments) {
      if (segment.isEmpty) {
        continue;
      }

      if (segment.length == 1) {
        final closestPosition = closestPointOnSegment(
          peakLocation,
          Location(segment.first.latitude, segment.first.longitude),
          Location(segment.first.latitude, segment.first.longitude),
        );
        _recordClosestElevation(
          distance: closestPosition.distance,
          elevation: segment.first.elevation,
          closestDistance: closestDistance,
          closestElevations: closestElevations,
        );
        if (closestPosition.distance < closestDistance) {
          closestDistance = closestPosition.distance;
        }
        continue;
      }

      for (var i = 0; i < segment.length - 1; i++) {
        final segmentPoint1 = segment[i];
        final segmentPoint2 = segment[i + 1];
        final point1 = Location(
          segmentPoint1.latitude,
          segmentPoint1.longitude,
        );
        final point2 = Location(
          segmentPoint2.latitude,
          segmentPoint2.longitude,
        );
        final closestPosition = closestPointOnSegment(
          peakLocation,
          point1,
          point2,
        );
        final startElevation = segmentPoint1.elevation;
        final endElevation = segmentPoint2.elevation;
        final elevation = startElevation != null && endElevation != null
            ? startElevation +
                  (endElevation - startElevation) * closestPosition.fraction
            : null;
        _recordClosestElevation(
          distance: closestPosition.distance,
          elevation: elevation,
          closestDistance: closestDistance,
          closestElevations: closestElevations,
        );
        if (closestPosition.distance < closestDistance) {
          closestDistance = closestPosition.distance;
        }
      }
    }

    return closestDistance <= thresholdMeters &&
        closestElevations.any(
          (elevation) =>
              elevation != null &&
              (peakElevation - elevation).abs() <= elevationThresholdMeters,
        );
  }

  void _recordClosestElevation({
    required double distance,
    required double? elevation,
    required double closestDistance,
    required List<double?> closestElevations,
  }) {
    if (distance < closestDistance) {
      closestElevations
        ..clear()
        ..add(elevation);
    } else if (distance == closestDistance) {
      closestElevations.add(elevation);
    }
  }

  double _metersToDegrees(int meters, {double? meanLatitudeRadians}) {
    final baseDegrees = meters / 111320.0;
    if (meanLatitudeRadians == null) {
      return baseDegrees;
    }

    final scale = math.cos(meanLatitudeRadians).abs().clamp(0.1, 1.0);
    return baseDegrees / scale;
  }

  double _meanLatitudeRadians(List<List<GpxTrackPoint>> segments) {
    var total = 0.0;
    var count = 0;

    for (final segment in segments) {
      for (final point in segment) {
        total += point.latitude;
        count += 1;
      }
    }

    if (count == 0) {
      return 0;
    }

    return (total / count) * math.pi / 180.0;
  }
}
