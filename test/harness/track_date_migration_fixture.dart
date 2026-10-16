import 'dart:io';

import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/track_date_migration_metadata.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/track_date_derivation_service.dart';
import 'package:peak_bagger/services/track_date_migration_repository.dart';
import 'package:peak_bagger/services/track_date_migration_service.dart';

import 'track_date_fixtures.dart';

class TrackDateMigrationFixture {
  TrackDateMigrationFixture._(this.directory, this.store);
  final Directory directory;
  final Store store;

  static Future<TrackDateMigrationFixture> create({bool seed = true}) async {
    final directory = await Directory.systemTemp.createTemp(
      'track-date-migration',
    );
    final fixture = TrackDateMigrationFixture._(
      directory,
      await openStore(directory: directory.path),
    );
    if (seed) fixture.seed();
    return fixture;
  }

  void seed() {
    final peak = Peak(
      osmId: 10,
      name: 'Fixture peak',
      latitude: -42,
      longitude: 147,
    );
    store.box<Peak>().put(peak);
    final tracks = [
      GpxTrack(
        gpxTrackId: 7,
        contentHash: '7',
        trackName: 'Hobart legacy local',
        gpxFile: datedGpx(),
        trackDate: DateTime(2026, 12, 31),
      ),
      GpxTrack(
        gpxTrackId: 8,
        contentHash: '8',
        trackName: 'Los Angeles legacy UTC',
        gpxFile: datedGpx(
          latitude: '34.0522',
          longitude: '-118.2437',
          time: '2027-01-01T07:30:00Z',
        ),
        trackDate: DateTime.utc(2027),
      ),
      // Already-canonical components count as unchanged even without metadata.
      GpxTrack(
        gpxTrackId: 9,
        contentHash: '9',
        trackName: 'Already agrees',
        gpxFile: datedGpx(),
        trackDate: DateTime.utc(2027),
      ),
      GpxTrack(
        gpxTrackId: 10,
        contentHash: '10',
        trackName: 'Missing time',
        gpxFile: datedGpx(time: null),
        trackDate: DateTime(2001, 2, 3),
      ),
      GpxTrack(
        gpxTrackId: 11,
        contentHash: '11',
        trackName: 'Unknown import',
        gpxFile: datedGpx(time: null),
        trackDateStatus: 3,
        trackDateDerivationVersion: 1,
        trackDateFailureReason: 'missing_time',
      ),
    ];
    for (final track in tracks) {
      track.startDateTime = DateTime.utc(2026, 12, 31, 13, 30);
      track.endDateTime = DateTime.utc(2026, 12, 31, 15);
      track.gpxFileRepaired = datedGpx(time: '2025-01-01T00:00:00Z');
      track.distance2d = 1234;
      track.ascent = 100;
      track.peaks.add(peak);
      store.box<GpxTrack>().put(track);
      store.box<PeaksBagged>().put(
        PeaksBagged(
          baggedId: track.gpxTrackId * 10,
          gpxId: track.gpxTrackId,
          peakId: peak.osmId,
          date: switch (track.gpxTrackId) {
            9 => DateTime.utc(2027),
            11 => null,
            // Legacy Australian Eastern midnight carrier, not location day.
            _ => DateTime.utc(2026, 12, 31, 13),
          },
        ),
      );
    }
  }

  TrackDateMigrationSnapshot get snapshot =>
      ObjectBoxTrackDateMigrationRepository(store).readSnapshot();
  TrackDateMigrationMetadata? get metadata =>
      ObjectBoxTrackDateMigrationRepository(store).readCompletion();

  TrackDateMigrationService service({
    TrackDateMigrationRepository? repository,
    TrackDateDerivationService Function()? derivation,
    Future<void> Function()? yieldToUi,
  }) => TrackDateMigrationService(
    repository: repository ?? ObjectBoxTrackDateMigrationRepository(store),
    derivation: derivation ?? TrackDateDerivationService.offline,
    clock: () => DateTime.utc(2026, 10, 16, 12),
    yieldToUi: yieldToUi,
  );

  Future<void> dispose() async {
    store.close();
    await directory.delete(recursive: true);
  }
}
