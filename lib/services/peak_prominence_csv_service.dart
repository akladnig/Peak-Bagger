import 'package:csv/csv.dart';

class PeakProminenceCsvFormatException implements Exception {
  PeakProminenceCsvFormatException(this.message, {this.lineNumber});

  final String message;
  final int? lineNumber;

  @override
  String toString() {
    final lineText = lineNumber == null ? '' : ' (line $lineNumber)';
    return 'PeakProminenceCsvFormatException$lineText: $message';
  }
}

class PeakProminenceCsvRow {
  const PeakProminenceCsvRow({
    required this.lineNumber,
    required this.latitude,
    required this.longitude,
    required this.elevation,
    required this.keySaddleLatitude,
    required this.keySaddleLongitude,
    required this.prominence,
  });

  final int lineNumber;
  final double latitude;
  final double longitude;
  final double elevation;
  final double keySaddleLatitude;
  final double keySaddleLongitude;
  final double prominence;

  bool get keySaddleIsLandMassHighPoint =>
      keySaddleLatitude == 0 && keySaddleLongitude == 0;

  List<dynamic> toCsvRow() {
    return [
      latitude,
      longitude,
      elevation,
      keySaddleLatitude,
      keySaddleLongitude,
      prominence,
    ];
  }
}

class PeakProminenceCsvDocument {
  PeakProminenceCsvDocument({required List<PeakProminenceCsvRow> rows})
      : rows = List<PeakProminenceCsvRow>.unmodifiable(rows);

  final List<PeakProminenceCsvRow> rows;

  String write() {
    final csvRows = <List<dynamic>>[
      for (final row in rows) row.toCsvRow(),
    ];
    return const ListToCsvConverter(eol: '\n').convert(csvRows);
  }
}

class PeakProminenceCsvService {
  const PeakProminenceCsvService();

  PeakProminenceCsvDocument parse(String contents) {
    final rawRows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(contents);

    final rows = <PeakProminenceCsvRow>[];
    for (var index = 0; index < rawRows.length; index++) {
      final rawRow = rawRows[index];
      if (_isBlankRow(rawRow)) {
        continue;
      }

      if (rawRow.length != 6) {
        throw PeakProminenceCsvFormatException(
          'expected 6 columns but found ${rawRow.length}: ${rawRow.join(',')}',
          lineNumber: index + 1,
        );
      }

      final lineNumber = index + 1;
      rows.add(
        PeakProminenceCsvRow(
          lineNumber: lineNumber,
          latitude: _parseDouble(rawRow[0], lineNumber: lineNumber, column: 1),
          longitude: _parseDouble(rawRow[1], lineNumber: lineNumber, column: 2),
          elevation: _parseDouble(rawRow[2], lineNumber: lineNumber, column: 3),
          keySaddleLatitude: _parseDouble(
            rawRow[3],
            lineNumber: lineNumber,
            column: 4,
          ),
          keySaddleLongitude: _parseDouble(
            rawRow[4],
            lineNumber: lineNumber,
            column: 5,
          ),
          prominence: _parseDouble(rawRow[5], lineNumber: lineNumber, column: 6),
        ),
      );
    }

    final document = PeakProminenceCsvDocument(rows: rows);
    validate(document);
    return document;
  }

  void validate(PeakProminenceCsvDocument document) {
    double? previousProminence;
    for (final row in document.rows) {
      final currentProminence = row.prominence;
      if (previousProminence != null && currentProminence > previousProminence) {
        throw PeakProminenceCsvFormatException(
          'expected prominence to be sorted descending, but line ${row.lineNumber} has ${currentProminence.toStringAsFixed(2)} after ${previousProminence.toStringAsFixed(2)}',
          lineNumber: row.lineNumber,
        );
      }
      previousProminence = currentProminence;
    }
  }

  double _parseDouble(
    Object? value, {
    required int lineNumber,
    required int column,
  }) {
    final text = '$value'.replaceAll('\r', '').replaceFirst('\uFEFF', '').trim();
    final parsed = double.tryParse(text);
    if (parsed == null) {
      throw PeakProminenceCsvFormatException(
        'expected numeric value in column $column but found "$text"',
        lineNumber: lineNumber,
      );
    }
    return parsed;
  }

  bool _isBlankRow(List<dynamic> row) {
    return row.every((cell) => '$cell'.trim().isEmpty);
  }
}
