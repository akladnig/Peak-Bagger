import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak_list.dart';
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
  test('startup ignores legacy peak list prefs and keeps default all peaks', () async {
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
    expect(prefs.getString('peak_list_selection_mode'), 'specificList');
    expect(prefs.getInt('peak_list_id'), 99);
  });

  test('startup resets corrupt v2 payloads to default all peaks', () async {
    SharedPreferences.setMockInitialValues({
      'peak_list_selection_mode_v2': 'specificList',
      'peak_list_selected_ids_v2': '{oops}',
      'peak_list_previous_specific_ids_v2': '[7]',
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

    expect(container.read(mapProvider).peakListSelectionMode, PeakListSelectionMode.allPeaks);
    expect(container.read(mapProvider).selectedPeakListIds, isEmpty);
    expect(container.read(mapProvider).previousSpecificPeakListIds, isEmpty);
  });

  test('startup restores pinned ids by region', () async {
    SharedPreferences.setMockInitialValues({
      'peak_list_selection_mode_v2': 'specificList',
      'peak_list_selected_ids_v2': '[7]',
      'peak_list_previous_specific_ids_v2': '[7]',
      'peak_list_pinned_ids_by_region_v1': '{"tasmania":[7],"new-south-wales":[8]}',
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

    expect(container.read(mapProvider).peakListSelectionMode, PeakListSelectionMode.specificList);
    expect(container.read(mapProvider).selectedPeakListIds, {7});
    expect(container.read(mapProvider).pinnedPeakListIdsByRegion, {
      'new-south-wales': {8},
      'tasmania': {7},
    });
  });

  test('startup clears corrupt pinned payload without disturbing selection', () async {
    SharedPreferences.setMockInitialValues({
      'peak_list_selection_mode_v2': 'specificList',
      'peak_list_selected_ids_v2': '[7]',
      'peak_list_previous_specific_ids_v2': '[7]',
      'peak_list_pinned_ids_by_region_v1': '{oops}',
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

    expect(container.read(mapProvider).peakListSelectionMode, PeakListSelectionMode.specificList);
    expect(container.read(mapProvider).selectedPeakListIds, {7});
    expect(container.read(mapProvider).previousSpecificPeakListIds, {7});
    expect(container.read(mapProvider).pinnedPeakListIdsByRegion, isEmpty);
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
              selectedPeakListIds: {7},
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
      PeakListSelectionMode.specificList,
    );
    expect(container.read(mapProvider).selectedPeakListIds, {7});
  });

  test('repository failure during reconcile preserves specific-list selection', () async {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              peakListSelectionMode: PeakListSelectionMode.specificList,
              selectedPeakListIds: {7},
              previousSpecificPeakListIds: {7},
            ),
          ),
        ),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(_ThrowingPeakListStorage()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(mapProvider.notifier).reconcileSelectedPeakList();
    await _drainAsync();

    expect(
      container.read(mapProvider).peakListSelectionMode,
      PeakListSelectionMode.specificList,
    );
    expect(container.read(mapProvider).selectedPeakListIds, {7});
    expect(container.read(mapProvider).previousSpecificPeakListIds, {7});
  });

  test('peak list selection save does not rewrite camera prefs', () async {
    SharedPreferences.setMockInitialValues({
      'map_position_lat': -43.0,
      'map_position_lng': 147.0,
      'map_zoom': 12.0,
    });

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(mapProvider.notifier).selectPeakList(
      PeakListSelectionMode.specificList,
      peakListId: 7,
    );
    await _drainAsync();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('map_position_lat'), -43.0);
    expect(prefs.getDouble('map_position_lng'), 147.0);
    expect(prefs.getDouble('map_zoom'), 12.0);
    expect(prefs.getString('peak_list_selection_mode_v2'), 'specificList');
    expect(prefs.getString('peak_list_selected_ids_v2'), '[7]');
    expect(prefs.getString('peak_list_previous_specific_ids_v2'), '[7]');
  });

  test('rapid toggles persist the final v2 selection state', () async {
    SharedPreferences.setMockInitialValues({});
    final tasmapRepository = await TestTasmapRepository.create();

    final container = ProviderContainer(
      overrides: [
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
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(mapProvider.notifier);
    await _drainAsync();
    notifier.selectPeakList(PeakListSelectionMode.specificList, peakListId: 7);
    notifier.selectPeakList(PeakListSelectionMode.specificList, peakListId: 8);
    await _drainAsync();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('peak_list_selection_mode_v2'), 'specificList');
    expect(prefs.getString('peak_list_selected_ids_v2'), '[8]');
    expect(prefs.getString('peak_list_previous_specific_ids_v2'), '[8]');
  });

  test('pinning peak list persists per-region ids without changing selection', () async {
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              peakListSelectionMode: PeakListSelectionMode.specificList,
              selectedPeakListIds: {7},
              previousSpecificPeakListIds: {7},
            ),
          ),
        ),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(mapProvider.notifier).pinPeakListForRegion(
      regionKey: 'tasmania',
      peakListId: 9,
    );
    await _drainAsync();

    expect(container.read(mapProvider).selectedPeakListIds, {7});
    expect(container.read(mapProvider).previousSpecificPeakListIds, {7});
    expect(container.read(mapProvider).pinnedPeakListIdsByRegion, {
      'tasmania': {9},
    });

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('peak_list_pinned_ids_by_region_v1'),
      '{"tasmania":[9]}',
    );
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

  @override
  Future<void> persistPeakListSelection() async {
    final mode = state.peakListSelectionMode;
    final selectedPeakListIds = state.selectedPeakListIds;
    final previousSpecificPeakListIds = state.previousSpecificPeakListIds;
    final pinnedPeakListIdsByRegion = state.pinnedPeakListIdsByRegion;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'peak_list_selection_mode_v2',
      mode.name,
    );
    await prefs.setString(
      'peak_list_selected_ids_v2',
      _sortedIdsJson(selectedPeakListIds),
    );
    await prefs.setString(
      'peak_list_previous_specific_ids_v2',
      _sortedIdsJson(previousSpecificPeakListIds),
    );
    await prefs.setString(
      'peak_list_pinned_ids_by_region_v1',
      _sortedRegionIdsJson(pinnedPeakListIdsByRegion),
    );
  }
}

String _sortedIdsJson(Set<int> ids) {
  final sorted = ids.toList()..sort();
  return '[${sorted.join(',')}]';
}

String _sortedRegionIdsJson(Map<String, Set<int>> idsByRegion) {
  final sortedKeys = idsByRegion.keys.toList()..sort();
  final parts = <String>[];
  for (final key in sortedKeys) {
    parts.add('"$key":${_sortedIdsJson(idsByRegion[key] ?? const <int>{})}');
  }
  return '{${parts.join(',')}}';
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

class _ThrowingPeakListStorage extends InMemoryPeakListStorage {
  @override
  List<PeakList> getAll() {
    throw StateError('boom');
  }
}
