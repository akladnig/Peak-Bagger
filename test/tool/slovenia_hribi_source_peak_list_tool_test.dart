import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/peak_source.dart';
import 'package:peak_bagger/services/slovenia_hribi_source_peak_list_service.dart';

import '../../tool/slovenia_hribi_source_peak_list.dart';

void main() {
  List<String> stdoutLines = [];
  List<String> stderrLines = [];

  setUp(() {
    stdoutLines = [];
    stderrLines = [];
  });

  test('prints help', () async {
    final exitCode = await runSloveniaHribiSourcePeakListTool(
      args: const ['--help'],
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(stderrLines, isEmpty);
    expect(
      stdoutLines.single,
      contains('slovenia_hribi_source_peak_list.dart'),
    );
  });

  test(
    'requires --source-of-truth when input rows do not provide it',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'slovenia-ranked-missing-source',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final exitCode = await runSloveniaHribiSourcePeakListTool(
        args: ['--output-dir', tempDir.path],
        pageLoader: (uri) async => _pages()[uri.toString()]!,
        peakSourceLoader: () async => InMemoryPeakSource([
          Peak(
            id: 1,
            osmId: 1001,
            name: 'Triglav',
            latitude: 46.37832,
            longitude: 13.83648,
          ),
        ]),
        cacheDirectoryResolver: () => Directory(p.join(tempDir.path, 'cache')),
        rangeConfigurations: _julianAlpsOnly,
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 1);
      expect(
        stderrLines.single,
        contains('Missing required --source-of-truth'),
      );
    },
  );

  test('parses and forwards the source-of-truth flag to the service', () async {
    final service = _CapturingRunService();

    final exitCode = await runSloveniaHribiSourcePeakListTool(
      args: const ['--source-of-truth', 'hribi', '--tie-window-meters', '0'],
      service: service,
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(service.capturedSourceOfTruth, 'hribi');
    expect(service.capturedTieWindowMeters, 0);
  });

  test(
    'loads peaks through the injected read-only peak source loader when no service is supplied',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'slovenia-ranked-loader',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final trackingPeakSource = _TrackingPeakSource([
        Peak(
          id: 1,
          osmId: 1001,
          name: 'Triglav',
          latitude: 46.37832,
          longitude: 13.83648,
        ),
        Peak(
          id: 2,
          osmId: 1002,
          name: 'Jôf di Montasio',
          altName: 'Montaž / Jôf di Montasio',
          latitude: 46.43973,
          longitude: 13.43612,
        ),
      ]);
      var loaderCallCount = 0;

      final exitCode = await runSloveniaHribiSourcePeakListTool(
        args: ['--output-dir', tempDir.path, '--source-of-truth', 'hribi'],
        pageLoader: (uri) async => _pages()[uri.toString()]!,
        peakSourceLoader: () async {
          loaderCallCount += 1;
          return trackingPeakSource;
        },
        cacheDirectoryResolver: () => Directory(p.join(tempDir.path, 'cache')),
        rangeConfigurations: _julianAlpsOnly,
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(exitCode, 0);
      expect(loaderCallCount, 1);
      expect(trackingPeakSource.getAllPeaksCallCount, 1);
      expect(
        stdoutLines,
        contains(contains('Wrote Slovenia ranked peak list with 2 rows')),
      );
    },
  );

  test('writes correlated artifact paths and counts', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'slovenia-ranked-tool',
    );
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final cacheDir = Directory(p.join(tempDir.path, 'cache'));

    File(
      p.join(tempDir.path, '$sloveniaRankedPeakListBaseName-V1.csv'),
    ).writeAsStringSync('existing');
    File(
      p.join(tempDir.path, '$sloveniaRankedPeakListBaseName-V1.review.csv'),
    ).writeAsStringSync('existing');
    File(
      p.join(tempDir.path, '$sloveniaRankedPeakListBaseName-V1.repair.csv'),
    ).writeAsStringSync('existing');
    File(
      p.join(tempDir.path, '$sloveniaRankedPeakListBaseName-V1.state.json'),
    ).writeAsStringSync('{}');

    final pages = <String, String>{
      'https://www.hribi.net/gorovje/julijske_alpe/1': _fixture(
        'hribi_range_julian_alps.html',
      ),
      'https://www.monti.uno/catena_montuosa/alpi_giulie/1': _fixture(
        'monti_range_julian_alps.html',
      ),
      'https://www.hribi.net/gora/triglav/1/1': _fixture(
        'hribi_detail_triglav.html',
      ),
      'https://www.hribi.net/gora/montaz___jof_di_montasio/1/629': _fixture(
        'hribi_detail_montaz.html',
      ),
      'https://www.hribi.net/gora/dom_planika_pod_triglavom/1/94': _fixture(
        'hribi_detail_dom_planika.html',
      ),
    };

    final service = SloveniaHribiSourcePeakListService(
      pageLoader: (uri) async => pages[uri.toString()]!,
      peakSource: InMemoryPeakSource([
        Peak(
          id: 1,
          osmId: 1001,
          name: 'Triglav',
          latitude: 46.37832,
          longitude: 13.83648,
        ),
        Peak(
          id: 2,
          osmId: 1002,
          name: 'Jôf di Montasio',
          altName: 'Montaž / Jôf di Montasio',
          latitude: 46.43973,
          longitude: 13.43612,
        ),
      ]),
      outputDirectoryResolver: () => tempDir,
      cacheDirectoryResolver: () => cacheDir,
      rangeConfigurations: const [
        SloveniaHribiSourceRangeConfig(
          order: 2,
          hribiRangeUrl: 'https://www.hribi.net/gorovje/julijske_alpe/1',
          mountainRangeLabel: 'Julian Alps',
          hikeRangeUrl: 'https://www.hike.uno/mountain_range/julian_alps/1',
          montiRangeUrl: 'https://www.monti.uno/catena_montuosa/alpi_giulie/1',
        ),
      ],
    );

    final exitCode = await runSloveniaHribiSourcePeakListTool(
      args: ['--output-dir', tempDir.path, '--source-of-truth', 'hribi'],
      service: service,
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    expect(
      stderrLines,
      contains(
        'Correlation split with tie window 10m: 2 canonical, 0 review (no review rows)',
      ),
    );
    expect(
      stdoutLines[0],
      contains('Wrote Slovenia ranked peak list with 2 rows'),
    );
    expect(stdoutLines[0], contains('$sloveniaRankedPeakListBaseName-V2.csv'));
    expect(
      stdoutLines[1],
      contains('$sloveniaRankedPeakListBaseName-V2.review.csv'),
    );
    expect(stdoutLines[2], contains('Repair list written with 0 entries'));
    expect(
      stdoutLines[2],
      contains('$sloveniaRankedPeakListBaseName-V2.repair.csv'),
    );
    expect(
      stdoutLines[3],
      contains('$sloveniaRankedPeakListBaseName-V2.state.json'),
    );
  });

  test('tie-window defaults to 10m and records the value in state', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'slovenia-ranked-tie-default',
    );
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final triglavBase = Location(46.37832, 13.83648);
    final triglavNearA = LocationDelta(
      distance: 30,
      angle: LocationDelta.north,
    ).move(triglavBase);
    final triglavNearB = LocationDelta(
      distance: 35,
      angle: LocationDelta.north,
    ).move(triglavBase);

    final exitCode = await runSloveniaHribiSourcePeakListTool(
      args: ['--output-dir', tempDir.path, '--source-of-truth', 'hribi'],
      pageLoader: (uri) async => _pages()[uri.toString()]!,
      peakSourceLoader: () async => InMemoryPeakSource([
        Peak(
          id: 1,
          osmId: 2001,
          name: 'Candidate A',
          latitude: triglavNearA.latitude,
          longitude: triglavNearA.longitude,
        ),
        Peak(
          id: 2,
          osmId: 2002,
          name: 'Candidate B',
          latitude: triglavNearB.latitude,
          longitude: triglavNearB.longitude,
        ),
        Peak(
          id: 3,
          osmId: 2003,
          name: 'Jôf di Montasio',
          altName: 'Montaž / Jôf di Montasio',
          latitude: 46.43973,
          longitude: 13.43612,
        ),
      ]),
      cacheDirectoryResolver: () => Directory(p.join(tempDir.path, 'cache')),
      rangeConfigurations: _julianAlpsOnly,
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    final state =
        jsonDecode(
              File(
                p.join(
                  tempDir.path,
                  '$sloveniaRankedPeakListBaseName-V1.state.json',
                ),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final reviewRows = const CsvDecoder().convert(
      File(
        p.join(tempDir.path, '$sloveniaRankedPeakListBaseName-V1.review.csv'),
      ).readAsStringSync(),
    );
    expect(state['TieWindowMeters'], 10);
    expect(reviewRows, hasLength(2));
    expect(reviewRows[1].last, 'multiple_tied_candidates');
    expect(
      stderrLines,
      contains(
        'Correlation split with tie window 10m: 1 canonical, 1 review (multiple_tied_candidates:1)',
      ),
    );
  });

  test('tie-window flag accepts 0 and affects only tie handling', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'slovenia-ranked-tie-zero',
    );
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final triglavBase = Location(46.37832, 13.83648);
    final triglavNearA = LocationDelta(
      distance: 30,
      angle: LocationDelta.north,
    ).move(triglavBase);
    final triglavNearB = LocationDelta(
      distance: 35,
      angle: LocationDelta.north,
    ).move(triglavBase);

    final exitCode = await runSloveniaHribiSourcePeakListTool(
      args: [
        '--output-dir',
        tempDir.path,
        '--source-of-truth',
        'hribi',
        '--tie-window-meters',
        '0',
      ],
      pageLoader: (uri) async => _pages()[uri.toString()]!,
      peakSourceLoader: () async => InMemoryPeakSource([
        Peak(
          id: 1,
          osmId: 2001,
          name: 'Candidate A',
          latitude: triglavNearA.latitude,
          longitude: triglavNearA.longitude,
        ),
        Peak(
          id: 2,
          osmId: 2002,
          name: 'Candidate B',
          latitude: triglavNearB.latitude,
          longitude: triglavNearB.longitude,
        ),
        Peak(
          id: 3,
          osmId: 2003,
          name: 'Jôf di Montasio',
          altName: 'Montaž / Jôf di Montasio',
          latitude: 46.43973,
          longitude: 13.43612,
        ),
      ]),
      cacheDirectoryResolver: () => Directory(p.join(tempDir.path, 'cache')),
      rangeConfigurations: _julianAlpsOnly,
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 0);
    final state =
        jsonDecode(
              File(
                p.join(
                  tempDir.path,
                  '$sloveniaRankedPeakListBaseName-V1.state.json',
                ),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final rankedRows = const CsvDecoder().convert(
      File(
        p.join(tempDir.path, '$sloveniaRankedPeakListBaseName-V1.csv'),
      ).readAsStringSync(),
    );
    final reviewRows = const CsvDecoder().convert(
      File(
        p.join(tempDir.path, '$sloveniaRankedPeakListBaseName-V1.review.csv'),
      ).readAsStringSync(),
    );
    expect(state['TieWindowMeters'], 0);
    expect(rankedRows, hasLength(3));
    expect(reviewRows, hasLength(1));
    expect(
      stderrLines,
      contains(
        'Correlation split with tie window 0m: 2 canonical, 0 review (no review rows)',
      ),
    );
  });

  test('fails on unknown flags', () async {
    final exitCode = await runSloveniaHribiSourcePeakListTool(
      args: const ['--nope'],
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stderrLines.single, contains('Unknown flag'));
    expect(stdoutLines.single, contains('Usage:'));
  });

  test('shell wrapper forwards flags to the tool entrypoint', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'slovenia-ranked-wrapper',
    );
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final argsFile = File(p.join(tempDir.path, 'args.txt'));
    final fakeBinary = File(p.join(tempDir.path, 'fake-binary.sh'))
      ..writeAsStringSync(
        '#!/usr/bin/env bash\nset -euo pipefail\nprintf "%s\\n" "\$@" > "${argsFile.path}"\n',
      );
    Process.runSync('chmod', ['+x', fakeBinary.path]);

    final scriptPath = p.join(
      Directory.current.path,
      'slovenia_hribi_source_peak_list.sh',
    );
    final result = await Process.run(
      '/bin/bash',
      [scriptPath, '--source-of-truth', 'HRIBI', '--tie-window-meters', '0'],
      environment: {
        ...Platform.environment,
        'PEAK_BAGGER_SLOVENIA_TOOL_BINARY': fakeBinary.path,
      },
    );

    expect(result.exitCode, 0);
    expect(argsFile.readAsLinesSync(), [
      '--source-of-truth',
      'HRIBI',
      '--tie-window-meters',
      '0',
    ]);
  });

  test('prints the exact missing repair baseline message', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'slovenia-ranked-repair-missing',
    );
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final service = SloveniaHribiSourcePeakListService(
      pageLoader: (_) async => throw StateError('should not fetch'),
      peakSource: InMemoryPeakSource(),
      outputDirectoryResolver: () => tempDir,
      cacheDirectoryResolver: () => Directory(p.join(tempDir.path, 'cache')),
    );

    final exitCode = await runSloveniaHribiSourcePeakListTool(
      args: ['--repair-list', '--output-dir', tempDir.path],
      service: service,
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(exitCode, 1);
    expect(stdoutLines, isEmpty);
    expect(
      stderrLines.single,
      'No repair file found. Run a normal crawl first.',
    );
  });
}

const _julianAlpsOnly = [
  SloveniaHribiSourceRangeConfig(
    order: 2,
    hribiRangeUrl: 'https://www.hribi.net/gorovje/julijske_alpe/1',
    mountainRangeLabel: 'Julian Alps',
    hikeRangeUrl: 'https://www.hike.uno/mountain_range/julian_alps/1',
    montiRangeUrl: 'https://www.monti.uno/catena_montuosa/alpi_giulie/1',
  ),
];

Map<String, String> _pages() {
  return {
    'https://www.hribi.net/gorovje/julijske_alpe/1': _fixture(
      'hribi_range_julian_alps.html',
    ),
    'https://www.monti.uno/catena_montuosa/alpi_giulie/1': _fixture(
      'monti_range_julian_alps.html',
    ),
    'https://www.hribi.net/gora/triglav/1/1': _fixture(
      'hribi_detail_triglav.html',
    ),
    'https://www.hribi.net/gora/montaz___jof_di_montasio/1/629': _fixture(
      'hribi_detail_montaz.html',
    ),
    'https://www.hribi.net/gora/dom_planika_pod_triglavom/1/94': _fixture(
      'hribi_detail_dom_planika.html',
    ),
  };
}

class _TrackingPeakSource implements PeakSource {
  _TrackingPeakSource(this._peaks);

  final List<Peak> _peaks;
  int getAllPeaksCallCount = 0;

  @override
  List<Peak> getAllPeaks() {
    getAllPeaksCallCount += 1;
    return List<Peak>.unmodifiable(_peaks);
  }
}

class _CapturingRunService extends SloveniaHribiSourcePeakListService {
  _CapturingRunService()
    : super(pageLoader: (_) async => '', peakSource: InMemoryPeakSource());

  String? capturedSourceOfTruth;
  int? capturedTieWindowMeters;

  @override
  Future<SloveniaHribiSourcePeakListRunResult> run({
    bool repairList = false,
    bool refreshCache = false,
    int tieWindowMeters = 10,
    String? sourceOfTruth,
  }) async {
    capturedSourceOfTruth = sourceOfTruth;
    capturedTieWindowMeters = tieWindowMeters;
    return const SloveniaHribiSourcePeakListRunResult(
      rows: [],
      canonicalRows: [],
      reviewRows: [],
      csvPath: '/tmp/slovenia-ranked.csv',
      reviewPath: '/tmp/slovenia-ranked.review.csv',
      repairPath: '/tmp/slovenia-ranked.repair.csv',
      statePath: '/tmp/slovenia-ranked.state.json',
      repairEntries: [],
      summaries: [],
      version: 1,
      createdNewVersion: true,
      tieWindowMeters: 10,
    );
  }
}

String _fixture(String name) {
  return File(
    p.join('test', 'fixtures', 'slovenia_hribi_source_peak_list', name),
  ).readAsStringSync();
}
