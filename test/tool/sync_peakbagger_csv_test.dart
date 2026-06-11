import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peakbagger_csv_sync_service.dart';
import 'package:peak_bagger/services/peakbagger_scraper.dart';

import '../../tool/sync_peakbagger_csv.dart';

class _NoopScraper implements PeakBaggerScraper {
  @override
  Future<void> verifyAvailable() async {}

  @override
  Future<PeakBaggerPeakDetails> showPeak(int peakbaggerPid) async {
    return PeakBaggerPeakDetails(
      peakbaggerPid: peakbaggerPid,
      name: 'Peak $peakbaggerPid',
      latitude: 0,
      longitude: 0,
    );
  }
}

class _CapturingService extends PeakBaggerCsvSyncService {
  _CapturingService()
    : super(
        peakSource: PeakRepository.test(InMemoryPeakStorage(const [])),
        scraper: _NoopScraper(),
      );

  String? csvPath;
  bool? createUnmatchedPeaks;
  bool? exactNameOnly;
  bool? elevationOnly;
  int? elevationToleranceMeters;
  int? maxRows;

  @override
  Future<PeakBaggerCsvSyncResult> syncCsv({
    required String csvPath,
    bool createUnmatchedPeaks = false,
    bool allowLiveLookups = true,
    bool exactNameOnly = false,
    bool elevationOnly = false,
    int elevationToleranceMeters = 10,
    int? maxRows,
  }) async {
    this.csvPath = csvPath;
    this.createUnmatchedPeaks = createUnmatchedPeaks;
    this.exactNameOnly = exactNameOnly;
    this.elevationOnly = elevationOnly;
    this.elevationToleranceMeters = elevationToleranceMeters;
    this.maxRows = maxRows;
    return const PeakBaggerCsvSyncResult(
      outputCsvPath: 'peak-bagger-peak-data-processed.csv',
      csvContents: 'csv',
      report: PeakBaggerCsvSyncReport(csvPath: 'path', rows: []),
    );
  }
}

class _CountingScraper implements PeakBaggerScraper {
  _CountingScraper(this.responses);

  final Map<int, PeakBaggerPeakDetails> responses;
  var verifyCount = 0;
  var showCount = 0;

  @override
  Future<void> verifyAvailable() async {
    verifyCount++;
  }

  @override
  Future<PeakBaggerPeakDetails> showPeak(int peakbaggerPid) async {
    showCount++;
    final response = responses[peakbaggerPid];
    if (response == null) {
      throw PeakBaggerCommandException(
        'missing response for pid $peakbaggerPid',
      );
    }
    return response;
  }
}

class _ForbiddenScraper implements PeakBaggerScraper {
  _ForbiddenScraper();

  var verifyCount = 0;
  var showCount = 0;

  @override
  Future<void> verifyAvailable() async {
    verifyCount++;
  }

  @override
  Future<PeakBaggerPeakDetails> showPeak(int peakbaggerPid) async {
    showCount++;
    throw PeakBaggerCommandException(
      'HTTP 403 Forbidden for pid $peakbaggerPid',
    );
  }
}

void main() {
  test('forwards the create-unmatched flag to the sync service', () async {
    final service = _CapturingService();

    final result = await syncPeakBaggerCsv(
      csvPath: 'peak-bagger-peak-data.csv',
      createUnmatchedPeaks: true,
      service: service,
    );

    expect(service.csvPath, 'peak-bagger-peak-data-lat-lon.csv');
    expect(service.createUnmatchedPeaks, isTrue);
    expect(result.csvContents, 'csv');
  });

  test(
    'forwards name and elevation match options to the sync service',
    () async {
      final service = _CapturingService();

      await syncPeakBaggerCsv(
        csvPath: 'peak-bagger-peak-data.csv',
        exactNameOnly: true,
        elevationOnly: true,
        elevationToleranceMeters: 7,
        service: service,
      );

      expect(service.csvPath, 'peak-bagger-peak-data-lat-lon.csv');
      expect(service.exactNameOnly, isTrue);
      expect(service.elevationOnly, isTrue);
      expect(service.elevationToleranceMeters, 7);
    },
  );

  test('forwards the row limit to the sync service', () async {
    final service = _CapturingService();

    await syncPeakBaggerCsv(
      csvPath: 'peak-bagger-peak-data.csv',
      maxRows: 12,
      service: service,
    );

    expect(service.csvPath, 'peak-bagger-peak-data-lat-lon.csv');
    expect(service.maxRows, 12);
  });

  test('prefers the cached lat-lon csv when it exists', () async {
    final tempDir = await Directory.systemTemp.createTemp('peakbagger-sync');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final sourcePath = p.join(tempDir.path, 'peak-bagger-peak-data.csv');
    final latLonPath = p.join(
      tempDir.path,
      'peak-bagger-peak-data-lat-lon.csv',
    );
    File(sourcePath).writeAsStringSync('source');
    File(latLonPath).writeAsStringSync('latlon');

    final service = _CapturingService();

    await syncPeakBaggerCsv(csvPath: sourcePath, service: service);

    expect(service.csvPath, latLonPath);
  });

  test('refreshes the lat-lon cache only for new rows', () async {
    final tempDir = await Directory.systemTemp.createTemp('peakbagger-cache');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final sourcePath = p.join(tempDir.path, 'peak-bagger-peak-data.csv');
    final latLonPath = p.join(
      tempDir.path,
      'peak-bagger-peak-data-lat-lon.csv',
    );
    File(sourcePath).writeAsStringSync(
      '''
Peak,Elev-M,Prom-M,Country,State/Prov,County,Range,Url
Mount Anne,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023
Mount Giblin,884,334,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=78112
'''
          .trim(),
    );
    File(latLonPath).writeAsStringSync(
      '''
Peak,Elev-M,Prom-M,Country,State/Prov,County,Range,Url,PeakBagger PID,Latitude,Longitude
Mount Anne,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023,74023,-41.5,146.5
'''
          .trim(),
    );

    final scraper = _CountingScraper({
      78112: const PeakBaggerPeakDetails(
        peakbaggerPid: 78112,
        name: 'Mount Giblin',
        latitude: -43.00799,
        longitude: 146.16562,
        elevation: 881,
      ),
    });

    final refreshedPath = await refreshPeakBaggerLatLonCsv(
      sourceCsvPath: sourcePath,
      latLonCsvPath: latLonPath,
      scraper: scraper,
    );

    expect(refreshedPath, latLonPath);
    expect(scraper.verifyCount, 1);
    expect(scraper.showCount, 1);

    final refreshed = File(latLonPath).readAsStringSync();
    expect(refreshed, contains('Mount Anne'));
    expect(refreshed, contains('Mount Giblin'));
    expect(refreshed, contains('78112'));
    expect(refreshed, contains('-43.00799'));
    expect(refreshed, contains('146.16562'));
    expect(refreshed, isNot(contains('note')));
    expect(refreshed, isNot(contains('safeToCreate')));
  });

  test(
    'falls back to the source csv on the first 403 and warns once',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('peakbagger-403');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final sourcePath = p.join(tempDir.path, 'peak-bagger-peak-data.csv');
      final latLonPath = p.join(
        tempDir.path,
        'peak-bagger-peak-data-lat-lon.csv',
      );
      File(sourcePath).writeAsStringSync(
        '''
Peak,Elev-M,Prom-M,Country,State/Prov,County,Range,Url
Mount Anne,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023
Mount Giblin,884,334,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=78112
'''
            .trim(),
      );

      final scraper = _ForbiddenScraper();
      final warnings = <String>[];

      final refreshedPath = await refreshPeakBaggerLatLonCsv(
        sourceCsvPath: sourcePath,
        latLonCsvPath: latLonPath,
        scraper: scraper,
        onWarning: warnings.add,
      );

      expect(refreshedPath, sourcePath);
      expect(scraper.verifyCount, 1);
      expect(scraper.showCount, 1);
      expect(warnings, hasLength(1));
      expect(warnings.single, contains('403'));
      expect(warnings.single, contains('falling back to the source CSV'));
      expect(File(latLonPath).existsSync(), isFalse);
    },
  );
}
