import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peak_source.dart';
import 'package:peak_bagger/services/slovenia_hribi_source_peak_list_service.dart';

typedef SloveniaPeakSourceLoader = Future<PeakSource> Function();

class _Invocation {
  const _Invocation({
    required this.showHelp,
    required this.outputDirectoryPath,
    required this.repairList,
    required this.refreshCache,
    required this.tieWindowMeters,
  });

  final bool showHelp;
  final String outputDirectoryPath;
  final bool repairList;
  final bool refreshCache;
  final int tieWindowMeters;
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
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

  _OwnedPeakSource? ownedPeakSource;
  final resolvedService = service ?? await () async {
    final peakSource = await (peakSourceLoader ?? _defaultPeakSourceLoader)();
    if (peakSource is _OwnedPeakSource) {
      ownedPeakSource = peakSource;
    }
    return SloveniaHribiSourcePeakListService(
      pageLoader: pageLoader,
      peakSource: peakSource,
      outputDirectoryResolver: () => Directory(invocation.outputDirectoryPath),
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
  } finally {
    ownedPeakSource?.close();
  }
}

_Invocation _parseInvocation(List<String> args) {
  var showHelp = false;
  var outputDirectoryPath = p.join('.', 'assets', 'peaks');
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
    repairList: repairList,
    refreshCache: refreshCache,
    tieWindowMeters: tieWindowMeters,
  );
}

String _usage() {
  return '''
Usage:
  dart run tool/slovenia_hribi_source_peak_list.dart [--repair-list] [--refresh-cache] [--tie-window-meters N] [--output-dir PATH]

Defaults:
  output-dir: ./assets/peaks
  tie-window-meters: 10
''';
}

Future<PeakSource> _defaultPeakSourceLoader() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await openStore();
  final repository = PeakRepository(
    store,
    peakListRewritePort: ObjectBoxPeakListRewritePort(store),
  );
  return _OwnedPeakSource(store: store, delegate: repository);
}

class _OwnedPeakSource implements PeakSource {
  _OwnedPeakSource({required this._store, required this._delegate});

  final Store _store;
  final PeakSource _delegate;

  @override
  List<Peak> getAllPeaks() => _delegate.getAllPeaks();

  void close() {
    _store.close();
  }
}
