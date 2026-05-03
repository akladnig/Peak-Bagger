import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_csv_export_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  group('PeakCsvExportService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('peak-csv-export');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('exports peaks in repository order with escaping and blank cells', () async {
      final repository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(
            osmId: 300,
            name: 'Zeta Peak',
            altName: '',
            elevation: null,
            latitude: -41.1,
            longitude: 146.2,
            area: null,
            gridZoneDesignator: '55G',
            mgrs100kId: 'AB',
            easting: '100',
            northing: '200',
            verified: false,
          ),
          Peak(
            osmId: 200,
            name: 'Alpha, "South"\nRidge',
            altName: 'Alt, "Name"',
            elevation: 1234.5,
            latitude: -40.3,
            longitude: 145.4,
            area: 'Area, 1',
            gridZoneDesignator: '55H',
            mgrs100kId: 'CD',
            easting: '300',
            northing: '400',
            verified: true,
          ),
        ]),
      );
      final service = PeakCsvExportService(
        peakRepository: repository,
        outputDirectory: tempDir,
      );

      final result = await service.exportPeaks();
      final exportedFile = File(result.path);
      final contents = await exportedFile.readAsString();
      final rows = const CsvToListConverter(eol: '\n').convert(contents);

      expect(result.path, '${tempDir.path}/peaks.csv');
      expect(result.exportedCount, 2);
      expect(contents, isNot(contains('\r')));
      expect(contents, contains('\n'));
      expect(rows.first.cast<String>(), [
        'Name',
        'Alt Name',
        'Elevation',
        'Latitude',
        'Longitude',
        'Area',
        'Zone',
        'mgrs100kId',
        'Easting',
        'Northing',
        'Verified',
        'osmId',
      ]);
      expect(rows[1][0], 'Zeta Peak');
      expect(rows[1][1].toString(), '');
      expect(rows[1][2].toString(), '');
      expect(rows[1][5].toString(), '');
      expect(rows[1][10].toString(), 'false');
      expect(rows[1][11].toString(), '300');
      expect(rows[2][0].toString(), 'Alpha, "South"\nRidge');
      expect(rows[2][1].toString(), 'Alt, "Name"');
      expect(rows[2][2].toString(), '1234.5');
      expect(rows[2][5].toString(), 'Area, 1');
      expect(rows[2][10].toString(), 'true');
      expect(rows[2][11].toString(), '200');
    });

    test('overwrites existing export and returns empty export metadata', () async {
      final outputFile = File('${tempDir.path}/peaks.csv');
      await outputFile.writeAsString('stale data');

      final repository = PeakRepository.test(InMemoryPeakStorage());
      final service = PeakCsvExportService(
        peakRepository: repository,
        outputDirectory: tempDir,
      );

      final result = await service.exportPeaks();
      final contents = await outputFile.readAsString();

      expect(result.path, outputFile.path);
      expect(result.exportedCount, 0);
      expect(contents, 'Name,Alt Name,Elevation,Latitude,Longitude,Area,Zone,mgrs100kId,Easting,Northing,Verified,osmId');
    });
  });
}
