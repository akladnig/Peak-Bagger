import 'dart:io';

import 'package:peak_bagger/services/route_graph_peak_list_generation_service.dart';

const _defaultRegionKey = 'tasmania';
const _defaultPeakSourceDescription =
    '~/Documents/Bushwalking/Features/peaks.csv';
const _defaultOutputDescription =
    '~/Documents/Bushwalking/Peak_Lists/<canonical-region>-route-graph-peak-list.csv';

class _Invocation {
  const _Invocation({
    required this.showHelp,
    required this.regionKey,
    required this.outputPath,
  });

  final bool showHelp;
  final String regionKey;
  final String? outputPath;
}

void main(List<String> args) async {
  final exitCode = await runRouteGraphPeakListTool(args: args);
  exit(exitCode);
}

Future<int> runRouteGraphPeakListTool({
  List<String> args = const [],
  RouteGraphPeakListGenerationService? service,
  void Function(String message)? stdoutWriter,
  void Function(String message)? stderrWriter,
}) async {
  final stdoutLine =
      stdoutWriter ?? ((String message) => stdout.writeln(message));
  final stderrLine =
      stderrWriter ?? ((String message) => stderr.writeln(message));

  late final _Invocation invocation;
  try {
    invocation = _parseInvocation(args);
  } on Object catch (error) {
    stderrLine(_errorMessage(error));
    return 1;
  }

  final resolvedService = service ?? RouteGraphPeakListGenerationService();
  if (invocation.showHelp) {
    try {
      final supportedRegions = await resolvedService.supportedRegionKeys();
      stdoutLine(_usage(supportedRegions));
      return 0;
    } on Object catch (error) {
      stderrLine(_errorMessage(error));
      return 1;
    }
  }

  try {
    final result = await resolvedService.generate(
      regionKey: invocation.regionKey,
      outputPath: invocation.outputPath,
    );
    stdoutLine(
      'Wrote ${result.matchedPeakCount} matched peaks to ${result.outputPath}',
    );
    return 0;
  } on Object catch (error) {
    stderrLine(_errorMessage(error));
    return 1;
  }
}

_Invocation _parseInvocation(List<String> args) {
  var showHelp = false;
  var regionKey = _defaultRegionKey;
  String? outputPath;
  var regionSet = false;
  var outputSet = false;

  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (arg == '--help' || arg == '-h') {
      if (showHelp) {
        throw ArgumentError('Help may only be requested once.');
      }
      showHelp = true;
      continue;
    }
    if (arg == '--region') {
      if (regionSet) {
        throw ArgumentError('--region may only be specified once.');
      }
      if (index + 1 >= args.length || args[index + 1].startsWith('-')) {
        throw ArgumentError('Missing value for --region.');
      }
      regionKey = _normalizeRegionKey(args[++index]);
      if (regionKey.isEmpty) {
        throw ArgumentError('--region must not be blank.');
      }
      regionSet = true;
      continue;
    }
    if (arg == '--output') {
      if (outputSet) {
        throw ArgumentError('--output may only be specified once.');
      }
      if (index + 1 >= args.length || args[index + 1].startsWith('-')) {
        throw ArgumentError('Missing value for --output.');
      }
      outputPath = args[++index];
      if (outputPath.isEmpty) {
        throw ArgumentError('--output must not be blank.');
      }
      outputSet = true;
      continue;
    }
    throw ArgumentError(
      arg.startsWith('-')
          ? 'Unknown option: $arg'
          : 'Positional arguments are not supported: $arg',
    );
  }

  if (showHelp && args.length != 1) {
    throw ArgumentError('--help cannot be combined with other arguments.');
  }

  return _Invocation(
    showHelp: showHelp,
    regionKey: regionKey,
    outputPath: outputPath,
  );
}

String _usage(List<String> supportedRegions) {
  final regions = supportedRegions.map((region) => '  $region').join('\n');
  return '''
Usage:
  ./route_graph_peak_list.sh [--region <manifest-key>] [--output <path>]

Options:
  --region <manifest-key>  Route-graph manifest region (case-insensitive).
  --output <path>          Exact destination CSV path.
  --help, -h               Show this help without reading or writing peak data.

Defaults:
  region: $_defaultRegionKey
  peak source: $_defaultPeakSourceDescription
  output: $_defaultOutputDescription

Supported route-graph regions:
$regions
''';
}

String _normalizeRegionKey(String value) => value.trim().toLowerCase();

String _errorMessage(Object error) {
  final message = error.toString();
  for (final prefix in const [
    'Bad state: ',
    'ArgumentError: ',
    'Exception: ',
  ]) {
    if (message.startsWith(prefix)) {
      return message.substring(prefix.length);
    }
  }
  return message;
}
