import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/route_graph_peak_list_generation_service.dart';

import '../../tool/route_graph_peak_list.dart';

void main() {
  List<String> stdoutLines = [];
  List<String> stderrLines = [];

  setUp(() {
    stdoutLines = [];
    stderrLines = [];
  });

  test('defaults the region and reports successful generation', () async {
    final service = _CapturingService();

    final exitCode = await runRouteGraphPeakListTool(
      service: service,
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(service.regionKey, 'tasmania');
    expect(service.outputPath, isNull);
    expect(stdoutLines.single, 'Wrote 2 matched peaks to /tmp/matches.csv');
    expect(stderrLines, isEmpty);
  });

  test(
    'normalizes a region key and forwards an explicit output path',
    () async {
      final service = _CapturingService();

      final exitCode = await runRouteGraphPeakListTool(
        args: const ['--region', ' FVG ', '--output', '/tmp/fvg.csv'],
        service: service,
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(service.regionKey, 'fvg');
      expect(service.outputPath, '/tmp/fvg.csv');
      expect(stderrLines, isEmpty);
    },
  );

  test(
    'prints help and lists supported canonical regions without generating',
    () async {
      final service = _CapturingService(
        supportedRegions: const ['fvg', 'tasmania'],
      );

      final exitCode = await runRouteGraphPeakListTool(
        args: const ['--help'],
        service: service,
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(service.generateCallCount, 0);
      expect(service.supportedRegionsCallCount, 1);
      expect(stderrLines, isEmpty);
      expect(stdoutLines.single, contains('./route_graph_peak_list.sh'));
      expect(stdoutLines.single, contains('--region <manifest-key>'));
      expect(stdoutLines.single, contains('--output <path>'));
      expect(stdoutLines.single, contains('--help, -h'));
      expect(stdoutLines.single, contains('region: tasmania'));
      expect(
        stdoutLines.single,
        contains('~/Documents/Bushwalking/Features/peaks.csv'),
      );
      expect(
        stdoutLines.single,
        contains('<canonical-region>-route-graph-peak-list.csv'),
      );
      expect(stdoutLines.single, contains('  fvg'));
      expect(stdoutLines.single, contains('  tasmania'));
    },
  );

  test('rejects unsupported syntax and positional arguments', () async {
    for (final args in const [
      ['--region'],
      ['--output'],
      ['--unknown'],
      ['tasmania'],
      ['--region=tasmania'],
      ['--help', '--region', 'tasmania'],
    ]) {
      final exitCode = await runRouteGraphPeakListTool(
        args: args,
        service: _CapturingService(),
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1, reason: args.join(' '));
      expect(stderrLines, isNotEmpty, reason: args.join(' '));
      expect(stdoutLines, isEmpty, reason: args.join(' '));
      stdoutLines = [];
      stderrLines = [];
    }
  });

  test('reports service failures on stderr with exit code one', () async {
    final exitCode = await runRouteGraphPeakListTool(
      args: const ['--region', 'unknown'],
      service: _CapturingService(
        failure: const RouteGraphPeakListGenerationException(
          'Unknown route-graph region "unknown".',
        ),
      ),
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stdoutLines, isEmpty);
    expect(
      stderrLines.single,
      contains('Unknown route-graph region "unknown".'),
    );
  });

  test('launcher forwards arguments from outside the repository root', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'route-graph-launcher',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final script = File(p.join(tempDir.path, 'route_graph_peak_list.sh'))
      ..writeAsStringSync(
        File(
          p.join(Directory.current.path, 'route_graph_peak_list.sh'),
        ).readAsStringSync(),
      );
    final output = File(p.join(tempDir.path, 'output.txt'));
    final fakeBinary = File(p.join(tempDir.path, 'fake-binary.sh'))
      ..writeAsStringSync(
        '#!/usr/bin/env bash\nset -euo pipefail\nprintf "cwd=%s\\n" "\$PWD" > "${output.path}"\nprintf "arg=%s\\n" "\$@" >> "${output.path}"\n',
      );
    Process.runSync('chmod', ['+x', fakeBinary.path]);
    final outsideDirectory = await Directory.systemTemp.createTemp(
      'route-graph-outside',
    );
    addTearDown(() => outsideDirectory.delete(recursive: true));

    final result = await Process.run(
      '/bin/bash',
      [script.path, '--region', 'FVG', '--output', '/tmp/fvg list.csv'],
      workingDirectory: outsideDirectory.path,
      environment: {
        ...Platform.environment,
        'PEAK_BAGGER_ROUTE_GRAPH_TOOL_BINARY': fakeBinary.path,
      },
    );

    expect(result.exitCode, 0);
    expect(output.readAsLinesSync(), [
      'cwd=${tempDir.path}',
      'arg=--region',
      'arg=FVG',
      'arg=--output',
      'arg=/tmp/fvg list.csv',
    ]);
  });

  test('launcher rebuilds when the shared executable target differs', () async {
    final tempDir = await Directory.systemTemp.createTemp('route-graph-target');
    addTearDown(() => tempDir.delete(recursive: true));
    final script = File(p.join(tempDir.path, 'route_graph_peak_list.sh'))
      ..writeAsStringSync(
        File(
          p.join(Directory.current.path, 'route_graph_peak_list.sh'),
        ).readAsStringSync(),
      );
    Directory(p.join(tempDir.path, 'tool')).createSync();
    Directory(p.join(tempDir.path, 'lib')).createSync();
    File(
      p.join(tempDir.path, 'tool', 'route_graph_peak_list.dart'),
    ).writeAsStringSync('');
    File(p.join(tempDir.path, 'lib', 'source.dart')).writeAsStringSync('');
    final releaseDirectory = Directory(
      p.join(tempDir.path, 'build', 'macos', 'Build', 'Products', 'Release'),
    )..createSync(recursive: true);
    final binary = File(
      p.join(
        releaseDirectory.path,
        'peak_bagger.app',
        'Contents',
        'MacOS',
        'peak_bagger',
      ),
    )..createSync(recursive: true);
    binary.writeAsStringSync('#!/usr/bin/env bash\nexit 0\n');
    Process.runSync('chmod', ['+x', binary.path]);
    final buildStamp = File(
      p.join(releaseDirectory.path, '.route_graph_peak_list_cli_build_stamp'),
    )..writeAsStringSync('');
    final targetStamp = File(
      p.join(releaseDirectory.path, '.peak_bagger_cli_target'),
    )..writeAsStringSync('tool/slovenia_hribi_source_peak_list.dart\n');
    Process.runSync('touch', [buildStamp.path]);
    final flutterLog = File(p.join(tempDir.path, 'flutter.log'));
    final fakeFlutter = File(p.join(tempDir.path, 'fake-flutter.sh'))
      ..writeAsStringSync(
        '#!/usr/bin/env bash\nset -euo pipefail\nprintf "cwd=%s\\n" "\$PWD" > "${flutterLog.path}"\nprintf "arg=%s\\n" "\$@" >> "${flutterLog.path}"\n',
      );
    Process.runSync('chmod', ['+x', fakeFlutter.path]);

    final result = await Process.run(
      '/bin/bash',
      [script.path, '--help'],
      environment: {
        ...Platform.environment,
        'PEAK_BAGGER_ROUTE_GRAPH_FLUTTER_BINARY': fakeFlutter.path,
      },
    );

    expect(result.exitCode, 0);
    expect(flutterLog.readAsLinesSync(), [
      'cwd=${tempDir.path}',
      'arg=build',
      'arg=macos',
      'arg=--release',
      'arg=-t',
      'arg=tool/route_graph_peak_list.dart',
    ]);
    expect(targetStamp.readAsStringSync(), 'tool/route_graph_peak_list.dart\n');
  });
}

class _CapturingService extends RouteGraphPeakListGenerationService {
  _CapturingService({this.supportedRegions = const ['tasmania'], this.failure})
    : super(textReader: (_) async => '');

  final List<String> supportedRegions;
  final Object? failure;
  int generateCallCount = 0;
  int supportedRegionsCallCount = 0;
  String? regionKey;
  String? outputPath;

  @override
  Future<RouteGraphPeakListGenerationResult> generate({
    required String regionKey,
    String? peakSourcePath,
    String? outputPath,
  }) async {
    generateCallCount += 1;
    this.regionKey = regionKey;
    this.outputPath = outputPath;
    if (failure != null) {
      throw failure!;
    }
    return const RouteGraphPeakListGenerationResult(
      outputPath: '/tmp/matches.csv',
      matchedPeakCount: 2,
      regionKey: 'tasmania',
    );
  }

  @override
  Future<List<String>> supportedRegionKeys() async {
    supportedRegionsCallCount += 1;
    return supportedRegions;
  }
}
