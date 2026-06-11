import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peakbagger_csv_sync_service.dart';
import 'package:peak_bagger/services/peakbagger_scraper.dart';

class _FakePeakBaggerScraper implements PeakBaggerScraper {
  _FakePeakBaggerScraper(this.responses, {this.available = true});

  final Map<int, PeakBaggerPeakDetails> responses;
  final bool available;

  @override
  Future<void> verifyAvailable() async {
    if (!available) {
      throw const PeakBaggerCommandException('uvx peakbagger missing');
    }
  }

  @override
  Future<PeakBaggerPeakDetails> showPeak(int peakbaggerPid) async {
    final response = responses[peakbaggerPid];
    if (response == null) {
      throw PeakBaggerCommandException(
        'missing response for pid $peakbaggerPid',
      );
    }
    return response;
  }
}

void main() {
  PeakRepository repositoryWith(List<Peak> peaks) {
    return PeakRepository.test(InMemoryPeakStorage(peaks));
  }

  Future<PeakBaggerCsvSyncResult> runSync({
    required String csv,
    required PeakRepository repository,
    required PeakBaggerScraper scraper,
    bool createUnmatchedPeaks = false,
    bool exactNameOnly = false,
    bool elevationOnly = false,
    int elevationToleranceMeters = 10,
    int? maxRows,
    Map<String, String> outputs = const {},
  }) async {
    final captured = <String, String>{};
    final service = PeakBaggerCsvSyncService(
      peakSource: repository,
      scraper: scraper,
      csvReader: (_) async => csv,
      csvWriter: (path, contents) async {
        captured[path] = contents;
      },
      reportWriter: (path, contents) async {
        captured[path] = contents;
      },
      logWriter: (path, contents) async {
        captured[path] = (captured[path] ?? '') + contents;
      },
      reportPathResolver: (_) => 'peak-bagger-peak-data.sync-report.json',
      importLogPathResolver: (_) => 'logs/import.log',
      clock: () => DateTime.utc(2026, 1, 1, 12, 0, 0),
    );

    final result = await service.syncCsv(
      csvPath: 'peak-bagger-peak-data.csv',
      createUnmatchedPeaks: createUnmatchedPeaks,
      exactNameOnly: exactNameOnly,
      elevationOnly: elevationOnly,
      elevationToleranceMeters: elevationToleranceMeters,
      maxRows: maxRows,
    );

    for (final entry in outputs.entries) {
      expect(captured[entry.key], contains(entry.value));
    }

    return result;
  }

  test('assesses a matched peak and writes a sync report', () async {
    final repository = repositoryWith([
      Peak(
        id: 1,
        osmId: 123,
        name: 'Mt Anne',
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1103,
        region: 'Tasmania',
      ),
    ]);
    final scraper = _FakePeakBaggerScraper({
      74023: const PeakBaggerPeakDetails(
        peakbaggerPid: 74023,
        name: 'Mt Anne',
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1103,
        prominence: 561,
        country: 'Australia',
        county: 'Tasmania',
        range: 'Tasmania',
        osmId: 123,
      ),
    });

    final result = await runSync(
      repository: repository,
      scraper: scraper,
      csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url
Mt Anne,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023
''',
      outputs: {
        'peak-bagger-peak-data.sync-report.json': 'updatedCount',
        'peak-bagger-peak-data-processed.csv': 'PeakBagger PID',
        'logs/import.log': 'action=strong-name-exact',
      },
    );

    expect(result.report.updatedCount, 1);
    expect(result.report.createdCount, 0);
    expect(result.report.unmatchedCount, 0);
    expect(result.report.fetchFailureCount, 0);
    expect(result.report.rows.single.note, contains('exact name match'));
    expect(result.outputCsvPath, 'peak-bagger-peak-data-processed.csv');
    expect(result.report.csvPath, 'peak-bagger-peak-data-processed.csv');

    final savedPeak = repository.getAllPeaks().single;
    expect(savedPeak.peakbaggerPid, 74023);
    expect(savedPeak.sourceOfTruth, Peak.sourceOfTruthOsm);
    expect(savedPeak.prominence, 561);
    expect(savedPeak.country, 'Australia');

    expect(result.csvContents, contains('PeakBagger PID'));
    expect(result.csvContents, contains('Latitude'));
    expect(result.csvContents, contains('Longitude'));
    expect(result.csvContents, contains('osmId'));
    expect(result.csvContents, contains('safeToCreate'));
    expect(result.csvContents, contains('false'));
    expect(result.csvContents, contains('exact name match'));
  });

  test('uses csv elevation when scraper omits elevation', () async {
    final repository = repositoryWith([
      Peak(
        id: 1,
        osmId: 123,
        name: 'Jurjev Vrh',
        latitude: 42.767122,
        longitude: 16.806626,
        elevation: 155,
        region: 'Dubrovnik-Neretva',
      ),
    ]);
    final scraper = _FakePeakBaggerScraper({
      111919: const PeakBaggerPeakDetails(
        peakbaggerPid: 111919,
        name: 'Jurjev vrh',
        latitude: 42.76715,
        longitude: 16.80668,
        elevation: null,
        prominence: 155.7,
        country: 'Croatia',
        county: 'Dubrovnik-Neretva',
        range: 'Dinaric Alps',
      ),
    });

    final result = await runSync(
      repository: repository,
      scraper: scraper,
      csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url
Jurjev vrh,155.7,155.7,Croatia,Dubrovnik-Neretva,,Dinaric Alps,https://www.peakbagger.com/peak.aspx?pid=111919
''',
      outputs: {
        'peak-bagger-peak-data.sync-report.json': 'strong-name-exact',
        'peak-bagger-peak-data-processed.csv': 'exact name match',
      },
    );

    expect(result.report.rows.single.action, 'strong-name-exact');
    expect(result.report.rows.single.note, 'exact name match');
    expect(result.csvContents, contains('exact name match'));
  });

  test('writes a note for pid reuse matches', () async {
    final repository = repositoryWith([
      Peak(
        id: 1,
        osmId: 123,
        peakbaggerPid: 74023,
        name: 'Abbotts Lookout',
        latitude: -42.780553,
        longitude: 146.654086,
        elevation: 1103,
        region: 'Tasmania',
      ),
    ]);
    final scraper = _FakePeakBaggerScraper({
      74023: const PeakBaggerPeakDetails(
        peakbaggerPid: 74023,
        name: 'Abbotts Lookout',
        latitude: -42.780553,
        longitude: 146.654086,
        elevation: 1103,
      ),
    });

    final result = await runSync(
      repository: repository,
      scraper: scraper,
      csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url
Abbotts Lookout,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023
''',
      outputs: {
        'peak-bagger-peak-data-processed.csv':
            'matched existing PeakBagger pid',
      },
    );

    expect(result.report.rows.single.action, 'pid-reuse');
    expect(result.report.rows.single.note, 'matched existing PeakBagger pid');
    expect(result.csvContents, contains('matched existing PeakBagger pid'));
  });

  test('skips PeakBagger lookups when cached lat/lon are present', () async {
    final repository = repositoryWith([
      Peak(
        id: 1,
        osmId: 123,
        name: 'Mount Giblin',
        latitude: -43.00799,
        longitude: 146.16562,
        elevation: 881,
        region: 'Tasmania',
      ),
    ]);
    final scraper = _FakePeakBaggerScraper({}, available: false);

    final result = await runSync(
      repository: repository,
      scraper: scraper,
      csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url,Latitude,Longitude
Mount Giblin,884,240,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=77037,-43.006468,146.185842
''',
      outputs: {'peak-bagger-peak-data-processed.csv': 'exact name match'},
    );

    expect(result.report.rows.single.action, 'strong-name-exact');
    expect(result.report.rows.single.note, contains('spatial diff:'));
    expect(result.csvContents, contains('Latitude'));
    expect(result.csvContents, contains('Longitude'));
  });

  test(
    'logs exact-name matches without spatial difference when coordinates are missing',
    () async {
      final repository = repositoryWith([
        Peak(
          id: 1,
          osmId: 123,
          name: 'Mount Giblin',
          latitude: -43.00799,
          longitude: 146.16562,
          elevation: 881,
          region: 'Tasmania',
        ),
      ]);
      final scraper = _FakePeakBaggerScraper({
        77037: const PeakBaggerPeakDetails(
          peakbaggerPid: 77037,
          name: 'Mount Giblin',
          latitude: -43.006468,
          longitude: 146.185842,
          elevation: 884,
          prominence: 240,
          country: 'Australia',
          county: 'Tasmania',
          range: 'Tasmania',
        ),
      });

      final result = await runSync(
        repository: repository,
        scraper: scraper,
        csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url
Mount Giblin,884,240,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=77037
''',
        outputs: {'logs/import.log': 'detail=exact name match'},
      );

      expect(result.report.rows.single.action, 'strong-name-exact');
      expect(result.report.rows.single.note, 'exact name match');
    },
  );

  test(
    'matches by name and elevation when latitude and longitude are missing',
    () async {
      final repository = repositoryWith([
        Peak(
          id: 1,
          osmId: 123,
          name: 'Mount Giblin',
          latitude: 60,
          longitude: 10,
          elevation: 881,
          region: 'Tasmania',
        ),
      ]);
      final scraper = _FakePeakBaggerScraper({}, available: false);

      final result = await runSync(
        repository: repository,
        scraper: scraper,
        csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url,Latitude,Longitude
Mount Giblin,884,240,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=77037,,
''',
        outputs: {'peak-bagger-peak-data-processed.csv': 'exact name match'},
      );

      expect(result.report.rows.single.action, 'strong-name-exact');
      expect(result.report.rows.single.note, 'exact name match');
      expect(result.csvContents, contains('exact name match'));
      expect(result.csvContents, isNot(contains('spatial diff:')));
    },
  );

  test('fills missing peak metadata when a match is found', () async {
    final repository = repositoryWith([
      Peak(
        id: 1,
        osmId: 123,
        name: 'Mt Anne',
        latitude: -40,
        longitude: 145,
        elevation: null,
        prominence: null,
        country: '',
        county: '',
        range: '',
        region: 'Old Region',
      ),
    ]);
    final scraper = _FakePeakBaggerScraper({
      74023: const PeakBaggerPeakDetails(
        peakbaggerPid: 74023,
        name: 'Mt Anne',
        latitude: -41.5,
        longitude: 146.5,
        elevation: null,
        prominence: null,
        country: '',
        county: '',
        range: '',
        osmId: 123,
      ),
    });

    await runSync(
      repository: repository,
      scraper: scraper,
      csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url
Mt Anne,1103,561,Australia,Tasmania,Hobart,Tasmania Ranges,https://www.peakbagger.com/peak.aspx?pid=74023
''',
    );

    final savedPeak = repository.getAllPeaks().single;
    expect(savedPeak.peakbaggerPid, 74023);
    expect(savedPeak.elevation, 1103);
    expect(savedPeak.prominence, 561);
    expect(savedPeak.country, 'Australia');
    expect(savedPeak.region, 'Old Region');
    expect(savedPeak.county, 'Hobart');
    expect(savedPeak.range, 'Tasmania Ranges');
  });

  test(
    'does not overwrite existing peak metadata when a match is found',
    () async {
      final repository = repositoryWith([
        Peak(
          id: 1,
          osmId: 123,
          peakbaggerPid: 74023,
          name: 'Mt Anne',
          latitude: -40,
          longitude: 145,
          elevation: 900,
          prominence: 100,
          country: 'Old Country',
          county: 'Old County',
          range: 'Old Range',
          region: 'Old Region',
        ),
      ]);
      final scraper = _FakePeakBaggerScraper({
        74023: const PeakBaggerPeakDetails(
          peakbaggerPid: 74023,
          name: 'Mt Anne',
          latitude: -41.5,
          longitude: 146.5,
          elevation: null,
          prominence: null,
          country: '',
          county: '',
          range: '',
          osmId: 123,
        ),
      });

      await runSync(
        repository: repository,
        scraper: scraper,
        csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url
Mt Anne,1103,561,Australia,Tasmania,Hobart,Tasmania Ranges,https://www.peakbagger.com/peak.aspx?pid=74023
''',
      );

      final savedPeak = repository.getAllPeaks().single;
      expect(savedPeak.elevation, 900);
      expect(savedPeak.prominence, 100);
      expect(savedPeak.country, 'Old Country');
      expect(savedPeak.region, 'Old Region');
      expect(savedPeak.county, 'Old County');
      expect(savedPeak.range, 'Old Range');
    },
  );

  test('records unresolved rows without creating peaks', () async {
    final repository = repositoryWith(const []);
    final scraper = _FakePeakBaggerScraper({
      74023: const PeakBaggerPeakDetails(
        peakbaggerPid: 74023,
        name: 'Mt Anne',
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1103,
        prominence: 561,
        country: 'Australia',
        county: 'Tasmania',
        range: 'Tasmania',
      ),
    });

    final result = await runSync(
      repository: repository,
      scraper: scraper,
      csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url
Mt Something Else,900,200,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023
''',
    );

    expect(result.report.unmatchedCount, 1);
    expect(result.report.rows.single.action, 'unresolved');
    expect(result.report.rows.single.note, contains('unresolved'));
    expect(result.csvContents, contains('true'));
    expect(repository.getAllPeaks(), isEmpty);
  });

  test('does not create unmatched peaks even when requested', () async {
    final repository = repositoryWith(const []);
    final scraper = _FakePeakBaggerScraper({
      74023: const PeakBaggerPeakDetails(
        peakbaggerPid: 74023,
        name: 'Mt Anne',
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1103,
        prominence: 561,
        country: 'Australia',
        county: 'Tasmania',
        range: 'Tasmania',
      ),
    });

    final result = await runSync(
      repository: repository,
      scraper: scraper,
      createUnmatchedPeaks: true,
      csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url
Mt Anne,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023
''',
    );

    expect(result.report.createdCount, 0);
    expect(result.report.unmatchedCount, 1);
    expect(result.csvContents, contains('true'));
    expect(repository.getAllPeaks(), isEmpty);
  });

  test('records unresolved rows without triggering live lookup', () async {
    final repository = repositoryWith(const []);
    final scraper = _FakePeakBaggerScraper({}, available: true);

    final result = await runSync(
      repository: repository,
      scraper: scraper,
      csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url
Mt Anne,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023
''',
    );

    expect(result.report.fetchFailureCount, 0);
    expect(result.report.unmatchedCount, 1);
    expect(result.report.rows.single.action, 'unresolved');
    expect(repository.getAllPeaks(), isEmpty);
  });

  test('applies exact-name-only matching when requested', () async {
    final repository = repositoryWith([
      Peak(
        id: 1,
        osmId: 123,
        name: 'Mount Giblin North',
        latitude: -43.006468,
        longitude: 146.185842,
        elevation: 884,
        region: 'Tasmania',
      ),
    ]);
    final scraper = _FakePeakBaggerScraper({}, available: false);

    final result = await runSync(
      repository: repository,
      scraper: scraper,
      exactNameOnly: true,
      csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url,Latitude,Longitude
Mount Giblin,884,240,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=77037,-43.006468,146.185842
''',
    );

    expect(result.report.unmatchedCount, 1);
    expect(result.report.rows.single.action, 'unresolved');
    expect(result.report.rows.single.note, contains('no exact-name match'));
  });

  test('applies elevation-only matching when requested', () async {
    final repository = repositoryWith([
      Peak(
        id: 1,
        osmId: 123,
        name: 'Completely Different Peak',
        latitude: -43.006468,
        longitude: 146.185842,
        elevation: 887,
        region: 'Tasmania',
      ),
    ]);
    final scraper = _FakePeakBaggerScraper({}, available: false);

    final result = await runSync(
      repository: repository,
      scraper: scraper,
      elevationOnly: true,
      elevationToleranceMeters: 5,
      csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url,Latitude,Longitude
Mount Giblin,884,240,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=77037,-43.006468,146.185842
''',
    );

    expect(result.report.updatedCount, 1);
    expect(result.report.rows.single.action, 'elevation-match');
    expect(result.report.rows.single.note, contains('elevation match'));
  });

  test('limits processing to the requested number of rows', () async {
    final repository = repositoryWith([
      Peak(
        id: 1,
        osmId: 123,
        name: 'Mt Anne',
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1103,
        region: 'Tasmania',
      ),
    ]);
    final scraper = _FakePeakBaggerScraper({
      74023: const PeakBaggerPeakDetails(
        peakbaggerPid: 74023,
        name: 'Mt Anne',
        latitude: -41.5,
        longitude: 146.5,
        elevation: 1103,
      ),
      74024: const PeakBaggerPeakDetails(
        peakbaggerPid: 74024,
        name: 'Unknown Peak',
        latitude: -41.6,
        longitude: 146.6,
        elevation: 900,
      ),
    });

    final result = await runSync(
      repository: repository,
      scraper: scraper,
      maxRows: 1,
      csv: '''
Peak,Elev-M,Prom-M,Country,Region,County,Range,Url
Mt Anne,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023
Unknown Peak,900,200,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74024
''',
    );

    expect(result.report.processedCount, 1);
    expect(result.report.rows, hasLength(1));
    expect(result.report.rows.single.peakbaggerPid, 74023);
  });
}
