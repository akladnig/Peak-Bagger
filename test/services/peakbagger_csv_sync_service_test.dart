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
      throw PeakBaggerCommandException('missing response for pid $peakbaggerPid');
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
        'logs/import.log': 'action=spatial-match',
      },
    );

    expect(result.report.updatedCount, 1);
    expect(result.report.createdCount, 0);
    expect(result.report.unmatchedCount, 0);
    expect(result.report.fetchFailureCount, 0);
    expect(result.report.rows.single.note, 'matched via strong spatial match');
    expect(result.outputCsvPath, 'peak-bagger-peak-data-processed.csv');
    expect(result.report.csvPath, 'peak-bagger-peak-data-processed.csv');

    final savedPeak = repository.getAllPeaks().single;
    expect(savedPeak.peakbaggerPid, isNull);
    expect(savedPeak.sourceOfTruth, Peak.sourceOfTruthOsm);
    expect(savedPeak.prominence, isNull);
    expect(savedPeak.country, '');

    expect(result.csvContents, contains('PeakBagger PID'));
    expect(result.csvContents, contains('Latitude'));
    expect(result.csvContents, contains('Longitude'));
    expect(result.csvContents, contains('osmId'));
    expect(result.csvContents, contains('safeToCreate'));
    expect(result.csvContents, contains('false'));
    expect(result.csvContents, contains('matched via strong spatial match'));
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
        'peak-bagger-peak-data.sync-report.json': 'spatial-match',
        'peak-bagger-peak-data-processed.csv': 'matched via strong spatial match',
      },
    );

    expect(result.report.rows.single.action, 'spatial-match');
    expect(result.report.rows.single.note, 'matched via strong spatial match');
    expect(result.csvContents, contains('matched via strong spatial match'));
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
      outputs: {
        'peak-bagger-peak-data-processed.csv': 'matched via exact name',
      },
    );

    expect(result.report.rows.single.action, 'strong-name-exact');
    expect(result.report.rows.single.note, contains('spatial diff:'));
    expect(result.csvContents, contains('Latitude'));
    expect(result.csvContents, contains('Longitude'));
  });

  test('logs exact-name matches with spatial difference notes', () async {
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
      outputs: {
        'logs/import.log': 'note=matched via exact name',
      },
    );

    expect(result.report.rows.single.action, 'strong-name-exact');
    expect(result.report.rows.single.note, contains('spatial diff:'));
  });

  test('does not update objectbox peak metadata during review mode', () async {
    final repository = repositoryWith([
      Peak(
        id: 1,
        osmId: 123,
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
  });

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

  test('reports fetch failures and leaves the repository untouched', () async {
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

    expect(result.report.fetchFailureCount, 1);
    expect(result.report.rows.single.action, 'fetch-failure');
    expect(repository.getAllPeaks(), isEmpty);
  });
}
