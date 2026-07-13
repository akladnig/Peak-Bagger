import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/peak_prominence_import_service.dart';

import '../../tool/peak_prominence_csv.dart';

void main() {
  List<String> stdoutLines = [];
  List<String> stderrLines = [];

  setUp(() {
    stdoutLines = [];
    stderrLines = [];
  });

  PeakProminenceImportResult buildResult({required int writeFailureCount}) {
    return PeakProminenceImportResult(
      report: PeakProminenceImportReport(
        csvPath: 'input.csv',
        rows: [
          PeakProminenceImportRowReport(action: 'updated', detail: 'ok'),
          if (writeFailureCount > 0)
            PeakProminenceImportRowReport(
              action: 'write-failure',
              detail: 'boom',
            ),
        ],
      ),
      previewCsvPath: './tool/peak-prominence-objectbox-preview.csv',
      previewCsvContents: 'preview',
    );
  }

  test('validates the default csv path when asked', () async {
    final exitCode = await runPeakProminenceCsvTool(
      args: ['validate'],
      csvReader: (path) async {
        expect(path, './assets/all-peaks-sorted-p100.csv');
        return '1,2,3,4,5,6\n0,0,0,0,0,0';
      },
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(stderrLines, isEmpty);
    expect(stdoutLines.single, contains('Validated 2 rows'));
  });

  test('fails validation on malformed input', () async {
    final exitCode = await runPeakProminenceCsvTool(
      args: ['validate', '--csv-path', 'input.csv'],
      csvReader: (_) async => '1,2,3,4,5',
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stdoutLines, isEmpty);
    expect(stderrLines.single, contains('PeakProminenceCsvFormatException'));
  });

  test('runs import in dry-run mode and reports the preview path', () async {
    final invocations = <(String csvPath, bool dryRun)>[];
    final exitCode = await runPeakProminenceCsvTool(
      args: ['--dry-run', '--csv-path', 'custom.csv'],
      importRunner: (csvPath, dryRun) async {
        invocations.add((csvPath, dryRun));
        return buildResult(writeFailureCount: 0);
      },
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(invocations.single, ('custom.csv', true));
    expect(stderrLines, isEmpty);
    expect(
      stdoutLines.join('\n'),
      contains(
        'Preview written to ./tool/peak-prominence-objectbox-preview.csv',
      ),
    );
    expect(stdoutLines.join('\n'), contains('Matched 1, updated 1'));
  });

  test('returns a non-zero exit code after a write failure', () async {
    final exitCode = await runPeakProminenceCsvTool(
      args: const ['import'],
      importRunner: (csvPath, dryRun) async {
        expect(csvPath, './assets/all-peaks-sorted-p100.csv');
        expect(dryRun, isFalse);
        return buildResult(writeFailureCount: 1);
      },
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines, isEmpty);
    expect(stdoutLines.join('\n'), contains('write failures 1'));
  });
}
