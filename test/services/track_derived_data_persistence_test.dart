import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/track_derived_data_persistence.dart';

void main() {
  test('ObjectBox replacement removes stale peak correlations', () async {
    final directory = await Directory.systemTemp.createTemp(
      'track-derived-data-persistence-test',
    );
    final store = await openStore(directory: directory.path);
    addTearDown(() async {
      store.close();
      await directory.delete(recursive: true);
    });
    final peak = Peak(
      osmId: 10,
      name: 'Stale peak',
      latitude: -42,
      longitude: 146,
    );
    store.box<Peak>().put(peak);
    final refreshedPeak = Peak(
      osmId: 11,
      name: 'Refreshed peak',
      latitude: -42,
      longitude: 146,
    );
    store.box<Peak>().put(refreshedPeak);
    final original = GpxTrack(
      gpxTrackId: 1,
      contentHash: 'track-1',
      trackName: 'Track 1',
    )..peaks.add(peak);
    store.box<GpxTrack>().put(original);
    final stored = store.box<GpxTrack>().get(1)!;
    final replacement = GpxTrack.fromMap(stored.toMap())
      ..peaks.addAll(stored.peaks);
    replacement.peaks.clear();
    replacement.peaks.add(refreshedPeak);

    ObjectBoxTrackDerivedDataPersistence(
      store,
    ).replaceTrackAndSync(existing: stored, replacement: replacement);

    expect(store.box<GpxTrack>().get(1)!.peaks.map((peak) => peak.osmId), [11]);
  });

  group('RepositoryTrackDerivedDataPersistence', () {
    test('updates one track and synchronizes bagged history', () {
      final original = _track(id: 1, peakIds: [10]);
      final unrelated = _track(id: 2, peakIds: [20]);
      final tracks = GpxTrackRepository.test(
        InMemoryGpxTrackStorage([original, unrelated]),
      );
      final bagged = PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 4, gpxId: 1, peakId: 10),
          PeaksBagged(baggedId: 9, gpxId: 2, peakId: 20),
        ]),
      );
      final replacement = _track(id: 1, peakIds: [11]);

      RepositoryTrackDerivedDataPersistence(
        tracks: tracks,
        peaksBagged: bagged,
      ).replaceTrackAndSync(existing: original, replacement: replacement);

      expect(tracks.findById(1)!.peaks.map((peak) => peak.osmId), [11]);
      expect(tracks.findById(2), same(unrelated));
      expect(
        bagged.getAll().map((row) => (row.baggedId, row.gpxId, row.peakId)),
        [(9, 2, 20), (10, 1, 11)],
      );
    });

    for (final failure in TrackDerivedDataPersistenceFailure.values) {
      test('restores exact persisted rows when $failure fails', () {
        final original = _track(id: 1, peakIds: [10]);
        final unrelated = _track(id: 2, peakIds: [20]);
        final tracks = GpxTrackRepository.test(
          InMemoryGpxTrackStorage([original, unrelated]),
        );
        final bagged = PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage([
            PeaksBagged(baggedId: 4, gpxId: 1, peakId: 10),
            PeaksBagged(baggedId: 9, gpxId: 2, peakId: 20),
          ]),
        );
        final priorTrack = _trackSnapshot(original);
        final priorRows = _rowSnapshots(bagged.getAll());

        expect(
          () =>
              RepositoryTrackDerivedDataPersistence(
                tracks: tracks,
                peaksBagged: bagged,
                failureForTest: failure,
              ).replaceTrackAndSync(
                existing: original,
                replacement: _track(id: 1, peakIds: [11]),
              ),
          throwsStateError,
        );

        expect(_trackSnapshot(tracks.findById(1)!), priorTrack);
        expect(_rowSnapshots(bagged.getAll()), priorRows);
      });
    }
  });
}

GpxTrack _track({required int id, required List<int> peakIds}) {
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'track-$id',
    trackName: 'Track $id',
  );
  track.peaks.addAll([
    for (final peakId in peakIds)
      Peak(osmId: peakId, name: 'Peak $peakId', latitude: -42, longitude: 146),
  ]);
  return track;
}

String _trackSnapshot(GpxTrack track) {
  return '${jsonEncode(track.toMap())}|${track.peaks.map((peak) => peak.osmId).join(',')}';
}

List<(int, int, int, DateTime?)> _rowSnapshots(Iterable<PeaksBagged> rows) {
  return [
    for (final row in rows) (row.baggedId, row.gpxId, row.peakId, row.date),
  ];
}
