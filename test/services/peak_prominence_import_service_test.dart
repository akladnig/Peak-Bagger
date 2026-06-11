import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_prominence_import_service.dart';
import 'package:peak_bagger/services/peak_prominence_preview_export_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('peak-prominence-import');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  PeakProminenceImportService buildService({
    required PeakRepository repository,
    required Future<String> Function(String path) csvReader,
    required Map<String, String> logWrites,
    Future<PeakSaveResult> Function(Peak peak)? savePeak,
    bool dryRunPreviewInToolDir = false,
    void Function(PeakProminenceImportProgress progress)? onProgress,
    int progressInterval = 100000,
  }) {
    return PeakProminenceImportService(
      peakRepository: repository,
      csvReader: csvReader,
      previewExportService: PeakProminencePreviewExportService(
        peakSource: repository,
        outputDirectory: dryRunPreviewInToolDir ? null : tempDir,
      ),
      logWriter: (path, contents) async {
        logWrites[path] = (logWrites[path] ?? '') + contents;
      },
      logPathResolver: (_) => '${tempDir.path}/logs/prominence.log',
      savePeak: savePeak,
      clock: () => DateTime.utc(2026, 1, 1, 12, 0, 0),
      onProgress: onProgress,
      progressInterval: progressInterval,
    );
  }

  test('creates dry-run preview, logs unresolved rows, and logs unmatched peaks', () async {
    final repository = PeakRepository.test(
      InMemoryPeakStorage([
        Peak(
          id: 1,
          osmId: 100,
          name: 'Mt Anne',
          latitude: -41.5001,
          longitude: 146.5001,
          elevation: 1100,
          prominence: null,
        ),
        Peak(
          id: 2,
          osmId: 200,
          name: 'Mt Ossa',
          latitude: -41.88,
          longitude: 146.45,
          elevation: 1617,
          prominence: 100,
        ),
      ]),
    );
    final logWrites = <String, String>{};
    final service = buildService(
      repository: repository,
      csvReader: (_) async => '''
 -41.5001,146.5001,1100,0,0,1100
-41.88,146.45,1000,0,0,1000
''',
      logWrites: logWrites,
    );

    final result = await service.importCsv(csvPath: 'input.csv', dryRun: true);

    expect(result.previewCsvPath, '${tempDir.path}/peak-prominence-objectbox-preview.csv');
    expect(result.report.matchedCount, 1);
    expect(result.report.updatedCount, 0);
    expect(result.report.unresolvedCsvRowCount, 1);
    expect(result.report.unmatchedPeakCount, 1);
    expect(result.report.writeFailureCount, 0);
    expect(logWrites['${tempDir.path}/logs/prominence-unresolved-csv.log'], contains('action=unresolved-csv-row'));
    expect(logWrites['${tempDir.path}/logs/prominence-not-found-in-dataset.log'], contains('action=not-found-in-dataset'));

    final previewRows = const CsvToListConverter(eol: '\n').convert(
      result.previewCsvContents!,
    );
    expect(previewRows.first.cast<String>(), [
      'id',
      'region',
      'name',
      'latitude',
      'longitude',
      'elevation',
      'prominence',
    ]);
    expect(previewRows[1][0].toString(), '1');
    expect(previewRows[1][6].toString(), '1100.0');
    expect(previewRows[2][0].toString(), '2');
    expect(previewRows[2][6].toString(), '100.0');
  });

  test('reports progress while processing rows', () async {
    final repository = PeakRepository.test(
      InMemoryPeakStorage([
        Peak(
          id: 1,
          osmId: 100,
          name: 'Mt Anne',
          latitude: -41.5001,
          longitude: 146.5001,
          elevation: 1100,
          prominence: null,
        ),
      ]),
    );
    final progress = <PeakProminenceImportProgress>[];
    final service = buildService(
      repository: repository,
      csvReader: (_) async => '''
-41.5001,146.5001,1100,0,0,1100
0.0000,0.0000,0.0000,0.0000,0.0000,0.0000
''',
      logWrites: <String, String>{},
      onProgress: progress.add,
      progressInterval: 1,
    );

    final result = await service.importCsv(csvPath: 'input.csv', dryRun: true);

    expect(result.report.matchedCount, 1);
    expect(progress, isNotEmpty);
    expect(progress.last.processedRowCount, 2);
    expect(progress.last.matchedCount, 1);
    expect(progress.last.remainingPeakCount, 0);
  });

  test('continues after a write failure and reports the failure count', () async {
    final repository = PeakRepository.test(
      InMemoryPeakStorage([
        Peak(
          id: 1,
          osmId: 100,
          name: 'Mt Anne',
          latitude: -41.5001,
          longitude: 146.5001,
          elevation: 1100,
          prominence: null,
        ),
        Peak(
          id: 2,
          osmId: 200,
          name: 'Mt Ossa',
          latitude: -41.88,
          longitude: 146.45,
          elevation: 1617,
          prominence: null,
        ),
        Peak(
          id: 3,
          osmId: 300,
          name: 'Mt Pelion East',
          latitude: -41.73,
          longitude: 146.58,
          elevation: 1546,
          prominence: 1546,
        ),
      ]),
    );
    final logWrites = <String, String>{};
    final service = buildService(
      repository: repository,
      csvReader: (_) async => '''
-41.88,146.45,1617,0,0,1617
-41.5001,146.5001,1100,0,0,1100
''',
      logWrites: logWrites,
      savePeak: (peak) async {
        if (peak.id == 2) {
          throw StateError('boom');
        }
        return PeakSaveResult(peak: peak);
      },
    );

    final result = await service.importCsv(csvPath: 'input.csv', dryRun: false);

    expect(result.report.matchedCount, 1);
    expect(result.report.updatedCount, 1);
    expect(result.report.writeFailureCount, 1);
    expect(result.report.unmatchedPeakCount, 1);
    expect(logWrites['${tempDir.path}/logs/prominence.log'], contains('action=write-failure'));
    expect(logWrites['${tempDir.path}/logs/prominence-not-found-in-dataset.log'], contains('action=not-found-in-dataset'));
  });
}
