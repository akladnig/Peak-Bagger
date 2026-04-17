import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

class GpxTrackGeometryParser {
  const GpxTrackGeometryParser();

  List<List<LatLng>> extractSegments(String rawGpxXml) {
    final document = XmlDocument.parse(rawGpxXml);

    final trackSegments = document
        .findAllElements('trkseg')
        .toList(growable: false);
    if (trackSegments.isNotEmpty) {
      final segments = <List<LatLng>>[];
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

  List<LatLng> _extractPoints(Iterable<XmlElement> elements) {
    final points = <LatLng>[];
    for (final element in elements) {
      final lat = double.tryParse(element.getAttribute('lat') ?? '');
      final lon = double.tryParse(element.getAttribute('lon') ?? '');
      if (lat == null || lon == null) {
        continue;
      }
      points.add(LatLng(lat, lon));
    }
    return points;
  }
}
