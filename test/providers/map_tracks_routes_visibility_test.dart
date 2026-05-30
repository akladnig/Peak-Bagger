import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
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
    expect(state.showTrails, isFalse);
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
    notifier.setShowTrails(true);
    completer.complete(prefs);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(mapProvider).showRoutes, isTrue);
    expect(container.read(mapProvider).showTracks, isFalse);
    expect(container.read(mapProvider).showTrails, isTrue);
  });

  test('stored visibility combination restores before later dataset changes', () async {
    SharedPreferences.setMockInitialValues({
      'show_tracks': true,
      'show_routes': true,
    });
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
    expect(state.showTracks, isTrue);
    expect(state.showRoutes, isTrue);
    expect(state.showTrails, isFalse);
  });

  test('turning routes off does not mutate track selection state', () async {
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

    final notifier = container.read(mapProvider.notifier);
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      showTracks: true,
      showRoutes: true,
      selectedTrackId: 7,
      hoveredTrackId: 7,
      selectedLocation: const LatLng(-41.5, 146.5),
    );

    notifier.setShowRoutes(false);

    final state = container.read(mapProvider);
    expect(state.showTracks, isTrue);
    expect(state.selectedTrackId, 7);
    expect(state.hoveredTrackId, 7);
    expect(state.selectedLocation, const LatLng(-41.5, 146.5));
  });

  test('turning tracks off clears selected and hovered track state', () async {
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
              InMemoryGpxTrackStorage([
                GpxTrack(
                  gpxTrackId: 7,
                  contentHash: 'hash-7',
                  trackName: 'Track 7',
                  gpxFile: '<gpx></gpx>',
                ),
              ]),
            ),
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
    notifier.state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      tracks: [
        GpxTrack(
          gpxTrackId: 7,
          contentHash: 'hash-7',
          trackName: 'Track 7',
          gpxFile: '<gpx></gpx>',
        ),
      ],
      showTracks: true,
      selectedTrackId: 7,
      hoveredTrackId: 7,
    );

    notifier.toggleTracks();

    final state = container.read(mapProvider);
    expect(state.showTracks, isFalse);
    expect(state.selectedTrackId, isNull);
    expect(state.hoveredTrackId, isNull);
  });
}
