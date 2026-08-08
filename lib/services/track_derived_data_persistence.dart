import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';

abstract interface class TrackDerivedDataPersistence {
  void replaceTrackAndSync({
    required GpxTrack existing,
    required GpxTrack replacement,
  });
}

/// Commits the selected track and its derived bagged history in one write
/// transaction so ObjectBox rolls both changes back together on failure.
class ObjectBoxTrackDerivedDataPersistence
    implements TrackDerivedDataPersistence {
  ObjectBoxTrackDerivedDataPersistence(this._store);

  final Store _store;

  @override
  void replaceTrackAndSync({
    required GpxTrack existing,
    required GpxTrack replacement,
  }) {
    _store.runInTransaction(TxMode.write, () {
      final tracks = _store.box<GpxTrack>();
      final bagged = _store.box<PeaksBagged>();
      replacement.gpxTrackId = existing.gpxTrackId;
      tracks.put(replacement);

      final plan = PeaksBaggedRepository.buildSyncPlan(
        tracks.getAll(),
        bagged.getAll(),
      );
      if (plan.removeIds.isNotEmpty) {
        bagged.removeMany(plan.removeIds);
      }
      if (plan.rows.isNotEmpty) {
        bagged.putMany(plan.rows);
      }
    });
  }
}

enum TrackDerivedDataPersistenceFailure { beforeTrackWrite, beforeBaggedWrite }

/// Repository-backed implementation for tests and non-ObjectBox test doubles.
/// It restores exact snapshots when an injected write fails.
class RepositoryTrackDerivedDataPersistence
    implements TrackDerivedDataPersistence {
  RepositoryTrackDerivedDataPersistence({
    required this.tracks,
    required this.peaksBagged,
    this.failureForTest,
  });

  final GpxTrackRepository tracks;
  final PeaksBaggedRepository peaksBagged;
  final TrackDerivedDataPersistenceFailure? failureForTest;

  @override
  void replaceTrackAndSync({
    required GpxTrack existing,
    required GpxTrack replacement,
  }) {
    final priorTrack = _copyTrack(existing);
    final priorRows = _copyRows(peaksBagged.getAll());
    try {
      if (failureForTest ==
          TrackDerivedDataPersistenceFailure.beforeTrackWrite) {
        throw StateError('Injected failure before selected-track write');
      }
      tracks.replaceTrack(existing: existing, replacement: replacement);

      final plan = PeaksBaggedRepository.buildSyncPlan(
        tracks.getAllTracks(),
        peaksBagged.getAll(),
      );
      if (failureForTest ==
          TrackDerivedDataPersistenceFailure.beforeBaggedWrite) {
        throw StateError('Injected failure before bagged-history write');
      }
      peaksBagged.applySyncPlan(plan);
    } catch (_) {
      tracks.replaceTrack(existing: replacement, replacement: priorTrack);
      peaksBagged.replaceAllForRecovery(priorRows);
      rethrow;
    }
  }

  static GpxTrack _copyTrack(GpxTrack track) {
    final copy = GpxTrack.fromMap(track.toMap());
    copy.peaks.addAll(track.peaks);
    return copy;
  }

  static List<PeaksBagged> _copyRows(Iterable<PeaksBagged> rows) {
    return [
      for (final row in rows)
        PeaksBagged(
          baggedId: row.baggedId,
          peakId: row.peakId,
          gpxId: row.gpxId,
          date: row.date,
        ),
    ];
  }
}
