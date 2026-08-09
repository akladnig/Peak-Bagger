import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

class GpxTrackGeometryParser {
  const GpxTrackGeometryParser();

  List<List<LatLng>> extractSegments(String rawGpxXml) {
    return extractElevationSegments(rawGpxXml)
        .map(
          (segment) => segment
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(growable: false),
        )
        .toList(growable: false);
  }

  List<List<GpxTrackPoint>> extractElevationSegments(String rawGpxXml) {
    final document = XmlDocument.parse(rawGpxXml);

    final trackSegments = document
        .findAllElements('trkseg')
        .toList(growable: false);
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

    throw const FormatException('No trackpoints found');
  }

  List<GpxTrackPoint> _extractPoints(Iterable<XmlElement> elements) {
    final points = <GpxTrackPoint>[];
    for (final element in elements) {
      final lat = double.tryParse(element.getAttribute('lat') ?? '');
      final lon = double.tryParse(element.getAttribute('lon') ?? '');
      if (lat == null || lon == null) {
        continue;
      }
      points.add(
        GpxTrackPoint(
          latitude: lat,
          longitude: lon,
          elevation: _parseElevation(element.getElement('ele')?.innerText),
        ),
      );
    }
    return points;
  }

  double? _parseElevation(String? value) {
    final elevation = double.tryParse(value?.trim() ?? '');
    return elevation != null && elevation.isFinite ? elevation : null;
  }
}

class GpxTrackPoint {
  const GpxTrackPoint({
    required this.latitude,
    required this.longitude,
    this.elevation,
  });

  final double latitude;
  final double longitude;
  final double? elevation;
}
