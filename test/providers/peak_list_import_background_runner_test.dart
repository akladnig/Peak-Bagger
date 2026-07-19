import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/peak_list_import_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';

import '../harness/test_map_notifier.dart';

void main() {
  test(
    'background runner exposes row progress and extended presentation fields',
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
        peakRepository: peakRepository,
      );
      final service = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: peakListRepository,
        csvLoader: (_) async =>
            'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\n'
            'Wrong Name,1363,${matchingPeak.gridZoneDesignator},${matchingCoords.easting},${matchingCoords.northing},-41.85916,145.97754,3\n'
            'Missing Peak,800,55G,4 15 135,53 65 355,-41.00000,145.00000,1\n'
            'Mount Ossa West,1617,${ambiguousPeakA.gridZoneDesignator},${ambiguousCoords.easting},${ambiguousCoords.northing},-41.6542,146.0312,6\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
        clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
      );

      final container = ProviderContainer(
        overrides: [
          peakListRepositoryProvider.overrideWithValue(peakListRepository),
          currentRoutePathProvider.overrideWithValue('/peaks'),
          peakListImportServiceProvider.overrideWithValue(service),
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 15,
                basemap: Basemap.tracestrack,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final progressEvents = <PeakListImportProgress>[];
      final runner = container.read(peakListImportBackgroundRunnerProvider);
      final result = await runner(
        listName: 'Warnings',
        csvPath: '/tmp/warnings.csv',
        onProgress: progressEvents.add,
      );

      expect(progressEvents, isNotEmpty);
      expect(progressEvents.first.processedRows, 0);
      expect(progressEvents.first.totalRows, 3);
      expect(progressEvents.first.currentFileName, 'warnings.csv');
      expect(progressEvents.last.processedRows, 3);
      expect(progressEvents.last.totalRows, 3);

      expect(result.importedCount, 2);
      expect(result.skippedCount, 1);
      expect(result.ambiguousCount, 1);
      expect(result.warningCount, 2);
      expect(result.logEntryCount, 2);
      expect(result.importLogNote, 'See import.log for details.');
    },
  );

  test(
    'background runner reloads map-owned peaks so metadata filters refresh in all peaks mode',
    () async {
      final originalPeak = _buildPeak(
        osmId: 101,
        name: 'FVG T Peak',
        elevation: 1000,
        latitude: 46.2,
        longitude: 13.2,
      ).copyWith(rating: 4.8, difficulty: 'T', region: 'fvg');
      final updatedPeak = originalPeak.copyWith(
        rating: 4.2,
        difficulty: 'Easy',
        region: 'tasmania',
      );
      final peakRepository = PeakRepository.test(
        InMemoryPeakStorage([originalPeak]),
      );
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final mapNotifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          peaks: [originalPeak],
          peakListSelectionMode: PeakListSelectionMode.allPeaks,
          peakDifficultyFilter: const PeakDifficultyFilterOption(
            region: 'fvg',
            difficulty: 'T',
          ),
        ),
        peakRepository: peakRepository,
      );

      final container = ProviderContainer(
        overrides: [
          peakListRepositoryProvider.overrideWithValue(peakListRepository),
          currentRoutePathProvider.overrideWithValue('/map'),
          peakListSelectionRefreshSchedulerProvider.overrideWithValue((
            task,
          ) async {
            await task();
          }),
          peakListImportServiceProvider.overrideWithValue(
            _ReloadingImportService(
              peakRepository: peakRepository,
              peakListRepository: peakListRepository,
              updatedPeak: updatedPeak,
            ),
          ),
          mapProvider.overrideWith(() => mapNotifier),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container
            .read(filteredPeaksProvider)
            .map((peak) => peak.osmId)
            .toList(),
        [101],
      );
      expect(container.read(mapDifficultyFilterOptionsProvider), [
        const PeakDifficultyFilterOption(region: 'fvg', difficulty: 'T'),
      ]);

      final runner = container.read(peakListImportBackgroundRunnerProvider);
      await runner(listName: 'Imported Peaks', csvPath: '/tmp/import.csv');
      await Future<void>.delayed(Duration.zero);

      expect(mapNotifier.reloadPeakMarkersCallCount, 1);
      expect(container.read(peakRevisionProvider), 1);
      expect(container.read(peakListRevisionProvider), 1);
      expect(container.read(mapProvider).peaks.single.difficulty, 'Easy');
      expect(container.read(filteredPeaksProvider), isEmpty);
      expect(container.read(mapDifficultyFilterOptionsProvider), [
        const PeakDifficultyFilterOption(
          region: 'tasmania',
          difficulty: 'Easy',
        ),
      ]);
    },
  );

  test(
    'background runner does not await map reload when map is off-screen',
    () async {
      final originalPeak = _buildPeak(
        osmId: 101,
        name: 'FVG T Peak',
        elevation: 1000,
        latitude: 46.2,
        longitude: 13.2,
      ).copyWith(rating: 4.8, difficulty: 'T', region: 'fvg');
      final updatedPeak = originalPeak.copyWith(
        rating: 4.2,
        difficulty: 'Easy',
        region: 'tasmania',
      );
      final peakRepository = PeakRepository.test(
        InMemoryPeakStorage([originalPeak]),
      );
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final mapNotifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          peaks: [originalPeak],
          peakListSelectionMode: PeakListSelectionMode.allPeaks,
        ),
        peakRepository: peakRepository,
      );

      final container = ProviderContainer(
        overrides: [
          peakListRepositoryProvider.overrideWithValue(peakListRepository),
          currentRoutePathProvider.overrideWithValue('/peaks'),
          peakListImportServiceProvider.overrideWithValue(
            _ReloadingImportService(
              peakRepository: peakRepository,
              peakListRepository: peakListRepository,
              updatedPeak: updatedPeak,
            ),
          ),
          mapProvider.overrideWith(() => mapNotifier),
        ],
      );
      addTearDown(container.dispose);

      final runner = container.read(peakListImportBackgroundRunnerProvider);
      await runner(listName: 'Imported Peaks', csvPath: '/tmp/import.csv');
      await Future<void>.delayed(Duration.zero);

      expect(mapNotifier.reloadPeakMarkersCallCount, 0);
      expect(container.read(peakRevisionProvider), 1);
      expect(container.read(peakListRevisionProvider), 1);
    },
  );
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

class _ReloadingImportService extends PeakListImportService {
  _ReloadingImportService({
    required this.peakRepository,
    required this.peakListRepository,
    required this.updatedPeak,
  }) : super(
         peakRepository: peakRepository,
         peakListRepository: peakListRepository,
       );

  final PeakRepository peakRepository;
  final PeakListRepository peakListRepository;
  final Peak updatedPeak;

  @override
  Future<PeakListImportResult> importPeakList({
    required String listName,
    required String csvPath,
    PeakListImportProgressCallback? onProgress,
  }) async {
    await peakRepository.save(updatedPeak);
    await peakListRepository.save(PeakList(name: listName));
    return const PeakListImportResult(
      peakListId: 1,
      updated: false,
      importedCount: 1,
      skippedCount: 0,
      matchedCount: 1,
      ambiguousCount: 0,
      warningEntries: [],
      logEntries: [],
    );
  }
}
