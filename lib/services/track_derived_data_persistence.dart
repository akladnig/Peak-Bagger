import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';

abstract interface class TrackDerivedDataPersistence {
  void importTrackAndSync(GpxTrack track);

  void replaceTrackAndSync({
    required GpxTrack existing,
    required GpxTrack replacement,
  });
}

/// Commits the selected track and its derived bagged history in one write
/// transaction so ObjectBox rolls both changes back together on failure.
class ObjectBoxTrackDerivedDataPersistence
    implements TrackDerivedDataPersistence {
  ObjectBoxTrackDerivedDataPersistence(
    this._store, {
    this.beforeBaggedWriteForTest,
  });

  final Store _store;
  final void Function()? beforeBaggedWriteForTest;

  @override
  void importTrackAndSync(GpxTrack track) {
    final originalId = track.gpxTrackId;
    try {
      _store.runInTransaction(TxMode.write, () {
        final tracks = _store.box<GpxTrack>();
        final previous = originalId == 0 ? null : tracks.get(originalId);
        if (previous != null) {
          previous.peaks.clear();
          tracks.put(previous);
        }
        tracks.put(track);
        _sync();
      });
    } catch (_) {
      track.gpxTrackId = originalId;
      rethrow;
    }
  }

  void _sync() {
    final bagged = _store.box<PeaksBagged>();
    final plan = PeaksBaggedRepository.buildSyncPlan(
      _store.box<GpxTrack>().getAll(),
      bagged.getAll(),
    );
    if (plan.removeIds.isNotEmpty) bagged.removeMany(plan.removeIds);
    beforeBaggedWriteForTest?.call();
    if (plan.rows.isNotEmpty) bagged.putMany(plan.rows);
  }

  @override
  void replaceTrackAndSync({
    required GpxTrack existing,
    required GpxTrack replacement,
  }) {
    _store.runInTransaction(TxMode.write, () {
      final tracks = _store.box<GpxTrack>();
      replacement.gpxTrackId = existing.gpxTrackId;
      existing.peaks.clear();
      tracks.put(existing);
      tracks.put(replacement);

      _sync();
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
  void importTrackAndSync(GpxTrack track) {
    final originalId = track.gpxTrackId;
    final prior = tracks.findById(originalId);
    final priorRows = _copyRows(peaksBagged.getAll());
    try {
      tracks.putTrack(track);
      if (failureForTest ==
          TrackDerivedDataPersistenceFailure.beforeBaggedWrite) {
        throw StateError('Injected failure before bagged-history write');
      }
      peaksBagged.applySyncPlan(
        PeaksBaggedRepository.buildSyncPlan(
          tracks.getAllTracks(),
          peaksBagged.getAll(),
        ),
      );
    } catch (_) {
      if (prior != null) {
        tracks.putTrack(prior);
      } else if (track.gpxTrackId != originalId || originalId != 0) {
        tracks.deleteTrack(track.gpxTrackId);
      }
      track.gpxTrackId = originalId;
      peaksBagged.replaceAllForRecovery(priorRows);
      rethrow;
    }
  }

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
