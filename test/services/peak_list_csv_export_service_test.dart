import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_csv_export_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  group('PeakListCsvExportService', () {
    late Directory tempRoot;
    late Directory outputDirectory;

    setUp(() async {
      tempRoot = await Directory.systemTemp.createTemp('peak-list-csv-export');
      outputDirectory = Directory('${tempRoot.path}/Peak_Lists');
      await outputDirectory.create();
    });

    tearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    test('exports multiple lists with exact headers and row values', () async {
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Zeta List',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 300, points: 4),
            ]),
          )..peakListId = 2,
          PeakList(
            name: 'Alpha List',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 200, points: 7),
              const PeakListItem(peakOsmId: 100, points: 3),
            ]),
          )..peakListId = 1,
        ]),
      );
      final peakRepository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(
            osmId: 100,
            name: 'Alpha',
            altName: 'Alt Alpha',
            elevation: 1234.5,
            latitude: -41,
            longitude: 146,
            gridZoneDesignator: '55G',
            mgrs100kId: 'AA',
            easting: '111',
            northing: '222',
          ),
          Peak(
            osmId: 200,
            name: 'Bravo',
            altName: '',
            elevation: null,
            latitude: -42,
            longitude: 147,
            gridZoneDesignator: '55H',
            mgrs100kId: 'BB',
            easting: '333',
            northing: '444',
          ),
          Peak(
            osmId: 300,
            name: 'Zulu',
            altName: 'Alt Zulu',
            elevation: 999,
            latitude: -43,
            longitude: 148,
            gridZoneDesignator: '55J',
            mgrs100kId: 'CC',
            easting: '555',
            northing: '666',
          ),
        ]),
      );

      final service = PeakListCsvExportService(
        peakListRepository: peakListRepository,
        peakRepository: peakRepository,
        outputDirectoryResolver: () => outputDirectory,
      );

      final result = await service.exportPeakLists();

      expect(result.outputDirectoryPath, outputDirectory.path);
      expect(result.exportedFileCount, 2);
      expect(result.skippedListCount, 0);

      final alphaFile = File(
        '${outputDirectory.path}/alpha-list-peak-list.csv',
      );
      final zetaFile = File('${outputDirectory.path}/zeta-list-peak-list.csv');
      expect(await alphaFile.exists(), isTrue);
      expect(await zetaFile.exists(), isTrue);

      final alphaRows = const CsvToListConverter(
        eol: '\n',
      ).convert(await alphaFile.readAsString());
      final zetaRows = const CsvToListConverter(
        eol: '\n',
      ).convert(await zetaFile.readAsString());

      expect(alphaRows.first.cast<String>(), [
        'Name',
        'Alt Name',
        'Elevation',
        'Zone',
        'mgrs100kId',
        'Easting',
        'Northing',
        'Points',
        'osmId',
      ]);
      expect(alphaRows[1].map((value) => '$value').toList(), [
        'Bravo',
        '',
        '',
        '55H',
        'BB',
        '333',
        '444',
        '7',
        '200',
      ]);
      expect(alphaRows[2].map((value) => '$value').toList(), [
        'Alpha',
        'Alt Alpha',
        '1234.5',
        '55G',
        'AA',
        '111',
        '222',
        '3',
        '100',
      ]);
      expect(zetaRows[1].map((value) => '$value').toList(), [
        'Zulu',
        'Alt Zulu',
        '999.0',
        '55J',
        'CC',
        '555',
        '666',
        '4',
        '300',
      ]);
    });
  });
}
