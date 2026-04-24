import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/services/gpx_track_filter.dart';
import 'package:xml/xml.dart';

void main() {
  test('drops points without time and keeps a minimal gpx doc', () {
    const rawXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Test Track</name>
    <trkseg>
      <trkpt lat="-42.0000" lon="146.0000">
        <time>2024-01-15T08:00:00Z</time>
      </trkpt>
      <trkpt lat="-42.0001" lon="146.0001">
        <ele>123</ele>
      </trkpt>
      <trkpt lat="-42.0002" lon="146.0002">
        <time>2024-01-15T08:10:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';

    final result = const GpxTrackFilter().filter(
      rawXml,
      config: GpxFilterConfig.defaults,
    );

    expect(result.usedRawFallback, isFalse);
    expect(result.filteredXml, isNotNull);

    final document = XmlDocument.parse(result.filteredXml!);
    expect(document.findAllElements('trkpt'), hasLength(2));
    expect(
      document.findAllElements('trkpt').every((point) {
        return point.findElements('time').isNotEmpty;
      }),
      isTrue,
    );
    expect(document.findAllElements('ele'), isEmpty);
  });

  test('falls back to raw gpx when fewer than two points survive', () {
    const rawXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Fallback Track</name>
    <trkseg>
      <trkpt lat="-42.0000" lon="146.0000">
        <time>2024-01-15T08:00:00Z</time>
      </trkpt>
      <trkpt lat="-42.5000" lon="146.5000">
        <ele>123</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';

    final result = const GpxTrackFilter().filter(
      rawXml,
      config: GpxFilterConfig.defaults,
    );

    expect(result.usedRawFallback, isTrue);
    expect(result.filteredXml, isNull);
    expect(result.displaySegments, hasLength(1));
    expect(result.displaySegments.single, hasLength(2));
  });

  test('skips Hampel filtering when outlier filter is none', () {
    const rawXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Outlier Track</name>
    <trkseg>
      <trkpt lat="-42.0000" lon="146.0000">
        <time>2024-01-15T08:00:00Z</time>
        <ele>100</ele>
      </trkpt>
      <trkpt lat="-42.0001" lon="146.0001">
        <time>2024-01-15T08:05:00Z</time>
        <ele>1000</ele>
      </trkpt>
      <trkpt lat="-42.0002" lon="146.0002">
        <time>2024-01-15T08:10:00Z</time>
        <ele>110</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';

    final disabled = const GpxTrackFilter().filter(
      rawXml,
      config: GpxFilterConfig.defaults.copyWith(
        outlierFilter: GpxTrackOutlierFilter.none,
        elevationSmoother: GpxTrackElevationSmoother.none,
        positionSmoother: GpxTrackPositionSmoother.none,
      ),
    );

    final enabled = const GpxTrackFilter().filter(
      rawXml,
      config: GpxFilterConfig.defaults.copyWith(
        elevationSmoother: GpxTrackElevationSmoother.none,
        positionSmoother: GpxTrackPositionSmoother.none,
      ),
    );

    expect(disabled.usedRawFallback, isFalse);
    expect(enabled.usedRawFallback, isFalse);
    expect(disabled.filteredXml, contains('<ele>1000.00</ele>'));
    expect(enabled.filteredXml, isNot(contains('<ele>1000.00</ele>')));
  });
}
