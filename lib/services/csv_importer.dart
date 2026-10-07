import 'dart:io';

import 'package:csv/csv.dart';
import 'package:peak_bagger/models/tasmap50k.dart';

class TasmapCsvImportResult {
  const TasmapCsvImportResult({
    required this.maps,
    required this.importedCount,
    required this.skippedCount,
    this.warning,
    this.logEntries = const [],
    this.changed = false,
    this.selectionRetargets = const {},
  });

  final List<Tasmap50k> maps;
  final int importedCount;
  final int skippedCount;
  final String? warning;
  final List<String> logEntries;
  final bool changed;
  final Map<int, int> selectionRetargets;
}

class TasmapCsvRowParseResult {
  const TasmapCsvRowParseResult({this.map, this.error});

  final Tasmap50k? map;
  final String? error;

  bool get isValid => map != null;
}

/// Strictly parses the Mapping-store TasMap catalog before any database write.
class CsvImporter {
  static const _requiredHeaders = <String>{
    'Series',
    'Name',
    'Parent',
    'MGRS',
    'eastingMin',
    'eastingMax',
    'northingMin',
    'northingMax',
    'mgrsMid',
    'eastingMid',
    'northingMid',
    'p1',
    'p2',
    'p3',
    'p4',
    'p5',
    'p6',
    'p7',
    'p8',
    'p9',
    'p10',
    'p11',
    'p12',
  };

  static Future<TasmapCsvImportResult> importFromCsv(String csvPath) async {
    final contents = await File(csvPath).readAsString();
    return importFromContents(contents);
  }

  static TasmapCsvImportResult importFromContents(String contents) {
    final rows = _parseRows(contents);
    if (rows.isEmpty) {
      throw const FormatException('TasMap CSV is empty.');
    }

    final headers = _validateHeaders(rows.first);
    final maps = <Tasmap50k>[];
    final identities = <String>{};
    for (var index = 1; index < rows.length; index++) {
      final row = rows[index];
      if (_isBlankRow(row)) {
        continue;
      }
      if (row.length > headers.length) {
        throw FormatException('Row ${index + 1}: too many columns.');
      }
      final result = parseRow(headers, row, rowNumber: index + 1);
      if (!result.isValid) {
        throw FormatException(result.error!);
      }
      final map = result.map!;
      if (!identities.add(normalizedIdentity(map.series, map.name))) {
        throw FormatException('Row ${index + 1}: duplicate TasMap identity.');
      }
      maps.add(map);
    }
    if (maps.isEmpty) {
      throw const FormatException('TasMap CSV contains no data rows.');
    }

    return TasmapCsvImportResult(
      maps: List.unmodifiable(maps),
      importedCount: maps.length,
      skippedCount: 0,
    );
  }

  static TasmapCsvRowParseResult parseRow(
    List<String> headers,
    List<dynamic> row, {
    int rowNumber = 0,
  }) {
    final data = <String, String>{
      for (var index = 0; index < headers.length; index++)
        headers[index]: index < row.length ? row[index].toString().trim() : '',
    };
    for (final header in const ['Series', 'Name', 'MGRS', 'mgrsMid']) {
      if (data[header]!.isEmpty) {
        return _invalid(rowNumber, 'missing $header');
      }
    }

    final integers = <String, int>{};
    for (final header in const [
      'eastingMin',
      'eastingMax',
      'northingMin',
      'northingMax',
      'eastingMid',
      'northingMid',
    ]) {
      final value = int.tryParse(data[header]!);
      if (value == null) {
        return _invalid(rowNumber, 'invalid integer $header');
      }
      integers[header] = value;
    }

    final points = <String>[];
    var sawBlank = false;
    for (var index = 1; index <= 12; index++) {
      final rawPoint = data['p$index'] ?? '';
      if (rawPoint.isEmpty) {
        sawBlank = true;
        continue;
      }
      final point = normalizePointValue(rawPoint);
      if (point == null) {
        return _invalid(rowNumber, 'invalid point p$index');
      }
      if (sawBlank) {
        return _invalid(rowNumber, 'non-contiguous TasMap points at p$index');
      }
      points.add(point);
    }
    for (var index = 0; index < headers.length; index++) {
      final match = RegExp(r'^p(\d+)$').firstMatch(headers[index]);
      final pointNumber = int.tryParse(match?.group(1) ?? '');
      if (pointNumber != null &&
          pointNumber > 12 &&
          normalizePointValue(index < row.length ? row[index] : null) != null) {
        return _invalid(rowNumber, 'unexpected populated point p$pointNumber');
      }
    }
    if (!const {4, 6, 8, 10, 12}.contains(points.length)) {
      return _invalid(
        rowNumber,
        'expected 4, 6, 8, 10, or 12 points but found ${points.length}',
      );
    }

    return TasmapCsvRowParseResult(
      map: Tasmap50k(
        series: data['Series']!,
        name: data['Name']!,
        parentSeries: data['Parent']!,
        mgrs100kIds: data['MGRS']!,
        eastingMin: integers['eastingMin']!,
        eastingMax: integers['eastingMax']!,
        northingMin: integers['northingMin']!,
        northingMax: integers['northingMax']!,
        mgrsMid: data['mgrsMid']!,
        eastingMid: integers['eastingMid']!,
        northingMid: integers['northingMid']!,
        p1: points[0],
        p2: points[1],
        p3: points[2],
        p4: points[3],
        p5: points.length > 4 ? points[4] : '',
        p6: points.length > 5 ? points[5] : '',
        p7: points.length > 6 ? points[6] : '',
        p8: points.length > 7 ? points[7] : '',
        p9: points.length > 8 ? points[8] : '',
        p10: points.length > 9 ? points[9] : '',
        p11: points.length > 10 ? points[10] : '',
        p12: points.length > 11 ? points[11] : '',
      ),
    );
  }

  static String normalizedIdentity(String series, String name) =>
      '${series.trim().toLowerCase()}\u0000${name.trim().toLowerCase()}';

  static String? normalizePointValue(Object? raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    final normalized = text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    return RegExp(r'^[A-Z]{2}\d{10}$').hasMatch(normalized) ? normalized : null;
  }

  static List<List<dynamic>> _parseRows(String contents) {
    try {
      _validateRfc4180(contents);
      return const CsvDecoder(
        fieldDelimiter: ',',
        skipEmptyLines: false,
      ).convert(contents);
    } on Object catch (error) {
      throw FormatException('TasMap CSV is not valid RFC 4180 CSV: $error');
    }
  }

  static List<String> _validateHeaders(List<dynamic> rawHeaders) {
    final headers = rawHeaders
        .map((header) => header.toString().trim())
        .toList();
    while (headers.isNotEmpty && headers.last.isEmpty) {
      headers.removeLast();
    }
    if (headers.isEmpty) {
      throw const FormatException('TasMap CSV has no headers.');
    }
    final seen = <String>{};
    for (final header in headers) {
      if (header.isEmpty ||
          !_requiredHeaders.contains(header) ||
          !seen.add(header)) {
        throw FormatException('Invalid TasMap CSV header: "$header".');
      }
    }
    if (seen.length != _requiredHeaders.length) {
      final missing = _requiredHeaders.difference(seen).toList()..sort();
      throw FormatException(
        'Missing TasMap CSV headers: ${missing.join(', ')}.',
      );
    }
    return List.unmodifiable(headers);
  }

  static bool _isBlankRow(List<dynamic> row) =>
      row.every((value) => value.toString().trim().isEmpty);

  static void _validateRfc4180(String contents) {
    var inQuotes = false;
    var atFieldStart = true;
    for (var index = 0; index < contents.length; index++) {
      final character = contents[index];
      if (inQuotes) {
        if (character != '"') {
          continue;
        }
        if (index + 1 < contents.length && contents[index + 1] == '"') {
          index++;
          continue;
        }
        inQuotes = false;
        if (index + 1 < contents.length &&
            !const {',', '\r', '\n'}.contains(contents[index + 1])) {
          throw const FormatException('Invalid quote in TasMap CSV.');
        }
        atFieldStart = false;
        continue;
      }
      if (character == '"') {
        if (!atFieldStart) {
          throw const FormatException('Invalid quote in TasMap CSV.');
        }
        inQuotes = true;
        continue;
      }
      atFieldStart = character == ',' || character == '\r' || character == '\n';
    }
    if (inQuotes) {
      throw const FormatException('Unterminated quote in TasMap CSV.');
    }
  }

  static TasmapCsvRowParseResult _invalid(int rowNumber, String reason) {
    final prefix = rowNumber > 0 ? 'Row $rowNumber' : 'TasMap row';
    return TasmapCsvRowParseResult(error: '$prefix: $reason');
  }
}
