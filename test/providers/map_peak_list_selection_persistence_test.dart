import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_list_import_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test('startup normalizes stale persisted specific list to all peaks', () async {
    SharedPreferences.setMockInitialValues({
      'map_position_lat': -43.0,
      'map_position_lng': 147.0,
      'map_zoom': 12.0,
      'peak_list_selection_mode': 'specificList',
      'peak_list_id': 99,
    });

    final tasmapRepository = await TestTasmapRepository.create();
    final container = ProviderContainer(
      overrides: [
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        mapProvider.overrideWith(
          () => MapNotifier(
            peakRepository: PeakRepository.test(InMemoryPeakStorage()),
            overpassService: OverpassService(),
            tasmapRepository: tasmapRepository,
            gpxTrackRepository: GpxTrackRepository.test(
              InMemoryGpxTrackStorage(),
            ),
            peaksBaggedRepository: PeaksBaggedRepository.test(
              InMemoryPeaksBaggedStorage(),
            ),
            loadPeaksOnBuild: false,
            loadTracksOnBuild: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(mapProvider.notifier);
    await _drainAsync();

    expect(
      container.read(mapProvider).peakListSelectionMode,
      PeakListSelectionMode.allPeaks,
    );
    expect(container.read(mapProvider).selectedPeakListId, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('peak_list_selection_mode'), 'allPeaks');
    expect(prefs.getInt('peak_list_id'), isNull);
  });

  test('import runner bumps revision and reconciles selected list', () async {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              peakListSelectionMode: PeakListSelectionMode.specificList,
              selectedPeakListId: 7,
            ),
          ),
        ),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        peakListImportServiceProvider.overrideWithValue(_FakeImportService()),
      ],
    );
    addTearDown(container.dispose);

    final runner = container.read(peakListImportRunnerProvider);
    await runner(listName: 'Alpha', csvPath: '/tmp/alpha.csv');

    expect(container.read(peakListRevisionProvider), 1);
    expect(
      container.read(mapProvider).peakListSelectionMode,
      PeakListSelectionMode.allPeaks,
    );
    expect(container.read(mapProvider).selectedPeakListId, isNull);
  });
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

class _InitialStateMapNotifier extends MapNotifier {
  _InitialStateMapNotifier(this.initialState);

  final MapState initialState;

  @override
  MapState build() => initialState;
}

class _FakeImportService extends PeakListImportService {
  _FakeImportService()
    : super(
        peakRepository: PeakRepository.test(InMemoryPeakStorage()),
        peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
      );

  @override
  Future<PeakListImportResult> importPeakList({
    required String listName,
    required String csvPath,
  }) async {
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
