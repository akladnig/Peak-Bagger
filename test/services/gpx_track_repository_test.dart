import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';

void main() {
  test('saveTrack assigns an id on create and defaults visible true', () {
    final repository = GpxTrackRepository.test(InMemoryGpxTrackStorage());
    final track = GpxTrack(
      contentHash: 'hash-1',
      trackName: 'Created Track',
      gpxFile: '<gpx></gpx>',
    );

    final saved = repository.saveTrack(track);

    expect(saved.gpxTrackId, greaterThan(0));
    expect(repository.getAllTracks().single.gpxTrackId, saved.gpxTrackId);
    expect(repository.getAllTracks().single.trackName, 'Created Track');
    expect(repository.getAllTracks().single.visible, isTrue);
  });

  test('saveTrack preserves visible on update', () {
    final repository = GpxTrackRepository.test(InMemoryGpxTrackStorage());
    final created = repository.saveTrack(
      GpxTrack(
        contentHash: 'hash-2',
        trackName: 'Visible Track',
        gpxFile: '<gpx></gpx>',
      ),
    );

    created.visible = false;
    final updated = repository.saveTrack(created);

    expect(updated.visible, isFalse);
    expect(repository.getAllTracks().single.visible, isFalse);
  });
}
