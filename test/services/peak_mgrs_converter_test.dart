import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';

void main() {
  test('splits a combined MGRS string into fields', () {
    final components = PeakMgrsConverter.fromForwardString('55GEN1234567890');

    expect(components.gridZoneDesignator, '55G');
    expect(components.mgrs100kId, 'EN');
    expect(components.easting, '12345');
    expect(components.northing, '67890');
  });

  test('converts a LatLng to fixed-width MGRS fields', () {
    final components = PeakMgrsConverter.fromLatLng(const LatLng(-41.5, 146.5));

    expect(components.gridZoneDesignator, '55G');
    expect(components.mgrs100kId, hasLength(2));
    expect(components.easting, hasLength(5));
    expect(components.northing, hasLength(5));
  });

  test('rejects malformed combined MGRS strings', () {
    expect(
      () => PeakMgrsConverter.fromForwardString('55GEN123'),
      throwsFormatException,
    );
  });

  test('normalizes CSV UTM fields into comparable MGRS components', () {
    final fromCsv = PeakMgrsConverter.fromCsvUtm(
      zone: '55G',
      easting: '4 15 135',
      northing: '53 65 355',
    );
    final fromLatLng = PeakMgrsConverter.fromLatLng(
      const LatLng(-41.85916, 145.97754),
    );

    expect(fromCsv.gridZoneDesignator, fromLatLng.gridZoneDesignator);
    expect(fromCsv.mgrs100kId, fromLatLng.mgrs100kId);
    expect(fromCsv.easting, fromLatLng.easting);
    expect(fromCsv.northing, fromLatLng.northing);
  });
}
