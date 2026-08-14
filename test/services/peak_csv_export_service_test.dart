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

    test(
      'exports peaks in repository order with escaping and blank cells',
      () async {
        final repository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              id: 42,
              osmId: 300,
              peakbaggerPid: null,
              name: 'Zeta Peak',
              altName: '',
              elevation: null,
              prominence: null,
              country: '',
              county: '',
              range: '',
              rating: null,
              durationMinutes: null,
              durationLabel: '',
              difficulty: '',
              viaFerrata: '',
              notes: '',
              latitude: -41.1,
              longitude: 146.2,
              region: null,
              gridZoneDesignator: '55G',
              mgrs100kId: 'AB',
              easting: '100',
              northing: '200',
              verified: false,
            ),
            Peak(
              id: 24,
              osmId: 200,
              peakbaggerPid: 12345,
              name: 'Alpha, "South"\nRidge',
              altName: 'Alt, "Name"',
              elevation: 1234.5,
              prominence: 456.7,
              country: 'Australia',
              county: 'Meander Valley',
              range: 'Great Western Tiers',
              rating: 4.5,
              durationMinutes: 180,
              durationLabel: '3 hours',
              difficulty: 'Hard',
              viaFerrata: 'No',
              notes: 'Bring water',
              latitude: -40.3,
              longitude: 145.4,
              region: 'Area, 1',
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
        final rows = const CsvDecoder().convert(contents);

        expect(result.path, '${tempDir.path}/peaks.csv');
        expect(result.exportedCount, 2);
        expect(contents, isNot(contains('\r')));
        expect(contents, contains('\n'));
        expect(rows.first.cast<String>(), [
          'id',
          'osmId',
          'peakbaggerPid',
          'name',
          'altName',
          'elevation',
          'prominence',
          'country',
          'county',
          'range',
          'rating',
          'durationMinutes',
          'durationLabel',
          'difficulty',
          'viaFerrata',
          'notes',
          'latitude',
          'longitude',
          'region',
          'gridZoneDesignator',
          'mgrs100kId',
          'easting',
          'northing',
          'verified',
          'sourceOfTruth',
        ]);
        expect(rows[1].map((value) => value.toString()), [
          '42',
          '300',
          '',
          'Zeta Peak',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '-41.1',
          '146.2',
          '',
          '55G',
          'AB',
          '100',
          '200',
          'false',
          'OSM',
        ]);
        expect(rows[2].map((value) => value.toString()), [
          '24',
          '200',
          '12345',
          'Alpha, "South"\nRidge',
          'Alt, "Name"',
          '1234.5',
          '456.7',
          'Australia',
          'Meander Valley',
          'Great Western Tiers',
          '4.5',
          '180',
          '3 hours',
          'Hard',
          'No',
          'Bring water',
          '-40.3',
          '145.4',
          'Area, 1',
          '55H',
          'CD',
          '300',
          '400',
          'true',
          'OSM',
        ]);
      },
    );

    test(
      'overwrites existing export and returns empty export metadata',
      () async {
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
        expect(
          contents,
          'id,osmId,peakbaggerPid,name,altName,elevation,prominence,country,county,range,rating,durationMinutes,durationLabel,difficulty,viaFerrata,notes,latitude,longitude,region,gridZoneDesignator,mgrs100kId,easting,northing,verified,sourceOfTruth',
        );
      },
    );

    test('reports row progress during export', () async {
      final repository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(
            osmId: 1,
            name: 'Alpha',
            latitude: -41,
            longitude: 146,
            gridZoneDesignator: '55G',
            mgrs100kId: 'AA',
            easting: '00111',
            northing: '00222',
          ),
          Peak(
            osmId: 2,
            name: 'Bravo',
            latitude: -42,
            longitude: 147,
            gridZoneDesignator: '55H',
            mgrs100kId: 'BB',
            easting: '00333',
            northing: '00444',
          ),
        ]),
      );
      final service = PeakCsvExportService(
        peakRepository: repository,
        outputDirectory: tempDir,
      );
      final progressEvents = <PeakCsvExportProgress>[];

      await service.exportPeaks(onProgress: progressEvents.add);

      expect(progressEvents, hasLength(3));
      expect(progressEvents.first.writtenCount, 0);
      expect(progressEvents.first.totalCount, 2);
      expect(progressEvents.first.fileName, 'peaks.csv');
      expect(progressEvents.last.writtenCount, 2);
      expect(progressEvents.last.totalCount, 2);
    });
  });
}
