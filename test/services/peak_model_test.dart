import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';

void main() {
  test('defaults sourceOfTruth to OSM', () {
    final peak = Peak(name: 'Mt Anne', latitude: -41.5, longitude: 146.5);

    expect(peak.sourceOfTruth, Peak.sourceOfTruthOsm);
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
  });
}
