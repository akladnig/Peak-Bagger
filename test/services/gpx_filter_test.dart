import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/services/gpx_filter.dart';
import 'package:xml/xml.dart';

void main() {
  test('keeps route geometry without timestamps', () {
    const rawXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <rte>
    <name>Route One</name>
    <desc>Route description</desc>
    <rtept lat="-41.0000" lon="146.0000"><ele>100</ele></rtept>
    <rtept lat="-41.0001" lon="146.0001"><ele>105</ele></rtept>
    <rtept lat="-41.0002" lon="146.0002"><ele>110</ele></rtept>
  </rte>
</gpx>
''';

    final result = const GpxFilter().filter(
      rawXml,
      config: const GpxFilterConfig(
        hampelWindow: 5,
        outlierFilter: GpxTrackOutlierFilter.hampel,
        elevationSmoother: GpxTrackElevationSmoother.none,
        elevationWindow: 5,
        positionSmoother: GpxTrackPositionSmoother.kalman,
        positionWindow: 3,
      ),
    );

    expect(result.usedRawFallback, isFalse);
    expect(result.filteredXml, isNotNull);

    final document = XmlDocument.parse(result.filteredXml!);
    expect(document.findAllElements('rtept'), hasLength(3));
    expect(document.findAllElements('time'), isEmpty);
    expect(document.findAllElements('name').first.innerText, 'Route One');
    expect(document.findAllElements('desc').first.innerText, 'Route description');
    expect(result.displaySegments, hasLength(1));
    expect(result.displaySegments.single, hasLength(3));
  });
}
