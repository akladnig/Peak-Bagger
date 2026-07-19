import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_source.dart';
import 'package:peak_bagger/services/slovenia_hribi_source_peak_list_service.dart';
import 'package:peak_bagger/services/slovenia_peak_correlation_service.dart';

void main() {
  group('SloveniaHribiSourcePeakListService', () {
    late Directory tempDir;
    late Directory cacheDir;
    late Map<String, String> fullPages;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('slovenia-ranked-peaks');
      cacheDir = Directory(p.join(tempDir.path, 'cache'));
      fullPages = {
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
        'https://www.hribi.net/gorovje/karavanke/11': _fixture(
          'hribi_range_karavanke.html',
        ),
        'https://www.monti.uno/catena_montuosa/caravanche/11': _fixture(
          'monti_range_karawanks.html',
        ),
        'https://www.hribi.net/gora/stol/11/500': _fixture(
          'hribi_detail_stol.html',
        ),
      };
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writes ranked, review, repair, and state artifacts together', () async {
      final partialPages = <String, String>{
        'https://www.hribi.net/gorovje/julijske_alpe/1': _fixture(
          'hribi_range_partial_julian_alps.html',
        ),
        'https://www.monti.uno/catena_montuosa/alpi_giulie/1': _fixture(
          'monti_range_partial_julian_alps.html',
        ),
        'https://www.hribi.net/gora/triglav/1/1': _fixture(
          'hribi_detail_triglav.html',
        ),
        'https://www.hribi.net/gora/montaz___jof_di_montasio/1/629': _fixture(
          'hribi_detail_montaz.html',
        ),
        'https://www.hribi.net/gora/skrivnostni_vrh/1/777': _fixture(
          'hribi_detail_missing_fields_peak.html',
        ),
      };

      final service = _service(
        pageLoader: (uri) async {
          final url = uri.toString();
          if (url == 'https://www.hribi.net/gora/pokvarjen_vrh/1/991') {
            throw HttpException('detail fetch failed');
          }
          return partialPages[url]!;
        },
        peakSource: InMemoryPeakSource([
          _peak(
            id: 1,
            osmId: 1001,
            name: 'Triglav',
            latitude: 46.37832,
            longitude: 13.83648,
            prominence: 2048,
            country: 'Slovenia',
            county: 'Upper Carniola',
            range: 'Julian Alps',
            difficulty: 'T5',
            viaFerrata: 'B',
            notes: 'Snow early season',
          ),
          _peak(
            id: 2,
            osmId: 1002,
            name: 'Jof di Montasio',
            altName: 'Montaz Jof di Montasio',
            latitude: 46.43973,
            longitude: 13.43612,
            prominence: 1200,
            country: 'Italy',
            county: 'Udine',
            range: 'Julian Alps',
          ),
        ]),
        rangeConfigurations: const [
          SloveniaHribiSourceRangeConfig(
            order: 2,
            hribiRangeUrl: 'https://www.hribi.net/gorovje/julijske_alpe/1',
            mountainRangeLabel: 'Julian Alps',
            hikeRangeUrl: 'https://www.hike.uno/mountain_range/julian_alps/1',
            montiRangeUrl:
                'https://www.monti.uno/catena_montuosa/alpi_giulie/1',
          ),
        ],
        tempDir: tempDir,
        cacheDir: cacheDir,
      );

      final result = await service.run(sourceOfTruth: 'hribi');

      expect(result.version, 1);
      expect(result.createdNewVersion, isTrue);
      expect(result.rows.map((row) => row.name), [
        'Triglav',
        'Montaž / Jôf di Montasio',
        'Skrivnostni vrh',
      ]);
      expect(result.canonicalRows.map((row) => row.name), [
        'Triglav',
        'Montaž / Jôf di Montasio',
      ]);
      expect(result.reviewRows, hasLength(1));
      expect(
        result.reviewRows.single.correlationReason,
        'missing_hribi_coordinates',
      );
      expect(result.reviewRows.single.row.region, 'Slovenia');
      expect(result.canonicalRows.first.sourceOfTruth, 'HRIBI');
      expect(result.reviewRows.single.row.sourceOfTruth, 'HRIBI');
      expect(result.repairEntries, hasLength(3));

      final rankedRows = const CsvDecoder().convert(
        File(result.csvPath).readAsStringSync(),
      );
      final reviewRows = const CsvDecoder().convert(
        File(result.reviewPath).readAsStringSync(),
      );
      final repairRows = const CsvDecoder().convert(
        File(result.repairPath).readAsStringSync(),
      );
      expect(rankedRows.first.cast<String>(), sloveniaRankedPeakListCsvHeader);
      expect(
        reviewRows.first.cast<String>(),
        sloveniaCorrelationReviewCsvHeader,
      );
      expect(
        repairRows.first.cast<String>(),
        sloveniaHribiSourcePeakListRepairCsvHeader,
      );
      expect(rankedRows, hasLength(3));
      expect(reviewRows, hasLength(2));
      expect(repairRows, hasLength(4));
      expect(rankedRows[1][1], 'Tricorno / Triglav');
      expect(rankedRows[2][1], 'Montaz Jof di Montasio');
      expect(rankedRows[1][9], 'Slovenia');
      expect(reviewRows[1][9], 'Slovenia');
      expect(rankedRows[1][15], 'HRIBI');
      expect(reviewRows[1][15], 'HRIBI');
      expect(reviewRows[1].last, 'missing_hribi_coordinates');

      final state =
          jsonDecode(File(result.statePath).readAsStringSync())
              as Map<String, dynamic>;
      expect(state['BaseName'], sloveniaRankedPeakListBaseName);
      expect(state['TieWindowMeters'], 10);
      expect(state['Artifacts']['ReviewCsv'], endsWith('.review.csv'));
      expect(state['Correlation']['CanonicalRowCount'], 2);
      expect(state['Correlation']['ReviewRowCount'], 1);
      expect(state['Correlation']['ReviewReasonCounts'], {
        'missing_hribi_coordinates': 1,
      });
      expect(
        result.summaries,
        contains(
          'Correlation split with tie window 10m: 2 canonical, 1 review (missing_hribi_coordinates:1)',
        ),
      );
    });

    test(
      'reuses cache and suppresses versions when visible CSV artifacts do not change',
      () async {
        final requestCounts = <String, int>{};

        Future<String> loader(Uri uri) async {
          final url = uri.toString();
          requestCounts.update(url, (value) => value + 1, ifAbsent: () => 1);
          return fullPages[url]!;
        }

        final firstService = _service(
          pageLoader: loader,
          peakSource: InMemoryPeakSource(_fullFixturePeaks),
          rangeConfigurations: _julianAlpsOnly,
          tempDir: tempDir,
          cacheDir: cacheDir,
        );
        final firstResult = await firstService.run(sourceOfTruth: 'hribi');

        final secondService = _service(
          pageLoader: loader,
          peakSource: InMemoryPeakSource(_fullFixturePeaks),
          rangeConfigurations: _julianAlpsOnly,
          tempDir: tempDir,
          cacheDir: cacheDir,
        );
        final secondResult = await secondService.run(sourceOfTruth: 'hribi');

        expect(firstResult.createdNewVersion, isTrue);
        expect(secondResult.createdNewVersion, isFalse);
        expect(secondResult.version, 1);
        expect(
          requestCounts.values.fold<int>(0, (sum, value) => sum + value),
          5,
        );
        expect(
          File(
            p.join(tempDir.path, '$sloveniaRankedPeakListBaseName-V2.csv'),
          ).existsSync(),
          isFalse,
        );
        expect(
          File(
            p.join(
              tempDir.path,
              '$sloveniaRankedPeakListBaseName-V2.review.csv',
            ),
          ).existsSync(),
          isFalse,
        );
      },
    );

    test(
      'creates a new version when the correlated CSV contents change',
      () async {
        final firstService = _service(
          pageLoader: (uri) async => fullPages[uri.toString()]!,
          peakSource: InMemoryPeakSource(),
          rangeConfigurations: _julianAlpsOnly,
          tempDir: tempDir,
          cacheDir: cacheDir,
        );
        final firstResult = await firstService.run(sourceOfTruth: 'hribi');

        final secondService = _service(
          pageLoader: (uri) async => fullPages[uri.toString()]!,
          peakSource: InMemoryPeakSource(_fullFixturePeaks),
          rangeConfigurations: _julianAlpsOnly,
          tempDir: tempDir,
          cacheDir: cacheDir,
        );
        final secondResult = await secondService.run(sourceOfTruth: 'hribi');

        expect(firstResult.reviewRows, hasLength(2));
        expect(firstResult.canonicalRows, isEmpty);
        expect(secondResult.createdNewVersion, isTrue);
        expect(secondResult.version, 2);
        expect(secondResult.canonicalRows, hasLength(2));
        expect(secondResult.reviewRows, isEmpty);
      },
    );

    test('rejects old raw-only snapshots as repair baselines', () async {
      File(
        p.join(tempDir.path, 'slovenia-hribi-source-peaks-V1.csv'),
      ).writeAsStringSync('old raw csv');
      File(
        p.join(tempDir.path, 'slovenia-hribi-source-peaks-V1.repair.csv'),
      ).writeAsStringSync('old repair csv');
      File(
        p.join(tempDir.path, 'slovenia-hribi-source-peaks-V1.state.json'),
      ).writeAsStringSync('{}');

      final service = _service(
        pageLoader: (_) async => throw StateError('should not fetch'),
        peakSource: InMemoryPeakSource(_fullFixturePeaks),
        rangeConfigurations: _julianAlpsOnly,
        tempDir: tempDir,
        cacheDir: cacheDir,
      );

      await expectLater(
        service.run(repairList: true, sourceOfTruth: 'hribi'),
        throwsA(
          isA<SloveniaHribiSourcePeakListException>().having(
            (error) => error.message,
            'message',
            'No repair file found. Run a normal crawl first.',
          ),
        ),
      );
    });

    test('repair rerun rebuilds the latest correlated snapshot', () async {
      final firstService = _service(
        pageLoader: (uri) async {
          final url = uri.toString();
          if (url == 'https://www.hribi.net/gorovje/karavanke/11') {
            throw HttpException('range fetch failed');
          }
          return fullPages[url]!;
        },
        peakSource: InMemoryPeakSource([
          ..._fullFixturePeaks,
          _peak(
            id: 3,
            osmId: 1003,
            name: 'Stol',
            latitude: 46.43119,
            longitude: 14.15431,
            prominence: 1300,
            country: 'Slovenia',
            county: 'Upper Carniola',
            range: 'Karawanks',
          ),
        ]),
        rangeConfigurations: _julianAndKarawanks,
        tempDir: tempDir,
        cacheDir: cacheDir,
      );
      final firstResult = await firstService.run(sourceOfTruth: 'hribi');

      final repairedService = _service(
        pageLoader: (uri) async => fullPages[uri.toString()]!,
        peakSource: InMemoryPeakSource([
          ..._fullFixturePeaks,
          _peak(
            id: 3,
            osmId: 1003,
            name: 'Stol',
            latitude: 46.43119,
            longitude: 14.15431,
            prominence: 1300,
            country: 'Slovenia',
            county: 'Upper Carniola',
            range: 'Karawanks',
          ),
        ]),
        rangeConfigurations: _julianAndKarawanks,
        tempDir: tempDir,
        cacheDir: cacheDir,
      );
      final repairedResult = await repairedService.run(
        repairList: true,
        sourceOfTruth: 'hribi',
      );

      expect(firstResult.repairEntries.single.kind, 'range');
      expect(repairedResult.createdNewVersion, isTrue);
      expect(repairedResult.version, 2);
      expect(repairedResult.repairEntries, isEmpty);
      expect(repairedResult.canonicalRows.map((row) => row.name), [
        'Triglav',
        'Jôf di Montasio',
        'Stol',
      ]);
    });
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

const _julianAndKarawanks = [
  ..._julianAlpsOnly,
  SloveniaHribiSourceRangeConfig(
    order: 4,
    hribiRangeUrl: 'https://www.hribi.net/gorovje/karavanke/11',
    mountainRangeLabel: 'Karawanks',
    hikeRangeUrl: 'https://www.hike.uno/mountain_range/karawanks/11',
    montiRangeUrl: 'https://www.monti.uno/catena_montuosa/caravanche/11',
  ),
];

final _fullFixturePeaks = [
  _peak(
    id: 1,
    osmId: 1001,
    name: 'Triglav',
    latitude: 46.37832,
    longitude: 13.83648,
    prominence: 2048,
    country: 'Slovenia',
    county: 'Upper Carniola',
    range: 'Julian Alps',
  ),
  _peak(
    id: 2,
    osmId: 1002,
    name: 'Jôf di Montasio',
    altName: 'Montaž / Jôf di Montasio',
    latitude: 46.43973,
    longitude: 13.43612,
    prominence: 1200,
    country: 'Italy, Slovenia',
    county: 'Udine',
    range: 'Julian Alps',
  ),
];

SloveniaHribiSourcePeakListService _service({
  required Future<String> Function(Uri uri) pageLoader,
  required PeakSource peakSource,
  required List<SloveniaHribiSourceRangeConfig> rangeConfigurations,
  required Directory tempDir,
  required Directory cacheDir,
}) {
  return SloveniaHribiSourcePeakListService(
    pageLoader: pageLoader,
    peakSource: peakSource,
    outputDirectoryResolver: () => tempDir,
    cacheDirectoryResolver: () => cacheDir,
    rangeConfigurations: rangeConfigurations,
  );
}

Peak _peak({
  required int id,
  required int osmId,
  required String name,
  required double latitude,
  required double longitude,
  String altName = '',
  double? prominence,
  String country = '',
  String county = '',
  String range = '',
  String difficulty = 'T4',
  String viaFerrata = 'A/B',
  String notes = 'Stored notes',
}) {
  return Peak(
    id: id,
    osmId: osmId,
    name: name,
    altName: altName,
    latitude: latitude,
    longitude: longitude,
    prominence: prominence,
    country: country,
    county: county,
    range: range,
    difficulty: difficulty,
    viaFerrata: viaFerrata,
    notes: notes,
  );
}

String _fixture(String name) {
  return File(
    'test/fixtures/slovenia_hribi_source_peak_list/$name',
  ).readAsStringSync();
}
