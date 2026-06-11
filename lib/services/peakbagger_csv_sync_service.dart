import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peakbagger_csv_import_service.dart';
import 'package:peak_bagger/services/peakbagger_peak_correlation_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peak_source.dart';
import 'package:peak_bagger/services/peakbagger_scraper.dart';

class PeakBaggerCsvSyncRowReport {
  const PeakBaggerCsvSyncRowReport({
    required this.rowNumber,
    required this.action,
    required this.detail,
    required this.note,
    this.peakbaggerPid,
    this.osmId,
  });

  final int rowNumber;
  final int? peakbaggerPid;
  final int? osmId;
  final String action;
  final String detail;
  final String note;

  Map<String, dynamic> toJson() {
    return {
      'row': rowNumber,
      'peakbaggerPid': peakbaggerPid,
      'osmId': osmId,
      'action': action,
      'detail': detail,
      'note': note,
    };
  }
}

class PeakBaggerCsvSyncReport {
  const PeakBaggerCsvSyncReport({required this.csvPath, required this.rows});

  final String csvPath;
  final List<PeakBaggerCsvSyncRowReport> rows;

  int get processedCount => rows.length;
  int get updatedCount => rows.where((row) {
    return row.action == 'spatial-match' ||
        row.action == 'closest-location-tie-break' ||
        row.action == 'strong-name-fallback' ||
        row.action == 'strong-name-exact' ||
        row.action == 'elevation-match' ||
        row.action == 'name-elevation-match' ||
        row.action == 'pid-reuse' ||
        row.action == 'promoted-osm-id';
  }).length;
  int get createdCount => rows.where((row) => row.action == 'created').length;
  int get unmatchedCount =>
      rows.where((row) => row.action == 'unresolved').length;
  int get skippedCount => rows.where((row) => row.action == 'skipped').length;
  int get fetchFailureCount =>
      rows.where((row) => row.action == 'fetch-failure').length;

  Map<String, dynamic> toJson() {
    return {
      'csvPath': csvPath,
      'processedCount': processedCount,
      'updatedCount': updatedCount,
      'createdCount': createdCount,
      'unmatchedCount': unmatchedCount,
      'skippedCount': skippedCount,
      'fetchFailureCount': fetchFailureCount,
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
    };
  }
}

class PeakBaggerCsvSyncResult {
  const PeakBaggerCsvSyncResult({
    required this.outputCsvPath,
    required this.csvContents,
    required this.report,
  });

  final String outputCsvPath;
  final String csvContents;
  final PeakBaggerCsvSyncReport report;
}

class PeakBaggerCsvSyncException implements Exception {
  const PeakBaggerCsvSyncException(this.message);

  final String message;

  @override
  String toString() => 'PeakBaggerCsvSyncException: $message';
}

typedef PeakBaggerCsvReader = Future<String> Function(String path);
typedef PeakBaggerCsvWriter =
    Future<void> Function(String path, String contents);
typedef PeakBaggerCsvRowProgress =
    void Function(int processedRows, int totalRows);

class PeakBaggerCsvSyncService {
  PeakBaggerCsvSyncService({
    required PeakSource peakSource,
    required PeakBaggerScraper scraper,
    PeakBaggerCsvImportService? csvImportService,
    PeakBaggerPeakCorrelationService? correlationService,
    PeakBaggerCsvReader? csvReader,
    PeakBaggerCsvWriter? csvWriter,
    PeakBaggerCsvWriter? reportWriter,
    PeakBaggerCsvWriter? logWriter,
    PeakBaggerCsvRowProgress? onRowProcessed,
    String Function(String csvPath)? outputCsvPathResolver,
    String Function(String csvPath)? reportPathResolver,
    String Function(String csvPath)? importLogPathResolver,
    DateTime Function()? clock,
  }) : _peakSource = peakSource,
       _scraper = scraper,
       _csvImportService = csvImportService ?? PeakBaggerCsvImportService(),
       _correlationService =
           correlationService ?? const PeakBaggerPeakCorrelationService(),
       _csvReader = csvReader ?? _readFile,
       _csvWriter = csvWriter ?? _writeAtomicFile,
       _reportWriter = reportWriter ?? _writeAtomicFile,
       _logWriter = logWriter ?? _appendFile,
       _onRowProcessed = onRowProcessed,
       _outputCsvPathResolver = outputCsvPathResolver ?? _defaultOutputCsvPath,
       _reportPathResolver = reportPathResolver ?? _defaultReportPath,
       _importLogPathResolver = importLogPathResolver ?? _defaultImportLogPath,
       _clock = clock ?? DateTime.now;

  final PeakSource _peakSource;
  final PeakBaggerScraper _scraper;
  final PeakBaggerCsvImportService _csvImportService;
  final PeakBaggerPeakCorrelationService _correlationService;
  final PeakBaggerCsvReader _csvReader;
  final PeakBaggerCsvWriter _csvWriter;
  final PeakBaggerCsvWriter _reportWriter;
  final PeakBaggerCsvWriter _logWriter;
  final PeakBaggerCsvRowProgress? _onRowProcessed;
  final String Function(String csvPath) _outputCsvPathResolver;
  final String Function(String csvPath) _reportPathResolver;
  final String Function(String csvPath) _importLogPathResolver;
  final DateTime Function() _clock;

  Future<PeakBaggerCsvSyncResult> syncCsv({
    required String csvPath,
    bool createUnmatchedPeaks = false,
    bool allowLiveLookups = true,
    bool exactNameOnly = false,
    bool elevationOnly = false,
    int elevationToleranceMeters = 10,
    int? maxRows,
  }) async {
    final _ = createUnmatchedPeaks;
    final csvContents = await _csvReader(csvPath);
    final document = _csvImportService.parse(csvContents);
    final totalRows = maxRows == null
        ? document.rows.length
        : math.min(document.rows.length, maxRows);
    final requiresLookup = allowLiveLookups && _requiresLookup(document);
    if (requiresLookup) {
      try {
        await _scraper.verifyAvailable();
      } on Object catch (error) {
        await _appendSingleLogLine(
          _importLogPathResolver(csvPath),
          rowNumber: 0,
          peakbaggerPid: null,
          osmId: null,
          action: 'error',
          detail: 'uvx peakbagger is required: $error',
        );
        throw PeakBaggerCsvSyncException(
          'uvx peakbagger is required to sync PeakBagger CSV data.',
        );
      }
    }

    final rows = <PeakBaggerCsvSyncRowReport>[];
    final logEntries = <String>[];
    final allPeaks = List<Peak>.from(_peakSource.getAllPeaks());
    final peaksByPid = <int, Peak>{
      for (final peak in allPeaks)
        if (peak.peakbaggerPid != null) peak.peakbaggerPid!: peak,
    };
    for (var rowIndex = 0; rowIndex < totalRows; rowIndex++) {
      final row = document.rows[rowIndex];
      final rowNumber = row.lineNumber;
      final peakbaggerPid = _csvImportService.peakbaggerPidForRow(
        document,
        rowIndex,
      );
      if (peakbaggerPid == null) {
        rows.add(
          PeakBaggerCsvSyncRowReport(
            rowNumber: rowNumber,
            action: 'skipped',
            detail: 'missing PeakBagger URL or pid',
            note: '',
          ),
        );
        _onRowProcessed?.call(rows.length, totalRows);
        logEntries.add(
          _logLine(
            rowNumber: rowNumber,
            peakbaggerPid: null,
            osmId: _parseIntCell(document.cellValueAt(rowIndex, 'osmId')),
            action: 'skipped',
            detail: 'missing PeakBagger URL or pid',
            note: '',
          ),
        );
        continue;
      }

      final cachedDetails = _csvImportService.cachedPeakDetailsForRow(
        document,
        rowIndex,
      );

      if (cachedDetails == null && !allowLiveLookups) {
        rows.add(
          PeakBaggerCsvSyncRowReport(
            rowNumber: rowNumber,
            peakbaggerPid: peakbaggerPid,
            osmId: _parseIntCell(document.cellValueAt(rowIndex, 'osmId')),
            action: 'unresolved',
            detail: 'missing cached latitude/longitude',
            note: 'unresolved: missing cached latitude/longitude',
          ),
        );
        _onRowProcessed?.call(rows.length, totalRows);
        logEntries.add(
          _logLine(
            rowNumber: rowNumber,
            peakbaggerPid: peakbaggerPid,
            osmId: _parseIntCell(document.cellValueAt(rowIndex, 'osmId')),
            action: 'unresolved',
            detail: 'missing cached latitude/longitude',
            note: 'unresolved: missing cached latitude/longitude',
          ),
        );
        continue;
      }

      PeakBaggerPeakDetails details;
      if (cachedDetails != null) {
        details = cachedDetails;
      } else {
        try {
          details = await _scraper.showPeak(peakbaggerPid);
        } on Object catch (error) {
          rows.add(
            PeakBaggerCsvSyncRowReport(
              rowNumber: rowNumber,
              peakbaggerPid: peakbaggerPid,
              osmId: _parseIntCell(document.cellValueAt(rowIndex, 'osmId')),
              action: 'fetch-failure',
              detail: '$error',
              note: '',
            ),
          );
          _onRowProcessed?.call(rows.length, totalRows);
          logEntries.add(
            _logLine(
              rowNumber: rowNumber,
              peakbaggerPid: peakbaggerPid,
              osmId: _parseIntCell(document.cellValueAt(rowIndex, 'osmId')),
              action: 'fetch-failure',
              detail: '$error',
              note: '',
            ),
          );
          continue;
        }
      }

      final targetElevation =
          _parseDoubleCell(document.cellValueAt(rowIndex, 'Elev-M')) ??
          details.elevation;
      final targetCountry =
          _firstNonEmptyText([
            document.cellValueAt(rowIndex, 'Country'),
            details.country,
          ]) ??
          '';
      final targetCounty =
          _firstNonEmptyText([
            document.cellValueAt(rowIndex, 'County'),
            details.county,
          ]) ??
          '';
      final targetRange =
          _firstNonEmptyText([
            document.cellValueAt(rowIndex, 'Range'),
            details.range,
          ]) ??
          '';

      final existingPeak = peaksByPid[peakbaggerPid];
      final detailsForMatching = PeakBaggerPeakDetails(
        peakbaggerPid: details.peakbaggerPid,
        name: details.name,
        altName: details.altName,
        latitude: details.latitude,
        longitude: details.longitude,
        elevation: targetElevation ?? details.elevation,
        prominence: details.prominence,
        country: details.country,
        county: details.county,
        range: details.range,
        osmId: details.osmId,
      );
      final correlation = existingPeak != null
          ? _pidReuseResult(existingPeak, detailsForMatching)
          : _correlationService.correlate(
              peakBaggerPeak: detailsForMatching,
              peaks: allPeaks,
              options: PeakBaggerCorrelationOptions(
                exactNameOnly: exactNameOnly,
                elevationOnly: elevationOnly,
                elevationToleranceMeters: elevationToleranceMeters,
              ),
            );

      int? resolvedOsmId;
      String action;
      String detail;
      if (correlation.peak == null) {
        resolvedOsmId = _parseIntCell(document.cellValueAt(rowIndex, 'osmId'));
        action = correlation.action;
        detail = correlation.detail;
      } else {
        final updatedPeak = await _backfillMatchedPeak(
          peak: correlation.peak!,
          peakbaggerPid: peakbaggerPid,
          targetElevation: targetElevation,
          targetProminence:
              _parseDoubleCell(document.cellValueAt(rowIndex, 'Prom-M')) ??
              details.prominence,
          targetCountry: targetCountry,
          targetCounty: targetCounty,
          targetRange: targetRange,
        );
        if (updatedPeak != null) {
          _replacePeakInList(allPeaks, updatedPeak);
          if (updatedPeak.peakbaggerPid != null) {
            peaksByPid[updatedPeak.peakbaggerPid!] = updatedPeak;
          }
        }
        resolvedOsmId = correlation.peak!.osmId;
        action = correlation.action;
        detail = correlation.detail;
      }

      final existingPid = _parseIntCell(
        document.cellValueAt(rowIndex, 'PeakBagger PID'),
      );
      final existingLatitude = _parseDoubleCell(
        document.cellValueAt(rowIndex, 'Latitude'),
      );
      final existingLongitude = _parseDoubleCell(
        document.cellValueAt(rowIndex, 'Longitude'),
      );
      final existingOsmId = _parseIntCell(
        document.cellValueAt(rowIndex, 'osmId'),
      );
      final note = _buildNote(
        rowIndex: rowIndex,
        document: document,
        details: details,
        correlation: correlation,
        resolvedOsmId: resolvedOsmId,
        existingPid: existingPid,
        existingLatitude: existingLatitude,
        existingLongitude: existingLongitude,
        existingOsmId: existingOsmId,
        targetElevation: targetElevation,
        targetCountry: targetCountry,
        targetCounty: targetCounty,
        targetRange: targetRange,
      );

      _csvImportService.setSyncColumns(
        document,
        rowIndex,
        peakbaggerPid: peakbaggerPid,
        latitude: details.latitude,
        longitude: details.longitude,
        osmId: resolvedOsmId,
        safeToCreate: correlation.safeToCreate,
        note: note,
      );

      rows.add(
        PeakBaggerCsvSyncRowReport(
          rowNumber: rowNumber,
          peakbaggerPid: peakbaggerPid,
          osmId: resolvedOsmId,
          action: action,
          detail: detail,
          note: note,
        ),
      );
      _onRowProcessed?.call(rows.length, totalRows);
      logEntries.add(
        _logLine(
          rowNumber: rowNumber,
          peakbaggerPid: peakbaggerPid,
          osmId: resolvedOsmId,
          action: action,
          detail: detail,
          note: note,
        ),
      );
    }

    final csvOutput = _csvImportService.write(document);
    final outputCsvPath = _outputCsvPathResolver(csvPath);
    await _csvWriter(outputCsvPath, csvOutput);

    final report = PeakBaggerCsvSyncReport(csvPath: outputCsvPath, rows: rows);
    final reportPath = _reportPathResolver(csvPath);
    await _reportWriter(
      reportPath,
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );

    final logPath = _importLogPathResolver(csvPath);
    if (logEntries.isNotEmpty) {
      await _logWriter(logPath, '${logEntries.join('\n')}\n');
    }

    return PeakBaggerCsvSyncResult(
      outputCsvPath: outputCsvPath,
      csvContents: csvOutput,
      report: report,
    );
  }

  String _buildNote({
    required int rowIndex,
    required PeakBaggerCsvDocument document,
    required PeakBaggerPeakDetails details,
    required PeakBaggerCorrelationResult correlation,
    required int? resolvedOsmId,
    required int? existingPid,
    required double? existingLatitude,
    required double? existingLongitude,
    required int? existingOsmId,
    required double? targetElevation,
    required String targetCountry,
    required String targetCounty,
    required String targetRange,
  }) {
    if (correlation.peak == null) {
      return correlation.note;
    }

    final noteParts = <String>[];
    if (correlation.note.isNotEmpty) {
      noteParts.add(correlation.note);
    }

    if (existingPid != null && existingPid != details.peakbaggerPid) {
      noteParts.add('PeakBagger PID changed to ${details.peakbaggerPid}');
    }

    if ((existingLatitude != null &&
            details.latitude != null &&
            existingLatitude != details.latitude) ||
        (existingLongitude != null &&
            details.longitude != null &&
            existingLongitude != details.longitude)) {
      noteParts.add('latitude/longitude refreshed');
    }

    final currentElevation = _parseDoubleCell(
      document.cellValueAt(rowIndex, 'Elev-M'),
    );
    if (targetElevation != null &&
        currentElevation != null &&
        currentElevation != targetElevation) {
      noteParts.add('elevation updated');
    }

    final currentCountry =
        document.cellValueAt(rowIndex, 'Country')?.trim() ?? '';
    if (currentCountry.isNotEmpty && currentCountry != targetCountry) {
      noteParts.add('country refreshed');
    }

    final currentCounty =
        document.cellValueAt(rowIndex, 'County')?.trim() ?? '';
    if (currentCounty.isNotEmpty && currentCounty != targetCounty) {
      noteParts.add('county refreshed');
    }

    final currentRange = document.cellValueAt(rowIndex, 'Range')?.trim() ?? '';
    if (currentRange.isNotEmpty && currentRange != targetRange) {
      noteParts.add('range refreshed');
    }

    if (resolvedOsmId != null &&
        existingOsmId != null &&
        existingOsmId != resolvedOsmId) {
      noteParts.add('osmId changed $resolvedOsmId');
    }

    return noteParts.join('; ');
  }

  String _logLine({
    required int rowNumber,
    required int? peakbaggerPid,
    required int? osmId,
    required String action,
    required String detail,
    required String note,
  }) {
    final timestamp = _clock().toUtc().toIso8601String();
    final sanitizedDetail = detail.replaceAll('\n', ' ');
    final sanitizedNote = note.trim().replaceAll('\n', ' ');
    final noteSuffix = sanitizedNote.isEmpty || sanitizedNote == sanitizedDetail
        ? ''
        : ' note=$sanitizedNote';
    return '$timestamp row=$rowNumber peakbaggerPid=${peakbaggerPid ?? ''} osmId=${osmId ?? ''} action=$action detail=$sanitizedDetail$noteSuffix';
  }

  PeakBaggerCorrelationResult _pidReuseResult(
    Peak existingPeak,
    PeakBaggerPeakDetails details,
  ) {
    final hasStrongSpatialMatch = _correlationService.isStrongSpatialMatch(
      peakBaggerPeak: details,
      peak: existingPeak,
    );
    return PeakBaggerCorrelationResult(
      peak: existingPeak,
      action: 'pid-reuse',
      detail: hasStrongSpatialMatch
          ? 'matched existing PeakBagger pid with strong spatial match'
          : 'matched existing PeakBagger pid',
      note: hasStrongSpatialMatch
          ? 'matched existing PeakBagger pid with strong spatial match'
          : 'matched existing PeakBagger pid',
      safeToCreate: false,
    );
  }

  Future<Peak?> _backfillMatchedPeak({
    required Peak peak,
    required int peakbaggerPid,
    required double? targetElevation,
    required double? targetProminence,
    required String targetCountry,
    required String targetCounty,
    required String targetRange,
  }) async {
    final updatedPeak = peak.copyWith(
      peakbaggerPid: peak.peakbaggerPid ?? peakbaggerPid,
      elevation: peak.elevation ?? targetElevation,
      prominence: peak.prominence ?? targetProminence,
      country: peak.country.trim().isEmpty ? targetCountry : peak.country,
      county: peak.county.trim().isEmpty ? targetCounty : peak.county,
      range: peak.range.trim().isEmpty ? targetRange : peak.range,
    );

    if (_peaksEqual(peak, updatedPeak)) {
      return null;
    }

    final peakSource = _peakSource;
    if (peakSource is! PeakRepository) {
      return updatedPeak;
    }

    return await peakSource.save(updatedPeak);
  }

  void _replacePeakInList(List<Peak> peaks, Peak updatedPeak) {
    for (var index = 0; index < peaks.length; index++) {
      if (peaks[index].id == updatedPeak.id) {
        peaks[index] = updatedPeak;
        return;
      }
    }
  }

  bool _peaksEqual(Peak left, Peak right) {
    return left.id == right.id &&
        left.osmId == right.osmId &&
        left.peakbaggerPid == right.peakbaggerPid &&
        left.name == right.name &&
        left.altName == right.altName &&
        left.elevation == right.elevation &&
        left.prominence == right.prominence &&
        left.country == right.country &&
        left.county == right.county &&
        left.range == right.range &&
        left.latitude == right.latitude &&
        left.longitude == right.longitude &&
        left.region == right.region &&
        left.gridZoneDesignator == right.gridZoneDesignator &&
        left.mgrs100kId == right.mgrs100kId &&
        left.easting == right.easting &&
        left.northing == right.northing &&
        left.verified == right.verified &&
        left.sourceOfTruth == right.sourceOfTruth;
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

  String? _firstNonEmptyText(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  Future<void> _appendSingleLogLine(
    String logPath, {
    required int rowNumber,
    required int? peakbaggerPid,
    required int? osmId,
    required String action,
    required String detail,
  }) async {
    await _logWriter(
      logPath,
      '${_logLine(rowNumber: rowNumber, peakbaggerPid: peakbaggerPid, osmId: osmId, action: action, detail: detail, note: '')}\n',
    );
  }

  static String _defaultReportPath(String csvPath) {
    return p.setExtension(_baseCsvPath(csvPath), '.sync-report.json');
  }

  static String _defaultOutputCsvPath(String csvPath) {
    final basePath = _baseCsvPath(csvPath);
    final directory = p.dirname(basePath);
    final basename = p.basenameWithoutExtension(basePath);
    final extension = p.extension(basePath);
    final fileName =
        '$basename-processed${extension.isEmpty ? '.csv' : extension}';
    return directory == '.' ? fileName : p.join(directory, fileName);
  }

  bool _requiresLookup(PeakBaggerCsvDocument document) {
    for (var rowIndex = 0; rowIndex < document.rows.length; rowIndex++) {
      if (_csvImportService.cachedPeakDetailsForRow(document, rowIndex) ==
          null) {
        return true;
      }
    }
    return false;
  }

  static String _baseCsvPath(String csvPath) {
    final directory = p.dirname(csvPath);
    final basename = p.basenameWithoutExtension(csvPath);
    final normalizedBase = basename.endsWith('-lat-lon')
        ? basename.substring(0, basename.length - '-lat-lon'.length)
        : basename;
    final extension = p.extension(csvPath);
    final fileName = '$normalizedBase${extension.isEmpty ? '.csv' : extension}';
    return directory == '.' ? fileName : p.join(directory, fileName);
  }

  static String _defaultImportLogPath(String csvPath) {
    return p.join(Directory.current.path, 'logs', 'import.log');
  }

  static Future<String> _readFile(String path) {
    return File(path).readAsString();
  }

  static Future<void> _writeAtomicFile(String path, String contents) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final tempFile = File('$path.tmp');
    await tempFile.writeAsString(contents, flush: true);
    if (file.existsSync()) {
      await file.delete();
    }
    await tempFile.rename(path);
  }

  static Future<void> _appendFile(String path, String contents) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(contents, mode: FileMode.append, flush: true);
  }
}
