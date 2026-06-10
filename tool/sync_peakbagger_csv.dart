import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peakbagger_csv_import_service.dart';
import 'package:peak_bagger/services/peakbagger_csv_sync_service.dart';
import 'package:peak_bagger/services/peakbagger_scraper.dart';
import 'package:peak_bagger/services/peak_source.dart';

const _defaultCsvPath = 'peak-bagger-peak-data.csv';

class _SyncArgs {
  const _SyncArgs({
    required this.csvPath,
    required this.createUnmatchedPeaks,
  });

  final String csvPath;
  final bool createUnmatchedPeaks;
}

_SyncArgs _parseArgs(List<String> args) {
  var csvPath = _defaultCsvPath;
  var createUnmatchedPeaks = false;

  for (final arg in args) {
    if (arg == '--create-unmatched-peaks') {
      createUnmatchedPeaks = true;
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
  );
}

Future<PeakBaggerCsvSyncResult> syncPeakBaggerCsv({
  String csvPath = _defaultCsvPath,
  bool createUnmatchedPeaks = false,
  PeakBaggerCsvSyncService? service,
  PeakBaggerCsvRowProgress? onRowProcessed,
}) async {
  if (service != null) {
    final resolvedInputPath = _resolvedInputCsvPath(csvPath);
    return service.syncCsv(
      csvPath: resolvedInputPath,
      createUnmatchedPeaks: createUnmatchedPeaks,
    );
  }

  final sourceCsvPath = _sourceCsvPath(csvPath);
  final latLonCsvPath = _latLonCsvPath(sourceCsvPath);
  final sourceExists = File(sourceCsvPath).existsSync();
  final latLonExists = File(latLonCsvPath).existsSync();
  if (sourceExists) {
    await refreshPeakBaggerLatLonCsv(
      sourceCsvPath: sourceCsvPath,
      latLonCsvPath: latLonCsvPath,
      scraper: ProcessPeakBaggerScraper(),
    );
  } else if (!latLonExists) {
    throw FileSystemException('Missing PeakBagger CSV input', csvPath);
  }

  final peakSource = await _loadAssetPeakSource();
  final syncService = PeakBaggerCsvSyncService(
    peakSource: peakSource,
    scraper: ProcessPeakBaggerScraper(),
    onRowProcessed: onRowProcessed,
  );
    return await syncService.syncCsv(
      csvPath: latLonCsvPath,
      createUnmatchedPeaks: createUnmatchedPeaks,
      allowLiveLookups: false,
    );
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
  final existingPidIndex = existingDocument?.headerIndexOf(PeakBaggerCsvImportService.peakbaggerPidColumn);
  final existingLatitudeIndex = existingDocument?.headerIndexOf(PeakBaggerCsvImportService.latitudeColumn);
  final existingLongitudeIndex = existingDocument?.headerIndexOf(PeakBaggerCsvImportService.longitudeColumn);
  if (existingDocument != null) {
    for (var rowIndex = 0; rowIndex < existingDocument.rows.length; rowIndex++) {
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
        existingLatitudeIndex == null ? null : cachedRow.cells[existingLatitudeIndex],
      );
      longitude = _parseDoubleCell(
        existingLongitudeIndex == null ? null : cachedRow.cells[existingLongitudeIndex],
      );
    }

    peakbaggerPid ??= csvImportService.peakbaggerPidForRow(sourceDocument, rowIndex);

    if (latitude == null || longitude == null) {
      if (peakbaggerPid == null) {
        continue;
      }
      if (!availabilityChecked) {
        await activeScraper.verifyAvailable();
        availabilityChecked = true;
      }
      if (liveScrapingAvailable) {
        try {
          final details = await activeScraper.showPeak(peakbaggerPid);
          peakbaggerPid = details.peakbaggerPid;
          latitude = details.latitude;
          longitude = details.longitude;
        } on Object {
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

Future<PeakSource> _loadAssetPeakSource() async {
  final peaksDirectory = Directory(p.join(Directory.current.path, 'assets', 'peaks'));
  if (!peaksDirectory.existsSync()) {
    throw FileSystemException('Missing assets/peaks directory', peaksDirectory.path);
  }

  final peaks = <Peak>[];
  final entries = peaksDirectory
      .listSync(recursive: false)
      .whereType<File>()
      .where((file) => p.extension(file.path).toLowerCase() == '.json')
      .toList(growable: false)
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in entries) {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      continue;
    }

    final elements = decoded['elements'];
    if (elements is! List) {
      continue;
    }

    final region = p.basenameWithoutExtension(file.path).replaceFirst(RegExp(r'-peaks$'), '');
    for (final element in elements) {
      if (element is! Map) {
        continue;
      }

      try {
        final peak = Peak.fromOverpass(Map<String, dynamic>.from(element))
            .copyWith(region: region);
        if (peak.name != 'Unknown') {
          peaks.add(peak);
        }
      } catch (_) {
        continue;
      }
    }
  }

  return InMemoryPeakSource(peaks);
}

String? _cacheRowKey(PeakBaggerCsvDocument document, int rowIndex) {
  final url = document.cellValueAt(rowIndex, 'Url') ?? document.cellValueAt(rowIndex, 'URL');
  if (url != null && url.trim().isNotEmpty) {
    return 'url:${url.trim()}';
  }

  final pid = _parseIntCell(document.cellValueAt(rowIndex, PeakBaggerCsvImportService.peakbaggerPidColumn));
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

Future<void> main(List<String> args) async {
  final parsedArgs = _parseArgs(args);
  final progressFilePath = Platform.environment['PEAKBAGGER_PROGRESS_FILE'];
  RandomAccessFile? progressFile;
  if (progressFilePath != null && progressFilePath.isNotEmpty) {
    final file = File(progressFilePath);
    await file.parent.create(recursive: true);
    progressFile = file.openSync(mode: FileMode.writeOnlyAppend);
  }

  var processedRows = 0;
  try {
    final result = await syncPeakBaggerCsv(
      csvPath: parsedArgs.csvPath,
      createUnmatchedPeaks: parsedArgs.createUnmatchedPeaks,
      onRowProcessed: (processed, total) {
        processedRows = processed;
        _writeProgress(progressFile, '.');
        if (processed % 100 == 0 || processed == total) {
          _writeProgress(progressFile, ' $processed/$total\n');
        }
      },
    );

    if (processedRows > 0 && processedRows % 100 != 0) {
      _writeProgress(progressFile, ' $processedRows/${result.report.processedCount}\n');
    }
    stdout.writeln(jsonEncode(result.report.toJson()));
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
