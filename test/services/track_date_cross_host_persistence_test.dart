import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/track_date_derivation_service.dart';
import 'package:peak_bagger/services/track_derived_data_persistence.dart';
import '../harness/track_date_fixtures.dart';

void main() {
  test(
    'closed ObjectBox data keeps identical Track/ascent days across host processes',
    () async {
      expectTrackDateHostOffsets();
      final child = Platform.environment['TRACK_DATE_CROSS_HOST_CHILD'] == '1';
      if (child) {
        final store = await openStore(
          directory: Platform.environment['TRACK_DATE_CROSS_HOST_DB']!,
        );
        try {
          _expectStoredDays(store);
          _writeFixture(store, 3, hobart: false);
        } finally {
          store.close();
        }
        return;
      }
      final directory = await Directory.systemTemp.createTemp(
        'track-date-cross-host',
      );
      addTearDown(() => directory.delete(recursive: true));
      var store = await openStore(directory: directory.path);
      try {
        store.box<Peak>().put(
          Peak(osmId: 10, name: 'Fixture peak', latitude: -42, longitude: 147),
        );
        _writeFixture(store, 1, hobart: true);
        _writeFixture(store, 2, hobart: false);
      } finally {
        store.close();
      }
      final other = Platform.environment['TZ'] == 'UTC'
          ? 'Australia/Hobart'
          : 'UTC';
      final result = await Process.run(
        'flutter',
        [
          'test',
          '--reporter',
          'expanded',
          'test/services/track_date_cross_host_persistence_test.dart',
        ],
        environment: {
          ...Platform.environment,
          'TZ': other,
          'TRACK_DATE_CROSS_HOST_CHILD': '1',
          'TRACK_DATE_CROSS_HOST_DB': directory.path,
        },
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      store = await openStore(directory: directory.path);
      try {
        _expectStoredDays(store);
        expect(
          store.box<GpxTrack>().get(3)!.trackDate,
          DateTime.utc(2026, 12, 31),
        );
        expect(
          store
              .box<PeaksBagged>()
              .getAll()
              .singleWhere((row) => row.gpxId == 3)
              .date,
          DateTime.utc(2026, 12, 31),
        );
      } finally {
        store.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

void _writeFixture(Store store, int id, {required bool hobart}) {
  final gpx = hobart
      ? datedGpx()
      : datedGpx(
          latitude: '34.0522',
          longitude: '-118.2437',
          time: '2027-01-01T07:30:00Z',
        );
  final date = TrackDateDerivationService.offline().derive(gpx);
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'fixture-$id',
    trackName: 'Fixture $id',
    gpxFile: gpx,
    trackDate: date.day,
    trackDateStatus: 1,
    trackDateDerivationVersion: 1,
    trackDateTimezoneId: date.timezoneId,
  )..peaks.add(store.box<Peak>().getAll().single);
  ObjectBoxTrackDerivedDataPersistence(store).importTrackAndSync(track);
}

void _expectStoredDays(Store store) {
  for (final fixture in [
    (1, DateTime.utc(2027, 1, 1), 'Australia/Hobart'),
    (2, DateTime.utc(2026, 12, 31), 'America/Los_Angeles'),
  ]) {
    final track = store.box<GpxTrack>().get(fixture.$1)!;
    expect(track.trackDate, fixture.$2);
    expect(track.trackDateStatus, 1);
    expect(track.trackDateDerivationVersion, 1);
    expect(track.trackDateTimezoneId, fixture.$3);
    expect(track.trackDate!.hour, 0);
    expect(track.peaks.single.osmId, 10);
    final row = store.box<PeaksBagged>().getAll().singleWhere(
      (row) => row.gpxId == fixture.$1,
    );
    expect(row.date, fixture.$2);
    expect(row.baggedId, fixture.$1);
  }
}
