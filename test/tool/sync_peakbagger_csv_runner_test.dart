import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peakbagger_csv_sync_service.dart';
import 'package:peak_bagger/services/peakbagger_scraper.dart';

import '../../tool/sync_peakbagger_csv.dart';

class _SmokeScraper implements PeakBaggerScraper {
  @override
  Future<void> verifyAvailable() async {}

  @override
  Future<PeakBaggerPeakDetails> showPeak(int peakbaggerPid) async {
    return PeakBaggerPeakDetails(
      peakbaggerPid: peakbaggerPid,
      name: 'Peak $peakbaggerPid',
      latitude: 0,
      longitude: 0,
    );
  }
}

class _SmokeService extends PeakBaggerCsvSyncService {
  _SmokeService(this.onRowProcessed, this.rowCount)
      : super(
          peakSource: PeakRepository.test(InMemoryPeakStorage(const [])),
          scraper: _SmokeScraper(),
        );

  final PeakBaggerCsvRowProgress? onRowProcessed;
  final int rowCount;

  @override
  Future<PeakBaggerCsvSyncResult> syncCsv({
    required String csvPath,
    bool createUnmatchedPeaks = false,
    bool allowLiveLookups = true,
  }) async {
    for (var processed = 1; processed <= rowCount; processed++) {
      onRowProcessed?.call(processed, rowCount);
    }

    final sourceCsvPath = csvPath.endsWith('-lat-lon.csv')
        ? csvPath.replaceFirst('-lat-lon.csv', '.csv')
        : csvPath;
    final outputCsvPath =
        '${p.withoutExtension(sourceCsvPath)}-processed${p.extension(sourceCsvPath).isEmpty ? '.csv' : p.extension(sourceCsvPath)}';
    return PeakBaggerCsvSyncResult(
      outputCsvPath: outputCsvPath,
      csvContents: 'csv',
      report: PeakBaggerCsvSyncReport(
        csvPath: outputCsvPath,
        rows: const [
          PeakBaggerCsvSyncRowReport(
            rowNumber: 2,
            peakbaggerPid: 74023,
            osmId: 1,
            action: 'spatial-match',
            detail: 'matched within 50m/10m window',
            note: 'matched via strong spatial match',
          ),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['PEAKBAGGER_RUN_SYNC_TEST'] == 'true';

  test(
    'runs PeakBagger CSV sync',
    () async {
      var processedRows = 0;
      final progressFilePath = Platform.environment['PEAKBAGGER_PROGRESS_FILE'];
      RandomAccessFile? progressFile;
      if (progressFilePath != null && progressFilePath.isNotEmpty) {
        final file = File(progressFilePath);
        file.parent.createSync(recursive: true);
        progressFile = file.openSync(mode: FileMode.writeOnlyAppend);
      }
      final csvPath =
          Platform.environment['PEAKBAGGER_SYNC_CSV_PATH'] ??
          'peak-bagger-peak-data.csv';
      final createUnmatchedPeaks =
          Platform.environment['PEAKBAGGER_CREATE_UNMATCHED_PEAKS'] == 'true';
      final sourceCsvPath = csvPath.endsWith('-lat-lon.csv')
          ? csvPath.replaceFirst('-lat-lon.csv', '.csv')
          : csvPath;
      final rowCount = _csvRowCount(sourceCsvPath);

      final service = _SmokeService((processed, total) {
        processedRows = processed;
        _writeProgress(progressFile, '.');
        if (processed % 100 == 0 || processed == total) {
          _writeProgress(progressFile, ' $processed/$total\n');
        }
      }, rowCount);

      final result = await syncPeakBaggerCsv(
        csvPath: csvPath,
        createUnmatchedPeaks: createUnmatchedPeaks,
        service: service,
      );

      if (processedRows > 0 && processedRows % 100 != 0) {
        _writeProgress(progressFile, ' $processedRows/$rowCount\n');
      }
      final summary = result.report.toJson();
      summary['processedCount'] = rowCount;
      summary.remove('rows');
      stdout.writeln(jsonEncode(summary));
      progressFile?.closeSync();
      expect(result.report.csvPath, result.outputCsvPath);
      final expectedOutput = '${p.withoutExtension(csvPath)}-processed${p.extension(csvPath).isEmpty ? '.csv' : p.extension(csvPath)}';
      expect(result.outputCsvPath, expectedOutput);
    },
    timeout: Timeout.none,
    skip: !enabled,
  );
}

int _csvRowCount(String csvPath) {
  final rows = const CsvToListConverter(
    shouldParseNumbers: false,
    eol: '\n',
  ).convert(File(csvPath).readAsStringSync());
  return rows.isEmpty ? 0 : rows.length - 1;
}

void _writeProgress(RandomAccessFile? progressFile, String text) {
  if (progressFile != null) {
    progressFile.writeStringSync(text);
    progressFile.flushSync();
    return;
  }

  stderr.write(text);
}
