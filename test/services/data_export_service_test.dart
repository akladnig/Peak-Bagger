import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/data_export_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  test('prepare peaks export builds deterministic UTF-8 CSV payload', () async {
    final service = DefaultDataExportService(
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          Peak(
            osmId: 20,
            name: 'Zulu Peak',
            elevation: null,
            latitude: -42.2,
            longitude: 146.2,
            area: null,
            gridZoneDesignator: '55G',
            mgrs100kId: 'DQ',
            easting: '12345',
            northing: '67890',
            sourceOfTruth: Peak.sourceOfTruthHwc,
          ),
          Peak(
            osmId: 10,
            name: 'Alpha Peak',
            elevation: 1234.5,
            latitude: -41.1,
            longitude: 145.1,
            area: 'Tasmania',
            gridZoneDesignator: '55G',
            mgrs100kId: 'CP',
            easting: '11111',
            northing: '22222',
          ),
        ]),
      ),
      peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
      fileSystem: RecordingDataExportFileSystem(),
      clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
    );

    final plan = await service.preparePeaksExport('/tmp/export');

    expect(plan.targets, hasLength(1));
    expect(plan.targets.single.fileName, 'peaks.csv');
    expect(plan.targets.single.path, '/tmp/export/peaks.csv');
    expect(plan.targets.single.rowCount, 2);
    expect(plan.totalRowCount, 2);
    expect(plan.warningEntries, isEmpty);
    expect(
      plan.targets.single.payload,
      'name,elevation,Latitude,longitude,area,gridZoneDesignator,mgrs100kId,easting,northing,osmId,sourceOfTruth\n'
      'Alpha Peak,1234.5,-41.1,145.1,Tasmania,55G,CP,11111,22222,10,OSM\n'
      'Zulu Peak,,-42.2,146.2,,55G,DQ,12345,67890,20,HWC',
    );
  });

  test(
    'commit writes prepared peaks payload without rereading repositories',
    () async {
      final peakStorage = InMemoryPeakStorage([
        Peak(osmId: 1, name: 'Alpha', latitude: -41, longitude: 145),
      ]);
      final fileSystem = RecordingDataExportFileSystem();
      final service = DefaultDataExportService(
        peakRepository: PeakRepository.test(peakStorage),
        peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
        fileSystem: fileSystem,
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
      );
      final plan = await service.preparePeaksExport('/tmp/export');
      await peakStorage.clearAll();

      final result = await service.commitExport(plan);

      expect(result.exportedFileCount, 1);
      expect(result.exportedRowCount, 1);
      expect(fileSystem.writes, {
        '/tmp/export/peaks.csv.tmp': plan.targets.single.payload,
      });
      expect(fileSystem.replacements, [
        ('/tmp/export/peaks.csv.tmp', '/tmp/export/peaks.csv'),
      ]);
    },
  );

  test(
    'prepare peak lists export maps rows in deterministic list order',
    () async {
      final service = DefaultDataExportService(
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              osmId: 10,
              name: 'Alpha Peak',
              elevation: 1234,
              latitude: -41.1,
              longitude: 145.1,
              gridZoneDesignator: '55G',
              mgrs100kId: 'CP',
              easting: '11111',
              northing: '22222',
            ),
            Peak(
              osmId: 20,
              name: 'Zulu Peak',
              elevation: null,
              latitude: -42.2,
              longitude: 146.2,
              gridZoneDesignator: '55G',
              mgrs100kId: 'DQ',
              easting: '33333',
              northing: '44444',
            ),
          ]),
        ),
        peakListRepository: PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(
              peakListId: 2,
              name: 'Beta List',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 20, points: 8),
              ]),
            ),
            PeakList(
              peakListId: 1,
              name: 'Alpha List',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 20, points: 5),
                const PeakListItem(peakOsmId: 10, points: 3),
              ]),
            ),
          ]),
        ),
        fileSystem: RecordingDataExportFileSystem(),
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
      );

      final plan = await service.preparePeakListsExport(
        '/tmp/export',
        logDirectory: '/tmp/root',
      );

      expect(plan.targets.map((target) => target.fileName), [
        'alpha-list-peak-list.csv',
        'beta-list-peak-list.csv',
      ]);
      expect(plan.totalRowCount, 3);
      expect(plan.warningEntries, isEmpty);
      expect(
        plan.targets.first.payload,
        'Name,Height,gridZoneDesignator,mgrs100kId,Easting,Northing,Latitude,Longitude,Points\n'
        'Zulu Peak,,55G,DQ,33333,44444,-42.2,146.2,5\n'
        'Alpha Peak,1234.0,55G,CP,11111,22222,-41.1,145.1,3',
      );
    },
  );

  test(
    'prepare peak lists export skips malformed lists and missing peaks',
    () async {
      final service = DefaultDataExportService(
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              osmId: 10,
              name: 'Alpha Peak',
              latitude: -41.1,
              longitude: 145.1,
            ),
          ]),
        ),
        peakListRepository: PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(peakListId: 1, name: 'Broken List', peakList: 'not json'),
            PeakList(
              peakListId: 2,
              name: 'Valid List',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 99, points: 9),
                const PeakListItem(peakOsmId: 10, points: 4),
              ]),
            ),
          ]),
        ),
        fileSystem: RecordingDataExportFileSystem(),
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
      );

      final plan = await service.preparePeakListsExport(
        '/tmp/export',
        logDirectory: '/tmp/root',
      );

      expect(plan.targets, hasLength(1));
      expect(plan.targets.single.fileName, 'valid-list-peak-list.csv');
      expect(plan.targets.single.rowCount, 1);
      expect(plan.warningLogPath, '/tmp/root/export.log');
      expect(plan.warningEntries, [
        '2024-01-02T03:04:05.000Z | peak-list | Broken List | Skipped malformed peak-list payload.',
        '2024-01-02T03:04:05.000Z | peak-list | Valid List | Skipped missing peak osmId 99.',
      ]);
    },
  );

  test(
    'prepare peak lists export handles all malformed lists as zero-file success',
    () async {
      final service = DefaultDataExportService(
        peakRepository: PeakRepository.test(InMemoryPeakStorage()),
        peakListRepository: PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(peakListId: 1, name: 'Broken List', peakList: 'not json'),
          ]),
        ),
        fileSystem: RecordingDataExportFileSystem(),
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
      );

      final plan = await service.preparePeakListsExport(
        '/tmp/export',
        logDirectory: '/tmp/root',
      );

      expect(plan.targets, isEmpty);
      expect(plan.totalRowCount, 0);
      expect(plan.warningEntries, hasLength(1));
      expect(plan.warningLogPath, '/tmp/root/export.log');
    },
  );

  test('prepare peak lists export sanitizes duplicate filenames', () async {
    final peakListPayload = encodePeakListItems(const []);
    final service = DefaultDataExportService(
      peakRepository: PeakRepository.test(InMemoryPeakStorage()),
      peakListRepository: PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            peakListId: 1,
            name: '  My/List: One  ',
            peakList: peakListPayload,
          ),
          PeakList(
            peakListId: 2,
            name: 'My List One',
            peakList: peakListPayload,
          ),
          PeakList(peakListId: 3, name: '///', peakList: peakListPayload),
        ]),
      ),
      fileSystem: RecordingDataExportFileSystem(),
      clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
    );

    final plan = await service.preparePeakListsExport(
      '/tmp/export',
      logDirectory: '/tmp/root',
    );

    expect(plan.targets.map((target) => target.fileName), [
      'my-list-one-peak-list.csv',
      'my-list-one-2-peak-list.csv',
      'peak-list-peak-list.csv',
    ]);
  });

  test(
    'commit appends warning entries to export log after CSV writes',
    () async {
      final fileSystem = RecordingDataExportFileSystem();
      final service = DefaultDataExportService(
        peakRepository: PeakRepository.test(InMemoryPeakStorage()),
        peakListRepository: PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(peakListId: 1, name: 'Broken List', peakList: 'not json'),
          ]),
        ),
        fileSystem: fileSystem,
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
      );
      final plan = await service.preparePeakListsExport(
        '/tmp/export',
        logDirectory: '/tmp/root',
      );

      final result = await service.commitExport(plan);

      expect(result.exportedFileCount, 0);
      expect(result.exportedRowCount, 0);
      expect(result.warningCount, 1);
      expect(result.logPath, '/tmp/root/export.log');
      expect(fileSystem.writes, isEmpty);
      expect(fileSystem.appendedLogs, {
        '/tmp/root/export.log': plan.warningEntries,
      });
    },
  );
}

class RecordingDataExportFileSystem implements DataExportFileSystem {
  final writes = <String, String>{};
  final replacements = <(String, String)>[];
  final appendedLogs = <String, List<String>>{};

  @override
  Future<void> appendLog(String path, List<String> entries) async {
    appendedLogs[path] = entries;
  }

  @override
  Future<bool> directoryExists(String path) async => true;

  @override
  Future<bool> fileExists(String path) async => false;

  @override
  Future<bool> isDirectoryWritable(String path) async => true;

  @override
  Future<void> deleteFileIfExists(String path) async {}

  @override
  Future<void> replaceFile({
    required String tempPath,
    required String targetPath,
  }) async {
    replacements.add((tempPath, targetPath));
  }

  @override
  Future<void> writeTextFile(String path, String contents) async {
    writes[path] = contents;
  }
}
