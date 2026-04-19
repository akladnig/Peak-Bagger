import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/peak_list_file_picker.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';

typedef PeakListCsvLoader = Future<String> Function(String csvPath);
typedef PeakListImportRootLoader = Future<String> Function();
typedef PeakListLogWriter =
    Future<void> Function(String logPath, List<String> entries);

class PeakListImportResult {
  const PeakListImportResult({
    required this.peakListId,
    required this.updated,
    required this.importedCount,
    required this.skippedCount,
    required this.matchedCount,
    required this.ambiguousCount,
    required this.warningEntries,
    required this.logEntries,
    this.warningMessage,
  });

  final int peakListId;
  final bool updated;
  final int importedCount;
  final int skippedCount;
  final int matchedCount;
  final int ambiguousCount;
  final List<String> warningEntries;
  final List<String> logEntries;
  final String? warningMessage;
}

class PeakListImportService {
  PeakListImportService({
    required PeakRepository peakRepository,
    required PeakListRepository peakListRepository,
    PeakListCsvLoader? csvLoader,
    PeakListImportRootLoader? importRootLoader,
    PeakListLogWriter? logWriter,
    DateTime Function()? clock,
  }) : _peakRepository = peakRepository,
       _peakListRepository = peakListRepository,
       _csvLoader = csvLoader ?? _loadCsvFromDisk,
       _importRootLoader =
           importRootLoader ?? PlatformPeakListFilePicker().resolveImportRoot,
       _logWriter = logWriter ?? _appendLogEntries,
       _clock = clock ?? DateTime.now;

  final PeakRepository _peakRepository;
  final PeakListRepository _peakListRepository;
  final PeakListCsvLoader _csvLoader;
  final PeakListImportRootLoader _importRootLoader;
  final PeakListLogWriter _logWriter;
  final DateTime Function() _clock;

  Future<PeakListImportResult> importPeakList({
    required String listName,
    required String csvPath,
  }) async {
    final trimmedListName = listName.trim();
    if (trimmedListName.isEmpty) {
      throw const FormatException('A list name is required.');
    }

    final existing = _peakListRepository.findByName(trimmedListName);
    final rows = _parseCsv(await _csvLoader(csvPath));
    final peaks = _peakRepository.getAllPeaks();
    final items = <PeakListItem>[];
    final warningEntries = <String>[];
    final logEntries = <String>[];
    var ambiguousCount = 0;
    var skippedCount = 0;

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (_isRowBlank(row)) {
        continue;
      }

      final parseResult = _parseRow(rows.first, row, rowIndex + 1);
      if (parseResult.error != null) {
        skippedCount += 1;
        warningEntries.add(parseResult.error!);
        logEntries.add(_timestampedLogEntry(csvPath, parseResult.error!));
        continue;
      }

      final csvRow = parseResult.row!;
      final matches = _findHardMatches(csvRow, peaks);
      if (matches.isEmpty) {
        final warning =
            'Row ${csvRow.rowNumber}: no matching peak found for ${csvRow.name}';
        skippedCount += 1;
        warningEntries.add(warning);
        logEntries.add(_timestampedLogEntry(csvPath, warning));
        continue;
      }
      if (matches.length > 1) {
        final warning =
            'Row ${csvRow.rowNumber}: multiple matching peaks found for ${csvRow.name}';
        ambiguousCount += 1;
        skippedCount += 1;
        warningEntries.add(warning);
        logEntries.add(_timestampedLogEntry(csvPath, warning));
        continue;
      }

      final peak = matches.single;
      if (_normalizeName(csvRow.name) != _normalizeName(peak.name)) {
        final warning =
            'Row ${csvRow.rowNumber}: imported ${csvRow.name} as ${peak.name}';
        warningEntries.add(warning);
        logEntries.add(_timestampedLogEntry(csvPath, warning));
      }

      items.add(PeakListItem(peakOsmId: peak.osmId, points: csvRow.points));
    }

    final saved = await _peakListRepository.save(
      PeakList(name: trimmedListName, peakList: encodePeakListItems(items)),
    );

    String? warningMessage;
    if (logEntries.isNotEmpty) {
      try {
        final importRoot = await _importRootLoader();
        await _logWriter(
          GpxImporter.resolveImportLogPath(importRoot),
          logEntries,
        );
      } catch (_) {
        warningEntries.add('Could not update import.log.');
        warningMessage = 'Could not update import.log.';
      }
    }

    return PeakListImportResult(
      peakListId: saved.peakListId,
      updated: existing != null,
      importedCount: items.length,
      skippedCount: skippedCount,
      matchedCount: items.length,
      ambiguousCount: ambiguousCount,
      warningEntries: List<String>.unmodifiable(warningEntries),
      logEntries: List<String>.unmodifiable(logEntries),
      warningMessage: warningMessage,
    );
  }

  List<List<dynamic>> _parseCsv(String contents) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(contents);
    if (rows.isEmpty) {
      throw const FormatException('CSV file is empty.');
    }

    final headers = rows.first
        .map((value) => _normalizeHeader('$value'))
        .toList();
    _requireHeaders(headers, const [
      'Name',
      'Height',
      'Zone',
      'Easting',
      'Northing',
      'Latitude',
      'Longitude',
      'Points',
    ]);

    rows[0] = headers;
    return rows;
  }

  _PeakListCsvRowParseResult _parseRow(
    List<dynamic> headers,
    List<dynamic> row,
    int rowNumber,
  ) {
    try {
      final data = <String, String>{};
      for (var index = 0; index < headers.length; index++) {
        data[headers[index] as String] = index < row.length
            ? '${row[index]}'
            : '';
      }

      final zone = data['Zone']!.trim().toUpperCase();
      final mgrs = PeakMgrsConverter.fromCsvUtm(
        zone: zone,
        easting: data['Easting']!,
        northing: data['Northing']!,
      );
      return _PeakListCsvRowParseResult(
        row: _PeakListCsvRow(
          rowNumber: rowNumber,
          name: data['Name']!.trim(),
          height: double.parse(_preferHeightValue(data)).round(),
          zone: zone,
          mgrs100kId: mgrs.mgrs100kId,
          easting: int.parse(mgrs.easting),
          northing: int.parse(mgrs.northing),
          latitude: double.parse(data['Latitude']!.trim()),
          longitude: double.parse(data['Longitude']!.trim()),
          points: data['Points']!.trim(),
        ),
      );
    } catch (_) {
      return _PeakListCsvRowParseResult(
        error: 'Row $rowNumber: invalid peak-list data',
      );
    }
  }

  List<Peak> _findHardMatches(_PeakListCsvRow row, List<Peak> peaks) {
    return peaks
        .where((peak) {
          if (peak.elevation == null) {
            return false;
          }
          if (peak.gridZoneDesignator.toUpperCase() != row.zone) {
            return false;
          }
          if (peak.mgrs100kId.toUpperCase() != row.mgrs100kId) {
            return false;
          }
          final peakEasting = int.tryParse(peak.easting);
          final peakNorthing = int.tryParse(peak.northing);
          if (peakEasting == null || peakNorthing == null) {
            return false;
          }
          if ((peakEasting - row.easting).abs() > 10 ||
              (peakNorthing - row.northing).abs() > 10) {
            return false;
          }
          if (peak.elevation!.round() != row.height) {
            return false;
          }

          return haversineDistance(
                row.latitude,
                row.longitude,
                peak.latitude,
                peak.longitude,
              ) <=
              50;
        })
        .toList(growable: false);
  }

  bool _isRowBlank(List<dynamic> row) {
    return row.every((value) => '$value'.trim().isEmpty);
  }

  String _normalizeHeader(String header) {
    final trimmed = header.replaceFirst('\u{FEFF}', '').trim();
    if (trimmed == 'Ht') {
      return 'Height';
    }
    return trimmed;
  }

  void _requireHeaders(List<dynamic> headers, List<String> requiredHeaders) {
    for (final header in requiredHeaders) {
      if (!headers.contains(header)) {
        throw FormatException('CSV is missing required column: $header');
      }
    }
  }

  String _preferHeightValue(Map<String, String> data) {
    return data['Height']?.trim() ?? data['Ht']?.trim() ?? '';
  }

  String _normalizeName(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized.replaceAllMapped(
      RegExp(r'^(.+),\s*(mt|mount)$'),
      (match) => '${match.group(2)} ${match.group(1)}',
    );
    normalized = normalized.replaceAll(RegExp(r'\bmt\b'), 'mount');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _timestampedLogEntry(String csvPath, String warning) {
    return '${_clock().toIso8601String()} | $csvPath | $warning';
  }

  static Future<String> _loadCsvFromDisk(String csvPath) async {
    final file = File(csvPath);
    if (!await file.exists()) {
      throw FormatException('Selected file does not exist: $csvPath');
    }

    return utf8.decode(await file.readAsBytes());
  }

  static Future<void> _appendLogEntries(
    String logPath,
    List<String> entries,
  ) async {
    if (entries.isEmpty) {
      return;
    }

    final logFile = File(logPath);
    await logFile.parent.create(recursive: true);
    await logFile.writeAsString(
      '${entries.join('\n')}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

class _PeakListCsvRow {
  const _PeakListCsvRow({
    required this.rowNumber,
    required this.name,
    required this.height,
    required this.zone,
    required this.mgrs100kId,
    required this.easting,
    required this.northing,
    required this.latitude,
    required this.longitude,
    required this.points,
  });

  final int rowNumber;
  final String name;
  final int height;
  final String zone;
  final String mgrs100kId;
  final int easting;
  final int northing;
  final double latitude;
  final double longitude;
  final String points;
}

class _PeakListCsvRowParseResult {
  const _PeakListCsvRowParseResult({this.row, this.error});

  final _PeakListCsvRow? row;
  final String? error;
}
