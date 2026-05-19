import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test('prefs missing restores both visibility flags false', () async {
    SharedPreferences.setMockInitialValues({});
    final tasmapRepository = await TestTasmapRepository.create();
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => MapNotifier(
            peakRepository: PeakRepository.test(InMemoryPeakStorage()),
            overpassService: OverpassService(),
            tasmapRepository: tasmapRepository,
            gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
            peaksBaggedRepository: PeaksBaggedRepository.test(
              InMemoryPeaksBaggedStorage(),
            ),
            migrationMarkerStore: const MigrationMarkerStore(),
            loadPositionOnBuild: false,
            loadPeaksOnBuild: false,
            loadTracksOnBuild: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(mapProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(mapProvider);
    expect(state.showTracks, isFalse);
    expect(state.showRoutes, isFalse);
  });

  test('first user toggle wins over pending visibility restore for that flag', () async {
    SharedPreferences.setMockInitialValues({
      'show_tracks': false,
      'show_routes': false,
    });
    final tasmapRepository = await TestTasmapRepository.create();
    final prefs = await SharedPreferences.getInstance();
    final completer = Completer<SharedPreferences>();
    final container = ProviderContainer(
      overrides: [
        mapPreferencesLoaderProvider.overrideWithValue(() => completer.future),
        mapProvider.overrideWith(
          () => MapNotifier(
            peakRepository: PeakRepository.test(InMemoryPeakStorage()),
            overpassService: OverpassService(),
            tasmapRepository: tasmapRepository,
            gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
            peaksBaggedRepository: PeaksBaggedRepository.test(
              InMemoryPeaksBaggedStorage(),
            ),
            migrationMarkerStore: const MigrationMarkerStore(),
            loadPositionOnBuild: false,
            loadPeaksOnBuild: false,
            loadTracksOnBuild: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(mapProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    notifier.setShowRoutes(true);
    completer.complete(prefs);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(mapProvider).showRoutes, isTrue);
    expect(container.read(mapProvider).showTracks, isFalse);
  });
}
