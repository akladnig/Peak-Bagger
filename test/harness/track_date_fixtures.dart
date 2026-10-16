import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void expectTrackDateHostOffsets() {
  final zone = Platform.environment['TZ'];
  expect(
    zone,
    anyOf('Australia/Hobart', 'UTC'),
    reason: 'Launch with an explicit supported TZ',
  );
  expect(
    DateTime(2026, 1, 15).timeZoneOffset,
    Duration(hours: zone == 'Australia/Hobart' ? 11 : 0),
  );
  expect(
    DateTime(2026, 7, 15).timeZoneOffset,
    Duration(hours: zone == 'Australia/Hobart' ? 10 : 0),
  );
}

String datedGpx({
  String latitude = '-42.8821',
  String longitude = '147.3272',
  String? time = '2026-12-31T13:30:00Z',
  String extraPoints = '',
}) =>
    '''<gpx version="1.1"><trk><name>Fixture walk</name><trkseg>
<trkpt lat="$latitude" lon="$longitude"><ele>100</ele>${time == null ? '' : '<time>$time</time>'}</trkpt>
$extraPoints</trkseg></trk></gpx>''';
