import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/elevation_profile_series_builder.dart';

void main() {
  test('parses track profile JSON with gaps and timestamps', () {
    final series = ElevationProfileSeriesBuilder.fromTrackProfileJson('''
[
  {"segmentIndex":0,"pointIndex":0,"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"segmentIndex":0,"pointIndex":1,"distanceMeters":12.5,"elevationMeters":null,"timeLocal":null},
  {"segmentIndex":1,"pointIndex":0,"distanceMeters":42.25,"elevationMeters":120,"timeLocal":"2024-01-15T08:20:00.000"}
]
''');

    expect(series.samples, hasLength(3));
    expect(series.samples[0].segmentIndex, 0);
    expect(series.samples[0].pointIndex, 0);
    expect(series.samples[0].distanceMeters, 0);
    expect(series.samples[0].elevationMeters, 100);
    expect(series.samples[0].timeLocal, DateTime(2024, 1, 15, 8));
    expect(series.samples[1].elevationMeters, isNull);
    expect(series.samples[2].segmentIndex, 1);
    expect(series.samples[2].pointIndex, 0);
    expect(series.samples[2].distanceMeters, 42.25);
    expect(series.samples[2].elevationMeters, 120);
    expect(series.supportsTimeAxis, isTrue);
  });

  test('disables time mode when fewer than two timestamps remain', () {
    final series = ElevationProfileSeriesBuilder.fromTrackProfileJson('''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"distanceMeters":10,"elevationMeters":110,"timeLocal":null}
]
''');

    expect(series.supportsTimeAxis, isFalse);
    expect(series.hasUsableTimeAxis, isFalse);
  });

  test('builds route series from cumulative geodesic distance', () {
    final series = ElevationProfileSeriesBuilder.fromRoutePoints(
      points: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.5, 146.51),
        LatLng(-41.5, 146.52),
      ],
      elevations: const [100, 120, 140],
    );

    expect(series.samples, hasLength(3));
    expect(series.samples.first.distanceMeters, 0);
    expect(series.samples[1].distanceMeters, greaterThan(0));
    expect(
      series.samples[2].distanceMeters,
      greaterThan(series.samples[1].distanceMeters),
    );
    expect(series.samples[2].elevationMeters, 140);
    expect(series.supportsTimeAxis, isFalse);
  });

  test('returns empty series for invalid JSON', () {
    final series = ElevationProfileSeriesBuilder.fromTrackProfileJson('nope');

    expect(series.samples, isEmpty);
    expect(series.supportsTimeAxis, isFalse);
  });
}
