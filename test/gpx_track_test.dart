import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';

void main() {
  group('GpxTrack', () {
    test('empty constructor creates with default values', () {
      final track = GpxTrack(
        fileLocation: '/path/to/track.gpx',
        trackName: '2024-01-15-test-track',
      );

      expect(track.fileLocation, '/path/to/track.gpx');
      expect(track.trackName, '2024-01-15-test-track');
      expect(track.trackColour, 0xFFa726bc);
    });

    test('fromMap creates track from map', () {
      final map = {
        'gpxTrackId': 1,
        'fileLocation': '/test/path.gpx',
        'trackName': '2024-01-15-mountain',
        'startDateTime': '2024-01-15T10:00:00.000',
        'distance': 5.5,
        'ascent': 300.0,
        'totalTimeMillis': 3600000,
        'trackColour': 0xFFa726bc,
      };

      final track = GpxTrack.fromMap(map);

      expect(track.gpxTrackId, 1);
      expect(track.fileLocation, '/test/path.gpx');
      expect(track.trackName, '2024-01-15-mountain');
      expect(track.distance, 5.5);
    });

    test('toMap returns correct map', () {
      final track = GpxTrack(
        fileLocation: '/test/path.gpx',
        trackName: '2024-01-15-test',
        distance: 5.5,
        trackColour: 0xFFa726bc,
      );

      final map = track.toMap();

      expect(map['fileLocation'], '/test/path.gpx');
      expect(map['trackName'], '2024-01-15-test');
      expect(map['distance'], 5.5);
    });
  });
}
