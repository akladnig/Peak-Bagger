import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_import_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  group('PeakListImportService', () {
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
          encodePeakListItems([
            const PeakListItem(peakOsmId: 101, points: 3),
          ]),
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
        );
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
          encodePeakListItems([
            const PeakListItem(peakOsmId: 201, points: 6),
          ]),
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
          encodePeakListItems([
            const PeakListItem(peakOsmId: 101, points: 6),
          ]),
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

    test('blank and invalid values normalize to defaults with warnings', () async {
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
      expect(result.warningEntries.first, contains('normalized invalid points'));
      expect(result.warningEntries.last, contains('missing height'));
      expect(
        peakListRepository.getAllPeakLists().single.peakList,
        encodePeakListItems([const PeakListItem(peakOsmId: 101, points: 0)]),
      );
    });

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
