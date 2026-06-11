import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/peak_prominence_csv_service.dart';
import 'package:peak_bagger/services/peak_prominence_import_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';

const String _defaultCsvPath = './assets/all-peaks-sorted-p100.csv';

enum _PeakProminenceCommand { validate, importData }

class _PeakProminenceInvocation {
  const _PeakProminenceInvocation({
    required this.command,
    required this.csvPath,
    required this.dryRun,
    required this.showHelp,
  });

  final _PeakProminenceCommand command;
  final String csvPath;
  final bool dryRun;
  final bool showHelp;
}

typedef PeakProminenceImportRunner = Future<PeakProminenceImportResult> Function(
  String csvPath,
  bool dryRun,
);

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final exitCode = await runPeakProminenceCsvTool(args: args);
  exit(exitCode);
}

Future<int> runPeakProminenceCsvTool({
  List<String> args = const [],
  Future<String> Function(String path)? csvReader,
  PeakProminenceImportRunner? importRunner,
  PeakProminenceCsvService? csvService,
  void Function(String message)? stdoutWriter,
  void Function(String message)? stderrWriter,
}) async {
  final stdoutLine = stdoutWriter ??
      ((String message) => stdout.writeln(message));
  final stderrLine = stderrWriter ??
      ((String message) => stderr.writeln(message));
  final parser = csvService ?? const PeakProminenceCsvService();
  final reader = csvReader ?? ((String path) => File(path).readAsString());

  late final _PeakProminenceInvocation invocation;
  try {
    invocation = _parseInvocation(args);
  } on Object catch (error) {
    stderrLine(error.toString());
    stdoutLine(_usage());
    return 1;
  }

  if (invocation.showHelp) {
    stdoutLine(_usage());
    return 0;
  }

  if (invocation.command == _PeakProminenceCommand.validate && invocation.dryRun) {
    stderrLine('--dry-run can only be used with import mode');
    return 1;
  }

  if (invocation.command == _PeakProminenceCommand.validate) {
    try {
      final contents = await reader(invocation.csvPath);
      final document = parser.parse(contents);
      stdoutLine('Validated ${document.rows.length} rows from ${invocation.csvPath}');
      return 0;
    } on Object catch (error) {
      stderrLine(error.toString());
      return 1;
    }
  }

  final runner = importRunner ?? _defaultImportRunner(reader, stdoutLine);

  try {
    final result = await runner(invocation.csvPath, invocation.dryRun);
    final report = result.report;
    stdoutLine(
      'Matched ${report.matchedCount}, updated ${report.updatedCount}, '
      'unresolved ${report.unresolvedCsvRowCount}, unmatched ${report.unmatchedPeakCount}, '
      'write failures ${report.writeFailureCount}',
    );
    if (result.previewCsvPath != null) {
      stdoutLine('Preview written to ${result.previewCsvPath}');
    }
    return report.writeFailureCount > 0 ? 1 : 0;
  } on Object catch (error) {
    stderrLine(error.toString());
    return 1;
  }
}

PeakProminenceImportRunner _defaultImportRunner(
  Future<String> Function(String path) csvReader,
  void Function(String message) stdoutLine,
) {
  return (String csvPath, bool dryRun) async {
    final store = await openStore();
    final repository = PeakRepository(
      store,
      peakListRewritePort: ObjectBoxPeakListRewritePort(store),
    );
    final service = PeakProminenceImportService(
      peakRepository: repository,
      csvReader: csvReader,
      onProgress: (progress) {
        stdoutLine(
          'Processed ${progress.processedRowCount} rows, '
          'matched ${progress.matchedCount}, '
          'updated ${progress.updatedCount}, '
          'unresolved ${progress.unresolvedCsvRowCount}, '
          'write failures ${progress.writeFailureCount}, '
          'remaining peaks ${progress.remainingPeakCount}',
        );
      },
    );
    return service.importCsv(csvPath: csvPath, dryRun: dryRun);
  };
}

_PeakProminenceInvocation _parseInvocation(List<String> args) {
  var command = _PeakProminenceCommand.importData;
  var csvPath = _defaultCsvPath;
  var dryRun = false;
  var showHelp = false;
  var csvPathSet = false;

  for (var index = 0; index < args.length; index++) {
    final arg = args[index];

    if (arg == '--help' || arg == '-h') {
      showHelp = true;
      continue;
    }

    if (arg == '--dry-run') {
      dryRun = true;
      continue;
    }

    if (arg == 'validate') {
      command = _PeakProminenceCommand.validate;
      continue;
    }

    if (arg == 'import') {
      command = _PeakProminenceCommand.importData;
      continue;
    }

    if (arg == '--csv-path') {
      if (index + 1 >= args.length) {
        throw ArgumentError('Missing value for --csv-path');
      }
      if (csvPathSet) {
        throw ArgumentError('CSV path specified more than once');
      }
      csvPath = args[++index];
      csvPathSet = true;
      continue;
    }

    if (arg.startsWith('--csv-path=')) {
      if (csvPathSet) {
        throw ArgumentError('CSV path specified more than once');
      }
      csvPath = arg.substring('--csv-path='.length);
      csvPathSet = true;
      continue;
    }

    if (arg.startsWith('-')) {
      throw ArgumentError('Unknown flag: $arg');
    }

    if (csvPathSet) {
      throw ArgumentError('CSV path specified more than once');
    }

    csvPath = arg;
    csvPathSet = true;
  }

  return _PeakProminenceInvocation(
    command: command,
    csvPath: csvPath,
    dryRun: dryRun,
    showHelp: showHelp,
  );
}

String _usage() {
  return '''
Usage:
  ./peak_prominence_csv.sh validate [--csv-path PATH]
  ./peak_prominence_csv.sh import [--dry-run] [--csv-path PATH]

Defaults:
  csv-path: $_defaultCsvPath
  dry-run preview: ./tool/peak-prominence-objectbox-preview.csv
  log paths:
    ./logs/prominence.log
    ./logs/prominence-unresolved-csv.log
    ./logs/prominence-not-found-in-dataset.log
''';
}
