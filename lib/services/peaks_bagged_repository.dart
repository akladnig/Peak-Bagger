import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';

import '../objectbox.g.dart';

class PeaksBaggedRepository {
  PeaksBaggedRepository(Store store)
    : _store = store,
      _box = store.box<PeaksBagged>();

  final Store _store;
  final Box<PeaksBagged> _box;

  List<PeaksBagged> getAll() {
    return _box.getAll();
  }

  Future<void> rebuildFromTracks(
    Iterable<GpxTrack> tracks, {
    void Function()? beforePutManyForTest,
  }) async {
    final rows = deriveRows(tracks);
    _store.runInTransaction(TxMode.write, () {
      _box.removeAll();
      beforePutManyForTest?.call();
      if (rows.isNotEmpty) {
        _box.putMany(rows);
      }
    });
  }

  Future<void> syncFromTracks(
    Iterable<GpxTrack> tracks, {
    void Function()? beforeWriteForTest,
  }) async {
    final plan = buildSyncPlan(tracks, _box.getAll());

    _store.runInTransaction(TxMode.write, () {
      if (plan.removeIds.isNotEmpty) {
        _box.removeMany(plan.removeIds);
      }
      beforeWriteForTest?.call();
      if (plan.rows.isNotEmpty) {
        _box.putMany(plan.rows);
      }
    });
  }

  static ({List<PeaksBagged> rows, List<int> removeIds}) buildSyncPlan(
    Iterable<GpxTrack> tracks,
    Iterable<PeaksBagged> existingRows,
  ) {
    final desiredRows = deriveRows(tracks);
    final sortedExistingRows = existingRows.toList(growable: false)
      ..sort((a, b) => a.baggedId.compareTo(b.baggedId));

    final existingByKey = <(int, int), PeaksBagged>{};
    final duplicateIds = <int>[];
    var nextBaggedId = 1;

    for (final row in sortedExistingRows) {
      if (row.baggedId >= nextBaggedId) {
        nextBaggedId = row.baggedId + 1;
      }
      final key = (row.gpxId, row.peakId);
      if (existingByKey.containsKey(key)) {
        duplicateIds.add(row.baggedId);
        continue;
      }
      existingByKey[key] = row;
    }

    final syncedRows = <PeaksBagged>[];
    for (final desiredRow in desiredRows) {
      final key = (desiredRow.gpxId, desiredRow.peakId);
      final existingRow = existingByKey.remove(key);
      if (existingRow != null) {
        syncedRows.add(
          PeaksBagged(
            baggedId: existingRow.baggedId,
            peakId: desiredRow.peakId,
            gpxId: desiredRow.gpxId,
            date: desiredRow.date,
          ),
        );
        continue;
      }

      syncedRows.add(
        PeaksBagged(
          baggedId: nextBaggedId++,
          peakId: desiredRow.peakId,
          gpxId: desiredRow.gpxId,
          date: desiredRow.date,
        ),
      );
    }

    return (
      rows: syncedRows,
      removeIds: [
        ...duplicateIds,
        ...existingByKey.values.map((row) => row.baggedId),
      ],
    );
  }

  static List<PeaksBagged> deriveRows(Iterable<GpxTrack> tracks) {
    final sortedTracks =
        tracks.where((track) => track.gpxTrackId > 0).toList(growable: false)
          ..sort((a, b) => a.gpxTrackId.compareTo(b.gpxTrackId));

    final rows = <PeaksBagged>[];
    var nextBaggedId = 1;
    for (final track in sortedTracks) {
      final peakIds =
          track.peaks
              .map((peak) => peak.osmId)
              .where((peakId) => peakId > 0)
              .toSet()
              .toList(growable: false)
            ..sort();

      for (final peakId in peakIds) {
        rows.add(
          PeaksBagged(
            baggedId: nextBaggedId++,
            peakId: peakId,
            gpxId: track.gpxTrackId,
            date: track.trackDate,
          ),
        );
      }
    }
    return rows;
  }
}
