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

    for (final segment in segments) {
      if (segment.isEmpty) {
        continue;
      }

      if (segment.length == 1) {
        final elevation = segment.first.elevation;
        if (haversineDistance(
                  peakLocation.latitude,
                  peakLocation.longitude,
                  segment.first.latitude,
                  segment.first.longitude,
                ) <=
                thresholdMeters &&
            elevation != null &&
            (peakElevation - elevation).abs() <= elevationThresholdMeters) {
          return true;
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
        final startElevation = segmentPoint1.elevation;
        final endElevation = segmentPoint2.elevation;
        if (startElevation != null &&
            endElevation != null &&
            _segmentHasMatchingPosition(
              peakLocation: peakLocation,
              start: point1,
              end: point2,
              peakElevation: peakElevation,
              startElevation: startElevation,
              endElevation: endElevation,
            )) {
          return true;
        }
      }
    }

    return false;
  }

  bool _segmentHasMatchingPosition({
    required Location peakLocation,
    required Location start,
    required Location end,
    required double peakElevation,
    required double startElevation,
    required double endElevation,
  }) {
    final latitudeRadians =
        (peakLocation.latitude + start.latitude + end.latitude) /
        3 *
        math.pi /
        180;
    final longitudeScale = math.cos(latitudeRadians) * oneDegree;
    final startX = start.longitude * longitudeScale;
    final startY = start.latitude * oneDegree;
    final endX = end.longitude * longitudeScale;
    final endY = end.latitude * oneDegree;
    final peakX = peakLocation.longitude * longitudeScale;
    final peakY = peakLocation.latitude * oneDegree;
    final deltaX = endX - startX;
    final deltaY = endY - startY;
    final lengthSquared = deltaX * deltaX + deltaY * deltaY;
    if (lengthSquared == 0) {
      return false;
    }

    final startToPeakX = startX - peakX;
    final startToPeakY = startY - peakY;
    final thresholdSquared = thresholdMeters * thresholdMeters;
    final linear = 2 * (startToPeakX * deltaX + startToPeakY * deltaY);
    final constant =
        startToPeakX * startToPeakX +
        startToPeakY * startToPeakY -
        thresholdSquared;
    final discriminant = linear * linear - 4 * lengthSquared * constant;
    if (discriminant < 0) {
      return false;
    }

    final distanceRoot = math.sqrt(discriminant);
    final distanceStart = math.max(
      0.0,
      math.min(
        (-linear - distanceRoot) / (2 * lengthSquared),
        (-linear + distanceRoot) / (2 * lengthSquared),
      ),
    );
    final distanceEnd = math.min(
      1.0,
      math.max(
        (-linear - distanceRoot) / (2 * lengthSquared),
        (-linear + distanceRoot) / (2 * lengthSquared),
      ),
    );
    if (distanceStart > distanceEnd) {
      return false;
    }

    final elevationDelta = endElevation - startElevation;
    if (elevationDelta == 0) {
      return (peakElevation - startElevation).abs() <= elevationThresholdMeters;
    }

    final elevationStart = math.max(
      0.0,
      math.min(
        (peakElevation - elevationThresholdMeters - startElevation) /
            elevationDelta,
        (peakElevation + elevationThresholdMeters - startElevation) /
            elevationDelta,
      ),
    );
    final elevationEnd = math.min(
      1.0,
      math.max(
        (peakElevation - elevationThresholdMeters - startElevation) /
            elevationDelta,
        (peakElevation + elevationThresholdMeters - startElevation) /
            elevationDelta,
      ),
    );
    return elevationStart <= elevationEnd &&
        distanceStart <= elevationEnd &&
        elevationStart <= distanceEnd;
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
