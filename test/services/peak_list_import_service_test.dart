import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_csv_export_service.dart';
import 'package:peak_bagger/services/peak_list_import_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  group('PeakListImportService', () {
    test(
      'ranked csv extended header imports by osmId and updates peak metadata',
      () async {
        final peak =
            _buildPeak(
              osmId: 101,
              name: 'Monte Old',
              elevation: 900,
              latitude: 46.2001,
              longitude: 13.1001,
            ).copyWith(
              prominence: 222,
              country: 'Italy',
              county: 'Old County',
              range: 'Old Range',
              region: 'italy-nord-est',
              sourceOfTruth: Peak.sourceOfTruthHwc,
            );
        final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
          peakRepository: peakRepository,
        );
        final service = PeakListImportService(
          peakRepository: peakRepository,
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes,sourceOfTruth\n'
              'Monte Amariana,101,4.35,1906,544,46.4084,13.0475,Italy,Friuli Venezia Giulia,Carnic Alps,Udine,EE,Optional,Ridge scramble, hribi \n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
        );

        final result = await service.importPeakList(
          listName: '  FVG Ranked  ',
          csvPath: '/tmp/fvg-ranked.csv',
        );

        final storedPeak = peakRepository.findByOsmId(101);
        final storedList = peakListRepository.getAllPeakLists().single;

        expect(result.updated, isFalse);
        expect(result.importedCount, 1);
        expect(result.skippedCount, 0);
        expect(result.warningEntries, isEmpty);
        expect(peakRepository.getAllPeaks(), hasLength(1));
        expect(storedPeak, isNotNull);
        expect(storedPeak?.name, 'Monte Amariana');
        expect(storedPeak?.elevation, 1906);
        expect(storedPeak?.prominence, 544);
        expect(storedPeak?.latitude, 46.4084);
        expect(storedPeak?.longitude, 13.0475);
        expect(storedPeak?.country, 'Italy');
        expect(storedPeak?.county, 'Udine');
        expect(storedPeak?.range, 'Carnic Alps');
        expect(storedPeak?.region, 'fvg');
        expect(storedPeak?.sourceOfTruth, 'HRIBI');
        expect(storedPeak?.rating, 4.4);
        expect(storedPeak?.difficulty, 'EE');
        expect(storedPeak?.viaFerrata, 'Optional');
        expect(storedPeak?.notes, 'Ridge scramble');
        expect(storedList.name, 'FVG Ranked');
        expect(storedList.region, 'fvg');
        expect(storedList.minLat, 46.4084);
        expect(storedList.maxLat, 46.4084);
        expect(storedList.minLng, 13.0475);
        expect(storedList.maxLng, 13.0475);
        expect(
          storedList.peakList,
          encodePeakListItems([const PeakListItem(peakOsmId: 101, points: 1)]),
        );
      },
    );

    test('ranked csv missing osmId fails atomically', () async {
      final peak =
          _buildPeak(
            osmId: 101,
            name: 'Monte Amariana',
            elevation: 1906,
            latitude: 46.4084,
            longitude: 13.0475,
          ).copyWith(
            region: 'italy-nord-est',
            sourceOfTruth: Peak.sourceOfTruthHwc,
          );
      final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes\n'
            'Monte Amariana,,4.3,1906,544,46.4084,13.0475,Italy,Friuli Venezia Giulia,Carnic Alps,Udine,EE,Optional,Ridge scramble\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      await expectLater(
        service.importPeakList(
          listName: 'FVG Ranked',
          csvPath: '/tmp/fvg-ranked.csv',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'row 2 is missing osmId (Monte Amariana)',
          ),
        ),
      );

      expect(
        peakRepository.findByOsmId(101)?.sourceOfTruth,
        Peak.sourceOfTruthHwc,
      );
      expect(peakListRepository.getAllPeakLists(), isEmpty);
    });

    test('ranked csv blank values keep existing stored fields', () async {
      final peak =
          _buildPeak(
            osmId: 101,
            name: 'Monte Amariana',
            elevation: 1906,
            latitude: 46.4084,
            longitude: 13.0475,
          ).copyWith(
            prominence: 544,
            country: 'Italy',
            county: 'Udine',
            range: 'Carnic Alps',
            rating: 4.2,
            durationMinutes: 300,
            durationLabel: '4-5 hours',
            difficulty: 'EE',
            viaFerrata: 'Optional',
            notes: 'Keep me',
            region: 'italy-nord-est',
          );
      final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes,sourceOfTruth\n'
            'Monte Amariana,101,,,,,,,Friuli Venezia Giulia,,,,,,fvg\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      await service.importPeakList(
        listName: 'FVG Ranked',
        csvPath: '/tmp/fvg-ranked.csv',
      );

      final storedPeak = peakRepository.findByOsmId(101);
      expect(storedPeak?.prominence, 544);
      expect(storedPeak?.country, 'Italy');
      expect(storedPeak?.county, 'Udine');
      expect(storedPeak?.range, 'Carnic Alps');
      expect(storedPeak?.rating, 4.2);
      expect(storedPeak?.durationMinutes, 300);
      expect(storedPeak?.durationLabel, '4-5 hours');
      expect(storedPeak?.difficulty, 'EE');
      expect(storedPeak?.viaFerrata, 'Optional');
      expect(storedPeak?.notes, 'Keep me');
      expect(storedPeak?.region, 'fvg');
      expect(storedPeak?.sourceOfTruth, 'FVG');
    });

    test('ranked csv internal region keys fail atomically', () async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Monte Amariana',
        elevation: 1906,
        latitude: 46.4084,
        longitude: 13.0475,
      );
      final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes,sourceOfTruth\n'
            'Monte Amariana,101,4.3,1906,544,46.4084,13.0475,Italy,slovenia,Carnic Alps,Udine,EE,Optional,Ridge scramble,HRIBI\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      await expectLater(
        service.importPeakList(
          listName: 'FVG Ranked',
          csvPath: '/tmp/fvg-ranked.csv',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'unsupported region "slovenia" on row 2',
          ),
        ),
      );

      expect(peakRepository.findByOsmId(101)?.region, Peak.defaultRegion);
      expect(peakListRepository.getAllPeakLists(), isEmpty);
    });

    test('ranked csv mixed canonical regions import as a mixed peak list', () async {
      final peakA = _buildPeak(
        osmId: 101,
        name: 'Monte Amariana',
        elevation: 1906,
        latitude: 46.4084,
        longitude: 13.0475,
      );
      final peakB = _buildPeak(
        osmId: 202,
        name: 'Monte Baldo',
        elevation: 2218,
        latitude: 45.7332,
        longitude: 10.8061,
      );
      final peakRepository = PeakRepository.test(
        InMemoryPeakStorage([peakA, peakB]),
      );
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes,sourceOfTruth\n'
            'Monte Amariana,101,4.3,1906,544,46.4084,13.0475,Italy,Friuli Venezia Giulia,Carnic Alps,Udine,EE,Optional,Ridge scramble,HRIBI\n'
            'Monte Baldo,202,4.1,2218,1800,45.7332,10.8061,Italy,Veneto,Monte Baldo,Verona,EEA,No,Lake view,HRIBI\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      final result = await service.importPeakList(
        listName: 'Italy North East Ranked',
        csvPath: '/tmp/north-east-ranked.csv',
      );

      expect(result.importedCount, 2);
      expect(result.skippedCount, 0);
      expect(peakRepository.findByOsmId(101)?.region, 'fvg');
      expect(peakRepository.findByOsmId(202)?.region, 'veneto');
      expect(
        peakListRepository.findByName('Italy North East Ranked')?.region,
        PeakList.mixedRegion,
      );
    });

    test('ranked csv invalid rating fails atomically', () async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Monte Amariana',
        elevation: 1906,
        latitude: 46.4084,
        longitude: 13.0475,
      );
      final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes\n'
            'Monte Amariana,101,5.4,1906,544,46.4084,13.0475,Italy,Friuli Venezia Giulia,Carnic Alps,Udine,EE,Optional,Ridge scramble\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      await expectLater(
        service.importPeakList(
          listName: 'FVG Ranked',
          csvPath: '/tmp/fvg-ranked.csv',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid rating "5.4" on row 2 (Monte Amariana)',
          ),
        ),
      );

      expect(
        peakRepository.findByOsmId(101)?.sourceOfTruth,
        Peak.sourceOfTruthOsm,
      );
      expect(peakListRepository.getAllPeakLists(), isEmpty);
    });

    test('ranked csv invalid sourceOfTruth fails atomically', () async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Monte Amariana',
        elevation: 1906,
        latitude: 46.4084,
        longitude: 13.0475,
      );
      final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes,sourceOfTruth\n'
            'Monte Amariana,101,4.3,1906,544,46.4084,13.0475,Italy,Friuli Venezia Giulia,Carnic Alps,Udine,EE,Optional,Ridge scramble,hribi/slovenia\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      await expectLater(
        service.importPeakList(
          listName: 'FVG Ranked',
          csvPath: '/tmp/fvg-ranked.csv',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'invalid sourceOfTruth "hribi/slovenia" on row 2 (Monte Amariana)',
          ),
        ),
      );

      expect(
        peakRepository.findByOsmId(101)?.sourceOfTruth,
        Peak.sourceOfTruthOsm,
      );
      expect(peakListRepository.getAllPeakLists(), isEmpty);
    });

    test(
      'ranked csv legacy header still supports FVG provenance fallback',
      () async {
        final peak = _buildPeak(
          osmId: 101,
          name: 'Monte Amariana',
          elevation: 1906,
          latitude: 46.4084,
          longitude: 13.0475,
        );
        final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: peakRepository,
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes\n'
              'Monte Amariana,101,4.3,1906,544,46.4084,13.0475,Italy,Friuli Venezia Giulia,Carnic Alps,Udine,EE,Optional,Ridge scramble\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
        );

        await service.importPeakList(
          listName: 'Legacy FVG Ranked',
          csvPath: '/tmp/legacy-fvg-ranked.csv',
        );

        expect(
          peakRepository.findByOsmId(101)?.sourceOfTruth,
          Peak.sourceOfTruthFvg,
        );
        expect(peakRepository.findByOsmId(101)?.region, 'fvg');
      },
    );

    test('ranked csv legacy header rejects newer manifest-backed regions', () async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Triglav',
        elevation: 2864,
        latitude: 46.3783,
        longitude: 13.8369,
      );
      final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes\n'
            'Triglav,101,4.9,2864,2048,46.3783,13.8369,Slovenia,Slovenia,Julian Alps,,AA,No,Highest peak\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      await expectLater(
        service.importPeakList(
          listName: 'Legacy Slovenia Ranked',
          csvPath: '/tmp/legacy-slovenia-ranked.csv',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'region "Slovenia" on row 2 requires sourceOfTruth in the ranked CSV header',
          ),
        ),
      );

      expect(peakListRepository.getAllPeakLists(), isEmpty);
      expect(
        peakRepository.findByOsmId(101)?.sourceOfTruth,
        Peak.sourceOfTruthOsm,
      );
    });

    test(
      'ranked csv explicit sourceOfTruth must stay consistent across one file',
      () async {
        final peakA = _buildPeak(
          osmId: 101,
          name: 'Monte Amariana',
          elevation: 1906,
          latitude: 46.4084,
          longitude: 13.0475,
        );
        final peakB = _buildPeak(
          osmId: 202,
          name: 'Triglav',
          elevation: 2864,
          latitude: 46.3783,
          longitude: 13.8369,
        );
        final peakRepository = PeakRepository.test(
          InMemoryPeakStorage([peakA, peakB]),
        );
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: peakRepository,
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes,sourceOfTruth\n'
              'Monte Amariana,101,4.3,1906,544,46.4084,13.0475,Italy,Friuli Venezia Giulia,Carnic Alps,Udine,EE,Optional,Ridge scramble,hribi\n'
              'Triglav,202,4.9,2864,2048,46.3783,13.8369,Slovenia,Slovenia,Julian Alps,,AA,No,Highest peak,peakbagger\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
        );

        await expectLater(
          service.importPeakList(
            listName: 'Mixed Provenance Ranked',
            csvPath: '/tmp/mixed-provenance-ranked.csv',
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'mixed sourceOfTruth values in one file',
            ),
          ),
        );

        expect(peakListRepository.getAllPeakLists(), isEmpty);
        expect(
          peakRepository.findByOsmId(101)?.sourceOfTruth,
          Peak.sourceOfTruthOsm,
        );
        expect(
          peakRepository.findByOsmId(202)?.sourceOfTruth,
          Peak.sourceOfTruthOsm,
        );
      },
    );

    test(
      'quoted-comma row parses and imports when hard match rules pass',
      () async {
        final peak = _buildPeak(
          osmId: 101,
          name: 'Mount Achilles',
          elevation: 1363,
          latitude: -41.85916,
          longitude: 145.97754,
        );
        final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: peakRepository,
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\n"Achilles, Mount",1363,55G,4 15 135,53 65 355,-41.85916,145.97754,3\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
          clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        );

        final result = await service.importPeakList(
          listName: 'Abels',
          csvPath: '/tmp/abels.csv',
        );

        expect(result.updated, isFalse);
        expect(result.importedCount, 1);
        expect(result.skippedCount, 0);
        expect(result.warningEntries, isEmpty);
        expect(
          peakRepository.findByOsmId(101)?.sourceOfTruth,
          Peak.sourceOfTruthHwc,
        );
        expect(
          peakListRepository.getAllPeakLists().single.peakList,
          encodePeakListItems([const PeakListItem(peakOsmId: 101, points: 3)]),
        );
      },
    );

    test('latitude and longitude differences within 500m still match', () async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Mount Achilles',
        elevation: 1363,
        latitude: -41.85916,
        longitude: 145.97754,
      );
      final coords = _csvCoordinatesFromPeak(peak);
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nMount Achilles,1363,${peak.gridZoneDesignator},${coords.easting},${coords.northing},-41.85566,145.97754,3\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
      );

      final result = await service.importPeakList(
        listName: 'LatLng Tolerance',
        csvPath: '/tmp/latlng.csv',
      );

      expect(result.importedCount, 1);
      expect(result.skippedCount, 0);
      expect(result.warningEntries, isEmpty);
    });

    test('unmatched rows create new HWC peaks and list entries', () async {
      final peakRepository = PeakRepository.test(InMemoryPeakStorage());
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nMissing Peak,800,55G,4 15 135,53 65 355,-41.00000,145.00000,1\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
      );

      final result = await service.importPeakList(
        listName: 'Create Missing Peak',
        csvPath: '/tmp/create-missing.csv',
      );

      final createdPeak = peakRepository.getAllPeaks().single;

      expect(result.importedCount, 1);
      expect(result.skippedCount, 0);
      expect(result.warningEntries, isEmpty);
      expect(createdPeak.osmId, lessThan(0));
      expect(createdPeak.name, 'Missing Peak');
      expect(createdPeak.sourceOfTruth, Peak.sourceOfTruthHwc);
      expect(
        peakListRepository.getAllPeakLists().single.peakList,
        encodePeakListItems([
          PeakListItem(peakOsmId: createdPeak.osmId, points: 1),
        ]),
      );
    });

    test(
      'unique match updates differing peak fields and marks sourceOfTruth HWC',
      () async {
        final peak = _buildPeak(
          osmId: 101,
          name: 'Mount Achilles',
          elevation: 1363,
          latitude: -41.85916,
          longitude: 145.97754,
        ).copyWith(altName: 'Manual Achilles', verified: true);
        final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final coords = _csvCoordinatesFromPeak(
          peak,
          eastingOffset: 75,
          northingOffset: -125,
        );
        final normalizedCoords = PeakMgrsConverter.fromCsvUtm(
          zone: peak.gridZoneDesignator,
          easting: coords.easting,
          northing: coords.northing,
        );
        final service = PeakListImportService(
          peakRepository: peakRepository,
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nMount Achilles,1401,${peak.gridZoneDesignator},${coords.easting},${coords.northing},-41.85856,145.97814,3\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
          clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        );

        final result = await service.importPeakList(
          listName: 'Corrections',
          csvPath: '/tmp/corrections.csv',
        );

        final correctedPeak = peakRepository.findByOsmId(101);

        expect(result.importedCount, 1);
        expect(result.warningEntries, hasLength(2));
        expect(result.warningEntries.first, contains('coordinate drift'));
        expect(result.warningEntries.last, contains('updated height'));
        expect(correctedPeak, isNotNull);
        expect(correctedPeak?.latitude, -41.85856);
        expect(correctedPeak?.longitude, 145.97814);
        expect(correctedPeak?.elevation, 1401);
        expect(correctedPeak?.easting, normalizedCoords.easting);
        expect(correctedPeak?.northing, normalizedCoords.northing);
        expect(correctedPeak?.altName, 'Manual Achilles');
        expect(correctedPeak?.verified, isTrue);
        expect(correctedPeak?.sourceOfTruth, Peak.sourceOfTruthHwc);
      },
    );

    test(
      'coordinate drift above 50m warns and still matches within 500m',
      () async {
        final peak = _buildPeak(
          osmId: 101,
          name: 'Mount Achilles',
          elevation: 1363,
          latitude: -41.85916,
          longitude: 145.97754,
        );
        final coords = _csvCoordinatesFromPeak(
          peak,
          eastingOffset: 75,
          northingOffset: -125,
        );
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nMount Achilles,1363,${peak.gridZoneDesignator},${coords.easting},${coords.northing},-41.85916,145.97754,3\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
          clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        );

        final result = await service.importPeakList(
          listName: 'Coordinate Drift',
          csvPath: '/tmp/drift.csv',
        );

        expect(result.importedCount, 1);
        expect(result.skippedCount, 0);
        expect(result.warningEntries, hasLength(1));
        expect(result.warningEntries.single, contains('coordinate drift'));
        expect(result.warningEntries.single, contains('easting 75m'));
        expect(result.warningEntries.single, contains('northing 125m'));
        expect(result.logEntries, hasLength(1));
      },
    );

    test(
      'accepted matches above 50m require a strong name confirmation',
      () async {
        final peak = _buildPeak(
          osmId: 101,
          name: 'Mount Achilles',
          elevation: 1363,
          latitude: -41.85916,
          longitude: 145.97754,
        );
        final coords = _csvCoordinatesFromPeak(
          peak,
          eastingOffset: 900,
          northingOffset: -900,
        );
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nWrong Name,1363,${peak.gridZoneDesignator},${coords.easting},${coords.northing},-41.85916,145.97754,3\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
          clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        );

        final result = await service.importPeakList(
          listName: 'Needs Name Confirmation',
          csvPath: '/tmp/name-confirmation.csv',
        );

        expect(result.importedCount, 0);
        expect(result.skippedCount, 1);
        expect(
          result.warningEntries.single,
          contains('no confident name-confirmed match found'),
        );
      },
    );

    test(
      'matching can escalate beyond 500m when a unique strong name match exists',
      () async {
        final peak = _buildPeak(
          osmId: 101,
          name: 'Mount Achilles',
          elevation: 1363,
          latitude: -41.85916,
          longitude: 145.97754,
        );
        final coords = _csvCoordinatesFromPeak(
          peak,
          eastingOffset: 900,
          northingOffset: -900,
        );
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nMount Achilles,1363,${peak.gridZoneDesignator},${coords.easting},${coords.northing},-41.85916,145.97754,3\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
          clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        );

        final result = await service.importPeakList(
          listName: 'Escalation',
          csvPath: '/tmp/escalation.csv',
        );

        expect(result.importedCount, 1);
        expect(result.skippedCount, 0);
        expect(result.warningEntries.single, contains('coordinate drift'));
      },
    );

    test('unchanged unique match keeps sourceOfTruth fixed as HWC', () async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Mount Achilles',
        elevation: 1363,
        latitude: -41.85916,
        longitude: 145.97754,
      ).copyWith(sourceOfTruth: Peak.sourceOfTruthHwc);
      final coords = _csvCoordinatesFromPeak(peak);
      final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
        csvLoader: (_) async =>
            'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nMount Achilles,1363,${peak.gridZoneDesignator},${coords.easting},${coords.northing},-41.85916,145.97754,3\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
      );

      final result = await service.importPeakList(
        listName: 'Source Reset',
        csvPath: '/tmp/reset.csv',
      );

      expect(result.importedCount, 1);
      expect(result.warningEntries, isEmpty);
      expect(
        peakRepository.findByOsmId(101)?.sourceOfTruth,
        Peak.sourceOfTruthHwc,
      );
    });

    test('matched HWC peak keeps stored peak data unchanged', () async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Mount Achilles',
        elevation: 1363,
        latitude: -41.85916,
        longitude: 145.97754,
      ).copyWith(sourceOfTruth: Peak.sourceOfTruthHwc);
      final coords = _csvCoordinatesFromPeak(
        peak,
        eastingOffset: 75,
        northingOffset: -125,
      );
      final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nMount Achilles,1401,${peak.gridZoneDesignator},${coords.easting},${coords.northing},-41.85856,145.97814,3\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
      );

      final result = await service.importPeakList(
        listName: 'Protected HWC',
        csvPath: '/tmp/protected-hwc.csv',
      );

      final storedPeak = peakRepository.findByOsmId(101);

      expect(result.importedCount, 1);
      expect(result.warningEntries, hasLength(2));
      expect(result.warningEntries.first, contains('coordinate drift'));
      expect(result.warningEntries.last, contains('kept height'));
      expect(storedPeak, isNotNull);
      expect(storedPeak?.latitude, peak.latitude);
      expect(storedPeak?.longitude, peak.longitude);
      expect(storedPeak?.elevation, peak.elevation);
      expect(storedPeak?.easting, peak.easting);
      expect(storedPeak?.northing, peak.northing);
      expect(storedPeak?.sourceOfTruth, Peak.sourceOfTruthHwc);
      expect(
        peakListRepository.getAllPeakLists().single.peakList,
        encodePeakListItems([const PeakListItem(peakOsmId: 101, points: 3)]),
      );
    });

    test(
      'ambiguous nearby peaks resolve when exactly one strong name match exists',
      () async {
        final targetPeak = _buildPeak(
          osmId: 201,
          name: 'Mount Ossa',
          elevation: 1617,
          latitude: -41.6542,
          longitude: 146.0312,
        );
        final nearbyPeak =
            _buildPeak(
              osmId: 202,
              name: 'Mount Ossa South',
              elevation: 1617,
              latitude: -41.6542,
              longitude: 146.0312,
            ).copyWith(
              gridZoneDesignator: targetPeak.gridZoneDesignator,
              mgrs100kId: targetPeak.mgrs100kId,
              easting: targetPeak.easting,
              northing: targetPeak.northing,
            );
        final coords = _csvCoordinatesFromPeak(targetPeak);
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: PeakRepository.test(
            InMemoryPeakStorage([targetPeak, nearbyPeak]),
          ),
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nMount Ossa,1617,${targetPeak.gridZoneDesignator},${coords.easting},${coords.northing},-41.6542,146.0312,6\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
          clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        );

        final result = await service.importPeakList(
          listName: 'Resolved Ambiguity',
          csvPath: '/tmp/resolved-ambiguity.csv',
        );

        expect(result.importedCount, 1);
        expect(result.skippedCount, 0);
        expect(
          peakListRepository.getAllPeakLists().single.peakList,
          encodePeakListItems([const PeakListItem(peakOsmId: 201, points: 6)]),
        );
      },
    );

    test(
      'name mismatch warns while unmatched rows create new peaks and ambiguous rows skip',
      () async {
        final matchingPeak = _buildPeak(
          osmId: 101,
          name: 'Mount Achilles',
          elevation: 1363,
          latitude: -41.85916,
          longitude: 145.97754,
        );
        final ambiguousPeakA = _buildPeak(
          osmId: 201,
          name: 'Mount Ossa',
          elevation: 1617,
          latitude: -41.6542,
          longitude: 146.0312,
        );
        final ambiguousPeakB = _buildPeak(
          osmId: 202,
          name: 'Mount Ossa South',
          elevation: 1617,
          latitude: -41.6542,
          longitude: 146.0312,
        );
        final matchingCoords = _csvCoordinatesFromPeak(matchingPeak);
        final ambiguousCoords = _csvCoordinatesFromPeak(ambiguousPeakA);
        final peakRepository = PeakRepository.test(
          InMemoryPeakStorage([matchingPeak, ambiguousPeakA, ambiguousPeakB]),
        );
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: peakRepository,
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nWrong Name,1363,${matchingPeak.gridZoneDesignator},${matchingCoords.easting},${matchingCoords.northing},-41.85916,145.97754,3\nMissing Peak,800,55G,4 15 135,53 65 355,-41.00000,145.00000,1\nMount Ossa West,1617,${ambiguousPeakA.gridZoneDesignator},${ambiguousCoords.easting},${ambiguousCoords.northing},-41.6542,146.0312,6\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
          clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        );

        final result = await service.importPeakList(
          listName: 'Warnings',
          csvPath: '/tmp/warnings.csv',
        );

        expect(result.importedCount, 2);
        expect(result.skippedCount, 1);
        expect(result.ambiguousCount, 1);
        expect(result.warningEntries, hasLength(2));
        expect(result.warningEntries.first, contains('imported Wrong Name as'));
        expect(
          result.warningEntries[1],
          contains('no confident name-confirmed match found'),
        );
        expect(result.logEntries, hasLength(2));
        expect(
          result.logEntries.first,
          startsWith('2024-01-02T03:04:05.000Z | '),
        );
        final createdPeak = peakRepository.getAllPeaks().firstWhere(
          (peak) => peak.name == 'Missing Peak',
        );
        expect(
          peakListRepository.getAllPeakLists().single.peakList,
          encodePeakListItems([
            const PeakListItem(peakOsmId: 101, points: 3),
            PeakListItem(peakOsmId: createdPeak.osmId, points: 1),
          ]),
        );
      },
    );

    test(
      're-import updates the existing list and surfaces log-write warnings',
      () async {
        final peak = _buildPeak(
          osmId: 101,
          name: 'Mount Achilles',
          elevation: 1363,
          latitude: -41.85916,
          longitude: 145.97754,
        );
        final coords = _csvCoordinatesFromPeak(peak);
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final createService = PeakListImportService(
          peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nMount Achilles,1363,${peak.gridZoneDesignator},${coords.easting},${coords.northing},-41.85916,145.97754,3\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
          clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        );

        final created = await createService.importPeakList(
          listName: 'Reimport',
          csvPath: '/tmp/create.csv',
        );

        final updateService = PeakListImportService(
          peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nWrong Name,1363,${peak.gridZoneDesignator},${coords.easting},${coords.northing},-41.85916,145.97754,6\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {
            throw StateError('boom');
          },
          clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        );

        final updated = await updateService.importPeakList(
          listName: 'Reimport',
          csvPath: '/tmp/update.csv',
        );

        expect(created.updated, isFalse);
        expect(updated.updated, isTrue);
        expect(updated.peakListId, created.peakListId);
        expect(updated.warningEntries, hasLength(2));
        expect(updated.warningEntries.last, 'Could not update import.log.');
        expect(updated.warningMessage, 'Could not update import.log.');
        expect(
          peakListRepository.getAllPeakLists().single.peakList,
          encodePeakListItems([const PeakListItem(peakOsmId: 101, points: 6)]),
        );
      },
    );

    test('Ht header alias is accepted', () async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Mount Achilles',
        elevation: 1363,
        latitude: -41.85916,
        longitude: 145.97754,
      );
      final coords = _csvCoordinatesFromPeak(peak);
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'Name,Ht,Zone,Easting,Northing,Latitude,Longitude,Points\nMount Achilles,1363,${peak.gridZoneDesignator},${coords.easting},${coords.northing},-41.85916,145.97754,3\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      final result = await service.importPeakList(
        listName: 'Alias Import',
        csvPath: '/tmp/alias.csv',
      );

      expect(result.importedCount, 1);
      expect(result.warningEntries, isEmpty);
    });

    test('latlng-only row derives UTM fields', () async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Mount Achilles',
        elevation: 1363,
        latitude: -41.85916,
        longitude: 145.97754,
      );
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nMount Achilles,1363,,,,-41.85916,145.97754,3\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      final result = await service.importPeakList(
        listName: 'LatLng Only',
        csvPath: '/tmp/latlng-only.csv',
      );

      expect(result.importedCount, 1);
      expect(peakListRepository.getAllPeakLists().single.peakList, isNotEmpty);
    });

    test('utm-only row derives latlng fields', () async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Mount Achilles',
        elevation: 1363,
        latitude: -41.85916,
        longitude: 145.97754,
      );
      final coords = _csvCoordinatesFromPeak(peak);
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nMount Achilles,1363,${peak.gridZoneDesignator},${coords.easting},${coords.northing},,,3\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      final result = await service.importPeakList(
        listName: 'UTM Only',
        csvPath: '/tmp/utm-only.csv',
      );

      expect(result.importedCount, 1);
      expect(result.warningEntries, isEmpty);
    });

    test(
      'blank and invalid values normalize to defaults with warnings',
      () async {
        final peak = _buildPeak(
          osmId: 101,
          name: 'Unknown',
          elevation: 0,
          latitude: -41.85916,
          longitude: 145.97754,
        );
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\n,,,,,-41.85916,145.97754,abc\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
          clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        );

        final result = await service.importPeakList(
          listName: 'Defaults',
          csvPath: '/tmp/defaults.csv',
        );

        expect(result.importedCount, 1);
        expect(result.warningEntries, hasLength(2));
        expect(
          result.warningEntries.first,
          contains('normalized invalid points'),
        );
        expect(result.warningEntries.last, contains('missing height'));
        expect(
          peakListRepository.getAllPeakLists().single.peakList,
          encodePeakListItems([const PeakListItem(peakOsmId: 101, points: 0)]),
        );
      },
    );

    test('duplicate resolved peaks keep first occurrence only', () async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Mount Achilles',
        elevation: 1363,
        latitude: -41.85916,
        longitude: 145.97754,
      );
      final coords = _csvCoordinatesFromPeak(peak);
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nMount Achilles,1363,${peak.gridZoneDesignator},${coords.easting},${coords.northing},-41.85916,145.97754,3\nMount Achilles,1363,${peak.gridZoneDesignator},${coords.easting},${coords.northing},-41.85916,145.97754,6\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      final result = await service.importPeakList(
        listName: 'Dedupe',
        csvPath: '/tmp/dedupe.csv',
      );

      expect(result.importedCount, 1);
      expect(
        peakListRepository.getAllPeakLists().single.peakList,
        encodePeakListItems([const PeakListItem(peakOsmId: 101, points: 3)]),
      );
    });

    test(
      'app-owned export csv updates by osmId, creates missing peaks, and preserves duplicate row order',
      () async {
        final existingPeak =
            _buildPeak(
              osmId: 101,
              name: 'Old Alpha',
              elevation: 1200,
              latitude: -41.80,
              longitude: 146.00,
            ).copyWith(
              altName: 'Old Alt',
              country: 'Old Country',
              county: 'Old County',
              range: 'Old Range',
              region: 'old-region',
              sourceOfTruth: Peak.sourceOfTruthOsm,
              verified: true,
              notes: 'keep notes',
            );
        final syntheticPeak = _buildPeak(
          osmId: -7,
          name: 'Synthetic Old',
          elevation: 333,
          latitude: -42.20,
          longitude: 146.60,
        ).copyWith(sourceOfTruth: Peak.sourceOfTruthHwc, difficulty: 'T4');
        final missingPeakTemplate =
            _buildPeak(
              osmId: 202,
              name: 'Created Peak',
              elevation: 1400,
              latitude: -41.91,
              longitude: 145.95,
            ).copyWith(
              altName: 'Created Alt',
              country: 'Australia',
              county: 'Kentish',
              range: 'Great Western Tiers',
              region: 'tasmania',
              sourceOfTruth: Peak.sourceOfTruthPeakBagger,
            );
        final updatedSyntheticTemplate =
            _buildPeak(
              osmId: -7,
              name: 'Synthetic Imported',
              elevation: 777,
              latitude: -42.201,
              longitude: 146.601,
            ).copyWith(
              altName: 'Synthetic Alt',
              country: 'Australia',
              county: 'Huon Valley',
              range: 'Southwest',
              region: 'tasmania',
              sourceOfTruth: Peak.sourceOfTruthHwc,
            );
        final peakRepository = PeakRepository.test(
          InMemoryPeakStorage([existingPeak, syntheticPeak]),
        );
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: peakRepository,
          peakListRepository: peakListRepository,
          csvLoader: (_) async => _appOwnedCsv([
            _appOwnedCsvRowForPeak(
              existingPeak.copyWith(
                name: 'Imported Alpha',
                altName: 'Imported Alt',
                elevation: 1250,
                country: 'Australia',
                county: 'Central Highlands',
                range: 'Du Cane',
                region: 'tasmania',
                sourceOfTruth: Peak.sourceOfTruthHwc,
              ),
              points: 7,
            ),
            _appOwnedCsvRowForPeak(missingPeakTemplate, points: 2),
            _appOwnedCsvRowForPeak(
              existingPeak.copyWith(
                name: 'Imported Alpha',
                altName: 'Imported Alt',
                elevation: 1250,
                country: 'Australia',
                county: 'Central Highlands',
                range: 'Du Cane',
                region: 'tasmania',
                sourceOfTruth: Peak.sourceOfTruthHwc,
              ),
              points: 5,
            ),
            _appOwnedCsvRowForPeak(updatedSyntheticTemplate, points: 9),
          ]),
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
        );

        final result = await service.importPeakList(
          listName: 'Round Trip Import',
          csvPath: '/tmp/round-trip.csv',
        );

        final importedPeak = peakRepository.findByOsmId(101);
        final createdPeak = peakRepository.findByOsmId(202);
        final updatedSyntheticPeak = peakRepository.findByOsmId(-7);
        final importedList = peakListRepository.findByName('Round Trip Import');

        expect(result.updated, isFalse);
        expect(result.importedCount, 4);
        expect(result.skippedCount, 0);
        expect(result.warningEntries, isEmpty);
        expect(importedPeak?.name, 'Imported Alpha');
        expect(importedPeak?.altName, 'Imported Alt');
        expect(importedPeak?.elevation, 1250);
        expect(importedPeak?.country, 'Australia');
        expect(importedPeak?.county, 'Central Highlands');
        expect(importedPeak?.range, 'Du Cane');
        expect(importedPeak?.region, 'tasmania');
        expect(importedPeak?.sourceOfTruth, Peak.sourceOfTruthHwc);
        expect(importedPeak?.verified, isTrue);
        expect(importedPeak?.notes, 'keep notes');
        expect(createdPeak, isNotNull);
        expect(createdPeak?.osmId, 202);
        expect(createdPeak?.name, 'Created Peak');
        expect(createdPeak?.altName, 'Created Alt');
        expect(createdPeak?.country, 'Australia');
        expect(createdPeak?.county, 'Kentish');
        expect(createdPeak?.range, 'Great Western Tiers');
        expect(createdPeak?.region, 'tasmania');
        expect(createdPeak?.sourceOfTruth, Peak.sourceOfTruthPeakBagger);
        expect(createdPeak?.difficulty, '');
        expect(createdPeak?.notes, '');
        expect(createdPeak?.verified, isFalse);
        expect(createdPeak?.prominence, isNull);
        expect(updatedSyntheticPeak?.name, 'Synthetic Imported');
        expect(updatedSyntheticPeak?.difficulty, 'T4');
        expect(importedList?.region, Peak.defaultRegion);
        expect(
          decodePeakListItems(
            importedList!.peakList,
          ).map((item) => (item.peakOsmId, item.points)).toList(),
          [(101, 7), (202, 2), (101, 5), (-7, 9)],
        );
      },
    );

    test('app-owned export import preserves an existing list region', () async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Mount Achilles',
        elevation: 1363,
        latitude: -41.85916,
        longitude: 145.97754,
      ).copyWith(region: 'old-peak-region');
      final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Existing Import',
            region: 'italy-nord-est',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 101, points: 1),
            ]),
          )..peakListId = 1,
        ]),
        peakRepository: peakRepository,
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async => _appOwnedCsv([
          _appOwnedCsvRowForPeak(
            peak.copyWith(
              region: 'tasmania',
              sourceOfTruth: Peak.sourceOfTruthHwc,
            ),
            points: 4,
          ),
        ]),
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      final result = await service.importPeakList(
        listName: 'Existing Import',
        csvPath: '/tmp/existing-import.csv',
      );

      expect(result.updated, isTrue);
      expect(
        peakListRepository.findByName('Existing Import')?.region,
        Peak.defaultRegion,
      );
      expect(
        decodePeakListItems(
          peakListRepository.findByName('Existing Import')!.peakList,
        ).map((item) => (item.peakOsmId, item.points)).toList(),
        [(101, 4)],
      );
    });

    test('app-owned export import left pads short grid components', () async {
      final expectedLatLng = PeakMgrsConverter.latLngFromComponents(
        gridZoneDesignator: '55G',
        mgrs100kId: 'EP',
        easting: '00020',
        northing: '08881',
      );
      final peakRepository = PeakRepository.test(InMemoryPeakStorage());
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async => _appOwnedCsv([
          {
            'name': 'Short Grid Peak',
            'altName': '',
            'elevation': '1200',
            'gridZoneDesignator': '55G',
            'mgrs100kId': 'EP',
            'easting': '20',
            'northing': '8881',
            'Points': '3',
            'osmId': '101',
            'country': 'Australia',
            'region': 'tasmania',
            'county': 'Kentish',
            'range': 'Range',
            'sourceOfTruth': Peak.sourceOfTruthOsm,
          },
        ]),
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      await service.importPeakList(
        listName: 'Short Grid Import',
        csvPath: '/tmp/short-grid.csv',
      );

      final createdPeak = peakRepository.findByOsmId(101);
      expect(createdPeak?.easting, '00020');
      expect(createdPeak?.northing, '08881');
      expect(createdPeak?.latitude, closeTo(expectedLatLng.latitude, 0.000001));
      expect(
        createdPeak?.longitude,
        closeTo(expectedLatLng.longitude, 0.000001),
      );
    });

    test(
      'app-owned export import validates the full file before writes',
      () async {
        final peak = _buildPeak(
          osmId: 101,
          name: 'Original Peak',
          elevation: 1363,
          latitude: -41.85916,
          longitude: 145.97754,
        ).copyWith(sourceOfTruth: Peak.sourceOfTruthOsm);
        final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: peakRepository,
          peakListRepository: peakListRepository,
          csvLoader: (_) async => _appOwnedCsv([
            _appOwnedCsvRowForPeak(
              peak.copyWith(
                name: 'Updated Peak',
                sourceOfTruth: Peak.sourceOfTruthHwc,
              ),
              points: 3,
            ),
            {
              'name': 'Broken Peak',
              'altName': '',
              'elevation': '1200',
              'gridZoneDesignator': '55G',
              'mgrs100kId': 'EP',
              'easting': '00000',
              'northing': '50223',
              'Points': 'oops',
              'osmId': '202',
              'country': 'Australia',
              'region': 'tasmania',
              'county': 'Kentish',
              'range': 'Range',
              'sourceOfTruth': Peak.sourceOfTruthOsm,
            },
          ]),
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
        );

        await expectLater(
          service.importPeakList(
            listName: 'Atomic Import',
            csvPath: '/tmp/atomic.csv',
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'invalid Points "oops" on row 3 (Broken Peak)',
            ),
          ),
        );

        expect(peakRepository.findByOsmId(101)?.name, 'Original Peak');
        expect(
          peakRepository.findByOsmId(101)?.sourceOfTruth,
          Peak.sourceOfTruthOsm,
        );
        expect(peakRepository.findByOsmId(202), isNull);
        expect(peakListRepository.getAllPeakLists(), isEmpty);
      },
    );

    test('old export header is rejected by the new-format importer', () async {
      final peakRepository = PeakRepository.test(InMemoryPeakStorage());
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'Name,Alt Name,Elevation,Zone,mgrs100kId,Easting,Northing,Points,osmId\n'
            'Legacy Peak,,1200,55G,EP,00000,50223,3,101\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      await expectLater(
        service.importPeakList(
          listName: 'Legacy Export',
          csvPath: '/tmp/legacy-export.csv',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'CSV is missing required column: Height',
          ),
        ),
      );

      expect(peakRepository.getAllPeaks(), isEmpty);
      expect(peakListRepository.getAllPeakLists(), isEmpty);
    });

    test('missing headers throw before row import succeeds', () async {
      final service = PeakListImportService(
        peakRepository: PeakRepository.test(InMemoryPeakStorage()),
        peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
        csvLoader: (_) async =>
            'Name,Height,Zone,Easting,Northing,Latitude,Longitude\nMissing Points,1000,55G,4 15 135,53 65 355,-41.0,145.0\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      await expectLater(
        service.importPeakList(
          listName: 'Missing Header',
          csvPath: '/tmp/missing-header.csv',
        ),
        throwsFormatException,
      );
    });
  });
}

Peak _buildPeak({
  required int osmId,
  required String name,
  required double elevation,
  required double latitude,
  required double longitude,
}) {
  final mgrs = PeakMgrsConverter.fromLatLng(LatLng(latitude, longitude));
  return Peak(
    osmId: osmId,
    name: name,
    elevation: elevation,
    latitude: latitude,
    longitude: longitude,
    gridZoneDesignator: mgrs.gridZoneDesignator,
    mgrs100kId: mgrs.mgrs100kId,
    easting: mgrs.easting,
    northing: mgrs.northing,
  );
}

({String easting, String northing}) _csvCoordinatesFromPeak(
  Peak peak, {
  int eastingOffset = 0,
  int northingOffset = 0,
}) {
  final utm = mgrs.Mgrs.decode(
    '${peak.gridZoneDesignator}${peak.mgrs100kId}${peak.easting}${peak.northing}',
  );
  return (
    easting: _formatCsvUtmComponent(utm.easting.truncate() + eastingOffset),
    northing: _formatCsvUtmComponent(utm.northing.truncate() + northingOffset),
  );
}

String _formatCsvUtmComponent(int value) {
  final digits = value.toString();
  if (digits.length == 6) {
    return '${digits.substring(0, 1)} ${digits.substring(1, 3)} ${digits.substring(3)}';
  }
  if (digits.length == 7) {
    return '${digits.substring(0, 2)} ${digits.substring(2, 4)} ${digits.substring(4)}';
  }
  return digits;
}

String _appOwnedCsv(List<Map<String, String>> rows) {
  final lines = [
    PeakListCsvExportService.csvHeaders.join(','),
    for (final row in rows)
      PeakListCsvExportService.csvHeaders
          .map((header) => _csvCell(row[header] ?? ''))
          .join(','),
  ];
  return '${lines.join('\n')}\n';
}

Map<String, String> _appOwnedCsvRowForPeak(Peak peak, {required int points}) {
  return {
    'name': peak.name,
    'altName': peak.altName,
    'elevation': peak.elevation?.toString() ?? '',
    'gridZoneDesignator': peak.gridZoneDesignator,
    'mgrs100kId': peak.mgrs100kId,
    'easting': peak.easting,
    'northing': peak.northing,
    'Points': '$points',
    'osmId': '${peak.osmId}',
    'country': peak.country,
    'region': peak.region ?? '',
    'county': peak.county,
    'range': peak.range,
    'sourceOfTruth': peak.sourceOfTruth,
  };
}

String _csvCell(String value) {
  if (!value.contains(',') && !value.contains('"') && !value.contains('\n')) {
    return value;
  }
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
