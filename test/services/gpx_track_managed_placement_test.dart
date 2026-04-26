import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';

void main() {
  group('GpxTrack managed placement fields', () {
    test('fromMap/toMap roundtrip preserves managedPlacementPending', () {
      final track = GpxTrack(
        contentHash: 'abc123',
        trackName: 'Test Track',
        managedPlacementPending: true,
        managedRelativePath: 'Tracks/Tasmania/test.gpx',
      );

      final map = track.toMap();
      final restored = GpxTrack.fromMap(map);

      expect(restored.managedPlacementPending, isTrue);
      expect(restored.managedRelativePath, 'Tracks/Tasmania/test.gpx');
    });

    test('fromMap defaults to false/null when fields are absent', () {
      final legacyMap = <String, dynamic>{
        'gpxTrackId': 1,
        'contentHash': 'abc123',
        'trackName': 'Legacy Track',
        'managedPlacementPending': null,
        'managedRelativePath': null,
      };

      final track = GpxTrack.fromMap(legacyMap);

      expect(track.managedPlacementPending, isFalse);
      expect(track.managedRelativePath, isNull);
    });

    test('fromMap handles missing fields gracefully', () {
      final legacyMap = <String, dynamic>{
        'gpxTrackId': 1,
        'contentHash': 'abc123',
        'trackName': 'Legacy Track',
      };

      final track = GpxTrack.fromMap(legacyMap);

      expect(track.managedPlacementPending, isFalse);
      expect(track.managedRelativePath, isNull);
    });

    test('toMap includes managed placement fields', () {
      final track = GpxTrack(
        contentHash: 'abc123',
        trackName: 'Test Track',
        managedPlacementPending: true,
        managedRelativePath: 'Tracks/Tasmania/test.gpx',
      );

      final map = track.toMap();

      expect(map['managedPlacementPending'], isTrue);
      expect(map['managedRelativePath'], 'Tracks/Tasmania/test.gpx');
    });
  });
}
