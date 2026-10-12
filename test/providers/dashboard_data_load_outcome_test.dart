import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/local_data_load_outcome_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/mapping_catalog_fixture.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  test(
    'a failed actual track read never qualifies its empty fallback',
    () async {
      SharedPreferences.setMockInitialValues({
        MigrationMarkerStore.migrationKey: true,
        MigrationMarkerStore.itemVisibilityBackfillKey: true,
        MigrationMarkerStore.peaksBaggedBackfillKey: true,
      });
      final notifier = MapNotifier(
        mappingCatalog: testMappingCatalog,
        peakRepository: PeakRepository.test(InMemoryPeakStorage()),
        gpxTrackRepository: GpxTrackRepository.test(_FailingTracks()),
        routeRepository: RouteRepository.test(InMemoryRouteStorage()),
        peaksBaggedRepository: PeaksBaggedRepository.test(
          InMemoryPeaksBaggedStorage(),
        ),
        tasmapRepository: await TestTasmapRepository.create(),
        loadPeaksOnBuild: false,
        loadPositionOnBuild: false,
      );
      final container = ProviderContainer(
        overrides: [
          ...mappingCatalogTestOverrides,
          mapProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);
      container.read(mapProvider);
      expect(container.read(mapDashboardLoadProvider).isLoading, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(container.read(mapProvider).tracks, isEmpty);
      expect(container.read(mapDashboardLoadProvider).hasError, isTrue);
      expect(
        '${container.read(mapDashboardLoadProvider).error}',
        contains('tracks unavailable'),
      );
    },
  );
}

class _FailingTracks extends InMemoryGpxTrackStorage {
  @override
  List<GpxTrack> getAll() => throw StateError('tracks unavailable');
}
