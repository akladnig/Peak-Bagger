import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';

void main() {
  test('defaults sourceOfTruth to OSM', () {
    final peak = Peak(name: 'Mt Anne', latitude: -41.5, longitude: 146.5);

    expect(peak.sourceOfTruth, Peak.sourceOfTruthOsm);
    expect(peak.region, Peak.defaultRegion);
    expect(peak.peakbaggerPid, isNull);
    expect(peak.prominence, isNull);
    expect(peak.country, '');
    expect(peak.county, '');
    expect(peak.range, '');
    expect(peak.durationMinutes, isNull);
    expect(peak.durationLabel, '');
  });

  test('defaults alternate name and verified metadata', () {
    final peak = Peak(name: 'Mt Anne', latitude: -41.5, longitude: 146.5);

    expect(peak.altName, '');
    expect(peak.verified, isFalse);
    expect(peak.region, Peak.defaultRegion);
  });

  test('copyWith preserves alternate name and verified metadata', () {
    final peak = Peak(
      name: 'Mt Anne',
      altName: 'Anne Peak',
      latitude: -41.5,
      longitude: 146.5,
      verified: true,
    );

    final copy = peak.copyWith(name: 'Mount Anne');

    expect(copy.altName, 'Anne Peak');
    expect(copy.verified, isTrue);
  });

  test('copyWith preserves PeakBagger metadata', () {
    final peak = Peak(
      name: 'Mt Anne',
      latitude: -41.5,
      longitude: 146.5,
      peakbaggerPid: 123,
      prominence: 456.7,
      country: 'Australia',
      county: 'Hobart',
      range: 'Eastern Arthur Range',
      durationMinutes: 300,
      durationLabel: '4-5 hours',
    );

    final copy = peak.copyWith(name: 'Mount Anne');

    expect(copy.peakbaggerPid, 123);
    expect(copy.prominence, 456.7);
    expect(copy.country, 'Australia');
    expect(copy.county, 'Hobart');
    expect(copy.range, 'Eastern Arthur Range');
    expect(copy.durationMinutes, 300);
    expect(copy.durationLabel, '4-5 hours');
  });

  test('sourceOfTruthPeakBagger uses peakbagger.com', () {
    expect(Peak.sourceOfTruthPeakBagger, 'peakbagger.com');
  });

  test('fromOverpass parses osmId', () {
    final peak = Peak.fromOverpass({
      'id': 123456,
      'lat': -41.5,
      'lon': 146.5,
      'tags': {'name': 'Mt Anne'},
    });

    expect(peak.osmId, 123456);
    expect(peak.name, 'Mt Anne');
    expect(peak.latitude, -41.5);
    expect(peak.longitude, 146.5);
    expect(peak.sourceOfTruth, Peak.sourceOfTruthOsm);
    expect(peak.region, Peak.defaultRegion);
  });
}
