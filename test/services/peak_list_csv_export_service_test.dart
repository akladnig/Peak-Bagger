import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
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

    test(
      'exports multiple lists with exact headers and expanded row values',
      () async {
        final peakListRepository = _peakListRepository([
          (
            peakList: PeakList(name: 'Zeta List')..peakListId = 2,
            items: const [PeakListItem(peakOsmId: 300, points: 4)],
          ),
          (
            peakList: PeakList(name: 'Alpha List')..peakListId = 1,
            items: const [
              PeakListItem(peakOsmId: 200, points: 7),
              PeakListItem(peakOsmId: 100, points: 3),
              PeakListItem(peakOsmId: 200, points: 9),
            ],
          ),
        ]);
        final peakRepository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              osmId: 100,
              name: 'Alpha',
              altName: 'Alt Alpha',
              elevation: 1234.5,
              prominence: 678.9,
              rating: 4.4,
              durationLabel: '4-5 hours',
              difficulty: 'T4',
              viaFerrata: 'VF-A',
              notes: 'Granite ridge',
              latitude: -41,
              longitude: 146,
              country: 'Australia',
              region: 'tasmania',
              county: 'Derwent Valley',
              range: 'Du Cane',
              peakbaggerPid: 9001,
              gridZoneDesignator: '55G',
              mgrs100kId: 'AA',
              easting: '00111',
              northing: '00222',
              verified: true,
              sourceOfTruth: Peak.sourceOfTruthHwc,
            ),
            Peak(
              osmId: 200,
              name: 'Bravo',
              altName: '',
              elevation: null,
              prominence: null,
              rating: 4.0,
              durationMinutes: 255,
              durationLabel: '',
              difficulty: 'Easy',
              viaFerrata: '',
              notes: '',
              latitude: -42,
              longitude: 147,
              country: 'Australia',
              region: 'tasmania',
              county: 'Central Highlands',
              range: 'Cradle',
              gridZoneDesignator: '55H',
              mgrs100kId: 'BB',
              easting: '00333',
              northing: '00444',
              verified: false,
              sourceOfTruth: Peak.sourceOfTruthOsm,
            ),
            Peak(
              osmId: 300,
              name: 'Zulu',
              altName: 'Alt Zulu',
              elevation: 999,
              prominence: 321,
              durationMinutes: 2880,
              difficulty: 'Hard',
              viaFerrata: 'VF-B',
              notes: 'Snow possible',
              latitude: -43,
              longitude: 148,
              country: 'Australia',
              region: 'tasmania',
              county: 'Kentish',
              range: 'Great Western Tiers',
              peakbaggerPid: 42,
              gridZoneDesignator: '55J',
              mgrs100kId: 'CC',
              easting: '00555',
              northing: '00666',
              verified: true,
              sourceOfTruth: Peak.sourceOfTruthPeakBagger,
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
        final zetaFile = File(
          '${outputDirectory.path}/zeta-list-peak-list.csv',
        );
        expect(await alphaFile.exists(), isTrue);
        expect(await zetaFile.exists(), isTrue);

        final alphaRows = const CsvDecoder().convert(
          await alphaFile.readAsString(),
        );
        final zetaRows = const CsvDecoder().convert(
          await zetaFile.readAsString(),
        );

        expect(
          alphaRows.first.cast<String>(),
          PeakListCsvExportService.csvHeaders,
        );
        expect(alphaRows.first.cast<String>(), [
          'name',
          'altName',
          'elevation',
          'prominence',
          'rating',
          'difficulty',
          'duration',
          'viaFerrata',
          'gridZoneDesignator',
          'mgrs100kId',
          'easting',
          'northing',
          'points',
          'osmId',
          'peakbaggerPid',
          'country',
          'region',
          'county',
          'range',
          'notes',
          'verified',
          'sourceOfTruth',
        ]);
        expect(alphaRows[1].map((value) => '$value').toList(), [
          'Alpha',
          'Alt Alpha',
          '1234.5',
          '678.9',
          '4.4',
          'T4',
          '4-5 hours',
          'VF-A',
          '55G',
          'AA',
          '00111',
          '00222',
          '3',
          '100',
          '9001',
          'Australia',
          'tasmania',
          'Derwent Valley',
          'Du Cane',
          'Granite ridge',
          'true',
          'HWC',
        ]);
        expect(alphaRows[2].map((value) => '$value').toList(), [
          'Bravo',
          '',
          '',
          '',
          '4.0',
          'Easy',
          '4:15',
          '',
          '55H',
          'BB',
          '00333',
          '00444',
          '7',
          '200',
          '',
          'Australia',
          'tasmania',
          'Central Highlands',
          'Cradle',
          '',
          'false',
          'OSM',
        ]);
        expect(alphaRows[3].map((value) => '$value').toList(), [
          'Bravo',
          '',
          '',
          '',
          '4.0',
          'Easy',
          '4:15',
          '',
          '55H',
          'BB',
          '00333',
          '00444',
          '9',
          '200',
          '',
          'Australia',
          'tasmania',
          'Central Highlands',
          'Cradle',
          '',
          'false',
          'OSM',
        ]);
        expect(zetaRows[1].map((value) => '$value').toList(), [
          'Zulu',
          'Alt Zulu',
          '999.0',
          '321.0',
          '',
          'Hard',
          '2 days',
          'VF-B',
          '55J',
          'CC',
          '00555',
          '00666',
          '4',
          '300',
          '42',
          'Australia',
          'tasmania',
          'Kentish',
          'Great Western Tiers',
          'Snow possible',
          'true',
          'peakbagger.com',
        ]);
      },
    );

    test(
      'derives grid-reference columns from lat lng when stored values are blank or invalid',
      () async {
        final blankPeak = Peak(
          osmId: 100,
          name: 'Blank Grid Peak',
          latitude: -41.851,
          longitude: 146.035,
          gridZoneDesignator: '',
          mgrs100kId: '',
          easting: '',
          northing: '',
          sourceOfTruth: Peak.sourceOfTruthHwc,
        );
        final invalidPeak = Peak(
          osmId: 200,
          name: 'Invalid Grid Peak',
          latitude: -42.1234,
          longitude: 147.4567,
          gridZoneDesignator: 'oops',
          mgrs100kId: '1',
          easting: 'abc',
          northing: '12',
          sourceOfTruth: Peak.sourceOfTruthOsm,
        );
        final blankMgrs = PeakMgrsConverter.fromLatLng(
          LatLng(blankPeak.latitude, blankPeak.longitude),
        );
        final invalidMgrs = PeakMgrsConverter.fromLatLng(
          LatLng(invalidPeak.latitude, invalidPeak.longitude),
        );

        final service = PeakListCsvExportService(
          peakListRepository: _peakListRepository([
            (
              peakList: PeakList(name: 'Derived Grid')..peakListId = 1,
              items: const [
                PeakListItem(peakOsmId: 100, points: 1),
                PeakListItem(peakOsmId: 200, points: 2),
              ],
            ),
          ]),
          peakRepository: PeakRepository.test(
            InMemoryPeakStorage([blankPeak, invalidPeak]),
          ),
          outputDirectoryResolver: () => outputDirectory,
        );

        await service.exportPeakLists();

        final rows = const CsvDecoder().convert(
          await File(
            '${outputDirectory.path}/derived-grid-peak-list.csv',
          ).readAsString(),
        );

        expect(rows[1].map((value) => '$value').toList().sublist(8, 12), [
          blankMgrs.gridZoneDesignator,
          blankMgrs.mgrs100kId,
          blankMgrs.easting,
          blankMgrs.northing,
        ]);
        expect(rows[2].map((value) => '$value').toList().sublist(8, 12), [
          invalidMgrs.gridZoneDesignator,
          invalidMgrs.mgrs100kId,
          invalidMgrs.easting,
          invalidMgrs.northing,
        ]);
      },
    );

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

    test('reports file and row progress during export', () async {
      final peakListRepository = _peakListRepository([
        (
          peakList: PeakList(name: 'Alpha List')..peakListId = 1,
          items: const [
            PeakListItem(peakOsmId: 100, points: 3),
            PeakListItem(peakOsmId: 999, points: 1),
          ],
        ),
        (
          peakList: PeakList(name: 'Bravo List')..peakListId = 2,
          items: const [PeakListItem(peakOsmId: 200, points: 7)],
        ),
      ]);
      final peakRepository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(
            osmId: 100,
            name: 'Alpha',
            latitude: -41,
            longitude: 146,
            gridZoneDesignator: '55G',
            mgrs100kId: 'AA',
            easting: '00111',
            northing: '00222',
          ),
          Peak(
            osmId: 200,
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
      final service = PeakListCsvExportService(
        peakListRepository: peakListRepository,
        peakRepository: peakRepository,
        outputDirectoryResolver: () => outputDirectory,
      );
      final progressEvents = <PeakListCsvExportProgress>[];

      final result = await service.exportPeakLists(
        onProgress: progressEvents.add,
      );

      expect(result.exportedFileCount, 2);
      expect(progressEvents, isNotEmpty);
      expect(progressEvents.first.completedFileCount, 0);
      expect(progressEvents.first.totalFileCount, 2);
      expect(progressEvents.last.completedFileCount, 2);
      expect(progressEvents.last.totalFileCount, 2);
      expect(
        progressEvents.where((event) => event.currentFileWrittenRowCount == 1),
        isNotEmpty,
      );
    });

    test(
      'exports from relational memberships even when legacy payload is stale',
      () async {
        final peakRepository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              osmId: 100,
              name: 'Alpha',
              latitude: -41,
              longitude: 146,
              gridZoneDesignator: '55G',
              mgrs100kId: 'AA',
              easting: '00111',
              northing: '00222',
            ),
          ]),
        );
        final peakList = PeakList(
          peakListId: 1,
          name: 'Relational',
        );
        final itemStorage = InMemoryPeakListItemEntityStorage([
          PeakListItemEntity(id: 1, points: 3)
            ..peakList.target = peakList
            ..peak.target = peakRepository.findByOsmId(100),
        ]);
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage([peakList]),
          itemStorage: itemStorage,
          peakRepository: peakRepository,
        );

        final service = PeakListCsvExportService(
          peakListRepository: peakListRepository,
          peakRepository: peakRepository,
          outputDirectoryResolver: () => outputDirectory,
        );

        final result = await service.exportPeakLists();

        expect(result.exportedFileCount, 1);
        final rows = const CsvDecoder().convert(
          await File(
            '${outputDirectory.path}/relational-peak-list.csv',
          ).readAsString(),
        );
        expect(rows[1][0], 'Alpha');
        expect(rows[1][12].toString(), '3');
      },
    );

    test(
      'exports empty lists, skips invalid lists, and records deterministic warnings',
      () async {
        final peakListRepository = _peakListRepository([
          (peakList: PeakList(name: '...')..peakListId = 1, items: const []),
          (peakList: PeakList(name: 'Empty')..peakListId = 3, items: const []),
          (
            peakList: PeakList(name: 'Mixed')..peakListId = 4,
            items: const [
              PeakListItem(peakOsmId: 999, points: 5),
              PeakListItem(peakOsmId: 100, points: 7),
            ],
          ),
          (
            peakList: PeakList(name: 'Zero')..peakListId = 5,
            items: const [PeakListItem(peakOsmId: 888, points: 3)],
          ),
        ]);
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
        expect(result.skippedMalformedListCount, 0);
        expect(result.skippedZeroResolvedRowListCount, 1);
        expect(result.skippedListCount, 2);
        expect(result.warningEntries, [
          'Peak list 1 (...): blank normalized filename stem',
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

        final skipped = PeakList(name: 'Same')..peakListId = 1;
        final exported = PeakList(name: 'same')..peakListId = 2;
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage([skipped, exported]),
          itemStorage: _ThrowingPeakListItemEntityStorage(
            throwForPeakListIds: const {1},
            items: [
              PeakListItemEntity(id: 1, points: 2)
                ..peakList.target = exported
                ..peak.target = Peak(
                  osmId: 100,
                  name: 'Duplicated Peak',
                  latitude: -41,
                  longitude: 146,
                ),
              PeakListItemEntity(id: 2, points: 9)
                ..peakList.target = exported
                ..peak.target = Peak(
                  osmId: 100,
                  name: 'Duplicated Peak',
                  latitude: -41,
                  longitude: 146,
                ),
            ],
          ),
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
        final rows = const CsvDecoder().convert(
          await exportedFile.readAsString(),
        );
        expect(rows, hasLength(3));
        expect(rows[1][12].toString(), '2');
        expect(rows[2][12].toString(), '9');
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
        peakListRepository: _peakListRepository([
          (
            peakList: PeakList(name: 'Alpha List')..peakListId = 1,
            items: const [PeakListItem(peakOsmId: 100, points: 3)],
          ),
        ]),
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
        final broken = PeakList(name: 'Broken')..peakListId = 2;
        final zero = PeakList(name: 'Zero')..peakListId = 3;
        final service = PeakListCsvExportService(
          peakListRepository: PeakListRepository.test(
            InMemoryPeakListStorage([
              PeakList(name: '...')..peakListId = 1,
              broken,
              zero,
            ]),
            itemStorage: _ThrowingPeakListItemEntityStorage(
              throwForPeakListIds: const {2},
              items: [
                PeakListItemEntity(id: 1, points: 5)
                  ..peakList.target = zero
                  ..peak.target = Peak(
                    osmId: 999,
                    name: 'Missing Peak',
                    latitude: -41,
                    longitude: 146,
                  ),
              ],
            ),
          ),
          peakRepository: PeakRepository.test(InMemoryPeakStorage()),
          outputDirectoryResolver: () => outputDirectory,
        );

        final result = await service.exportPeakLists();

        expect(result.exportedFileCount, 0);
        expect(result.skippedListCount, 3);
        expect(result.skippedMalformedListCount, 1);
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

PeakListRepository _peakListRepository(
  List<({PeakList peakList, List<PeakListItem> items})> definitions,
) {
  final peakLists = [for (final definition in definitions) definition.peakList];
  final peakListsById = {for (final peakList in peakLists) peakList.peakListId: peakList};
  final items = <PeakListItemEntity>[];
  var itemId = 1;
  for (final definition in definitions) {
    for (final item in definition.items) {
      items.add(
        PeakListItemEntity(id: itemId++, points: item.points)
          ..peakList.target = peakListsById[definition.peakList.peakListId]!
          ..peak.target = Peak(
            osmId: item.peakOsmId,
            name: 'Peak ${item.peakOsmId}',
            latitude: -42,
            longitude: 146,
          ),
      );
    }
  }

  return PeakListRepository.test(
    InMemoryPeakListStorage(peakLists),
    itemStorage: InMemoryPeakListItemEntityStorage(items),
  );
}

class _ThrowingPeakListItemEntityStorage extends InMemoryPeakListItemEntityStorage {
  _ThrowingPeakListItemEntityStorage({
    required this.throwForPeakListIds,
    List<PeakListItemEntity> items = const [],
  }) : super(items);

  final Set<int> throwForPeakListIds;

  @override
  List<PeakListItemEntity> getByPeakListId(int peakListId) {
    if (throwForPeakListIds.contains(peakListId)) {
      throw StateError('membership rows unavailable');
    }
    return super.getByPeakListId(peakListId);
  }
}
