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

    test(
      'succeeds with zero files and zero warnings when no lists exist',
      () async {
        final service = PeakListCsvExportService(
          peakListRepository: PeakListRepository.test(
            InMemoryPeakListStorage(),
          ),
          peakRepository: PeakRepository.test(InMemoryPeakStorage()),
          outputDirectoryResolver: () => outputDirectory,
        );

        final result = await service.exportPeakLists();

        expect(result.outputDirectoryPath, outputDirectory.path);
        expect(result.exportedFileCount, 0);
        expect(result.skippedListCount, 0);
        expect(result.warningEntries, isEmpty);
      },
    );

    test(
      'exports empty lists, skips invalid lists, and records deterministic warnings',
      () async {
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(name: '...', peakList: '[]')..peakListId = 1,
            PeakList(name: 'Broken', peakList: '{oops')..peakListId = 2,
            PeakList(name: 'Empty', peakList: '[]')..peakListId = 3,
            PeakList(
              name: 'Mixed',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 999, points: 5),
                const PeakListItem(peakOsmId: 100, points: 7),
              ]),
            )..peakListId = 4,
            PeakList(
              name: 'Zero',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 888, points: 3),
              ]),
            )..peakListId = 5,
          ]),
        );
        final peakRepository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              osmId: 100,
              name: 'Resolved Peak',
              latitude: -41,
              longitude: 146,
              gridZoneDesignator: '55G',
              mgrs100kId: 'AA',
              easting: '111',
              northing: '222',
            ),
          ]),
        );

        final service = PeakListCsvExportService(
          peakListRepository: peakListRepository,
          peakRepository: peakRepository,
          outputDirectoryResolver: () => outputDirectory,
        );

        final result = await service.exportPeakLists();

        expect(result.exportedFileCount, 2);
        expect(result.skippedRowCount, 2);
        expect(result.skippedBlankNameListCount, 1);
        expect(result.skippedMalformedListCount, 1);
        expect(result.skippedZeroResolvedRowListCount, 1);
        expect(result.skippedListCount, 3);
        expect(result.warningEntries, [
          'Peak list 1 (...): blank normalized filename stem',
          'Peak list 2 (Broken): malformed peakList payload',
          'Peak list 4 (Mixed): missing peak osmId 999',
          'Peak list 5 (Zero): missing peak osmId 888',
          'Peak list 5 (Zero): zero resolved peak rows',
        ]);

        expect(
          await File('${outputDirectory.path}/empty-peak-list.csv').exists(),
          isTrue,
        );
        expect(
          await File('${outputDirectory.path}/mixed-peak-list.csv').exists(),
          isTrue,
        );
        expect(
          await File('${outputDirectory.path}/zero-peak-list.csv').exists(),
          isFalse,
        );
      },
    );

    test(
      'skipped colliders reserve filename slots and duplicate raw rows still export',
      () async {
        final staleFile = File('${outputDirectory.path}/same-peak-list.csv');
        await staleFile.writeAsString('stale-data');

        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(name: 'Same', peakList: '{broken')..peakListId = 1,
            PeakList(
              name: 'same',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 100, points: 2),
                const PeakListItem(peakOsmId: 100, points: 9),
              ]),
            )..peakListId = 2,
          ]),
        );
        final peakRepository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              osmId: 100,
              name: 'Duplicated Peak',
              latitude: -41,
              longitude: 146,
              gridZoneDesignator: '55G',
              mgrs100kId: 'AA',
              easting: '111',
              northing: '222',
            ),
          ]),
        );

        final service = PeakListCsvExportService(
          peakListRepository: peakListRepository,
          peakRepository: peakRepository,
          outputDirectoryResolver: () => outputDirectory,
        );

        final result = await service.exportPeakLists();

        expect(result.exportedFileCount, 1);
        expect(result.skippedMalformedListCount, 1);
        expect(result.skippedListCount, 1);
        expect(await staleFile.readAsString(), 'stale-data');

        final exportedFile = File(
          '${outputDirectory.path}/same-2-peak-list.csv',
        );
        expect(await exportedFile.exists(), isTrue);
        final rows = const CsvToListConverter(
          eol: '\n',
        ).convert(await exportedFile.readAsString());
        expect(rows, hasLength(3));
        expect(rows[1][7].toString(), '2');
        expect(rows[2][7].toString(), '9');
      },
    );

    test(
      'missing output directory fails with path and recovery detail',
      () async {
        await outputDirectory.delete(recursive: true);

        final service = PeakListCsvExportService(
          peakListRepository: PeakListRepository.test(
            InMemoryPeakListStorage(),
          ),
          peakRepository: PeakRepository.test(InMemoryPeakStorage()),
          outputDirectoryResolver: () => outputDirectory,
        );

        await expectLater(
          service.exportPeakLists(),
          throwsA(
            isA<PeakListCsvExportException>()
                .having(
                  (error) => '$error',
                  'message',
                  contains(outputDirectory.path),
                )
                .having(
                  (error) => '$error',
                  'message',
                  contains('Create the folder and retry'),
                ),
          ),
        );
      },
    );

    test('file writer failure includes target file path', () async {
      final service = PeakListCsvExportService(
        peakListRepository: PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(
              name: 'Alpha List',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 100, points: 3),
              ]),
            )..peakListId = 1,
          ]),
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              osmId: 100,
              name: 'Alpha',
              latitude: -41,
              longitude: 146,
              gridZoneDesignator: '55G',
              mgrs100kId: 'AA',
              easting: '111',
              northing: '222',
            ),
          ]),
        ),
        outputDirectoryResolver: () => outputDirectory,
        fileWriter: _ThrowingPeakListCsvFileWriter(),
      );

      await expectLater(
        service.exportPeakLists(),
        throwsA(
          isA<PeakListCsvExportException>().having(
            (error) => '$error',
            'message',
            contains('${outputDirectory.path}/alpha-list-peak-list.csv'),
          ),
        ),
      );
    });

    test(
      'all skipped lists still succeed with zero files and warnings',
      () async {
        final service = PeakListCsvExportService(
          peakListRepository: PeakListRepository.test(
            InMemoryPeakListStorage([
              PeakList(name: '...', peakList: '[]')..peakListId = 1,
              PeakList(name: 'Broken', peakList: '{oops')..peakListId = 2,
              PeakList(
                name: 'Zero',
                peakList: encodePeakListItems([
                  const PeakListItem(peakOsmId: 999, points: 5),
                ]),
              )..peakListId = 3,
            ]),
          ),
          peakRepository: PeakRepository.test(InMemoryPeakStorage()),
          outputDirectoryResolver: () => outputDirectory,
        );

        final result = await service.exportPeakLists();

        expect(result.exportedFileCount, 0);
        expect(result.skippedListCount, 3);
        expect(result.warningEntries, isNotEmpty);
        expect(outputDirectory.listSync(), isEmpty);
      },
    );
  });
}

class _ThrowingPeakListCsvFileWriter implements PeakListCsvFileWriter {
  @override
  Future<void> write(String path, String contents) async {
    throw const FileSystemException('disk full');
  }
}
