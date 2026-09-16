import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/objectbox.g.dart';
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

  test(
    'normalises supported names and returns updated and unchanged counts',
    () {
      final dated = GpxTrack(
        gpxTrackId: 1,
        contentHash: 'dated',
        trackName: 'Mt Anne 10-03-2025',
        trackDate: DateTime.utc(2024, 1, 1),
        gpxFile: '<gpx>dated</gpx>',
        distance2d: 123.4,
        visible: false,
      );
      final unchanged = GpxTrack(
        gpxTrackId: 2,
        contentHash: 'unchanged',
        trackName: 'Mt Field',
      );
      final datedBefore = Map<String, dynamic>.from(dated.toMap());
      final repository = GpxTrackRepository.test(
        InMemoryGpxTrackStorage([dated, unchanged]),
      );

      final result = repository.normaliseTrackNames();

      expect(result.updatedCount, 1);
      expect(result.unchangedCount, 1);
      expect(repository.findById(1)!.trackName, 'Mt Anne');
      expect(repository.findById(1)!.toMap(), {
        ...datedBefore,
        'trackName': 'Mt Anne',
      });
      expect(repository.findById(2), same(unchanged));
    },
  );

  test('restores every name when the transactional batch write fails', () {
    final first = GpxTrack(
      gpxTrackId: 1,
      contentHash: 'first',
      trackName: 'Mt Anne 10-03-2025',
    );
    final second = GpxTrack(
      gpxTrackId: 2,
      contentHash: 'second',
      trackName: 'Mt Field 11/03/2025',
    );
    final repository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage.withFailureForTest(
        tracks: [first, second],
        failureForTest: TrackNameNormalisationFailure.afterFirstWrite,
      ),
    );

    expect(repository.normaliseTrackNames, throwsStateError);
    expect(repository.findById(1)!.trackName, 'Mt Anne 10-03-2025');
    expect(repository.findById(2)!.trackName, 'Mt Field 11/03/2025');
  });

  test(
    'ObjectBox batch normalisation preserves relations and rolls back',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'gpx-track-name-normalisation-test',
      );
      final store = await openStore(directory: directory.path);
      addTearDown(() async {
        store.close();
        await directory.delete(recursive: true);
      });
      final firstPeak = Peak(
        osmId: 10,
        name: 'First peak',
        latitude: -42,
        longitude: 146,
      );
      final secondPeak = Peak(
        osmId: 20,
        name: 'Second peak',
        latitude: -43,
        longitude: 147,
      );
      store.box<Peak>().putMany([firstPeak, secondPeak]);
      final first = GpxTrack(
        gpxTrackId: 1,
        contentHash: 'first',
        trackName: 'Mt Anne 10-03-2025',
        gpxFile: '<gpx>first</gpx>',
        distance2d: 123.4,
        visible: false,
      )..peaks.add(firstPeak);
      final second = GpxTrack(
        gpxTrackId: 2,
        contentHash: 'second',
        trackName: 'Mt Field 11/03/2025',
        gpxFile: '<gpx>second</gpx>',
        distance2d: 234.5,
      )..peaks.add(secondPeak);
      final tracks = store.box<GpxTrack>();
      tracks.putMany([first, second]);
      final firstBefore = Map<String, dynamic>.from(first.toMap());

      final result = GpxTrackRepository(store).normaliseTrackNames();

      expect(result.updatedCount, 2);
      expect(tracks.get(1)!.toMap(), {...firstBefore, 'trackName': 'Mt Anne'});
      expect(tracks.get(1)!.peaks.map((peak) => peak.osmId), [10]);
      expect(tracks.get(2)!.peaks.map((peak) => peak.osmId), [20]);

      final resetFirst = tracks.get(1)!..trackName = 'Mt Anne 10-03-2025';
      final resetSecond = tracks.get(2)!..trackName = 'Mt Field 11/03/2025';
      tracks.putMany([resetFirst, resetSecond]);

      final failingRepository = GpxTrackRepository.test(
        ObjectBoxGpxTrackStorage(
          store,
          failureForTest: TrackNameNormalisationFailure.afterFirstWrite,
        ),
      );

      expect(failingRepository.normaliseTrackNames, throwsStateError);
      expect(tracks.get(1)!.trackName, 'Mt Anne 10-03-2025');
      expect(tracks.get(2)!.trackName, 'Mt Field 11/03/2025');
      expect(tracks.get(1)!.peaks.map((peak) => peak.osmId), [10]);
      expect(tracks.get(2)!.peaks.map((peak) => peak.osmId), [20]);
    },
  );
}
