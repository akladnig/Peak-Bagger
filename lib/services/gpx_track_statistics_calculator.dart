import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

class GpxTrackStatistics {
  const GpxTrackStatistics({
    required this.distance,
    required this.distanceToPeak,
    required this.distanceFromPeak,
    required this.lowestElevation,
    required this.highestElevation,
  });

  final double distance;
  final double distanceToPeak;
  final double distanceFromPeak;
  final double lowestElevation;
  final double highestElevation;
}

class GpxTrackStatisticsCalculator {
  static const _distance = Distance();

  static const _zero = GpxTrackStatistics(
    distance: 0,
    distanceToPeak: 0,
    distanceFromPeak: 0,
    lowestElevation: 0,
    highestElevation: 0,
  );

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
    if (points.length == 1) {
      return _zero;
    }

    final hasCompleteElevation = points.every(
      (point) => point.elevation != null,
    );
    final distance = _calculateDistance(segments);
    if (!hasCompleteElevation) {
      return GpxTrackStatistics(
        distance: distance,
        distanceToPeak: 0,
        distanceFromPeak: 0,
        lowestElevation: 0,
        highestElevation: 0,
      );
    }

    final elevations = points
        .map((point) => point.elevation!)
        .toList(growable: false);
    var highestElevation = elevations.first;
    var lowestElevation = elevations.first;
    for (final elevation in elevations.skip(1)) {
      if (elevation > highestElevation) {
        highestElevation = elevation;
      }
      if (elevation < lowestElevation) {
        lowestElevation = elevation;
      }
    }

    var cumulativeDistance = 0.0;
    var distanceToPeak = 0.0;
    var peakFound = false;
    for (final segment in segments) {
      if (segment.isEmpty) {
        continue;
      }
      for (var i = 0; i < segment.length; i++) {
        final point = segment[i];
        if (!peakFound && point.elevation == highestElevation) {
          distanceToPeak = cumulativeDistance;
          peakFound = true;
        }

        if (i < segment.length - 1) {
          cumulativeDistance += _distance.as(
            LengthUnit.Meter,
            point.location,
            segment[i + 1].location,
          );
        }
      }
    }

    return GpxTrackStatistics(
      distance: distance,
      distanceToPeak: distanceToPeak,
      distanceFromPeak: distance - distanceToPeak,
      lowestElevation: lowestElevation,
      highestElevation: highestElevation,
    );
  }

  double _calculateDistance(List<List<_TrackPoint>> segments) {
    var totalDistance = 0.0;
    for (final segment in segments) {
      if (segment.length < 2) {
        continue;
      }
      for (var i = 0; i < segment.length - 1; i++) {
        totalDistance += _distance.as(
          LengthUnit.Meter,
          segment[i].location,
          segment[i + 1].location,
        );
      }
    }
    return totalDistance;
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
      final elevation = eleText == null || eleText.isEmpty
          ? null
          : double.tryParse(eleText);

      points.add(_TrackPoint(location: LatLng(lat, lon), elevation: elevation));
    }
    return points;
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
  const _TrackPoint({required this.location, required this.elevation});

  final LatLng location;
  final double? elevation;
}
