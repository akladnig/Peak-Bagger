import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:peak_bagger/models/tasmap50k.dart';

class TasmapCsvImportResult {
  const TasmapCsvImportResult({
    required this.maps,
    required this.importedCount,
    required this.skippedCount,
    this.warning,
    this.logEntries = const [],
  });

  final List<Tasmap50k> maps;
  final int importedCount;
  final int skippedCount;
  final String? warning;
  final List<String> logEntries;
}

class TasmapCsvRowParseResult {
  const TasmapCsvRowParseResult({this.map, this.error});

  final Tasmap50k? map;
  final String? error;

  bool get isValid => map != null;
}

class CsvImporter {
  static Future<TasmapCsvImportResult> importFromCsv(String csvPath) async {
    final contents = await rootBundle.loadString(csvPath);

    final rows = const CsvToListConverter().convert(contents);
    if (rows.isEmpty) {
      return const TasmapCsvImportResult(
        maps: [],
        importedCount: 0,
        skippedCount: 0,
      );
    }

    final headers = rows.first.map((h) => h.toString().trim()).toList();
    final maps = <Tasmap50k>[];
    final logEntries = <String>[];
    var skippedCount = 0;

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final result = parseRow(headers, row, rowNumber: i + 1);
      if (result.map != null) {
        maps.add(result.map!);
      } else if (result.error != null) {
        skippedCount += 1;
        logEntries.add(result.error!);
      }
    }

    return TasmapCsvImportResult(
      maps: maps,
      importedCount: maps.length,
      skippedCount: skippedCount,
      warning: skippedCount > 0
          ? 'Some Tasmap rows need manual review. See import.log.'
          : null,
      logEntries: logEntries,
    );
  }

  static TasmapCsvRowParseResult parseRow(
    List<String> headers,
    List<dynamic> row, {
    int rowNumber = 0,
  }) {
    final data = <String, dynamic>{};
    for (var i = 0; i < headers.length; i++) {
      data[headers[i]] = i < row.length ? row[i] : '';
    }

    final series = data['Series']?.toString().trim() ?? '';
    final name = data['Name']?.toString().trim() ?? '';
    if (series.isEmpty || name.isEmpty) {
      return TasmapCsvRowParseResult(
        error: _describeRowIssue(rowNumber, 'missing series or name'),
      );
    }

    final points = <String>[];
    var seenBlank = false;

    for (var i = 1; i <= 8; i++) {
      final normalized = normalizePointValue(data['p$i']);
      if (normalized == null) {
        seenBlank = true;
        continue;
      }

      if (seenBlank) {
        return TasmapCsvRowParseResult(
          error: _describeRowIssue(
            rowNumber,
            'non-sequential Tasmap points in p$i',
          ),
        );
      }

      points.add(normalized);
    }

    if (!const {4, 6, 8}.contains(points.length)) {
      return TasmapCsvRowParseResult(
        error: _describeRowIssue(
          rowNumber,
          'expected 4, 6, or 8 points but found ${points.length}',
        ),
      );
    }

    return TasmapCsvRowParseResult(
      map: Tasmap50k(
        series: series,
        name: name,
        parentSeries: data['Parent']?.toString().trim() ?? '',
        mgrs100kIds: data['MGRS']?.toString().trim() ?? '',
        eastingMin:
            int.tryParse(data['eastingMin']?.toString().trim() ?? '') ?? 0,
        eastingMax:
            int.tryParse(data['eastingMax']?.toString().trim() ?? '') ?? 0,
        northingMin:
            int.tryParse(data['northingMin']?.toString().trim() ?? '') ?? 0,
        northingMax:
            int.tryParse(data['northingMax']?.toString().trim() ?? '') ?? 0,
        mgrsMid: data['mgrsMid']?.toString().trim() ?? '',
        eastingMid:
            int.tryParse(data['eastingMid']?.toString().trim() ?? '') ?? 0,
        northingMid:
            int.tryParse(data['northingMid']?.toString().trim() ?? '') ?? 0,
        p1: points.isNotEmpty ? points[0] : '',
        p2: points.length > 1 ? points[1] : '',
        p3: points.length > 2 ? points[2] : '',
        p4: points.length > 3 ? points[3] : '',
        p5: points.length > 4 ? points[4] : '',
        p6: points.length > 5 ? points[5] : '',
        p7: points.length > 6 ? points[6] : '',
        p8: points.length > 7 ? points[7] : '',
      ),
    );
  }

  static String? normalizePointValue(Object? raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final normalized = text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (normalized.length != 12) {
      return null;
    }

    return normalized;
  }

  static String _describeRowIssue(int rowNumber, String reason) {
    final prefix = rowNumber > 0 ? 'Row $rowNumber' : 'Tasmap row';
    return '$prefix: $reason';
  }
}
