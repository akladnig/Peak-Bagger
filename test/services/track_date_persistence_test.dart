import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/track_derived_data_persistence.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/track_date_calendar_codec.dart';
import 'package:peak_bagger/services/my_ascents_summary_service.dart';
import 'package:peak_bagger/services/year_to_date_summary_service.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/services/track_date_query_parser.dart';
import '../harness/track_date_fixtures.dart';

void main() {
  setUpAll(expectTrackDateHostOffsets);
  late Directory directory;
  late Store store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('track-date-persistence');
    store = await openStore(directory: directory.path);
    store.box<Peak>().put(
      Peak(osmId: 10, name: 'Peak', latitude: -42, longitude: 147),
    );
  });
  tearDown(() async {
    store.close();
    await directory.delete(recursive: true);
  });

  GpxTrack resolvedTrack() => GpxTrack(
    gpxTrackId: 7,
    contentHash: 'h',
    trackName: 'Calendar walk',
    trackDate: DateTime.utc(2026, 12, 31),
    trackDateStatus: 1,
    trackDateDerivationVersion: 1,
    trackDateTimezoneId: 'America/Los_Angeles',
    gpxFile: datedGpx(
      latitude: '34.0522',
      longitude: '-118.2437',
      time: '2027-01-01T07:30:00Z',
    ),
    startDateTime: DateTime.utc(2027, 1, 1, 7, 30),
    distance2d: 1234,
    ascent: 100,
  )..peaks.add(store.box<Peak>().getAll().single);

  test(
    'atomic import round-trip and consumer calendar/year projections',
    () async {
      final original = resolvedTrack();
      final before = original.toMap();
      ObjectBoxTrackDerivedDataPersistence(store).importTrackAndSync(original);
      final track = store.box<GpxTrack>().get(7)!;
      final ascent = store.box<PeaksBagged>().getAll().single;
      expect(track.toMap(), before);
      expect(track.trackDate!.isUtc, isTrue);
      expect(track.trackDate, DateTime.utc(2026, 12, 31));
      expect(ascent.date, DateTime.utc(2026, 12, 31));
      expect(track.peaks.single.osmId, 10);
      expect(TrackDateCalendarCodec.day(track), DateTime.utc(2026, 12, 31));
      final year = const YearToDateSummaryService().buildSummary(
        tracks: [track],
        peaksBagged: [ascent],
        year: 2026,
      );
      expect(
        (year.walkCount, year.peaksClimbed, year.newPeaksClimbed),
        (1, 1, 1),
      );
      final nextYear = const YearToDateSummaryService().buildSummary(
        tracks: [track],
        peaksBagged: [ascent],
        year: 2027,
      );
      expect(nextYear.walkCount, 0);
      final ascents = const MyAscentsSummaryService().build(
        MyAscentsDataset(
          baggedRows: [ascent],
          peaksByOsmId: {10: track.peaks.single},
        ),
        ascending: true,
      );
      expect(ascents.sections.single.year, 2026);
      expect(ascents.sections.single.rows.single.dateText, 'Thu, 31 Dec 2026');
      final timeline = const SummaryCardService().buildTimeline(
        tracks: [track],
        period: SummaryPeriodPreset.yearToDate,
        metric: SummaryMetricDefinition(valueOf: (track) => track.distance2d),
        now: DateTime(2026, 12, 31),
      );
      expect(timeline.buckets.last.value, 1234);
      expect(
        const TrackDateRange(
          start: TrackCalendarDay(2026, 12, 31),
          end: TrackCalendarDay(2026, 12, 31),
        ).containsTrackDate(TrackDateCalendarCodec.day(track)),
        isTrue,
      );
      expect(
        PeaksBaggedRepository(store).latestAscentCalendarDaysByPeakId()[10],
        DateTime.utc(2026, 12, 31),
      );
    },
  );

  test(
    'sync preserves row identities, skipped legacy dates, and unknown imports',
    () async {
      final resolved = resolvedTrack();
      final skipped = GpxTrack(
        gpxTrackId: 8,
        contentHash: 'skip',
        trackName: 'Skipped',
        trackDateStatus: 2,
        trackDate: DateTime.utc(2001),
        trackDateFailureReason: 'missing_time',
      )..peaks.add(store.box<Peak>().getAll().single);
      final unresolved = GpxTrack(
        gpxTrackId: 9,
        contentHash: 'unknown',
        trackName: 'Unknown',
        trackDateStatus: 3,
        trackDateDerivationVersion: 1,
        trackDateFailureReason: 'missing_time',
        startDateTime: DateTime.utc(2027),
      )..peaks.add(store.box<Peak>().getAll().single);
      store.box<GpxTrack>().putMany([resolved, skipped, unresolved]);
      store.box<PeaksBagged>().putMany([
        PeaksBagged(
          baggedId: 20,
          gpxId: 7,
          peakId: 10,
          date: DateTime.utc(2027),
        ),
        PeaksBagged(
          baggedId: 21,
          gpxId: 8,
          peakId: 10,
          date: DateTime.utc(2000, 12, 31, 13),
        ),
      ]);
      final repository = PeaksBaggedRepository(store);
      await repository.syncFromTracks(store.box<GpxTrack>().getAll());
      final rows = repository.getAll()
        ..sort((a, b) => a.gpxId.compareTo(b.gpxId));
      expect(rows.map((row) => row.baggedId), [20, 21, 22]);
      expect(rows.map((row) => row.date), [
        DateTime.utc(2026, 12, 31),
        DateTime.utc(2000, 12, 31, 13),
        null,
      ]);
      expect(store.box<GpxTrack>().get(8)!.trackDate, DateTime.utc(2001));
      await repository.syncFromTracks(store.box<GpxTrack>().getAll());
      expect(repository.getAll().map((row) => row.baggedId), [20, 21, 22]);
    },
  );

  test('linked-date failure rolls back new and replacement Track writes', () {
    final boundary = ObjectBoxTrackDerivedDataPersistence(
      store,
      beforeBaggedWriteForTest: () => throw StateError('linked write failed'),
    );
    final track = resolvedTrack()..gpxTrackId = 0;
    expect(() => boundary.importTrackAndSync(track), throwsStateError);
    expect(track.gpxTrackId, 0);
    expect(store.box<GpxTrack>().count(), 0);
    expect(store.box<PeaksBagged>().count(), 0);
    final original = resolvedTrack();
    ObjectBoxTrackDerivedDataPersistence(store).importTrackAndSync(original);
    final beforeTrack = store.box<GpxTrack>().get(7)!.toMap();
    final beforeRow = store.box<PeaksBagged>().getAll().single;
    final replacement = resolvedTrack()..trackDate = DateTime.utc(2027, 1, 1);
    expect(
      () => boundary.replaceTrackAndSync(
        existing: store.box<GpxTrack>().get(7)!,
        replacement: replacement,
      ),
      throwsStateError,
    );
    expect(store.box<GpxTrack>().get(7)!.toMap(), beforeTrack);
    final after = store.box<PeaksBagged>().getAll().single;
    expect((after.baggedId, after.date), (beforeRow.baggedId, beforeRow.date));
    expect(store.box<GpxTrack>().get(7)!.peaks.single.osmId, 10);
  });
}
