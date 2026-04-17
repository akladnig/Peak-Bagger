import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/gpx_track_geometry.dart';

class TrackPeakCorrelationService {
  TrackPeakCorrelationService({
    required List<Peak> peaks,
    required this.thresholdMeters,
    GpxTrackGeometryParser? geometryParser,
  }) : _peaks = List<Peak>.unmodifiable(peaks),
       _geometryParser = geometryParser ?? const GpxTrackGeometryParser();

  final List<Peak> _peaks;
  final int thresholdMeters;
  final GpxTrackGeometryParser _geometryParser;

  List<Peak> matchPeaks(String rawGpxXml) {
    final segments = _geometryParser.extractSegments(rawGpxXml);
    final bounds = _boundsFor(segments);
    final candidates = _peaks.where((peak) => _isWithinBounds(peak, bounds));

    final matched = <Peak>[];
    final matchedIds = <int>{};
    for (final peak in candidates) {
      if (matchedIds.contains(peak.osmId)) {
        continue;
      }

      final peakLocation = Location(peak.latitude, peak.longitude);
      if (_isWithinThreshold(peakLocation, segments)) {
        matchedIds.add(peak.osmId);
        matched.add(peak);
      }
    }

    return matched;
  }

  ({double minLat, double maxLat, double minLon, double maxLon}) _boundsFor(
    List<List<LatLng>> segments,
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

    final delta = _metersToDegrees(thresholdMeters);
    return (
      minLat: minLat - delta,
      maxLat: maxLat + delta,
      minLon: minLon - delta,
      maxLon: maxLon + delta,
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

  bool _isWithinThreshold(Location peak, List<List<LatLng>> segments) {
    for (final segment in segments) {
      if (segment.isEmpty) {
        continue;
      }

      if (segment.length == 1) {
        final distance = distanceFromLine(
          peak,
          Location(segment.first.latitude, segment.first.longitude),
          Location(segment.first.latitude, segment.first.longitude),
        );
        if (distance != null && distance <= thresholdMeters) {
          return true;
        }
        continue;
      }

      for (var i = 0; i < segment.length - 1; i++) {
        final point1 = Location(segment[i].latitude, segment[i].longitude);
        final point2 = Location(
          segment[i + 1].latitude,
          segment[i + 1].longitude,
        );
        final distance = distanceFromSegment(peak, point1, point2);
        if (distance != null && distance <= thresholdMeters) {
          return true;
        }
      }
    }

    return false;
  }

  double _metersToDegrees(int meters) {
    return meters / 111320.0;
  }
}
