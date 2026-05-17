import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak_list.dart';

class PeakListSummaryRow {
  const PeakListSummaryRow({
    required this.peakList,
    required this.totalPeaks,
    required this.climbed,
    required this.unclimbed,
    required this.percentageValue,
  });

  final PeakList peakList;
  final int totalPeaks;
  final int climbed;
  final int unclimbed;
  final double percentageValue;

  String get percentageLabel => '${(percentageValue * 100).round()}%';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeakListSummaryRow &&
          runtimeType == other.runtimeType &&
          peakList.peakListId == other.peakList.peakListId &&
          peakList.name == other.peakList.name &&
          totalPeaks == other.totalPeaks &&
          climbed == other.climbed &&
          unclimbed == other.unclimbed &&
          percentageValue == other.percentageValue;

  @override
  int get hashCode => Object.hash(
    peakList.peakListId,
    peakList.name,
    totalPeaks,
    climbed,
    unclimbed,
    percentageValue,
  );
}

class PeakListSummaryService {
  const PeakListSummaryService();

  List<PeakListSummaryRow> buildRows({
    required Iterable<PeakList> peakLists,
    required Iterable<GpxTrack> tracks,
    int maxRows = 5,
  }) {
    if (maxRows <= 0) {
      return const [];
    }

    final climbedPeakIds = _climbedPeakIds(tracks);
    final rows = <PeakListSummaryRow>[];

    for (final peakList in peakLists) {
      PeakListSummaryRow? row;
      try {
        final items = decodePeakListItems(peakList.peakList);
        final uniquePeakIds = <int>{};
        for (final item in items) {
          if (item.peakOsmId > 0) {
            uniquePeakIds.add(item.peakOsmId);
          }
        }

        final totalPeaks = uniquePeakIds.length;
        final climbed = uniquePeakIds.where(climbedPeakIds.contains).length;
        row = PeakListSummaryRow(
          peakList: peakList,
          totalPeaks: totalPeaks,
          climbed: climbed,
          unclimbed: totalPeaks - climbed,
          percentageValue: totalPeaks == 0 ? 0 : climbed / totalPeaks,
        );
      } catch (_) {
        row = null;
      }

      if (row != null) {
        rows.add(row);
      }
    }

    rows.sort(_compareRows);
    if (rows.length <= maxRows) {
      return List<PeakListSummaryRow>.unmodifiable(rows);
    }

    return List<PeakListSummaryRow>.unmodifiable(rows.sublist(0, maxRows));
  }

  Set<int> _climbedPeakIds(Iterable<GpxTrack> tracks) {
    final climbedPeakIds = <int>{};

    for (final track in tracks) {
      for (final peak in track.peaks) {
        if (peak.osmId > 0) {
          climbedPeakIds.add(peak.osmId);
        }
      }
    }

    return climbedPeakIds;
  }

  int _compareRows(PeakListSummaryRow left, PeakListSummaryRow right) {
    final percentageCompare = right.percentageValue.compareTo(left.percentageValue);
    if (percentageCompare != 0) {
      return percentageCompare;
    }

    final nameCompare = left.peakList.name.compareTo(right.peakList.name);
    if (nameCompare != 0) {
      return nameCompare;
    }

    return left.peakList.peakListId.compareTo(right.peakList.peakListId);
  }
}
