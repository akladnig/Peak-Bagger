import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/gpx_track_geometry.dart';

class TrackRouteCorrelationService {
  TrackRouteCorrelationService({
    required this.thresholdMeters,
    this.minimumCoverage = 0.9,
    this.maximumUnmatchedGapMeters = 75,
    GpxTrackGeometryParser? geometryParser,
  }) : _geometryParser = geometryParser ?? const GpxTrackGeometryParser();

  final int thresholdMeters;
  final double minimumCoverage;
  final double maximumUnmatchedGapMeters;
  final GpxTrackGeometryParser _geometryParser;

  RouteWalkCorrelationResult correlate({
    required List<LatLng> routePoints,
    required String rawTrackGpxXml,
  }) {
    if (routePoints.length < 2) {
      return RouteWalkCorrelationResult(
        routeLengthMetres: 0,
        matchedLengthMetres: 0,
        longestUnmatchedGapMetres: 0,
        minimumCoverage: minimumCoverage,
        maximumUnmatchedGapMetres: maximumUnmatchedGapMeters,
      );
    }

    final trackSegments = _geometryParser.extractSegments(rawTrackGpxXml);
    if (trackSegments.every((segment) => segment.isEmpty)) {
      return RouteWalkCorrelationResult(
        routeLengthMetres: 0,
        matchedLengthMetres: 0,
        longestUnmatchedGapMetres: 0,
        minimumCoverage: minimumCoverage,
        maximumUnmatchedGapMetres: maximumUnmatchedGapMeters,
      );
    }

    var routeLengthMetres = 0.0;
    var matchedLengthMetres = 0.0;
    var longestUnmatchedGapMetres = 0.0;
    var currentUnmatchedGapMetres = 0.0;

    for (var index = 0; index < routePoints.length - 1; index++) {
      final start = routePoints[index];
      final end = routePoints[index + 1];
      final segmentLengthMetres = _segmentLengthMetres(start, end);
      routeLengthMetres += segmentLengthMetres;

      final midpoint = LatLng(
        (start.latitude + end.latitude) / 2,
        (start.longitude + end.longitude) / 2,
      );
      if (_isPointWithinTrack(midpoint, trackSegments)) {
        matchedLengthMetres += segmentLengthMetres;
        if (currentUnmatchedGapMetres > longestUnmatchedGapMetres) {
          longestUnmatchedGapMetres = currentUnmatchedGapMetres;
        }
        currentUnmatchedGapMetres = 0;
      } else {
        currentUnmatchedGapMetres += segmentLengthMetres;
      }
    }

    if (currentUnmatchedGapMetres > longestUnmatchedGapMetres) {
      longestUnmatchedGapMetres = currentUnmatchedGapMetres;
    }

    return RouteWalkCorrelationResult(
      routeLengthMetres: routeLengthMetres,
      matchedLengthMetres: matchedLengthMetres,
      longestUnmatchedGapMetres: longestUnmatchedGapMetres,
      minimumCoverage: minimumCoverage,
      maximumUnmatchedGapMetres: maximumUnmatchedGapMeters,
    );
  }

  bool _isPointWithinTrack(LatLng point, List<List<LatLng>> trackSegments) {
    final pointLocation = Location(point.latitude, point.longitude);

    for (final segment in trackSegments) {
      if (segment.isEmpty) {
        continue;
      }

      if (segment.length == 1) {
        final distance = pointLocation.distance2d(
          Location(segment.first.latitude, segment.first.longitude),
        );
        if (distance != null && distance <= thresholdMeters) {
          return true;
        }
        continue;
      }

      for (var index = 0; index < segment.length - 1; index++) {
        final start = Location(
          segment[index].latitude,
          segment[index].longitude,
        );
        final end = Location(
          segment[index + 1].latitude,
          segment[index + 1].longitude,
        );
        final distance = distanceFromSegment(pointLocation, start, end);
        if (distance != null && distance <= thresholdMeters) {
          return true;
        }
      }
    }

    return false;
  }

  double _segmentLengthMetres(LatLng start, LatLng end) {
    return Location(
          start.latitude,
          start.longitude,
        ).distance2d(Location(end.latitude, end.longitude)) ??
        0;
  }
}

class RouteWalkCorrelationResult {
  const RouteWalkCorrelationResult({
    required this.routeLengthMetres,
    required this.matchedLengthMetres,
    required this.longestUnmatchedGapMetres,
    required this.minimumCoverage,
    required this.maximumUnmatchedGapMetres,
  });

  final double routeLengthMetres;
  final double matchedLengthMetres;
  final double longestUnmatchedGapMetres;
  final double minimumCoverage;
  final double maximumUnmatchedGapMetres;

  double get matchedCoverage =>
      routeLengthMetres == 0 ? 0 : matchedLengthMetres / routeLengthMetres;

  bool get isWalked =>
      routeLengthMetres > 0 &&
      matchedCoverage >= minimumCoverage &&
      longestUnmatchedGapMetres <= maximumUnmatchedGapMetres;
}
