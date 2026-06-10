import 'package:csv/csv.dart';
import 'package:peak_bagger/services/peakbagger_scraper.dart';

class PeakBaggerCsvRow {
  PeakBaggerCsvRow({required this.lineNumber, required this.cells});

  final int lineNumber;
  final List<String> cells;
}

class PeakBaggerCsvDocument {
  PeakBaggerCsvDocument({
    required List<String> headers,
    required List<PeakBaggerCsvRow> rows,
  })  : headers = List<String>.from(headers),
        rows = List<PeakBaggerCsvRow>.from(rows);

  final List<String> headers;
  final List<PeakBaggerCsvRow> rows;

  int? headerIndexOf(String headerName) {
    final target = PeakBaggerCsvImportService._normalizeLookupKey(headerName);
    for (var i = 0; i < headers.length; i++) {
      if (PeakBaggerCsvImportService._normalizeLookupKey(headers[i]) == target) {
        return i;
      }
    }
    return null;
  }

  String? cellValueAt(int rowIndex, String headerName) {
    final headerIndex = headerIndexOf(headerName);
    if (headerIndex == null || rowIndex < 0 || rowIndex >= rows.length) {
      return null;
    }

    final row = rows[rowIndex];
    if (headerIndex >= row.cells.length) {
      return null;
    }

    return row.cells[headerIndex];
  }

  void ensureColumn(String headerName, {String defaultValue = ''}) {
    if (headerIndexOf(headerName) != null) {
      return;
    }

    headers.add(headerName);
    for (final row in rows) {
      row.cells.add(defaultValue);
    }
  }

  void setCellValue(int rowIndex, String headerName, String value) {
    final headerIndex = headerIndexOf(headerName);
    if (headerIndex == null || rowIndex < 0 || rowIndex >= rows.length) {
      return;
    }

    final row = rows[rowIndex];
    while (row.cells.length <= headerIndex) {
      row.cells.add('');
    }
    row.cells[headerIndex] = value;
  }
}

class PeakBaggerCsvImportService {
  static const peakbaggerPidColumn = 'PeakBagger PID';
  static const latitudeColumn = 'Latitude';
  static const longitudeColumn = 'Longitude';
  static const noteColumn = 'note';
  static const osmIdColumn = 'osmId';
  static const safeToCreateColumn = 'safeToCreate';

  PeakBaggerCsvDocument parse(
    String contents, {
    bool includeSyncColumns = true,
  }) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(contents);
    if (rows.isEmpty) {
      final document = PeakBaggerCsvDocument(headers: const [], rows: const []);
      _ensureSyncColumns(document);
      return document;
    }

    final headers = <String>[
      for (final value in rows.first) _normalizeHeader('$value'),
    ];
    final dataRows = <PeakBaggerCsvRow>[];
    for (var index = 1; index < rows.length; index++) {
      final rawRow = rows[index];
      final cells = <String>[
        for (final value in rawRow) _normalizeCellValue('$value'),
      ];
      dataRows.add(PeakBaggerCsvRow(lineNumber: index + 1, cells: cells));
    }

    final document = PeakBaggerCsvDocument(headers: headers, rows: dataRows);
    if (includeSyncColumns) {
      _ensureSyncColumns(document);
    }
    return document;
  }

  String write(PeakBaggerCsvDocument document) {
    final rows = <List<dynamic>>[
      document.headers,
      ...document.rows.map((row) => row.cells),
    ];
    return const ListToCsvConverter(eol: '\n').convert(rows);
  }

  int? peakbaggerPidForRow(PeakBaggerCsvDocument document, int rowIndex) {
    final explicitPid = _parseInt(document.cellValueAt(rowIndex, peakbaggerPidColumn));
    if (explicitPid != null) {
      return explicitPid;
    }

    final url = _firstNonEmpty([
      document.cellValueAt(rowIndex, 'Url'),
      document.cellValueAt(rowIndex, 'URL'),
    ]);
    return parsePeakbaggerPidFromUrl(url);
  }

  String? regionKeyForRow(PeakBaggerCsvDocument document, int rowIndex) {
    return _firstNonEmpty([
      document.cellValueAt(rowIndex, 'State/Prov'),
      document.cellValueAt(rowIndex, 'Region'),
    ]);
  }

  PeakBaggerPeakDetails? cachedPeakDetailsForRow(
    PeakBaggerCsvDocument document,
    int rowIndex,
  ) {
    final peakbaggerPid = peakbaggerPidForRow(document, rowIndex);
    if (peakbaggerPid == null) {
      return null;
    }

    final latitude = _parseDouble(document.cellValueAt(rowIndex, latitudeColumn));
    final longitude = _parseDouble(document.cellValueAt(rowIndex, longitudeColumn));
    if (latitude == null || longitude == null) {
      return null;
    }

    return PeakBaggerPeakDetails(
      peakbaggerPid: peakbaggerPid,
      name: _firstNonEmpty([
            document.cellValueAt(rowIndex, 'Peak'),
            document.cellValueAt(rowIndex, 'Name'),
          ]) ??
          'Unknown',
      latitude: latitude,
      longitude: longitude,
      elevation: _parseDouble(document.cellValueAt(rowIndex, 'Elev-M')),
      prominence: _parseDouble(document.cellValueAt(rowIndex, 'Prom-M')),
      country: _firstNonEmpty([
            document.cellValueAt(rowIndex, 'Country'),
          ]) ??
          '',
      county: _firstNonEmpty([
            document.cellValueAt(rowIndex, 'County'),
            document.cellValueAt(rowIndex, 'State/Prov'),
            document.cellValueAt(rowIndex, 'Region'),
          ]) ??
          '',
      range: _firstNonEmpty([document.cellValueAt(rowIndex, 'Range')]) ?? '',
      osmId: _parseInt(document.cellValueAt(rowIndex, osmIdColumn)),
    );
  }

  int? parsePeakbaggerPidFromUrl(String? url) {
    if (url == null) {
      return null;
    }

    final match = RegExp(r'[?&]pid=(\d+)').firstMatch(url);
    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(1) ?? '');
  }

  void setSyncColumns(
    PeakBaggerCsvDocument document,
    int rowIndex, {
    int? peakbaggerPid,
    double? latitude,
    double? longitude,
    int? osmId,
    bool? safeToCreate,
    String? note,
  }) {
    if (peakbaggerPid != null) {
      document.setCellValue(rowIndex, peakbaggerPidColumn, '$peakbaggerPid');
    }
    if (latitude != null) {
      document.setCellValue(rowIndex, latitudeColumn, _formatDouble(latitude));
    }
    if (longitude != null) {
      document.setCellValue(rowIndex, longitudeColumn, _formatDouble(longitude));
    }
    if (osmId != null) {
      document.setCellValue(rowIndex, osmIdColumn, '$osmId');
    }
    if (safeToCreate != null) {
      document.setCellValue(rowIndex, safeToCreateColumn, safeToCreate.toString());
    }
    document.setCellValue(rowIndex, noteColumn, note?.trim() ?? '');
  }

  void _ensureSyncColumns(PeakBaggerCsvDocument document) {
    document.ensureColumn(peakbaggerPidColumn);
    document.ensureColumn(latitudeColumn);
    document.ensureColumn(longitudeColumn);
    document.ensureColumn(noteColumn);
    document.ensureColumn(osmIdColumn);
    document.ensureColumn(safeToCreateColumn);
  }

  String _formatDouble(double value) {
    var text = value.toStringAsFixed(6);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return text;
  }

  String _normalizeHeader(String header) {
    return header
        .replaceFirst('\uFEFF', '')
        .replaceAll('\u00A0', ' ')
        .trim();
  }

  String _normalizeCellValue(String value) {
    return value.replaceAll('\r', '').replaceFirst('\uFEFF', '');
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  int? _parseInt(String? value) {
    if (value == null) {
      return null;
    }

    return int.tryParse(value.trim());
  }

  double? _parseDouble(String? value) {
    if (value == null) {
      return null;
    }

    return double.tryParse(value.trim());
  }

  static String _normalizeLookupKey(String header) {
    return header
        .replaceAll('\u00A0', ' ')
        .replaceFirst('\uFEFF', '')
        .trim()
        .toLowerCase();
  }
}
