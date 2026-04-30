import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
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
