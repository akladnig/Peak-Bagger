import 'package:peak_bagger/core/date_formatters.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';

class MyAscentsDataset {
  const MyAscentsDataset({
    required this.baggedRows,
    required this.peaksByOsmId,
  });

  const MyAscentsDataset.empty()
    : baggedRows = const [],
      peaksByOsmId = const {};

  final List<PeaksBagged> baggedRows;
  final Map<int, Peak> peaksByOsmId;

  bool get isEmpty => baggedRows.isEmpty;
}

class MyAscentsSummary {
  const MyAscentsSummary({required this.sections});

  const MyAscentsSummary.empty() : sections = const [];

  final List<MyAscentsYearSection> sections;

  bool get isEmpty => sections.isEmpty;
}

class MyAscentsYearSection {
  const MyAscentsYearSection({required this.year, required this.rows});

  final int year;
  final List<MyAscentsRow> rows;
}

class MyAscentsRow {
  const MyAscentsRow({
    required this.baggedId,
    required this.peakId,
    required this.peakName,
    required this.elevationText,
    required this.date,
    required this.dateText,
  });

  final int baggedId;
  final int peakId;
  final String peakName;
  final String elevationText;
  final DateTime date;
  final String dateText;

  int get year => date.year;
}

class MyAscentsSummaryService {
  const MyAscentsSummaryService();

  MyAscentsSummary build(
    MyAscentsDataset dataset, {
    required bool ascending,
  }) {
    if (dataset.isEmpty) {
      return const MyAscentsSummary.empty();
    }

    final rows = <MyAscentsRow>[
      for (final baggedRow in dataset.baggedRows)
        if (baggedRow.date != null)
          _buildRow(
            baggedRow: baggedRow,
            peak: dataset.peaksByOsmId[baggedRow.peakId],
          ),
    ];

    if (rows.isEmpty) {
      return const MyAscentsSummary.empty();
    }

    rows.sort((left, right) => _compareRows(left, right, ascending: ascending));

    final sections = <MyAscentsYearSection>[];
    MyAscentsYearSection? currentSection;
    for (final row in rows) {
      final currentYear = currentSection?.year;
      if (currentSection == null || currentYear != row.year) {
        currentSection = MyAscentsYearSection(year: row.year, rows: const []);
        sections.add(currentSection);
      }

      sections[sections.length - 1] = MyAscentsYearSection(
        year: currentSection.year,
        rows: [
          ...currentSection.rows,
          row,
        ],
      );
      currentSection = sections.last;
    }

    return MyAscentsSummary(
      sections: List<MyAscentsYearSection>.unmodifiable(sections),
    );
  }

  MyAscentsRow _buildRow({
    required PeaksBagged baggedRow,
    required Peak? peak,
  }) {
    final date = baggedRow.date!;
    final peakNameText = peak?.name.trim();
    final peakName = peakNameText == null || peakNameText.isEmpty
        ? 'Unknown Peak'
        : peakNameText;
    final elevationText = peak?.elevation == null
        ? 'Unknown'
        : formatElevation(peak!.elevation!);

    return MyAscentsRow(
      baggedId: baggedRow.baggedId,
      peakId: baggedRow.peakId,
      peakName: peakName,
      elevationText: elevationText,
      date: date,
      dateText: formatTrackDate(date),
    );
  }

  int _compareRows(
    MyAscentsRow left,
    MyAscentsRow right, {
    required bool ascending,
  }) {
    final dateCompare = ascending
        ? left.date.compareTo(right.date)
        : right.date.compareTo(left.date);
    if (dateCompare != 0) {
      return dateCompare;
    }

    final nameCompare = left.peakName.compareTo(right.peakName);
    if (nameCompare != 0) {
      return nameCompare;
    }

    final peakCompare = left.peakId.compareTo(right.peakId);
    if (peakCompare != 0) {
      return peakCompare;
    }

    return left.baggedId.compareTo(right.baggedId);
  }
}
