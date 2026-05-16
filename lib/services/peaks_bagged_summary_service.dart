import 'package:peak_bagger/models/gpx_track.dart';

class PeaksBaggedSeries {
  const PeaksBaggedSeries({
    required this.totalCountsByTrackId,
    required this.newCountsByTrackId,
  });

  final Map<int, int> totalCountsByTrackId;
  final Map<int, int> newCountsByTrackId;

  double? totalValueOf(GpxTrack track) {
    final count = totalCountsByTrackId[track.gpxTrackId];
    return count == null || count <= 0 ? null : count.toDouble();
  }

  double? newValueOf(GpxTrack track) {
    final count = newCountsByTrackId[track.gpxTrackId];
    return count == null || count <= 0 ? null : count.toDouble();
  }
}

class PeaksBaggedSummaryService {
  const PeaksBaggedSummaryService();

  PeaksBaggedSeries buildSeries(Iterable<GpxTrack> tracks) {
    final totalCountsByTrackId = <int, int>{};
    final orderedOccurrences = <_PeakOccurrence>[];

    for (final track in tracks) {
      if (track.gpxTrackId <= 0 || track.trackDate == null) {
        continue;
      }

      final uniquePeakIds = track.peaks
          .map((peak) => peak.osmId)
          .where((peakId) => peakId > 0)
          .toSet()
          .toList(growable: false)
        ..sort();
      if (uniquePeakIds.isEmpty) {
        continue;
      }

      totalCountsByTrackId[track.gpxTrackId] = uniquePeakIds.length;
      for (final peakId in uniquePeakIds) {
        orderedOccurrences.add(
          _PeakOccurrence(
            trackId: track.gpxTrackId,
            trackDate: track.trackDate!,
            peakId: peakId,
          ),
        );
      }
    }

    orderedOccurrences.sort(_compareOccurrences);

    final newCountsByTrackId = <int, int>{};
    final seenPeakIds = <int>{};
    for (final occurrence in orderedOccurrences) {
      if (!seenPeakIds.add(occurrence.peakId)) {
        continue;
      }
      newCountsByTrackId[occurrence.trackId] =
          (newCountsByTrackId[occurrence.trackId] ?? 0) + 1;
    }

    return PeaksBaggedSeries(
      totalCountsByTrackId: totalCountsByTrackId,
      newCountsByTrackId: newCountsByTrackId,
    );
  }
}

class _PeakOccurrence {
  const _PeakOccurrence({
    required this.trackId,
    required this.trackDate,
    required this.peakId,
  });

  final int trackId;
  final DateTime trackDate;
  final int peakId;
}

int _compareOccurrences(_PeakOccurrence left, _PeakOccurrence right) {
  final dateCompare = left.trackDate.compareTo(right.trackDate);
  if (dateCompare != 0) {
    return dateCompare;
  }

  final trackCompare = left.trackId.compareTo(right.trackId);
  if (trackCompare != 0) {
    return trackCompare;
  }

  return left.peakId.compareTo(right.peakId);
}
