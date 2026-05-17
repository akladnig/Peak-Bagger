import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';

void main() {
  group('GpxTrack serialization', () {
    test('fromMap/toMap roundtrip preserves surviving fields', () {
      final track = GpxTrack(
        contentHash: 'abc123',
        trackName: 'Test Track',
        trackDate: DateTime(2024, 1, 15),
        gpxFile: '<gpx></gpx>',
        peakCorrelationProcessed: true,
      );

      final map = track.toMap();
      final restored = GpxTrack.fromMap(map);

      expect(restored.contentHash, 'abc123');
      expect(restored.trackName, 'Test Track');
      expect(restored.trackDate, DateTime(2024, 1, 15));
      expect(restored.peakCorrelationProcessed, isTrue);
      expect(restored.toMap().containsKey('managedRelativePath'), isFalse);
      expect(restored.toMap().containsKey('managedPlacementPending'), isFalse);
    });

    test('fromMap ignores removed placement keys in legacy rows', () {
      final legacyMap = <String, dynamic>{
        'gpxTrackId': 1,
        'contentHash': 'abc123',
        'trackName': 'Legacy Track',
        'managedPlacementPending': true,
        'managedRelativePath': 'Tracks/Tasmania/test.gpx',
      };

      final track = GpxTrack.fromMap(legacyMap);

      expect(track.gpxTrackId, 1);
      expect(track.contentHash, 'abc123');
      expect(track.trackName, 'Legacy Track');
      expect(track.toMap().containsKey('managedPlacementPending'), isFalse);
      expect(track.toMap().containsKey('managedRelativePath'), isFalse);
    });

    test('fromMap handles missing fields gracefully', () {
      final legacyMap = <String, dynamic>{
        'gpxTrackId': 1,
        'contentHash': 'abc123',
        'trackName': 'Legacy Track',
      };

      final track = GpxTrack.fromMap(legacyMap);

      expect(track.gpxTrackId, 1);
      expect(track.contentHash, 'abc123');
      expect(track.trackName, 'Legacy Track');
    });
  });
}
