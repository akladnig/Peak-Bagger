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
