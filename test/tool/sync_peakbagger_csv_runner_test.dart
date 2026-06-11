import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/sync_peakbagger_csv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final enabled = Platform.environment['PEAKBAGGER_RUN_SYNC_TEST'] == 'true';

  test(
    'runs PeakBagger CSV sync',
    () async {
      final progressFilePath = Platform.environment['PEAKBAGGER_PROGRESS_FILE'];
      final argsFilePath = Platform.environment['PEAKBAGGER_SYNC_ARGS_FILE'];
      final summaryFilePath =
          Platform.environment['PEAKBAGGER_SYNC_SUMMARY_FILE'];

      RandomAccessFile? progressFile;
      if (progressFilePath != null && progressFilePath.isNotEmpty) {
        final file = File(progressFilePath);
        file.parent.createSync(recursive: true);
        progressFile = file.openSync(mode: FileMode.writeOnlyAppend);
      }

      final args = argsFilePath == null || argsFilePath.isEmpty
          ? const <String>[]
          : File(argsFilePath)
                .readAsLinesSync()
                .where((line) => line.isNotEmpty)
                .toList(growable: false);

      final result = await runSyncPeakBaggerCsvTool(
        args: args,
        progressFile: progressFile,
        warningWriter: stderr.writeln,
      );

      final summary = Map<String, dynamic>.from(result.report.toJson())
        ..remove('rows');
      final summaryText = jsonEncode(summary);
      if (summaryFilePath != null && summaryFilePath.isNotEmpty) {
        File(summaryFilePath).writeAsStringSync(summaryText);
      } else {
        stdout.writeln(summaryText);
      }

      expect(result.report.csvPath, result.outputCsvPath);
      progressFile?.closeSync();
    },
    timeout: Timeout.none,
    skip: !enabled,
  );
}
