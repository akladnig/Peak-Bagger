import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/track_route_correlation_service.dart';

void main() {
  test('marks a closely followed route as walked', () {
    final service = TrackRouteCorrelationService(thresholdMeters: 30);

    final result = service.correlate(
      routePoints: const [
        LatLng(0.0001, 0.0),
        LatLng(0.0001, 0.001),
        LatLng(0.0001, 0.002),
        LatLng(0.0001, 0.003),
      ],
      rawTrackGpxXml: _buildTrackGpx(const [
        LatLng(0.0, 0.0),
        LatLng(0.0, 0.001),
        LatLng(0.0, 0.002),
        LatLng(0.0, 0.003),
      ]),
    );

    expect(result.isWalked, isTrue);
    expect(result.matchedCoverage, closeTo(1.0, 0.01));
    expect(result.longestUnmatchedGapMetres, closeTo(0.0, 0.01));
  });

  test('rejects a route with low matched coverage', () {
    final service = TrackRouteCorrelationService(thresholdMeters: 30);

    final result = service.correlate(
      routePoints: const [
        LatLng(0.0, 0.0),
        LatLng(0.0, 0.001),
        LatLng(0.002, 0.001),
        LatLng(0.003, 0.001),
      ],
      rawTrackGpxXml: _buildTrackGpx(const [
        LatLng(0.0, 0.0),
        LatLng(0.0, 0.001),
        LatLng(0.0, 0.002),
        LatLng(0.0, 0.003),
      ]),
    );

    expect(result.isWalked, isFalse);
    expect(result.matchedCoverage, lessThan(0.9));
  });

  test('rejects a route that has a long unmatched gap', () {
    final service = TrackRouteCorrelationService(
      thresholdMeters: 30,
      maximumUnmatchedGapMeters: 75,
    );

    final routePoints = <LatLng>[
      for (var i = 0; i <= 20; i++) LatLng(0.0, i / 1000),
      const LatLng(0.001, 0.020),
      const LatLng(0.001, 0.021),
      const LatLng(0.0, 0.021),
      for (var i = 22; i <= 31; i++) LatLng(0.0, i / 1000),
    ];

    final result = service.correlate(
      routePoints: routePoints,
      rawTrackGpxXml: _buildTrackGpx([
        for (var i = 0; i <= 31; i++) LatLng(0.0, i / 1000),
      ]),
    );

    expect(result.matchedCoverage, greaterThan(0.9));
    expect(result.longestUnmatchedGapMetres, greaterThan(75));
    expect(result.isWalked, isFalse);
  });
}

String _buildTrackGpx(List<LatLng> points) {
  final buffer = StringBuffer()..write('<gpx><trk><trkseg>');
  for (final point in points) {
    buffer.write(
      '<trkpt lat="${point.latitude.toStringAsFixed(6)}" lon="${point.longitude.toStringAsFixed(6)}" />',
    );
  }
  buffer.write('</trkseg></trk></gpx>');
  return buffer.toString();
}
