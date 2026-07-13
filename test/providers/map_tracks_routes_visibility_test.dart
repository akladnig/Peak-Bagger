import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
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
            gpxTrackRepository: GpxTrackRepository.test(
              InMemoryGpxTrackStorage(),
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

    container.read(mapProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(mapProvider);
    expect(state.showTracks, isFalse);
    expect(state.showRoutes, isFalse);
    expect(state.showTrails, isFalse);
  });

  test('startup backfill restores hidden routes and tracks once', () async {
    SharedPreferences.setMockInitialValues({});
    final tasmapRepository = await TestTasmapRepository.create();
    final routeStorage = _CountingRouteStorage([
      Route(
        id: 7,
        name: 'Hidden Route',
        visible: false,
        gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
      ),
    ]);
    final trackStorage = _CountingGpxTrackStorage([
      GpxTrack(
        gpxTrackId: 11,
        contentHash: 'hash-11',
        trackName: 'Hidden Track',
        visible: false,
        gpxFile: '<gpx></gpx>',
      ),
    ]);
    final routeRepository = RouteRepository.test(routeStorage);
    final trackRepository = GpxTrackRepository.test(trackStorage);

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => MapNotifier(
            peakRepository: PeakRepository.test(InMemoryPeakStorage()),
            overpassService: OverpassService(),
            tasmapRepository: tasmapRepository,
            gpxTrackRepository: trackRepository,
            routeRepository: routeRepository,
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

    expect(routeRepository.getAllRoutes().single.visible, isTrue);
    expect(trackRepository.getAllTracks().single.visible, isTrue);
    expect(routeStorage.saveCount, 1);
    expect(trackStorage.saveCount, 1);

    final secondContainer = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => MapNotifier(
            peakRepository: PeakRepository.test(InMemoryPeakStorage()),
            overpassService: OverpassService(),
            tasmapRepository: tasmapRepository,
            gpxTrackRepository: trackRepository,
            routeRepository: routeRepository,
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
    addTearDown(secondContainer.dispose);

    secondContainer.read(mapProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(routeStorage.saveCount, 1);
    expect(trackStorage.saveCount, 1);
  });

  test(
    'first user toggle wins over pending visibility restore for that flag',
    () async {
      SharedPreferences.setMockInitialValues({
        'show_tracks': false,
        'show_routes': false,
      });
      final tasmapRepository = await TestTasmapRepository.create();
      final prefs = await SharedPreferences.getInstance();
      final completer = Completer<SharedPreferences>();
      final container = ProviderContainer(
        overrides: [
          mapPreferencesLoaderProvider.overrideWithValue(
            () => completer.future,
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
    },
  );

  test(
    'stored visibility combination restores before later dataset changes',
    () async {
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
              gpxTrackRepository: GpxTrackRepository.test(
                InMemoryGpxTrackStorage(),
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

      container.read(mapProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(mapProvider);
      expect(state.showTracks, isTrue);
      expect(state.showRoutes, isTrue);
      expect(state.showTrails, isFalse);
    },
  );

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
            gpxTrackRepository: GpxTrackRepository.test(
              InMemoryGpxTrackStorage(),
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

class _CountingRouteStorage implements RouteStorage {
  _CountingRouteStorage([List<Route> routes = const []])
    : _storage = InMemoryRouteStorage(routes);

  final InMemoryRouteStorage _storage;
  int saveCount = 0;

  @override
  Route? getById(int id) => _storage.getById(id);

  @override
  List<Route> getAll() => _storage.getAll();

  @override
  int save(Route route) {
    saveCount += 1;
    return _storage.save(route);
  }

  @override
  bool delete(int id) => _storage.delete(id);
}

class _CountingGpxTrackStorage implements GpxTrackStorage {
  _CountingGpxTrackStorage([List<GpxTrack> tracks = const []])
    : _storage = InMemoryGpxTrackStorage(tracks);

  final InMemoryGpxTrackStorage _storage;
  int saveCount = 0;

  @override
  GpxTrack? getById(int id) => _storage.getById(id);

  @override
  List<GpxTrack> getAll() => _storage.getAll();

  @override
  int save(GpxTrack track) {
    saveCount += 1;
    return _storage.save(track);
  }
}
