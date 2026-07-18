import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';

import '../objectbox.g.dart';

enum PeakDeleteDependencyType { gpxTrack, peakList, peaksBagged }

class PeakDeleteBlocker {
  const PeakDeleteBlocker({
    required this.dependencyType,
    required this.displayName,
  });

  final PeakDeleteDependencyType dependencyType;
  final String displayName;
}

class PeakDeleteGuardResult {
  const PeakDeleteGuardResult({required this.blockers});

  final List<PeakDeleteBlocker> blockers;

  bool get canDelete => blockers.isEmpty;
}

abstract class PeakDeleteGuardSource {
  List<GpxTrack> loadGpxTracks();

  List<PeakList> loadPeakLists();

  List<PeakListItemEntity> loadPeakListItems();

  List<PeaksBagged> loadPeaksBagged();
}

class ObjectBoxPeakDeleteGuardSource implements PeakDeleteGuardSource {
  ObjectBoxPeakDeleteGuardSource(this._store);

  final Store _store;

  @override
  List<GpxTrack> loadGpxTracks() => _store.box<GpxTrack>().getAll();

  @override
  List<PeakList> loadPeakLists() => _store.box<PeakList>().getAll();

  @override
  List<PeakListItemEntity> loadPeakListItems() {
    return _store.box<PeakListItemEntity>().getAll();
  }

  @override
  List<PeaksBagged> loadPeaksBagged() => _store.box<PeaksBagged>().getAll();
}

class PeakDeleteGuard {
  PeakDeleteGuard(this._source);

  final PeakDeleteGuardSource _source;

  PeakDeleteGuardResult check(Peak peak) {
    final blockers = <PeakDeleteBlocker>[];
    blockers.addAll(_gpxTrackBlockers(peak));
    blockers.addAll(_peakListBlockers(peak));
    blockers.addAll(_peaksBaggedBlockers(peak));
    return PeakDeleteGuardResult(blockers: List.unmodifiable(blockers));
  }

  List<PeakDeleteBlocker> _gpxTrackBlockers(Peak peak) {
    final tracks = _source.loadGpxTracks().toList(growable: false)
      ..sort((a, b) {
        final nameCompare = a.trackName.compareTo(b.trackName);
        return nameCompare != 0
            ? nameCompare
            : a.gpxTrackId.compareTo(b.gpxTrackId);
      });

    return tracks
        .where((track) => track.peaks.any((entry) => entry.id == peak.id))
        .map(
          (track) => PeakDeleteBlocker(
            dependencyType: PeakDeleteDependencyType.gpxTrack,
            displayName: track.trackName,
          ),
        )
        .toList(growable: false);
  }

  List<PeakDeleteBlocker> _peakListBlockers(Peak peak) {
    final peakLists = _source.loadPeakLists().toList(growable: false)
      ..sort((a, b) {
        final nameCompare = a.name.compareTo(b.name);
        return nameCompare != 0
            ? nameCompare
            : a.peakListId.compareTo(b.peakListId);
      });
    final peakListItemsByPeakListId = <int, List<PeakListItemEntity>>{};
    for (final item in _source.loadPeakListItems()) {
      final peakListId = _peakListIdForItem(item);
      if (peakListId == 0) {
        continue;
      }
      peakListItemsByPeakListId.putIfAbsent(peakListId, () => []).add(item);
    }

    final blockers = <PeakDeleteBlocker>[];
    for (final peakList in peakLists) {
      if (!peakList.isMembershipReady) {
        continue;
      }

      final relationalItems = peakListItemsByPeakListId[peakList.peakListId];
      final referencesPeak = relationalItems != null
          ? relationalItems.any((item) => item.peak.target?.osmId == peak.osmId)
          : () {
              try {
                return decodePeakListItems(
                  peakList.peakList,
                ).any((item) => item.peakOsmId == peak.osmId);
              } catch (_) {
                return false;
              }
            }();
      if (referencesPeak) {
        blockers.add(
          PeakDeleteBlocker(
            dependencyType: PeakDeleteDependencyType.peakList,
            displayName: peakList.name,
          ),
        );
      }
    }
    return blockers;
  }

  int _peakListIdForItem(PeakListItemEntity item) {
    try {
      return item.peakList.targetId;
    } catch (_) {
      return item.peakList.target?.peakListId ?? 0;
    }
  }

  List<PeakDeleteBlocker> _peaksBaggedBlockers(Peak peak) {
    final rows = _source.loadPeaksBagged().toList(growable: false)
      ..sort((a, b) => a.baggedId.compareTo(b.baggedId));

    return rows
        .where((row) => row.peakId == peak.osmId)
        .map(
          (_) => const PeakDeleteBlocker(
            dependencyType: PeakDeleteDependencyType.peaksBagged,
            displayName: 'bagged record',
          ),
        )
        .toList(growable: false);
  }
}
