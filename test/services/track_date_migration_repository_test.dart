import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/track_date_migration_metadata.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/track_date_calendar_codec.dart';
import 'package:peak_bagger/services/track_date_derivation_service.dart';
import 'package:peak_bagger/services/track_date_migration_repository.dart';

import '../harness/track_date_fixtures.dart';
import '../harness/track_date_migration_fixture.dart';

void main() {
  setUpAll(expectTrackDateHostOffsets);
  late TrackDateMigrationFixture fixture;
  setUp(() async => fixture = await TrackDateMigrationFixture.create());
  tearDown(() => fixture.dispose());

  test(
    'atomically corrects dates with durable counts, preserves IDs and skipped legacy values',
    () async {
      final before = fixture.snapshot;
      final result = await fixture.service().run();
      final metadata = result.metadata;
      expect(
        (metadata.id, metadata.key, metadata.completedVersion),
        (1, 'track_location_calendar_day', 1),
      );
      expect(
        (metadata.updatedCount, metadata.unchangedCount, metadata.skippedCount),
        (2, 1, 2),
      );
      expect(metadata.completedAt, DateTime.utc(2026, 10, 16, 12));
      expect(
        (metadata.geographicDataVersion, metadata.ianaDataVersion),
        ('2026e', '2026e'),
      );
      final skips = TrackDateMigrationSkip.decode(metadata.skippedRecordsJson);
      expect(skips.map((skip) => (skip.trackId, skip.trackName, skip.reason)), [
        (10, 'Missing time', 'missing_time'),
        (11, 'Unknown import', 'missing_time'),
      ]);
      expect(
        skips.first.message,
        contains('first recorded point has no timestamp'),
      );
      final after = fixture.snapshot;
      expect(
        after.tracks.map((track) => track.gpxTrackId),
        before.tracks.map((track) => track.gpxTrackId),
      );
      expect(
        after.ascents.map((row) => (row.baggedId, row.gpxId, row.peakId)),
        before.ascents.map((row) => (row.baggedId, row.gpxId, row.peakId)),
      );
      for (var i = 0; i < after.tracks.length; i++) {
        final track = after.tracks[i];
        final expected = {...before.tracks[i].toMap()};
        final actual = {...track.toMap()};
        for (final key in [
          'trackDate',
          'trackDateStatus',
          'trackDateDerivationVersion',
          'trackDateTimezoneId',
          'trackDateFailureReason',
        ]) {
          expected.remove(key);
          actual.remove(key);
        }
        expect(actual, expected, reason: 'Only date metadata may change');
        expect(track.peaks.map((peak) => peak.osmId), [10]);
        expect(track.trackDateDerivationVersion, 1);
      }
      for (final id in [7, 8, 9]) {
        final track = after.tracks.singleWhere(
          (track) => track.gpxTrackId == id,
        );
        final day = id == 8 ? DateTime.utc(2026, 12, 31) : DateTime.utc(2027);
        expect((track.trackDate, track.trackDateStatus), (day, 1));
        expect(TrackDateCalendarCodec.day(track), day);
        expect(after.ascents.singleWhere((row) => row.gpxId == id).date, day);
      }
      final skipped = after.tracks.singleWhere(
        (track) => track.gpxTrackId == 10,
      );
      expect(skipped.trackDateStatus, 2);
      expect(
        skipped.trackDate,
        before.tracks.singleWhere((track) => track.gpxTrackId == 10).trackDate,
      );
      expect(TrackDateCalendarCodec.day(skipped), DateTime.utc(2001, 2, 3));
      expect(
        after.tracks
            .singleWhere((track) => track.gpxTrackId == 11)
            .trackDateStatus,
        3,
      );
      await PeaksBaggedRepository(fixture.store).syncFromTracks(after.tracks);
      expect(
        fixture.snapshot.ascents.map((row) => (row.baggedId, row.date)),
        after.ascents.map((row) => (row.baggedId, row.date)),
      );
      expect(fixture.metadata!.skippedRecordsJson, metadata.skippedRecordsJson);
    },
  );

  for (final stage in TrackDateMigrationWriteStage.values) {
    test(
      '$stage failure rolls back dates, status, linked rows and marker; retry is idempotent',
      () async {
        final before = fixture.snapshot.fingerprint;
        final repository = ObjectBoxTrackDateMigrationRepository(
          fixture.store,
          beforeWriteForTest: (point) {
            if (point == stage) throw StateError('Injected $stage failure');
          },
        );
        await expectLater(
          fixture.service(repository: repository).run(),
          throwsStateError,
        );
        expect(fixture.metadata, isNull);
        expect(fixture.snapshot.fingerprint, before);
        await fixture.service().run();
        final committed = fixture.snapshot.fingerprint;
        final second = await fixture
            .service(
              derivation: () => throw StateError('Completed must not scan'),
            )
            .run();
        expect(second.alreadyCompleted, isTrue);
        expect(fixture.snapshot.fingerprint, committed);
        expect(fixture.store.box<TrackDateMigrationMetadata>().count(), 1);
      },
    );
  }

  test(
    'rejects changed Track input instead of overwriting a competing import/edit',
    () async {
      final repository = ObjectBoxTrackDateMigrationRepository(fixture.store);
      final before = repository.readSnapshot();
      final resolver = TrackDateDerivationService.offline();
      final outcomes = [
        for (final track in before.tracks) resolver.derive(track.gpxFile),
      ];
      final changed = fixture.store.box<GpxTrack>().get(7)!
        ..gpxFile = datedGpx(time: '2020-01-01T00:00:00Z');
      fixture.store.box<GpxTrack>().put(changed);
      final competing = fixture.snapshot.fingerprint;
      expect(
        () => repository.commit(
          snapshot: before,
          outcomes: outcomes,
          completedAt: DateTime.utc(2026),
        ),
        throwsA(isA<TrackDateMigrationInputsChanged>()),
      );
      expect(fixture.metadata, isNull);
      expect(fixture.snapshot.fingerprint, competing);
      await fixture.service().run();
      expect(
        fixture.store.box<GpxTrack>().get(7)!.trackDate,
        DateTime.utc(2020),
      );
    },
  );

  test(
    'rejects changed linked dates, membership, added and removed records',
    () {
      final repository = ObjectBoxTrackDateMigrationRepository(fixture.store);
      final resolver = TrackDateDerivationService.offline();
      for (final mutate in <void Function()>[
        () {
          final row = fixture.store.box<PeaksBagged>().get(70)!
            ..date = DateTime.utc(2000);
          fixture.store.box<PeaksBagged>().put(row);
        },
        () {
          final track = fixture.store.box<GpxTrack>().get(7)!;
          track.peaks.clear();
          fixture.store.box<GpxTrack>().put(track);
        },
        () {
          fixture.store.box<GpxTrack>().put(
            GpxTrack(
              gpxTrackId: 12,
              contentHash: 'new',
              trackName: 'Concurrent',
            ),
          );
        },
        () {
          fixture.store.box<GpxTrack>().remove(8);
        },
      ]) {
        final snapshot = repository.readSnapshot();
        final outcomes = [
          for (final track in snapshot.tracks) resolver.derive(track.gpxFile),
        ];
        mutate();
        final beforeCommit = fixture.snapshot.fingerprint;
        expect(
          () => repository.commit(
            snapshot: snapshot,
            outcomes: outcomes,
            completedAt: DateTime.utc(2026),
          ),
          throwsA(isA<TrackDateMigrationInputsChanged>()),
        );
        expect(fixture.snapshot.fingerprint, beforeCommit);
        expect(fixture.metadata, isNull);
      }
    },
  );
}
