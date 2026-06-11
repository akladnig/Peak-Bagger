import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_prominence_correlation_service.dart';
import 'package:peak_bagger/services/peak_prominence_csv_service.dart';
import 'package:peak_bagger/services/peak_prominence_preview_export_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';

typedef PeakProminenceCsvReader = Future<String> Function(String path);
typedef PeakProminenceCsvLineReader = Stream<String> Function(String path);
typedef PeakProminenceLogWriter = Future<void> Function(
  String path,
  String contents,
);
typedef PeakProminenceClock = DateTime Function();
typedef PeakProminenceImportProgressCallback = void Function(
  PeakProminenceImportProgress progress,
);

class PeakProminenceImportProgress {
  const PeakProminenceImportProgress({
    required this.processedRowCount,
    required this.matchedCount,
    required this.updatedCount,
    required this.unresolvedCsvRowCount,
    required this.writeFailureCount,
    required this.remainingPeakCount,
  });

  final int processedRowCount;
  final int matchedCount;
  final int updatedCount;
  final int unresolvedCsvRowCount;
  final int writeFailureCount;
  final int remainingPeakCount;
}

class PeakProminenceImportRowReport {
  const PeakProminenceImportRowReport({
    required this.action,
    required this.detail,
    this.csvRow,
    this.peak,
  });

  final String action;
  final String detail;
  final PeakProminenceCsvRow? csvRow;
  final Peak? peak;

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'detail': detail,
      'row': csvRow?.lineNumber,
      'peakId': peak?.id,
      'name': peak?.name,
    };
  }
}

class PeakProminenceImportReport {
  const PeakProminenceImportReport({
    required this.csvPath,
    required this.rows,
    int? matchedCount,
    int? updatedCount,
    int? unresolvedCsvRowCount,
    int? unmatchedPeakCount,
    int? writeFailureCount,
  }) : _matchedCount = matchedCount,
       _updatedCount = updatedCount,
       _unresolvedCsvRowCount = unresolvedCsvRowCount,
       _unmatchedPeakCount = unmatchedPeakCount,
       _writeFailureCount = writeFailureCount;

  final String csvPath;
  final List<PeakProminenceImportRowReport> rows;
  final int? _matchedCount;
  final int? _updatedCount;
  final int? _unresolvedCsvRowCount;
  final int? _unmatchedPeakCount;
  final int? _writeFailureCount;

  int get matchedCount =>
      _matchedCount ??
      rows.where((row) => row.action == 'matched' || row.action == 'updated').length;

  int get updatedCount =>
      _updatedCount ?? rows.where((row) => row.action == 'updated').length;

  int get unresolvedCsvRowCount =>
      _unresolvedCsvRowCount ??
      rows.where((row) => row.action == 'unresolved-csv-row').length;

  int get unmatchedPeakCount =>
      _unmatchedPeakCount ??
      rows.where((row) => row.action == 'not-found-in-dataset').length;

  int get writeFailureCount =>
      _writeFailureCount ?? rows.where((row) => row.action == 'write-failure').length;

  Map<String, dynamic> toJson() {
    return {
      'csvPath': csvPath,
      'matchedCount': matchedCount,
      'updatedCount': updatedCount,
      'unresolvedCsvRowCount': unresolvedCsvRowCount,
      'unmatchedPeakCount': unmatchedPeakCount,
      'writeFailureCount': writeFailureCount,
      'rows': rows.map((row) => row.toJson()).toList(growable: false),
    };
  }
}

class PeakProminenceImportResult {
  const PeakProminenceImportResult({
    required this.report,
    required this.previewCsvPath,
    required this.previewCsvContents,
  });

  final PeakProminenceImportReport report;
  final String? previewCsvPath;
  final String? previewCsvContents;
}

class PeakProminenceImportService {
  PeakProminenceImportService({
    required PeakRepository peakRepository,
    PeakProminenceCsvService? csvService,
    PeakProminenceCorrelationService? correlationService,
    PeakProminencePreviewExportService? previewExportService,
    PeakProminenceCsvReader? csvReader,
    PeakProminenceCsvLineReader? csvLineReader,
    PeakProminenceLogWriter? logWriter,
    PeakProminenceClock? clock,
    Future<PeakSaveResult> Function(Peak peak)? savePeak,
    String Function(String csvPath)? logPathResolver,
    PeakProminenceImportProgressCallback? onProgress,
    int progressInterval = 100000,
  }) : _peakRepository = peakRepository,
        _csvService = csvService ?? const PeakProminenceCsvService(),
        _correlationService = correlationService ??
            const PeakProminenceCorrelationService(),
        _previewExportService = previewExportService ??
            PeakProminencePreviewExportService(peakSource: peakRepository),
        _csvReader = csvReader ?? ((path) => File(path).readAsString()),
        _csvLineReader = csvLineReader,
        _logWriter = logWriter ?? _defaultLogWriter,
        _clock = clock ?? DateTime.now,
        _savePeak = savePeak ?? peakRepository.saveDetailed,
        _logPathResolver = logPathResolver ?? _defaultLogPathResolver,
        _onProgress = onProgress,
        _progressInterval = progressInterval;

  final PeakRepository _peakRepository;
  final PeakProminenceCsvService _csvService;
  final PeakProminenceCorrelationService _correlationService;
  final PeakProminencePreviewExportService _previewExportService;
  final PeakProminenceCsvReader _csvReader;
  final PeakProminenceCsvLineReader? _csvLineReader;
  final PeakProminenceLogWriter _logWriter;
  final PeakProminenceClock _clock;
  final Future<PeakSaveResult> Function(Peak peak) _savePeak;
  final String Function(String csvPath) _logPathResolver;
  final PeakProminenceImportProgressCallback? _onProgress;
  final int _progressInterval;

  Future<PeakProminenceImportResult> importCsv({
    required String csvPath,
    bool dryRun = false,
  }) async {
    final peaks = List<Peak>.from(_peakRepository.getAllPeaks());
    final peakIndex = _PeakSpatialIndex(peaks);

    final rowReports = <PeakProminenceImportRowReport>[];
    final projectedProminenceByPeakId = <int, double?>{};
    final matchedPeakIds = <int>{};
    var processedRowCount = 0;
    var matchedCount = 0;
    var updatedCount = 0;
    var unresolvedCsvRowCount = 0;
    var unmatchedPeakCount = 0;
    var writeFailureCount = 0;
    var lastReportedRowCount = 0;

    await for (final row in _rowStream(csvPath)) {
      processedRowCount += 1;
      final candidates = peakIndex.candidatesFor(
        latitude: row.latitude,
        longitude: row.longitude,
      );
      if (candidates.isEmpty) {
        _reportProgressIfNeeded(
          processedRowCount: processedRowCount,
          matchedCount: matchedCount,
          updatedCount: updatedCount,
          unresolvedCsvRowCount: unresolvedCsvRowCount,
          writeFailureCount: writeFailureCount,
          remainingPeakCount: peakIndex.count,
          lastReportedRowCount: lastReportedRowCount,
        );
        if (_shouldReportProgress(processedRowCount, lastReportedRowCount)) {
          lastReportedRowCount = processedRowCount;
        }
        continue;
      }

      final correlation = _correlationService.correlate(row: row, peaks: candidates);

      for (final skippedPeak in correlation.skippedDuplicatePeaks) {
        final skippedDetail =
            'skipped duplicate candidate after selecting Peak ${correlation.peak?.id ?? 'unknown'}';
        rowReports.add(
          PeakProminenceImportRowReport(
            action: 'skipped-duplicate-candidate',
            detail: skippedDetail,
            csvRow: row,
            peak: skippedPeak,
          ),
        );
        await _appendLog(
          path: _defaultEventLogPath(csvPath),
          line: _logLine(
            timestamp: _clock(),
            peakId: skippedPeak.id,
            name: skippedPeak.name,
            action: 'skipped-duplicate-candidate',
            detail: skippedDetail,
          ),
        );
      }

      if (!correlation.isMatched || correlation.peak == null) {
        final detail = correlation.detail;
        unresolvedCsvRowCount += 1;
        rowReports.add(
          PeakProminenceImportRowReport(
            action: 'unresolved-csv-row',
            detail: detail,
            csvRow: row,
          ),
        );
        await _appendLog(
          path: _unresolvedCsvLogPath(csvPath),
          line: _logLineForCsvRow(
            timestamp: _clock(),
            row: row,
            action: 'unresolved-csv-row',
            detail: detail,
          ),
        );
        continue;
      }

      final matchedPeak = correlation.peak!;
      matchedPeakIds.add(matchedPeak.id);
      peakIndex.remove(matchedPeak);
      projectedProminenceByPeakId[matchedPeak.id] = row.prominence;

      if (dryRun) {
        matchedCount += 1;
        rowReports.add(
          PeakProminenceImportRowReport(
            action: 'matched',
            detail: correlation.detail,
            csvRow: row,
            peak: matchedPeak,
          ),
        );
        continue;
      }

      try {
        final updatedPeak = matchedPeak.copyWith(prominence: row.prominence);
        await _savePeak(updatedPeak);
        matchedCount += 1;
        updatedCount += 1;
        rowReports.add(
          PeakProminenceImportRowReport(
            action: 'updated',
            detail: correlation.detail,
            csvRow: row,
            peak: matchedPeak,
          ),
        );
      } catch (error) {
        final detail = 'failed to persist prominence: $error';
        writeFailureCount += 1;
        rowReports.add(
          PeakProminenceImportRowReport(
            action: 'write-failure',
            detail: detail,
            csvRow: row,
            peak: matchedPeak,
          ),
        );
        await _appendLog(
          path: _defaultEventLogPath(csvPath),
          line: _logLine(
            timestamp: _clock(),
            peakId: matchedPeak.id,
            name: matchedPeak.name,
            action: 'write-failure',
            detail: detail,
          ),
        );
      }

      _reportProgressIfNeeded(
        processedRowCount: processedRowCount,
        matchedCount: matchedCount,
        updatedCount: updatedCount,
        unresolvedCsvRowCount: unresolvedCsvRowCount,
        writeFailureCount: writeFailureCount,
        remainingPeakCount: peakIndex.count,
        lastReportedRowCount: lastReportedRowCount,
      );
      if (_shouldReportProgress(processedRowCount, lastReportedRowCount)) {
        lastReportedRowCount = processedRowCount;
      }
    }

    for (final peak in peaks) {
      if (matchedPeakIds.contains(peak.id)) {
        continue;
      }

      final detail = 'not found in dataset';
      unmatchedPeakCount += 1;
      rowReports.add(
        PeakProminenceImportRowReport(
          action: 'not-found-in-dataset',
          detail: detail,
          peak: peak,
        ),
      );
      await _appendLog(
        path: _unmatchedPeakLogPath(csvPath),
        line: _logLine(
          timestamp: _clock(),
          peakId: peak.id,
          name: peak.name,
          action: 'not-found-in-dataset',
          detail: detail,
        ),
      );
    }

    String? previewCsvPath;
    String? previewCsvContents;
    if (dryRun) {
      final preview = await _previewExportService.exportPreview(
        prominenceByPeakId: projectedProminenceByPeakId,
      );
      previewCsvPath = preview.path;
      previewCsvContents = preview.csvContents;
    }

    _emitProgress(
      processedRowCount: processedRowCount,
      matchedCount: matchedCount,
      updatedCount: updatedCount,
      unresolvedCsvRowCount: unresolvedCsvRowCount,
      writeFailureCount: writeFailureCount,
      remainingPeakCount: peakIndex.count,
    );

    return PeakProminenceImportResult(
      report: PeakProminenceImportReport(
        csvPath: csvPath,
        rows: rowReports,
        matchedCount: matchedCount,
        updatedCount: updatedCount,
        unresolvedCsvRowCount: unresolvedCsvRowCount,
        unmatchedPeakCount: unmatchedPeakCount,
        writeFailureCount: writeFailureCount,
      ),
      previewCsvPath: previewCsvPath,
      previewCsvContents: previewCsvContents,
    );
  }

  String _defaultEventLogPath(String csvPath) {
    return _logPathResolver(csvPath);
  }

  String _unresolvedCsvLogPath(String csvPath) {
    return _derivedLogPath(_logPathResolver(csvPath), 'unresolved-csv');
  }

  String _unmatchedPeakLogPath(String csvPath) {
    return _derivedLogPath(_logPathResolver(csvPath), 'not-found-in-dataset');
  }

  String _derivedLogPath(String basePath, String suffix) {
    final directory = p.dirname(basePath);
    final basename = p.basenameWithoutExtension(basePath);
    final extension = p.extension(basePath);
    final fileName = '$basename-$suffix${extension.isEmpty ? '.log' : extension}';
    return p.join(directory, fileName);
  }

  Stream<PeakProminenceCsvRow> _rowStream(String csvPath) async* {
    final lineReader = _csvLineReader;
    if (lineReader != null) {
      yield* _csvService.parseRowStream(lineReader(csvPath));
      return;
    }

    final contents = await _csvReader(csvPath);
    yield* Stream<PeakProminenceCsvRow>.fromIterable(
      _csvService.parseRows(const LineSplitter().convert(contents)),
    );
  }

  void _reportProgressIfNeeded({
    required int processedRowCount,
    required int matchedCount,
    required int updatedCount,
    required int unresolvedCsvRowCount,
    required int writeFailureCount,
    required int remainingPeakCount,
    required int lastReportedRowCount,
  }) {
    if (!_shouldReportProgress(processedRowCount, lastReportedRowCount)) {
      return;
    }

    _emitProgress(
      processedRowCount: processedRowCount,
      matchedCount: matchedCount,
      updatedCount: updatedCount,
      unresolvedCsvRowCount: unresolvedCsvRowCount,
      writeFailureCount: writeFailureCount,
      remainingPeakCount: remainingPeakCount,
    );
  }

  bool _shouldReportProgress(int processedRowCount, int lastReportedRowCount) {
    return _onProgress != null &&
        processedRowCount > 0 &&
        processedRowCount - lastReportedRowCount >= _progressInterval;
  }

  void _emitProgress({
    required int processedRowCount,
    required int matchedCount,
    required int updatedCount,
    required int unresolvedCsvRowCount,
    required int writeFailureCount,
    required int remainingPeakCount,
  }) {
    _onProgress?.call(
      PeakProminenceImportProgress(
        processedRowCount: processedRowCount,
        matchedCount: matchedCount,
        updatedCount: updatedCount,
        unresolvedCsvRowCount: unresolvedCsvRowCount,
        writeFailureCount: writeFailureCount,
        remainingPeakCount: remainingPeakCount,
      ),
    );
  }

  Future<void> _appendLog({required String path, required String line}) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await _logWriter(path, '$line\n');
  }

  String _logLine({
    required DateTime timestamp,
    required int peakId,
    required String name,
    required String action,
    required String detail,
  }) {
    return '${timestamp.toUtc().toIso8601String()} peakId=$peakId name=${_escapeToken(name)} action=$action detail=${_escapeToken(detail)}';
  }

  String _logLineForCsvRow({
    required DateTime timestamp,
    required PeakProminenceCsvRow row,
    required String action,
    required String detail,
  }) {
    return '${timestamp.toUtc().toIso8601String()} latitude=${_formatDouble(row.latitude)} longitude=${_formatDouble(row.longitude)} elevation=${_formatDouble(row.elevation)} action=$action detail=${_escapeToken(detail)}';
  }

  String _escapeToken(String value) {
    return value.replaceAll(RegExp(r'\s+'), '_');
  }

  String _formatDouble(double value) {
    var text = value.toStringAsFixed(6);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    text = text.replaceFirst(RegExp(r'\.$'), '');
    return text;
  }

  static Future<void> _defaultLogWriter(String path, String contents) {
    return File(path).writeAsString(contents, mode: FileMode.append);
  }

  static String _defaultLogPathResolver(String csvPath) {
    return p.join(Directory.current.path, 'logs', 'prominence.log');
  }
}

class _PeakSpatialIndex {
  _PeakSpatialIndex(List<Peak> peaks)
    : _peaksById = {for (final peak in peaks) peak.id: peak} {
    for (final peak in peaks) {
      final key = _cellKeyFor(peak.latitude, peak.longitude);
      (_peaksByCell[key] ??= <Peak>[]).add(peak);
    }
  }

  static const double _cellSizeDegrees = 0.01;

  final Map<String, List<Peak>> _peaksByCell = <String, List<Peak>>{};
  final Map<int, Peak> _peaksById;

  int get count => _peaksById.length;

  List<Peak> candidatesFor({
    required double latitude,
    required double longitude,
  }) {
    final baseLatBucket = _bucketFor(latitude);
    final baseLonBucket = _bucketFor(longitude);
    final candidates = <Peak>[];
    final seenPeakIds = <int>{};

    for (var latOffset = -1; latOffset <= 1; latOffset += 1) {
      for (var lonOffset = -1; lonOffset <= 1; lonOffset += 1) {
        final key = _cellKey(baseLatBucket + latOffset, baseLonBucket + lonOffset);
        for (final peak in _peaksByCell[key] ?? const <Peak>[]) {
          if (seenPeakIds.add(peak.id)) {
            candidates.add(peak);
          }
        }
      }
    }

    return candidates;
  }

  void remove(Peak peak) {
    if (_peaksById.remove(peak.id) == null) {
      return;
    }

    final key = _cellKeyFor(peak.latitude, peak.longitude);
    final cellPeaks = _peaksByCell[key];
    if (cellPeaks == null) {
      return;
    }

    cellPeaks.removeWhere((candidate) => candidate.id == peak.id);
    if (cellPeaks.isEmpty) {
      _peaksByCell.remove(key);
    }
  }

  String _cellKeyFor(double latitude, double longitude) {
    return _cellKey(_bucketFor(latitude), _bucketFor(longitude));
  }

  int _bucketFor(double coordinate) {
    return (coordinate / _cellSizeDegrees).floor();
  }

  String _cellKey(int latBucket, int lonBucket) => '$latBucket:$lonBucket';
}
