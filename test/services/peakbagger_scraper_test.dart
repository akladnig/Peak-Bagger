import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/peakbagger_scraper.dart';

void main() {
  test('parses real peakbagger nested json shape', () {
    final details = PeakBaggerPeakDetails.fromJson({
      'pid': '74023',
      'name': 'Abbotts Lookout',
      'state': 'Tasmania',
      'elevation': {
        'feet': null,
        'meters': null,
      },
      'prominence': {
        'feet': null,
        'meters': null,
      },
      'location': {
        'latitude': -42.780553,
        'longitude': 146.654086,
        'county': null,
        'country': null,
      },
      'url': 'https://www.peakbagger.com/peak.aspx?pid=74023',
    });

    expect(details.peakbaggerPid, 74023);
    expect(details.name, 'Abbotts Lookout');
    expect(details.latitude, -42.780553);
    expect(details.longitude, 146.654086);
    expect(details.elevation, isNull);
    expect(details.prominence, isNull);
    expect(details.country, '');
    expect(details.county, '');
  });
}
