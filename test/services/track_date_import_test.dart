import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/track_date_derivation_service.dart';

import '../harness/track_date_fixtures.dart';
import '../harness/track_date_import_harness.dart';

void main() {
  setUpAll(expectTrackDateHostOffsets);
  late TrackDateImportHarness harness;
  setUp(() async => harness = await TrackDateImportHarness.create());
  tearDown(() => harness.close());

  test(
    'original first-point day persists through filtering and ascent sync',
    () async {
      final xml = datedGpx(
        extraPoints:
            '<trkpt lat="-42.8820" lon="147.3273"><ele>100</ele><time>2026-12-31T13:35:00Z</time></trkpt>',
      );
      final file = harness.file('new-year', xml);
      final result = await harness.container
          .read(mapProvider.notifier)
          .importGpxFiles(pathToEditedNames: {file.path: 'New year'});
      expect(result.addedCount, 1);
      final track = result.items.single.track;
      expect(track.trackDate, DateTime.utc(2027, 1, 1));
      expect(track.trackDateStatus, 1);
      expect(track.trackDateDerivationVersion, 1);
      expect(track.trackDateTimezoneId, 'Australia/Hobart');
      expect(track.gpxFile, xml);
      expect(track.startDateTime!.toUtc(), DateTime.utc(2026, 12, 31, 13, 30));
      expect(harness.ascents.getAll().single.date, DateTime.utc(2027, 1, 1));
      expect(
        harness.container.read(mapProvider).hasTrackRecoveryIssue,
        isFalse,
      );
      expect(result.warningMessage, isNull);
      expect(
        Directory(
          '${harness.directory.path}/Tracks/Australia/Tasmania',
        ).listSync().single.path,
        endsWith('_(01-01-2027).gpx'),
      );
    },
  );

  test(
    'missing/invalid/ambiguous first times import unknown with reason, never file date',
    () async {
      for (final fixture in <(String?, String)>[
        (null, 'missing_time'),
        ('invalidZ', 'invalid_time'),
        ('2026-01-01T08:00:00', 'ambiguous_time'),
      ]) {
        final xml = datedGpx(
          time: fixture.$1,
          extraPoints:
              '<trkpt lat="-42.8820" lon="147.3273"><ele>100</ele><time>2026-12-31T13:35:00Z</time></trkpt>',
        );
        final file = harness.file(fixture.$2, xml);
        await file.setLastModified(DateTime(2000, 1, 1));
        final result = await harness.container
            .read(mapProvider.notifier)
            .importGpxFiles(pathToEditedNames: {file.path: fixture.$2});
        expect(result.addedCount, 1);
        final track = result.items.single.track;
        expect(track.trackDate, isNull);
        expect(track.trackDateStatus, 3);
        expect(track.trackDateDerivationVersion, 1);
        expect(track.trackDateFailureReason, fixture.$2);
        expect(result.warningMessage, contains('unknown walk date'));
        expect(
          harness.container.read(mapProvider).trackOperationWarning,
          result.warningMessage,
        );
        expect(
          harness.container.read(mapProvider).hasTrackRecoveryIssue,
          isFalse,
        );
      }
      await harness.ascents.syncFromTracks(harness.tracks.getAllTracks());
      expect(harness.ascents.getAll().every((row) => row.date == null), isTrue);
      expect(harness.ascents.getAll(), hasLength(3));
    },
  );

  test(
    'replaceable geographic/rules failures produce successful unknown imports',
    () async {
      for (final fixture in [
        'geographic_lookup_failed',
        'timezone_rules_failed',
      ]) {
        await harness.close();
        harness = await TrackDateImportHarness.create(
          dateService: TrackDateDerivationService(
            lookupTimezone: ({required latitude, required longitude}) {
              if (fixture == 'geographic_lookup_failed') {
                throw StateError('lookup failed');
              }
              return 'Missing/Zone';
            },
            localTime: ({required instant, required timezoneId}) =>
                throw StateError('rules failed'),
          ),
        );
        final file = harness.file(fixture, datedGpx());
        final result = await harness.container
            .read(mapProvider.notifier)
            .importGpxFiles(pathToEditedNames: {file.path: fixture});
        expect(result.addedCount, 1);
        expect(result.items.single.track.trackDateFailureReason, fixture);
        expect(result.items.single.track.trackDate, isNull);
        expect(result.warningMessage, contains('Retry the import'));
        expect(harness.ascents.getAll().single.date, isNull);
      }
    },
  );

  test(
    'unusable first coordinates do not substitute later point for derivation',
    () async {
      final file = harness.file(
        'bad-coordinates',
        datedGpx(
          latitude: '',
          extraPoints:
              '<trkpt lat="-42.8821" lon="147.3272"><ele>100</ele><time>2026-12-31T13:35:00Z</time></trkpt>',
        ),
      );
      final plan = await GpxImporter(
        tracksFolder: '${harness.directory.path}/Tracks',
      ).planSelectiveImport(paths: [file.path], pathToEditedNames: {});
      expect(plan.addedCount, 1);
      expect(plan.items.single.track.trackDate, isNull);
      expect(
        plan.items.single.track.trackDateFailureReason,
        'invalid_coordinates',
      );
      expect(plan.warningMessage, contains('valid latitude and longitude'));
    },
  );
}
