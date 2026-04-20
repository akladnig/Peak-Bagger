import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';

void main() {
  group('PeaksBaggedRepository', () {
    test(
      'deriveRows keeps cross-track duplicates and collapses in-track duplicates',
      () {
        final trackOne =
            GpxTrack(
                gpxTrackId: 7,
                contentHash: 'a',
                trackName: 'Track 1',
                trackDate: DateTime.utc(2024, 1, 15),
              )
              ..peaks.addAll([
                Peak(osmId: 22, name: 'Peak B', latitude: -42, longitude: 146),
                Peak(osmId: 11, name: 'Peak A', latitude: -42, longitude: 146),
                Peak(osmId: 11, name: 'Peak A2', latitude: -42, longitude: 146),
              ]);

        final trackTwo =
            GpxTrack(
                gpxTrackId: 8,
                contentHash: 'b',
                trackName: 'Track 2',
                trackDate: DateTime.utc(2024, 1, 16),
              )
              ..peaks.add(
                Peak(osmId: 11, name: 'Peak A', latitude: -42, longitude: 146),
              );

        final rows = PeaksBaggedRepository.deriveRows([trackTwo, trackOne]);

        expect(
          rows
              .map((row) => (row.baggedId, row.gpxId, row.peakId, row.date))
              .toList(),
          [
            (1, 7, 11, DateTime.utc(2024, 1, 15)),
            (2, 7, 22, DateTime.utc(2024, 1, 15)),
            (3, 8, 11, DateTime.utc(2024, 1, 16)),
          ],
        );
      },
    );

    test('deriveRows stores null dates and skips invalid ids', () {
      final track =
          GpxTrack(gpxTrackId: 7, contentHash: 'hash', trackName: 'Track')
            ..peaks.addAll([
              Peak(
                osmId: 0,
                name: 'Invalid Peak',
                latitude: -42,
                longitude: 146,
              ),
              Peak(
                osmId: 33,
                name: 'Valid Peak',
                latitude: -42,
                longitude: 146,
              ),
            ]);

      final invalidTrack =
          GpxTrack(gpxTrackId: 0, contentHash: 'bad', trackName: 'Bad Track')
            ..peaks.add(
              Peak(osmId: 44, name: 'Peak', latitude: -42, longitude: 146),
            );

      final rows = PeaksBaggedRepository.deriveRows([track, invalidTrack]);

      expect(rows, hasLength(1));
      expect(rows.single.baggedId, 1);
      expect(rows.single.gpxId, 7);
      expect(rows.single.peakId, 33);
      expect(rows.single.date, isNull);
    });

    test(
      'rebuildFromTracks clears stored rows and restarts baggedId from 1',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('peaks-bagged');
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final store = await openStore(directory: tempDir.path);
        addTearDown(store.close);

        final repository = PeaksBaggedRepository(store);
        final box = store.box<PeaksBagged>();

        box.putMany([
          PeaksBagged(baggedId: 9, peakId: 999, gpxId: 999),
          PeaksBagged(baggedId: 10, peakId: 1000, gpxId: 1000),
        ]);

        final track =
            GpxTrack(
                gpxTrackId: 12,
                contentHash: 'hash',
                trackName: 'Track',
                trackDate: DateTime.utc(2024, 1, 17),
              )
              ..peaks.addAll([
                Peak(osmId: 50, name: 'Peak Z', latitude: -42, longitude: 146),
                Peak(osmId: 40, name: 'Peak Y', latitude: -42, longitude: 146),
              ]);

        await repository.rebuildFromTracks([track]);

        final stored = box.getAll()
          ..sort((a, b) => a.baggedId.compareTo(b.baggedId));

        expect(
          stored.map((row) => (row.baggedId, row.gpxId, row.peakId)).toList(),
          [(1, 12, 40), (2, 12, 50)],
        );
      },
      skip: 'ObjectBox native library unavailable in flutter test environment',
    );
  });
}
