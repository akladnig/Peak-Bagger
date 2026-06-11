import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/peakbagger_csv_import_service.dart';
import 'package:peak_bagger/services/peakbagger_csv_sync_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peakbagger_scraper.dart';

const _defaultCsvPath = 'peak-bagger-peak-data.csv';

class _SyncArgs {
  const _SyncArgs({
    required this.csvPath,
    required this.createUnmatchedPeaks,
    required this.exactNameOnly,
    required this.elevationOnly,
    required this.elevationToleranceMeters,
    required this.maxRows,
  });

  final String csvPath;
  final bool createUnmatchedPeaks;
  final bool exactNameOnly;
  final bool elevationOnly;
  final int elevationToleranceMeters;
  final int? maxRows;
}

_SyncArgs _parseArgs(List<String> args) {
  var csvPath = _defaultCsvPath;
  var createUnmatchedPeaks = false;
  var exactNameOnly = false;
  var elevationOnly = false;
  var elevationToleranceMeters = 10;
  int? maxRows;

  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (arg == '--create-unmatched-peaks') {
      createUnmatchedPeaks = true;
      continue;
    }
    if (arg == '--name' || arg == '-n') {
      exactNameOnly = true;
      continue;
    }
    if (arg == '--elevation' || arg == '-e') {
      elevationOnly = true;
      continue;
    }
    if (arg == '--tolerance' || arg == '-t') {
      if (index + 1 >= args.length) {
        throw ArgumentError('Missing value for $arg');
      }
      elevationToleranceMeters = int.parse(args[++index]);
      if (elevationToleranceMeters < 0) {
        throw ArgumentError('Tolerance must be non-negative');
      }
      continue;
    }
    if (arg == '--rows' || arg == '-r') {
      if (index + 1 >= args.length) {
        throw ArgumentError('Missing value for $arg');
      }
      maxRows = int.parse(args[++index]);
      if (maxRows < 0) {
        throw ArgumentError('Rows must be non-negative');
      }
      continue;
    }
    if (arg.startsWith('-')) {
      throw ArgumentError('Unknown flag: $arg');
    }
    csvPath = arg;
  }

  return _SyncArgs(
    csvPath: csvPath,
    createUnmatchedPeaks: createUnmatchedPeaks,
    exactNameOnly: exactNameOnly,
    elevationOnly: elevationOnly,
    elevationToleranceMeters: elevationToleranceMeters,
    maxRows: maxRows,
  );
}

Future<PeakBaggerCsvSyncResult> syncPeakBaggerCsv({
  String csvPath = _defaultCsvPath,
  bool createUnmatchedPeaks = false,
  bool exactNameOnly = false,
  bool elevationOnly = false,
  int elevationToleranceMeters = 10,
  int? maxRows,
  PeakBaggerCsvSyncService? service,
  PeakBaggerCsvRowProgress? onRowProcessed,
  void Function(String message)? onWarning,
}) async {
  if (service != null) {
    final resolvedInputPath = _resolvedInputCsvPath(csvPath);
    return service.syncCsv(
      csvPath: resolvedInputPath,
      createUnmatchedPeaks: createUnmatchedPeaks,
      exactNameOnly: exactNameOnly,
      elevationOnly: elevationOnly,
      elevationToleranceMeters: elevationToleranceMeters,
      maxRows: maxRows,
    );
  }

  final sourceCsvPath = _sourceCsvPath(csvPath);
  final latLonCsvPath = _latLonCsvPath(sourceCsvPath);
  final sourceExists = File(sourceCsvPath).existsSync();
  final latLonExists = File(latLonCsvPath).existsSync();
  var inputCsvPath = csvPath;
  if (sourceExists) {
    inputCsvPath = latLonExists ? latLonCsvPath : sourceCsvPath;
  } else if (latLonExists) {
    inputCsvPath = latLonCsvPath;
  } else {
    throw FileSystemException('Missing PeakBagger CSV input', csvPath);
  }

  WidgetsFlutterBinding.ensureInitialized();
  final store = await openStore();
  try {
    final peakRepository = PeakRepository(
      store,
      peakListRewritePort: ObjectBoxPeakListRewritePort(store),
    );
    final syncService = PeakBaggerCsvSyncService(
      peakSource: peakRepository,
      scraper: ProcessPeakBaggerScraper(),
      onRowProcessed: onRowProcessed,
    );
    return await syncService.syncCsv(
      csvPath: inputCsvPath,
      createUnmatchedPeaks: createUnmatchedPeaks,
      allowLiveLookups: false,
      exactNameOnly: exactNameOnly,
      elevationOnly: elevationOnly,
      elevationToleranceMeters: elevationToleranceMeters,
      maxRows: maxRows,
    );
  } finally {
    store.close();
  }
}

Future<PeakBaggerCsvSyncResult> runSyncPeakBaggerCsvTool({
  List<String> args = const [],
  PeakBaggerCsvSyncService? service,
  RandomAccessFile? progressFile,
  void Function(String message)? warningWriter,
}) async {
  final parsedArgs = _parseArgs(args);
  var processedRows = 0;

  final result = await syncPeakBaggerCsv(
    csvPath: parsedArgs.csvPath,
    createUnmatchedPeaks: parsedArgs.createUnmatchedPeaks,
    exactNameOnly: parsedArgs.exactNameOnly,
    elevationOnly: parsedArgs.elevationOnly,
    elevationToleranceMeters: parsedArgs.elevationToleranceMeters,
    maxRows: parsedArgs.maxRows,
    service: service,
    onWarning: (message) {
      warningWriter?.call(message);
      final logPath = p.join(Directory.current.path, 'logs', 'import.log');
      final logFile = File(logPath);
      logFile.parent.createSync(recursive: true);
      logFile.writeAsStringSync(
        '${_warningLogLine(message)}\n',
        mode: FileMode.append,
      );
    },
    onRowProcessed: (processed, total) {
      processedRows = processed;
      _writeProgress(progressFile, '.');
      if (processed % 100 == 0 || processed == total) {
        _writeProgress(progressFile, ' $processed/$total\n');
      }
    },
  );

  if (processedRows > 0 && processedRows % 100 != 0) {
    _writeProgress(
      progressFile,
      ' $processedRows/${result.report.processedCount}\n',
    );
  }

  return result;
}

String _resolvedInputCsvPath(String csvPath) {
  final sourceCsvPath = _sourceCsvPath(csvPath);
  final latLonCsvPath = _latLonCsvPath(sourceCsvPath);
  if (File(latLonCsvPath).existsSync()) {
    return latLonCsvPath;
  }

  return csvPath;
}

String _latLonCsvPath(String csvPath) {
  final sourceCsvPath = _sourceCsvPath(csvPath);
  final directory = p.dirname(sourceCsvPath);
  final basename = p.basenameWithoutExtension(sourceCsvPath);
  final extension = p.extension(sourceCsvPath);
  final fileName = '$basename-lat-lon${extension.isEmpty ? '.csv' : extension}';
  return directory == '.' ? fileName : p.join(directory, fileName);
}

String _sourceCsvPath(String csvPath) {
  final directory = p.dirname(csvPath);
  final basename = p.basenameWithoutExtension(csvPath);
  final normalizedBase = basename.endsWith('-lat-lon')
      ? basename.substring(0, basename.length - '-lat-lon'.length)
      : basename;
  final extension = p.extension(csvPath);
  final fileName = '$normalizedBase${extension.isEmpty ? '.csv' : extension}';
  return directory == '.' ? fileName : p.join(directory, fileName);
}

Future<String> refreshPeakBaggerLatLonCsv({
  required String sourceCsvPath,
  required String latLonCsvPath,
  PeakBaggerScraper? scraper,
  void Function(String message)? onWarning,
}) async {
  final csvImportService = PeakBaggerCsvImportService();
  final sourceContents = await File(sourceCsvPath).readAsString();
  final sourceDocument = csvImportService.parse(
    sourceContents,
    includeSyncColumns: false,
  );
  final outputDocument = csvImportService.parse(
    sourceContents,
    includeSyncColumns: false,
  );
  outputDocument.ensureColumn(PeakBaggerCsvImportService.peakbaggerPidColumn);
  outputDocument.ensureColumn(PeakBaggerCsvImportService.latitudeColumn);
  outputDocument.ensureColumn(PeakBaggerCsvImportService.longitudeColumn);

  PeakBaggerCsvDocument? existingDocument;
  final existingFile = File(latLonCsvPath);
  if (existingFile.existsSync()) {
    existingDocument = csvImportService.parse(
      await existingFile.readAsString(),
      includeSyncColumns: false,
    );
  }

  final existingRowsByKey = <String, PeakBaggerCsvRow>{};
  final existingPidIndex = existingDocument?.headerIndexOf(
    PeakBaggerCsvImportService.peakbaggerPidColumn,
  );
  final existingLatitudeIndex = existingDocument?.headerIndexOf(
    PeakBaggerCsvImportService.latitudeColumn,
  );
  final existingLongitudeIndex = existingDocument?.headerIndexOf(
    PeakBaggerCsvImportService.longitudeColumn,
  );
  if (existingDocument != null) {
    for (
      var rowIndex = 0;
      rowIndex < existingDocument.rows.length;
      rowIndex++
    ) {
      final key = _cacheRowKey(existingDocument, rowIndex);
      if (key != null) {
        existingRowsByKey[key] = existingDocument.rows[rowIndex];
      }
    }
  }

  final activeScraper = scraper ?? ProcessPeakBaggerScraper();
  var availabilityChecked = false;
  var liveScrapingAvailable = true;
  for (var rowIndex = 0; rowIndex < sourceDocument.rows.length; rowIndex++) {
    final sourceKey = _cacheRowKey(sourceDocument, rowIndex);
    final cachedRow = sourceKey == null ? null : existingRowsByKey[sourceKey];

    int? peakbaggerPid;
    double? latitude;
    double? longitude;

    if (cachedRow != null && existingDocument != null) {
      peakbaggerPid = _parseIntCell(
        existingPidIndex == null ? null : cachedRow.cells[existingPidIndex],
      );
      latitude = _parseDoubleCell(
        existingLatitudeIndex == null
            ? null
            : cachedRow.cells[existingLatitudeIndex],
      );
      longitude = _parseDoubleCell(
        existingLongitudeIndex == null
            ? null
            : cachedRow.cells[existingLongitudeIndex],
      );
    }

    peakbaggerPid ??= csvImportService.peakbaggerPidForRow(
      sourceDocument,
      rowIndex,
    );

    if (latitude == null || longitude == null) {
      if (peakbaggerPid == null) {
        continue;
      }
      if (!availabilityChecked) {
        try {
          await activeScraper.verifyAvailable();
        } on Object catch (error) {
          if (_isForbiddenError(error)) {
            onWarning?.call(
              'PeakBagger returned HTTP 403 while refreshing lat/lon data; '
              'falling back to the source CSV and stopping live scraping.',
            );
            return sourceCsvPath;
          }
          rethrow;
        }
        availabilityChecked = true;
      }
      if (liveScrapingAvailable) {
        try {
          final details = await activeScraper.showPeak(peakbaggerPid);
          peakbaggerPid = details.peakbaggerPid;
          latitude = details.latitude;
          longitude = details.longitude;
        } on Object catch (error) {
          if (_isForbiddenError(error)) {
            onWarning?.call(
              'PeakBagger returned HTTP 403 while refreshing lat/lon data; '
              'falling back to the source CSV and stopping live scraping.',
            );
            return sourceCsvPath;
          }
          liveScrapingAvailable = false;
        }
      }
    }

    if (peakbaggerPid != null) {
      outputDocument.setCellValue(
        rowIndex,
        PeakBaggerCsvImportService.peakbaggerPidColumn,
        '$peakbaggerPid',
      );
    }
    if (latitude != null) {
      outputDocument.setCellValue(
        rowIndex,
        PeakBaggerCsvImportService.latitudeColumn,
        _formatLatLonValue(latitude),
      );
    }
    if (longitude != null) {
      outputDocument.setCellValue(
        rowIndex,
        PeakBaggerCsvImportService.longitudeColumn,
        _formatLatLonValue(longitude),
      );
    }
  }

  final contents = csvImportService.write(outputDocument);
  await File(latLonCsvPath).parent.create(recursive: true);
  await File(latLonCsvPath).writeAsString(contents, flush: true);
  return latLonCsvPath;
}

String? _cacheRowKey(PeakBaggerCsvDocument document, int rowIndex) {
  final url =
      document.cellValueAt(rowIndex, 'Url') ??
      document.cellValueAt(rowIndex, 'URL');
  if (url != null && url.trim().isNotEmpty) {
    return 'url:${url.trim()}';
  }

  final pid = _parseIntCell(
    document.cellValueAt(
      rowIndex,
      PeakBaggerCsvImportService.peakbaggerPidColumn,
    ),
  );
  if (pid != null) {
    return 'pid:$pid';
  }

  return null;
}

String _formatLatLonValue(double value) {
  var text = value.toStringAsFixed(6);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  return text;
}

int? _parseIntCell(String? value) {
  if (value == null) {
    return null;
  }
  return int.tryParse(value.trim());
}

double? _parseDoubleCell(String? value) {
  if (value == null) {
    return null;
  }
  return double.tryParse(value.trim());
}

bool _isForbiddenError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('403') &&
      (text.contains('forbidden') ||
          text.contains('status code') ||
          text.contains('http'));
}

String _warningLogLine(String message) {
  final timestamp = DateTime.now().toUtc().toIso8601String();
  return '$timestamp row=0 peakbaggerPid= osmId= action=error detail=$message';
}

Future<void> main(List<String> args) async {
  final progressFilePath = Platform.environment['PEAKBAGGER_PROGRESS_FILE'];
  RandomAccessFile? progressFile;
  if (progressFilePath != null && progressFilePath.isNotEmpty) {
    final file = File(progressFilePath);
    await file.parent.create(recursive: true);
    progressFile = file.openSync(mode: FileMode.writeOnlyAppend);
  }

  try {
    final result = await runSyncPeakBaggerCsvTool(
      args: args,
      progressFile: progressFile,
      warningWriter: stderr.writeln,
    );
    stdout.writeln(jsonEncode(result.report.toJson()));
    exit(0);
  } finally {
    progressFile?.closeSync();
  }
}

void _writeProgress(RandomAccessFile? progressFile, String text) {
  if (progressFile != null) {
    progressFile.writeStringSync(text);
    progressFile.flushSync();
    return;
  }

  stderr.write(text);
}
