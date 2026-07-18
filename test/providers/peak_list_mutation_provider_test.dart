// ignore_for_file: use_super_parameters

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
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  test('successful source mutation no longer refreshes Tassy Full', () async {
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([_peak(11), _peak(22), _peak(99)]),
    );
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage(),
      peakRepository: peakRepository,
    );
    final abels = await repository.save(
      PeakList(
        name: 'Abels',
        peakList: encodePeakListItems([
          const PeakListItem(peakOsmId: 11, points: 2),
        ]),
      ),
    );
    await repository.save(
      PeakList(
        name: 'Tassy Full',
        peakList: encodePeakListItems([
          const PeakListItem(peakOsmId: 99, points: 9),
        ]),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              peakListSelectionMode: PeakListSelectionMode.specificList,
              selectedPeakListIds: {999},
            ),
          ),
        ),
        peakListRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final mutationRepository = container.read(
      peakListMutationRepositoryProvider,
    );
    await mutationRepository.addPeakItem(
      peakListId: abels.peakListId,
      item: const PeakListItem(peakOsmId: 22, points: 4),
    );

    expect(container.read(peakListRevisionProvider), 0);
    expect(
      container.read(mapProvider).peakListSelectionMode,
      PeakListSelectionMode.specificList,
    );
    expect(container.read(mapProvider).selectedPeakListId, 999);
    expect(
      repository.getPeakListItemsForList(abels.peakListId)
          .map((item) => (item.peakOsmId, item.points))
          .toList(),
      [(11, 2), (22, 4)],
    );
    expect(
      decodePeakListItems(
        repository.findByName('Tassy Full')!.peakList,
      ).map((item) => (item.peakOsmId, item.points)).toList(),
      [(99, 9)],
    );
  });

  test(
    'import runner still bumps revision and reconciles selection without refreshing Tassy Full',
    () async {
      final importedPeak = _peak(101);
      final importedCoords = _csvCoordinatesFromPeak(importedPeak);
      final peakRepository = PeakRepository.test(
        InMemoryPeakStorage([importedPeak]),
      );
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Tassy Full',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 99, points: 9),
            ]),
          )..peakListId = 1,
        ]),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([_peak(99), _peak(101)]),
        ),
      );
      final importService = PeakListImportService(
        peakRepository: peakRepository,
        peakListRepository: repository,
        csvLoader: (_) async =>
            'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\n'
            'Peak 101,1000,${importedPeak.gridZoneDesignator},${importedCoords.easting},${importedCoords.northing},${importedPeak.latitude},${importedPeak.longitude},3\n',
        importRootLoader: () async => '/tmp/Bushwalking',
        logWriter: (logPath, entries) async {},
      );

      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(
            () => _InitialStateMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 15,
                basemap: Basemap.tracestrack,
                peakListSelectionMode: PeakListSelectionMode.specificList,
                selectedPeakListIds: {999},
              ),
            ),
          ),
          peakRepositoryProvider.overrideWithValue(peakRepository),
          peakListRepositoryProvider.overrideWithValue(repository),
          peakListImportServiceProvider.overrideWithValue(importService),
        ],
      );
      addTearDown(container.dispose);

      final runner = container.read(peakListImportRunnerProvider);
      await runner(listName: 'Imported Peaks', csvPath: '/tmp/import.csv');

      expect(container.read(peakListRevisionProvider), 1);
      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.specificList,
      );
      expect(container.read(mapProvider).selectedPeakListId, 999);
      expect(repository.findByName('Imported Peaks'), isNotNull);
      expect(
        decodePeakListItems(
          repository.findByName('Tassy Full')!.peakList,
        ).map((item) => (item.peakOsmId, item.points)).toList(),
        [(99, 9)],
      );
    },
  );

  test(
    'membership refresh runner updates selected map peaks without reloading markers',
    () async {
      final peakRepository = PeakRepository.test(
        InMemoryPeakStorage([_peak(11), _peak(22)]),
      );
      final repository = PeakListRepository.test(
        InMemoryPeakListStorage(),
        peakRepository: peakRepository,
      );
      final saved = await repository.save(
        PeakList(
          name: 'Abels',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 11, points: 2),
          ]),
        ),
      );

      final mapNotifier = _InitialStateMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          peaks: peakRepository.getAllPeaks(),
          peakListSelectionMode: PeakListSelectionMode.specificList,
          selectedPeakListIds: {saved.peakListId},
        ),
      );
      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(() => mapNotifier),
          peakRepositoryProvider.overrideWithValue(peakRepository),
          peakListRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(filteredPeaksProvider).map((peak) => peak.osmId).toList(),
        [11],
      );

      await repository.addPeakItems(
        peakListId: saved.peakListId,
        items: const [PeakListItem(peakOsmId: 22, points: 4)],
      );

      expect(
        container.read(filteredPeaksProvider).map((peak) => peak.osmId).toList(),
        [11],
      );

      container.read(peakListMembershipRefreshRunnerProvider)();

      expect(container.read(peakListRevisionProvider), 1);
      expect(mapNotifier.reloadPeakMarkersCallCount, 0);
      expect(
        container.read(filteredPeaksProvider).map((peak) => peak.osmId).toList(),
        [11, 22],
      );
    },
  );
}

class _InitialStateMapNotifier extends MapNotifier {
  _InitialStateMapNotifier(this.initialState);

  final MapState initialState;
  int reloadPeakMarkersCallCount = 0;

  @override
  MapState build() => initialState;

  @override
  Future<void> reloadPeakMarkers() async {
    reloadPeakMarkersCallCount += 1;
    state = state.copyWith(isLoadingPeaks: false, clearError: true);
    reconcileSelectedPeakList();
  }
}

Peak _peak(int osmId, {String region = Peak.defaultRegion}) {
  final mgrsComponents = PeakMgrsConverter.fromLatLng(
    const LatLng(-41.5, 146.5),
  );
  return Peak(
    osmId: osmId,
    name: 'Peak $osmId',
    elevation: 1000,
    latitude: -41.5,
    longitude: 146.5,
    region: region,
    gridZoneDesignator: mgrsComponents.gridZoneDesignator,
    mgrs100kId: mgrsComponents.mgrs100kId,
    easting: mgrsComponents.easting,
    northing: mgrsComponents.northing,
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
