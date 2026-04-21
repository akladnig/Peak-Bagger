import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';

import '../objectbox.g.dart';

abstract class PeaksBaggedStorage {
  List<PeaksBagged> getAll();

  void replaceAll(
    List<PeaksBagged> rows, {
    void Function()? beforePutManyForTest,
  });

  void sync(
    ({List<PeaksBagged> rows, List<int> removeIds}) plan, {
    void Function()? beforeWriteForTest,
  });
}

class ObjectBoxPeaksBaggedStorage implements PeaksBaggedStorage {
  ObjectBoxPeaksBaggedStorage(this._store) : _box = _store.box<PeaksBagged>();

  final Store _store;
  final Box<PeaksBagged> _box;

  @override
  List<PeaksBagged> getAll() {
    return _box.getAll();
  }

  @override
  void replaceAll(
    List<PeaksBagged> rows, {
    void Function()? beforePutManyForTest,
  }) {
    _store.runInTransaction(TxMode.write, () {
      _box.removeAll();
      beforePutManyForTest?.call();
      if (rows.isNotEmpty) {
        _box.putMany(rows);
      }
    });
  }

  @override
  void sync(
    ({List<PeaksBagged> rows, List<int> removeIds}) plan, {
    void Function()? beforeWriteForTest,
  }) {
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
}

class InMemoryPeaksBaggedStorage implements PeaksBaggedStorage {
  InMemoryPeaksBaggedStorage([List<PeaksBagged> rows = const []])
    : _rows = List<PeaksBagged>.from(rows);

  List<PeaksBagged> _rows;

  @override
  List<PeaksBagged> getAll() {
    return List<PeaksBagged>.unmodifiable(_rows);
  }

  @override
  void replaceAll(
    List<PeaksBagged> rows, {
    void Function()? beforePutManyForTest,
  }) {
    beforePutManyForTest?.call();
    _rows = List<PeaksBagged>.from(rows);
  }

  @override
  void sync(
    ({List<PeaksBagged> rows, List<int> removeIds}) plan, {
    void Function()? beforeWriteForTest,
  }) {
    beforeWriteForTest?.call();
    final removeIds = plan.removeIds.toSet();
    final retainedRows = _rows
        .where((row) => !removeIds.contains(row.baggedId))
        .toList(growable: false);
    _rows = [...retainedRows, ...plan.rows];
  }
}

class PeaksBaggedRepository {
  PeaksBaggedRepository(Store store)
    : _storage = ObjectBoxPeaksBaggedStorage(store);

  PeaksBaggedRepository.test(PeaksBaggedStorage storage) : _storage = storage;

  final PeaksBaggedStorage _storage;

  List<PeaksBagged> getAll() {
    return _storage.getAll();
  }

  Map<int, DateTime?> latestAscentDatesByPeakId() {
    return _computeLatestAscentDatesByPeakId(_storage.getAll());
  }

  Future<void> rebuildFromTracks(
    Iterable<GpxTrack> tracks, {
    void Function()? beforePutManyForTest,
  }) async {
    final rows = deriveRows(tracks);
    _storage.replaceAll(rows, beforePutManyForTest: beforePutManyForTest);
  }

  Future<void> syncFromTracks(
    Iterable<GpxTrack> tracks, {
    void Function()? beforeWriteForTest,
  }) async {
    final plan = buildSyncPlan(tracks, _storage.getAll());
    _storage.sync(plan, beforeWriteForTest: beforeWriteForTest);
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

  static Map<int, DateTime?> _computeLatestAscentDatesByPeakId(
    Iterable<PeaksBagged> rows,
  ) {
    final latestByPeakId = <int, DateTime?>{};

    for (final row in rows) {
      final existing = latestByPeakId[row.peakId];
      final candidate = row.date;
      if (!latestByPeakId.containsKey(row.peakId)) {
        latestByPeakId[row.peakId] = candidate;
        continue;
      }
      if (candidate != null &&
          (existing == null || candidate.isAfter(existing))) {
        latestByPeakId[row.peakId] = candidate;
      }
    }

    return latestByPeakId;
  }
}
