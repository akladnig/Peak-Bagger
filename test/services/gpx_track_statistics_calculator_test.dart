import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/gpx_track_statistics_calculator.dart';

void main() {
  final calculator = GpxTrackStatisticsCalculator();

  test('calculates average moving and max speed', () {
    final gpx = _constantSpeedGpx();
    final stats = calculator.calculate(gpx);

    final distance = _distance.as(
      LengthUnit.Meter,
      const LatLng(-42.0, 146.0),
      const LatLng(-42.0, 146.05),
    );
    final expectedKmh = distance * 3600 / (5 * 60 * 1000);

    expect(stats.totalTimeMillis, 5 * 60 * 1000);
    expect(stats.movingTime, 5 * 60 * 1000);
    expect(stats.averageSpeedKmh, closeTo(expectedKmh, 0.05));
    expect(stats.movingSpeedKmh, closeTo(expectedKmh, 0.05));
    expect(stats.maxSpeedKmh, closeTo(expectedKmh, 0.05));
  });

  test('supports 30s 1m 3m and 5m windows', () {
    final gpx = _constantSpeedGpx();
    final distance = _distance.as(
      LengthUnit.Meter,
      const LatLng(-42.0, 146.0),
      const LatLng(-42.0, 146.05),
    );
    final expectedKmh = distance * 3600 / (5 * 60 * 1000);

    expect(
      calculator.calculateMaxSpeedKmh(
        gpx,
        window: const Duration(seconds: 30),
      ),
      closeTo(expectedKmh, 0.05),
    );
    expect(
      calculator.calculateMaxSpeedKmh(
        gpx,
        window: const Duration(minutes: 1),
      ),
      closeTo(expectedKmh, 0.05),
    );
    expect(
      calculator.calculateMaxSpeedKmh(
        gpx,
        window: const Duration(minutes: 3),
      ),
      closeTo(expectedKmh, 0.05),
    );
    expect(
      calculator.calculateMaxSpeedKmh(
        gpx,
        window: const Duration(minutes: 5),
      ),
      closeTo(expectedKmh, 0.05),
    );
  });

  test('returns null for short or non-progressing timing', () {
    final gpx = _shortOrBrokenGpx();

    expect(
      calculator.calculateMaxSpeedKmh(
        gpx,
        window: const Duration(minutes: 3),
      ),
      isNull,
    );

    final stats = calculator.calculate(gpx);
    expect(stats.averageSpeedKmh, isNull);
    expect(stats.movingSpeedKmh, isNull);
    expect(stats.maxSpeedKmh, isNull);
  });
}

const _distance = Distance();

String _constantSpeedGpx() => '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Speed Track</name>
    <trkseg>
      <trkpt lat="-42.0" lon="146.0"><time>2024-01-15T08:00:00</time></trkpt>
      <trkpt lat="-42.0" lon="146.01"><time>2024-01-15T08:01:00</time></trkpt>
      <trkpt lat="-42.0" lon="146.02"><time>2024-01-15T08:02:00</time></trkpt>
      <trkpt lat="-42.0" lon="146.03"><time>2024-01-15T08:03:00</time></trkpt>
      <trkpt lat="-42.0" lon="146.04"><time>2024-01-15T08:04:00</time></trkpt>
      <trkpt lat="-42.0" lon="146.05"><time>2024-01-15T08:05:00</time></trkpt>
    </trkseg>
  </trk>
</gpx>
''';

String _shortOrBrokenGpx() => '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Broken Speed Track</name>
    <trkseg>
      <trkpt lat="-42.0" lon="146.0"><time>2024-01-15T08:00:00</time></trkpt>
      <trkpt lat="-42.0" lon="146.01"><time>2024-01-15T08:00:00</time></trkpt>
      <trkpt lat="-42.0" lon="146.02"><time>2024-01-15T08:00:00</time></trkpt>
    </trkseg>
    <trkseg>
      <trkpt lat="-42.0" lon="146.03"><time>2024-01-15T08:10:00</time></trkpt>
      <trkpt lat="-42.0" lon="146.04"><time>2024-01-15T08:10:00</time></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
