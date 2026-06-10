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

  @override
  Future<PeakBaggerCsvSyncResult> syncCsv({
    required String csvPath,
    bool createUnmatchedPeaks = false,
    bool allowLiveLookups = true,
  }) async {
    this.csvPath = csvPath;
    this.createUnmatchedPeaks = createUnmatchedPeaks;
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
      throw PeakBaggerCommandException('missing response for pid $peakbaggerPid');
    }
    return response;
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

  test('prefers the cached lat-lon csv when it exists', () async {
    final tempDir = await Directory.systemTemp.createTemp('peakbagger-sync');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final sourcePath = p.join(tempDir.path, 'peak-bagger-peak-data.csv');
    final latLonPath = p.join(tempDir.path, 'peak-bagger-peak-data-lat-lon.csv');
    File(sourcePath).writeAsStringSync('source');
    File(latLonPath).writeAsStringSync('latlon');

    final service = _CapturingService();

    await syncPeakBaggerCsv(
      csvPath: sourcePath,
      service: service,
    );

    expect(service.csvPath, latLonPath);
  });

  test('refreshes the lat-lon cache only for new rows', () async {
    final tempDir = await Directory.systemTemp.createTemp('peakbagger-cache');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final sourcePath = p.join(tempDir.path, 'peak-bagger-peak-data.csv');
    final latLonPath = p.join(tempDir.path, 'peak-bagger-peak-data-lat-lon.csv');
    File(sourcePath).writeAsStringSync('''
Peak,Elev-M,Prom-M,Country,State/Prov,County,Range,Url
Mount Anne,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023
Mount Giblin,884,334,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=78112
'''.trim());
    File(latLonPath).writeAsStringSync('''
Peak,Elev-M,Prom-M,Country,State/Prov,County,Range,Url,PeakBagger PID,Latitude,Longitude
Mount Anne,1103,561,Australia,Tasmania,,Tasmania,https://www.peakbagger.com/peak.aspx?pid=74023,74023,-41.5,146.5
'''.trim());

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
}
