import 'package:peak_bagger/models/gpx_track.dart';

class YearToDateSummary {
  const YearToDateSummary({
    required this.year,
    required this.distance2d,
    required this.ascentMetres,
    required this.walkCount,
    required this.peaksClimbed,
    required this.newPeaksClimbed,
  });

  final int year;
  final double distance2d;
  final double ascentMetres;
  final int walkCount;
  final int peaksClimbed;
  final int newPeaksClimbed;
}

class YearToDateSummaryService {
  const YearToDateSummaryService();

  int initialYear({DateTime? now}) => (now ?? DateTime.now()).toLocal().year;

  int shiftYear({required int year, required bool forward}) =>
      forward ? year + 1 : year - 1;

  YearToDateSummary buildSummary({
    required Iterable<GpxTrack> tracks,
    required int year,
  }) {
    final usableTracks = tracks
        .where((track) => track.trackDate != null)
        .toList(growable: false);
    final yearTracks = usableTracks
        .where((track) => _localYear(track.trackDate!) == year)
        .toList(growable: false);

    return YearToDateSummary(
      year: year,
      distance2d: yearTracks.fold<double>(
        0,
        (sum, track) => sum + track.distance2d,
      ),
      ascentMetres: yearTracks.fold<double>(
        0,
        (sum, track) => sum + (track.ascent ?? 0),
      ),
      walkCount: yearTracks.length,
      peaksClimbed: _countUniquePeaks(yearTracks),
      newPeaksClimbed: _countNewPeaks(usableTracks, year),
    );
  }

  int _countUniquePeaks(Iterable<GpxTrack> tracks) {
    final uniquePeakIds = <int>{};
    for (final track in tracks) {
      uniquePeakIds.addAll(_peakIdsForTrack(track));
    }
    return uniquePeakIds.length;
  }

  int _countNewPeaks(List<GpxTrack> tracks, int year) {
    final occurrences = <_PeakOccurrence>[];
    for (final track in tracks) {
      final trackDate = track.trackDate!.toLocal();
      for (final peakId in _peakIdsForTrack(track)) {
        occurrences.add(
          _PeakOccurrence(
            trackId: track.gpxTrackId,
            trackDate: trackDate,
            peakId: peakId,
          ),
        );
      }
    }

    occurrences.sort(_compareOccurrences);

    final seenPeakIds = <int>{};
    var count = 0;
    for (final occurrence in occurrences) {
      if (!seenPeakIds.add(occurrence.peakId)) {
        continue;
      }

      if (_localYear(occurrence.trackDate) == year) {
        count += 1;
      }
    }

    return count;
  }

  Set<int> _peakIdsForTrack(GpxTrack track) {
    return track.peaks
        .map((peak) => peak.osmId)
        .where((peakId) => peakId > 0)
        .toSet();
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

int _localYear(DateTime date) => date.toLocal().year;
