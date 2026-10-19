import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/gpx_track.dart';
import '../models/peaks_bagged.dart';
import '../models/track_date_migration_metadata.dart';
import '../objectbox.g.dart';
import 'track_date_derivation_service.dart';

class TrackDateMigrationSnapshot {
  TrackDateMigrationSnapshot({required this.tracks, required this.ascents})
    : fingerprint = _fingerprint(tracks, ascents);

  final List<GpxTrack> tracks;
  final List<PeaksBagged> ascents;
  final String fingerprint;

  // Include all fields and relationships, not only the GPX: no prepared result
  // may erase a concurrent import, edit, deletion, or ascent synchronization.
  static String _fingerprint(List<GpxTrack> tracks, List<PeaksBagged> ascents) {
    final sortedTracks = [...tracks]
      ..sort((a, b) => a.gpxTrackId.compareTo(b.gpxTrackId));
    final sortedAscents = [...ascents]
      ..sort((a, b) => a.baggedId.compareTo(b.baggedId));
    return _digest([
      for (final track in sortedTracks)
        _digest({
          ...track.toMap(),
          'peaks': track.peaks.map((peak) => peak.osmId).toList()..sort(),
        }),
      for (final row in sortedAscents)
        [row.baggedId, row.gpxId, row.peakId, row.date?.toIso8601String()],
    ]);
  }

  static String _digest(Object value) =>
      sha256.convert(utf8.encode(jsonEncode(value))).toString();
}

class TrackDateMigrationSkip {
  const TrackDateMigrationSkip({
    required this.trackId,
    required this.trackName,
    required this.reason,
  });

  final int trackId;
  final String trackName;
  final String reason;

  String get message => TrackDateFailure.messageFor(reason).replaceAll(
    'Retry the import.',
    'Check the original GPX and offline timezone data.',
  );

  Map<String, Object> toMap() => {
    'trackId': trackId,
    'trackName': trackName,
    'reason': reason,
  };

  static List<TrackDateMigrationSkip> decode(String json) => [
    for (final row in jsonDecode(json) as List)
      TrackDateMigrationSkip(
        trackId: row['trackId'] as int,
        trackName: row['trackName'] as String,
        reason: row['reason'] as String,
      ),
  ];
}

abstract interface class TrackDateMigrationRepository {
  TrackDateMigrationMetadata? readCompletion();
  TrackDateMigrationSnapshot readSnapshot();
  TrackDateMigrationMetadata commit({
    required TrackDateMigrationSnapshot snapshot,
    required List<TrackDateDerivation> outcomes,
    required DateTime completedAt,
  });
}

enum TrackDateMigrationWriteStage { track, linkedDate, metadata, completion }

class TrackDateMigrationInputsChanged implements Exception {
  @override
  String toString() =>
      'Track or ascent data changed during date recalculation. Retry.';
}

/// Used only behind the app startup barrier, before Track/ascent writers start.
/// Revalidation in the same final write transaction also protects against
/// unexpected external writers. Preparation never holds an ObjectBox transaction.
class ObjectBoxTrackDateMigrationRepository
    implements TrackDateMigrationRepository {
  ObjectBoxTrackDateMigrationRepository(this._store, {this.beforeWriteForTest});

  final Store _store;
  final void Function(TrackDateMigrationWriteStage stage)? beforeWriteForTest;

  @override
  TrackDateMigrationMetadata? readCompletion() => _store
      .box<TrackDateMigrationMetadata>()
      .get(TrackDateMigrationMetadata.metadataId);

  @override
  TrackDateMigrationSnapshot readSnapshot() => _store.runInTransaction(
    TxMode.read,
    () => TrackDateMigrationSnapshot(
      tracks: _store.box<GpxTrack>().getAll(),
      ascents: _store.box<PeaksBagged>().getAll(),
    ),
  );

  @override
  TrackDateMigrationMetadata commit({
    required TrackDateMigrationSnapshot snapshot,
    required List<TrackDateDerivation> outcomes,
    required DateTime completedAt,
  }) => _store.runInTransaction(TxMode.write, () {
    if (outcomes.length != snapshot.tracks.length) {
      throw ArgumentError('Every Track needs a prepared date outcome');
    }
    final existing = readCompletion();
    if (isCurrent(existing)) return existing!;
    final current = readSnapshot();
    if (current.fingerprint != snapshot.fingerprint) {
      throw TrackDateMigrationInputsChanged();
    }
    var updated = 0;
    var unchanged = 0;
    final skipped = <TrackDateMigrationSkip>[];
    final ascentsByTrack = <int, List<PeaksBagged>>{};
    for (final row in current.ascents) {
      ascentsByTrack.putIfAbsent(row.gpxId, () => []).add(row);
    }
    final currentById = {
      for (final track in current.tracks) track.gpxTrackId: track,
    };
    for (var i = 0; i < snapshot.tracks.length; i++) {
      final track = currentById[snapshot.tracks[i].gpxTrackId]!;
      final outcome = outcomes[i];
      final linked = ascentsByTrack[track.gpxTrackId] ?? const <PeaksBagged>[];
      if (outcome.failure case final failure?) {
        skipped.add(
          TrackDateMigrationSkip(
            trackId: track.gpxTrackId,
            trackName: track.trackName,
            reason: failure.code,
          ),
        );
        // Recognized new-import unknown dates remain unknown, including on a
        // database created before this database-wide marker was introduced.
        if (track.trackDateStatus != TrackDateStatus.unresolvedImport) {
          track.trackDateStatus = TrackDateStatus.legacySkipped;
        }
        track.trackDateFailureReason = failure.code;
        track.trackDateTimezoneId = null;
      } else {
        final day = outcome.day!;
        if (track.trackDate == day && linked.every((row) => row.date == day)) {
          unchanged++;
        } else {
          updated++;
        }
        track.trackDate = day;
        track.trackDateStatus = TrackDateStatus.resolved;
        track.trackDateTimezoneId = outcome.timezoneId;
        track.trackDateFailureReason = null;
        for (final row in linked) {
          row.date = day;
          beforeWriteForTest?.call(TrackDateMigrationWriteStage.linkedDate);
          _store.box<PeaksBagged>().put(row);
        }
      }
      track.trackDateDerivationVersion = TrackDateDerivationService.version;
      beforeWriteForTest?.call(TrackDateMigrationWriteStage.track);
      _store.box<GpxTrack>().put(track);
    }
    final metadata = TrackDateMigrationMetadata(
      completedVersion: TrackDateDerivationService.version,
      completedAt: completedAt.toUtc(),
      geographicDataVersion: TrackDateDerivationService.geographicDataVersion,
      ianaDataVersion: TrackDateDerivationService.ianaDataVersion,
      updatedCount: updated,
      unchangedCount: unchanged,
      skippedCount: skipped.length,
      skippedRecordsJson: jsonEncode(
        skipped.map((skip) => skip.toMap()).toList(),
      ),
    );
    beforeWriteForTest?.call(TrackDateMigrationWriteStage.metadata);
    _store.box<TrackDateMigrationMetadata>().put(metadata);
    beforeWriteForTest?.call(TrackDateMigrationWriteStage.completion);
    return metadata;
  });

  static bool isCurrent(TrackDateMigrationMetadata? metadata) =>
      metadata?.key == TrackDateMigrationMetadata.migrationKey &&
      metadata!.completedVersion >= TrackDateDerivationService.version;
}
