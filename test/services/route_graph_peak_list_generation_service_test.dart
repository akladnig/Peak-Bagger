import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/peak_list_csv_export_service.dart';
import 'package:peak_bagger/services/route_graph_peak_list_generation_service.dart';

void main() {
  group('RouteGraphPeakListGenerationService', () {
    test(
      'generates sorted app-owned CSV from eligible highway segments',
      () async {
        final files = _FakeFiles({
          '/repo/assets/region_manifest.json': jsonEncode({
            'routingCoverages': {
              'tasmania': {'displayName': 'Tasmania'},
            },
            'tasmania': {
              'priority': '1',
              'highways': ['assets/highways/tasmania.json'],
            },
          }),
          '/repo/assets/highways/tasmania.json': _highwaysJson(),
          '/home/Documents/Bushwalking/Features/peaks.csv': _peaksCsv([
            _peakRow(name: 'Zulu', osmId: 2, latitude: 0, longitude: .0003),
            _peakRow(name: 'alpha', osmId: 3, latitude: 0, longitude: 0),
            _peakRow(name: 'Outside', osmId: 4, latitude: 0, longitude: .01),
            _peakRow(name: 'Alpha', osmId: 1, latitude: 0, longitude: .0002),
          ]),
        });
        final service = _service(files);

        final result = await service.generate(regionKey: 'TASMANIA');

        expect(result.regionKey, 'tasmania');
        expect(result.matchedPeakCount, 3);
        expect(
          result.outputPath,
          '/home/Documents/Bushwalking/Peak_Lists/tasmania-route-graph-peak-list.csv',
        );
        final rows = const CsvDecoder().convert(
          files.contents[result.outputPath]!,
        );
        expect(rows.first, PeakListCsvExportService.csvHeaders);
        expect(rows.skip(1).map((row) => row[0]), ['Alpha', 'alpha', 'Zulu']);
        expect(
          rows.skip(1).map((row) => row[12].toString()),
          everyElement('1'),
        );
        expect(rows.skip(1).map((row) => row[16]), everyElement('tasmania'));
      },
    );

    test(
      'uses ancestor highways and non-composite aliases without replacing source region',
      () async {
        final files = _FakeFiles({
          '/repo/assets/region_manifest.json': jsonEncode({
            'italy-nord-est': {
              'priority': '2.1',
              'highways': ['assets/highways/italy.json'],
            },
            'fvg': {'priority': '2.1.1'},
          }),
          '/repo/assets/highways/italy.json': _highwaysJson(),
          '/source.csv': _peaksCsv([
            _peakRow(
              name: 'FVG Peak',
              region: ' FvG ',
              latitude: 0,
              longitude: 0,
            ),
          ]),
        });

        final result = await _service(files).generate(
          regionKey: 'fvg',
          peakSourcePath: '/source.csv',
          outputPath: '/output/list.csv',
        );

        final rows = const CsvDecoder().convert(
          files.contents[result.outputPath]!,
        );
        expect(rows[1][16], 'fvg');
      },
    );

    test('accepts and exports a negative osmId', () async {
      final files = _FakeFiles({
        '/repo/assets/region_manifest.json': jsonEncode({
          'tasmania': {
            'priority': '1',
            'highways': ['assets/highways/tasmania.json'],
          },
        }),
        '/repo/assets/highways/tasmania.json': _highwaysJson(),
        '/source.csv': _peaksCsv([
          _peakRow(
            name: 'Synthetic Peak',
            osmId: -1,
            latitude: 0,
            longitude: 0,
          ),
        ]),
      });

      final result = await _service(files).generate(
        regionKey: 'tasmania',
        peakSourcePath: '/source.csv',
        outputPath: '/output/list.csv',
      );

      final row = const CsvDecoder().convert(
        files.contents[result.outputPath]!,
      )[1];
      final osmIdColumn = PeakListCsvExportService.csvHeaders.indexOf('osmId');
      expect(result.matchedPeakCount, 1);
      expect(row[osmIdColumn], '-1');
    });

    test(
      'unions matching non-composite regions for composite selections',
      () async {
        final files = _FakeFiles({
          '/repo/assets/region_manifest.json': jsonEncode({
            'north': {
              'priority': '2.1',
              'highways': ['assets/highways/north.json'],
              'peakListFilterAliases': ['north-alias'],
            },
            'south': {
              'priority': '2.2',
              'highways': ['assets/highways/south.json'],
            },
            'all': {
              'priority': '2',
              'composite': true,
              'highways': [
                'assets/highways/north.json',
                'assets/highways/south.json',
              ],
            },
          }),
          '/repo/assets/highways/north.json': _highwaysJson(),
          '/repo/assets/highways/south.json': _highwaysJson(),
          '/source.csv': _peaksCsv([
            _peakRow(
              name: 'North',
              region: 'north-alias',
              latitude: 0,
              longitude: 0,
            ),
            _peakRow(
              name: 'South',
              osmId: 2,
              region: 'south',
              latitude: 0,
              longitude: 0,
            ),
            _peakRow(
              name: 'Other',
              osmId: 3,
              region: 'other',
              latitude: 0,
              longitude: 0,
            ),
          ]),
        });

        final result = await _service(files).generate(
          regionKey: 'all',
          peakSourcePath: '/source.csv',
          outputPath: '/output/list.csv',
        );

        expect(result.matchedPeakCount, 2);
      },
    );

    test(
      'does not bridge unresolved way references and accepts only eligible ways',
      () async {
        final files = _FakeFiles({
          '/repo/assets/region_manifest.json': jsonEncode({
            'tasmania': {
              'priority': '1',
              'highways': ['assets/highways/tasmania.json'],
            },
          }),
          '/repo/assets/highways/tasmania.json': jsonEncode({
            'elements': [
              {'type': 'node', 'id': 1, 'lat': 0, 'lon': 0},
              {'type': 'node', 'id': 2, 'lat': 0, 'lon': .002},
              {'type': 'node', 'id': 3, 'lat': 0, 'lon': .004},
              {
                'type': 'way',
                'nodes': [1, 999, 3],
                'tags': {'highway': 'path'},
              },
              {
                'type': 'way',
                'nodes': [1, 2],
                'tags': {'highway': 'path', 'area': 'yes'},
              },
              {
                'type': 'way',
                'nodes': [2, 3],
                'tags': {'highway': 'path', 'place': 'square'},
              },
            ],
          }),
          '/source.csv': _peaksCsv([
            _peakRow(name: 'Bridge', latitude: 0, longitude: .002),
          ]),
        });

        await expectLater(
          _service(files).generate(
            regionKey: 'tasmania',
            peakSourcePath: '/source.csv',
            outputPath: '/output/list.csv',
          ),
          throwsA(
            isA<RouteGraphPeakListGenerationException>().having(
              (error) => error.message,
              'message',
              contains('/repo/assets/highways/tasmania.json'),
            ),
          ),
        );
        expect(files.contents.containsKey('/output/list.csv'), isFalse);
      },
    );

    test(
      'matches the inclusive 50 metre boundary once across multiple files',
      () async {
        final files = _FakeFiles({
          '/repo/assets/region_manifest.json': jsonEncode({
            'tasmania': {
              'priority': '1',
              'highways': [
                'assets/highways/one.json',
                'assets/highways/two.json',
              ],
            },
          }),
          '/repo/assets/highways/one.json': _highwaysJson(),
          '/repo/assets/highways/two.json': _highwaysJson(),
          '/source.csv': _peaksCsv([
            _peakRow(
              name: 'Boundary',
              latitude: 50 / 111319.49079327357,
              longitude: .0005,
            ),
            _peakRow(
              name: 'Outside',
              osmId: 2,
              latitude: 50.1 / 111319.49079327357,
              longitude: .0005,
            ),
          ]),
        });

        final result = await _service(files).generate(
          regionKey: 'tasmania',
          peakSourcePath: '/source.csv',
          outputPath: '/output/list.csv',
        );

        expect(result.matchedPeakCount, 1);
      },
    );

    test(
      'rejects malformed source before replacing an existing output and cleans temporary files',
      () async {
        final files = _FakeFiles({
          '/repo/assets/region_manifest.json': jsonEncode({
            'tasmania': {
              'priority': '1',
              'highways': ['assets/highways/tasmania.json'],
            },
          }),
          '/repo/assets/highways/tasmania.json': _highwaysJson(),
          '/source.csv': _peaksCsv([
            _peakRow(name: '', latitude: 0, longitude: 0),
          ]),
          '/output/list.csv': 'existing',
        });

        await expectLater(
          _service(files).generate(
            regionKey: 'tasmania',
            peakSourcePath: '/source.csv',
            outputPath: '/output/list.csv',
          ),
          throwsA(isA<RouteGraphPeakListGenerationException>()),
        );
        expect(files.contents['/output/list.csv'], 'existing');
        expect(
          files.contents.keys.where((path) => path.contains('.tmp-')),
          isEmpty,
        );
      },
    );

    test('writes a header-only CSV when no eligible peaks match', () async {
      final files = _FakeFiles({
        '/repo/assets/region_manifest.json': jsonEncode({
          'tasmania': {
            'priority': '1',
            'highways': ['assets/highways/tasmania.json'],
          },
        }),
        '/repo/assets/highways/tasmania.json': _highwaysJson(),
        '/source.csv': _peaksCsv([
          _peakRow(
            name: 'Other region',
            region: 'other',
            latitude: 0,
            longitude: 0,
          ),
        ]),
      });

      final result = await _service(files).generate(
        regionKey: 'tasmania',
        peakSourcePath: '/source.csv',
        outputPath: '/output/list.csv',
      );

      expect(result.matchedPeakCount, 0);
      expect(
        const CsvDecoder().convert(files.contents[result.outputPath]!),
        hasLength(1),
      );
    });

    test(
      'rejects invalid optional values while permitting invalid MGRS fields',
      () async {
        final invalidRating = _peakRow(
          name: 'Bad rating',
          latitude: 0,
          longitude: 0,
        )..[10] = 'infinity';
        final validFallbackMgrs =
            _peakRow(name: 'Derived MGRS', latitude: 0, longitude: 0)
              ..[19] = 'not-a-zone'
              ..[20] = 'bad'
              ..[21] = 'abc'
              ..[22] = '123';
        final files = _FakeFiles({
          '/repo/assets/region_manifest.json': jsonEncode({
            'tasmania': {
              'priority': '1',
              'highways': ['assets/highways/tasmania.json'],
            },
          }),
          '/repo/assets/highways/tasmania.json': _highwaysJson(),
          '/invalid.csv': _peaksCsv([invalidRating]),
          '/valid.csv': _peaksCsv([validFallbackMgrs]),
        });
        final service = _service(files);

        await expectLater(
          service.generate(
            regionKey: 'tasmania',
            peakSourcePath: '/invalid.csv',
            outputPath: '/output/list.csv',
          ),
          throwsA(
            isA<RouteGraphPeakListGenerationException>().having(
              (error) => error.message,
              'message',
              allOf(contains('/invalid.csv'), contains('rating')),
            ),
          ),
        );

        await service.generate(
          regionKey: 'tasmania',
          peakSourcePath: '/valid.csv',
          outputPath: '/output/list.csv',
        );
        final row = const CsvDecoder().convert(
          files.contents['/output/list.csv']!,
        )[1];
        expect(row.sublist(8, 12), isNot(['not-a-zone', 'bad', 'abc', '123']));
      },
    );

    test(
      'preserves an existing target and removes the temporary sibling on write or rename failure',
      () async {
        for (final files in [
          _outputFailureFiles(failWriting: true),
          _outputFailureFiles(failRenaming: true),
        ]) {
          await expectLater(
            _service(files).generate(
              regionKey: 'tasmania',
              peakSourcePath: '/source.csv',
              outputPath: '/output/list.csv',
            ),
            throwsA(isA<RouteGraphPeakListGenerationException>()),
          );
          expect(files.contents['/output/list.csv'], 'existing');
          expect(
            files.contents.keys.where((path) => path.contains('.tmp-')),
            isEmpty,
          );
        }
      },
    );
  });
}

RouteGraphPeakListGenerationService _service(_FakeFiles files) {
  return RouteGraphPeakListGenerationService(
    textReader: files.read,
    fileSystem: files,
    homeDirectoryResolver: () => '/home',
    repositoryRootResolver: () => '/repo',
    tempSuffixResolver: () => 'test',
  );
}

String _highwaysJson() => jsonEncode({
  'elements': [
    {'type': 'node', 'id': 1, 'lat': 0, 'lon': 0},
    {'type': 'node', 'id': 2, 'lat': 0, 'lon': .001},
    {
      'type': 'way',
      'nodes': [1, 2],
      'tags': {'highway': 'path'},
    },
  ],
});

String _peaksCsv(List<List<String>> rows) {
  return const CsvEncoder(
    lineDelimiter: '\n',
  ).convert([RouteGraphPeakListGenerationService.peakSourceHeaders, ...rows]);
}

List<String> _peakRow({
  int id = 1,
  int osmId = 1,
  String name = 'Peak',
  String region = 'tasmania',
  double latitude = 0,
  double longitude = 0,
}) {
  return [
    '$id',
    '$osmId',
    '',
    name,
    '',
    '1000',
    '',
    'Australia',
    '',
    '',
    '4',
    '90',
    '',
    '',
    '',
    '',
    '$latitude',
    '$longitude',
    region,
    '',
    '',
    '',
    '',
    'TRUE',
    'OSM',
  ];
}

class _FakeFiles implements RouteGraphPeakListFileSystem {
  _FakeFiles(
    this.contents, {
    this.failWriting = false,
    this.failRenaming = false,
  });

  final Map<String, String> contents;
  final bool failWriting;
  final bool failRenaming;

  Future<String> read(String path) async {
    final content = contents[path];
    if (content == null) {
      throw StateError('missing $path');
    }
    return content;
  }

  @override
  Future<void> deleteIfExists(String path) async {
    contents.remove(path);
  }

  @override
  Future<bool> directoryExists(String path) async =>
      path == '/output' || path == '/home/Documents/Bushwalking/Peak_Lists';

  @override
  Future<void> rename(String sourcePath, String destinationPath) async {
    if (failRenaming) {
      throw StateError('rename failed');
    }
    final contentsToMove = contents.remove(sourcePath);
    if (contentsToMove == null) {
      throw StateError('missing temporary file');
    }
    contents[destinationPath] = contentsToMove;
  }

  @override
  Future<void> writeText(String path, String contentsToWrite) async {
    contents[path] = contentsToWrite;
    if (failWriting) {
      throw StateError('write failed');
    }
  }
}

_FakeFiles _outputFailureFiles({
  bool failWriting = false,
  bool failRenaming = false,
}) {
  return _FakeFiles(
    {
      '/repo/assets/region_manifest.json': jsonEncode({
        'tasmania': {
          'priority': '1',
          'highways': ['assets/highways/tasmania.json'],
        },
      }),
      '/repo/assets/highways/tasmania.json': _highwaysJson(),
      '/source.csv': _peaksCsv([
        _peakRow(name: 'Peak', latitude: 0, longitude: 0),
      ]),
      '/output/list.csv': 'existing',
    },
    failWriting: failWriting,
    failRenaming: failRenaming,
  );
}
