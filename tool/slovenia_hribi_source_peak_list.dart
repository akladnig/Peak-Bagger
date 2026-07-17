import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/peak_csv_source.dart';
import 'package:peak_bagger/services/peak_source.dart';
import 'package:peak_bagger/services/slovenia_hribi_source_peak_list_service.dart';

typedef SloveniaPeakSourceLoader = Future<PeakSource> Function();

const _defaultPeaksCsvPath =
    '/Users/adrian/Documents/Bushwalking/Features/peaks.csv';

class _Invocation {
  const _Invocation({
    required this.showHelp,
    required this.outputDirectoryPath,
    required this.peaksCsvPath,
    required this.sourceOfTruth,
    required this.repairList,
    required this.refreshCache,
    required this.tieWindowMeters,
  });

  final bool showHelp;
  final String outputDirectoryPath;
  final String peaksCsvPath;
  final String? sourceOfTruth;
  final bool repairList;
  final bool refreshCache;
  final int tieWindowMeters;
}

void main(List<String> args) async {
  final exitCode = await runSloveniaHribiSourcePeakListTool(args: args);
  exit(exitCode);
}

Future<int> runSloveniaHribiSourcePeakListTool({
  List<String> args = const [],
  SloveniaHribiSourcePeakListService? service,
  SloveniaHribiSourcePageLoader? pageLoader,
  SloveniaPeakSourceLoader? peakSourceLoader,
  Directory Function()? cacheDirectoryResolver,
  List<SloveniaHribiSourceRangeConfig>? rangeConfigurations,
  void Function(String message)? stdoutWriter,
  void Function(String message)? stderrWriter,
}) async {
  final void Function(String message) stdoutLine =
      stdoutWriter ?? ((message) => stdout.writeln(message));
  final void Function(String message) stderrLine =
      stderrWriter ?? ((message) => stderr.writeln(message));

  late final _Invocation invocation;
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

  final resolvedService =
      service ??
      await () async {
        final peakSource =
            await (peakSourceLoader ??
                () => _defaultPeakSourceLoader(invocation.peaksCsvPath))();
        return SloveniaHribiSourcePeakListService(
          pageLoader: pageLoader,
          peakSource: peakSource,
          outputDirectoryResolver: () =>
              Directory(invocation.outputDirectoryPath),
          cacheDirectoryResolver: cacheDirectoryResolver,
          rangeConfigurations:
              rangeConfigurations ?? sloveniaHribiSourceRangeConfigurations,
          onProgress: stdoutLine,
        );
      }();

  try {
    final result = await resolvedService.run(
      repairList: invocation.repairList,
      refreshCache: invocation.refreshCache,
      tieWindowMeters: invocation.tieWindowMeters,
      sourceOfTruth: invocation.sourceOfTruth,
    );
    if (!result.createdNewVersion) {
      stdoutLine(
        'No changes detected. Reusing existing version V${result.version}.',
      );
    } else {
      stdoutLine(
        'Wrote Slovenia ranked peak list with ${result.canonicalRows.length} rows to ${result.csvPath}',
      );
      stdoutLine(
        'Correlation review CSV written with ${result.reviewRows.length} rows to ${result.reviewPath}',
      );
      stdoutLine(
        'Repair list written with ${result.repairEntries.length} entries to ${result.repairPath}',
      );
      stdoutLine('State written to ${result.statePath}');
    }
    for (final summary in result.summaries) {
      stderrLine(summary);
    }
    return 0;
  } on Object catch (error) {
    stderrLine(error.toString());
    return 1;
  }
}

_Invocation _parseInvocation(List<String> args) {
  var showHelp = false;
  var outputDirectoryPath = p.join('.', 'assets', 'peaks');
  var peaksCsvPath = _defaultPeaksCsvPath;
  String? sourceOfTruth;
  var repairList = false;
  var refreshCache = false;
  var tieWindowMeters = 10;

  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (arg == '--help' || arg == '-h') {
      showHelp = true;
      continue;
    }
    if (arg == '--output-dir') {
      if (index + 1 >= args.length) {
        throw ArgumentError('Missing value for --output-dir');
      }
      outputDirectoryPath = args[++index];
      continue;
    }
    if (arg.startsWith('--output-dir=')) {
      outputDirectoryPath = arg.substring('--output-dir='.length);
      continue;
    }
    if (arg == '--peaks-csv') {
      if (index + 1 >= args.length) {
        throw ArgumentError('Missing value for --peaks-csv');
      }
      peaksCsvPath = args[++index];
      continue;
    }
    if (arg.startsWith('--peaks-csv=')) {
      peaksCsvPath = arg.substring('--peaks-csv='.length);
      continue;
    }
    if (arg == '--source-of-truth') {
      if (index + 1 >= args.length) {
        throw ArgumentError('Missing value for --source-of-truth');
      }
      sourceOfTruth = args[++index];
      continue;
    }
    if (arg.startsWith('--source-of-truth=')) {
      sourceOfTruth = arg.substring('--source-of-truth='.length);
      continue;
    }
    if (arg == '--repair-list') {
      repairList = true;
      continue;
    }
    if (arg == '--refresh-cache') {
      refreshCache = true;
      continue;
    }
    if (arg == '--tie-window-meters') {
      if (index + 1 >= args.length) {
        throw ArgumentError('Missing value for --tie-window-meters');
      }
      tieWindowMeters = int.parse(args[++index]);
      if (tieWindowMeters < 0) {
        throw ArgumentError('Tie window must be non-negative');
      }
      continue;
    }
    if (arg.startsWith('--tie-window-meters=')) {
      tieWindowMeters = int.parse(arg.substring('--tie-window-meters='.length));
      if (tieWindowMeters < 0) {
        throw ArgumentError('Tie window must be non-negative');
      }
      continue;
    }
    throw ArgumentError('Unknown flag: $arg');
  }

  return _Invocation(
    showHelp: showHelp,
    outputDirectoryPath: outputDirectoryPath,
    peaksCsvPath: peaksCsvPath,
    sourceOfTruth: sourceOfTruth,
    repairList: repairList,
    refreshCache: refreshCache,
    tieWindowMeters: tieWindowMeters,
  );
}

String _usage() {
  return '''
Usage:
  dart run tool/slovenia_hribi_source_peak_list.dart [--source-of-truth VALUE] [--repair-list] [--refresh-cache] [--tie-window-meters N] [--output-dir PATH] [--peaks-csv PATH]

Defaults:
  output-dir: ./assets/peaks
  peaks-csv: $_defaultPeaksCsvPath
  tie-window-meters: 10
''';
}

Future<PeakSource> _defaultPeakSourceLoader(String csvPath) {
  return PeakCsvSource.load(csvPath);
}
