import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('hidden-branch requestCameraMove preserves selected location and peaks', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildRealNotifier();
    await _pumpApp(tester, notifier);

    router.go('/map');
    await tester.pumpAndSettle();
    router.go('/');
    await tester.pumpAndSettle();

    const target = LatLng(-41.6, 146.6);
    final peak = Peak(
      osmId: 7001,
      name: 'Route Entry Peak',
      latitude: target.latitude,
      longitude: target.longitude,
    );

    notifier.requestCameraMove(
      center: target,
      zoom: MapConstants.defaultZoom,
      selectedLocation: target,
      updateSelectedLocation: true,
      selectedPeaks: [peak],
      updateSelectedPeaks: true,
      clearGotoMgrs: true,
      clearHoveredPeakId: true,
      clearHoveredTrackId: true,
    );
    await tester.pump(const Duration(milliseconds: 100));

    router.go('/map');
    await tester.pumpAndSettle();

    final state = _container(tester).read(mapProvider);
    expect(state.cameraRequestCenter, isNull);
    expect(state.cameraRequestZoom, isNull);
    expect(state.center.latitude, closeTo(target.latitude, 0.000001));
    expect(state.center.longitude, closeTo(target.longitude, 0.000001));
    expect(state.selectedLocation, target);
    expect(state.selectedPeaks, [peak]);
  });

  testWidgets('hidden-branch selectMap keeps only the latest focus request', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = await TestTasmapRepository.create();
    final notifier = await _buildRealNotifier(repository: repository);
    await _pumpApp(tester, notifier, repository: repository);

    router.go('/map');
    await tester.pumpAndSettle();
    router.go('/');
    await tester.pumpAndSettle();

    final maps = repository.getAllMaps();
    notifier.selectMap(maps.first);
    notifier.selectMap(maps.last);
    await tester.pump(const Duration(milliseconds: 100));

    router.go('/map');
    await tester.pumpAndSettle();

    final state = _container(tester).read(mapProvider);
    expect(state.selectedMap?.name, maps.last.name);
    expect(state.tasmapDisplayMode, TasmapDisplayMode.selectedMap);
    expect(state.selectedLocation, isNull);
    expect(state.mapSuggestions, isEmpty);
    expect(state.mapSearchQuery, '');
  });

  testWidgets('cold-start showTrack persists only after final fit and latest track wins', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final firstTrack = _track(
      10,
      [const LatLng(-43.3, 147.0), const LatLng(-43.1, 147.2)],
    );
    final secondTrack = _track(
      20,
      [const LatLng(-41.6, 145.8), const LatLng(-41.4, 146.0)],
    );
    final gpxRepository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([firstTrack, secondTrack]),
    );
    final notifier = await _buildRealNotifier(gpxTrackRepository: gpxRepository);
    await _pumpApp(tester, notifier, gpxTrackRepository: gpxRepository);

    notifier.showTrack(10, selectedLocation: const LatLng(-43.0, 147.0));
    notifier.showTrack(20, selectedLocation: const LatLng(-41.5, 145.9));
    await tester.pump(const Duration(milliseconds: 100));

    final prefsBeforeMap = await SharedPreferences.getInstance();
    expect(prefsBeforeMap.getDouble('map_position_lat'), isNull);
    expect(prefsBeforeMap.getDouble('map_position_lng'), isNull);
    expect(prefsBeforeMap.getDouble('map_zoom'), isNull);

    router.go('/map');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    final state = _container(tester).read(mapProvider);
    expect(state.selectedTrackId, 20);
    expect(state.selectedLocation, const LatLng(-41.5, 145.9));

    final prefsAfterMap = await SharedPreferences.getInstance();
    expect(
      prefsAfterMap.getDouble('map_position_lat'),
      closeTo(state.center.latitude, 0.000001),
    );
    expect(
      prefsAfterMap.getDouble('map_position_lng'),
      closeTo(state.center.longitude, 0.000001),
    );
    expect(prefsAfterMap.getDouble('map_zoom'), state.zoom);
  });
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byKey(const Key('shared-app-bar'))),
  );
}

GpxTrack _track(int id, List<LatLng> points) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    gpxFile: '<gpx></gpx>',
    displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([points]),
  );
}

Future<MapNotifier> _buildRealNotifier({
  TestTasmapRepository? repository,
  GpxTrackRepository? gpxTrackRepository,
}) async {
  return MapNotifier(
    peakRepository: PeakRepository.test(InMemoryPeakStorage()),
    overpassService: OverpassService(),
    tasmapRepository: repository ?? await TestTasmapRepository.create(),
    gpxTrackRepository:
        gpxTrackRepository ?? GpxTrackRepository.test(InMemoryGpxTrackStorage()),
    peaksBaggedRepository: PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
    migrationMarkerStore: const MigrationMarkerStore(),
    loadPositionOnBuild: false,
    loadPeaksOnBuild: false,
    loadTracksOnBuild: false,
  );
}

Future<void> _pumpApp(
  WidgetTester tester,
  MapNotifier notifier, {
  TestTasmapRepository? repository,
  GpxTrackRepository? gpxTrackRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        if (repository != null)
          tasmapRepositoryProvider.overrideWithValue(repository),
        if (gpxTrackRepository != null)
          gpxTrackRepositoryProvider.overrideWithValue(gpxTrackRepository),
      ],
      child: const App(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
