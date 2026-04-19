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
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
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
          peakListRepository.getAllPeakLists().single.peakList,
          encodePeakListItems([
            const PeakListItem(peakOsmId: 101, points: '3'),
          ]),
        );
      },
    );

    test(
      'name mismatch warns only while zero and multi-match rows skip',
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
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage(),
        );
        final service = PeakListImportService(
          peakRepository: PeakRepository.test(
            InMemoryPeakStorage([matchingPeak, ambiguousPeakA, ambiguousPeakB]),
          ),
          peakListRepository: peakListRepository,
          csvLoader: (_) async =>
              'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nWrong Name,1363,${matchingPeak.gridZoneDesignator},${matchingCoords.easting},${matchingCoords.northing},-41.85916,145.97754,3\nMissing Peak,800,55G,4 15 135,53 65 355,-41.00000,145.00000,1\nMount Ossa,1617,${ambiguousPeakA.gridZoneDesignator},${ambiguousCoords.easting},${ambiguousCoords.northing},-41.6542,146.0312,6\n',
          importRootLoader: () async => '/tmp/Bushwalking',
          logWriter: (logPath, entries) async {},
          clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        );

        final result = await service.importPeakList(
          listName: 'Warnings',
          csvPath: '/tmp/warnings.csv',
        );

        expect(result.importedCount, 1);
        expect(result.skippedCount, 2);
        expect(result.ambiguousCount, 1);
        expect(result.warningEntries, hasLength(3));
        expect(result.warningEntries.first, contains('imported Wrong Name as'));
        expect(result.warningEntries[1], contains('no matching peak found'));
        expect(result.warningEntries[2], contains('multiple matching peaks'));
        expect(result.logEntries, hasLength(3));
        expect(
          result.logEntries.first,
          startsWith('2024-01-02T03:04:05.000Z | '),
        );
        expect(
          peakListRepository.getAllPeakLists().single.peakList,
          encodePeakListItems([
            const PeakListItem(peakOsmId: 101, points: '3'),
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
            const PeakListItem(peakOsmId: 101, points: '6'),
          ]),
        );
      },
    );
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

({String easting, String northing}) _csvCoordinatesFromPeak(Peak peak) {
  final utm = mgrs.Mgrs.decode(
    '${peak.gridZoneDesignator}${peak.mgrs100kId}${peak.easting}${peak.northing}',
  );
  return (
    easting: _formatCsvUtmComponent(utm.easting.truncate()),
    northing: _formatCsvUtmComponent(utm.northing.truncate()),
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
