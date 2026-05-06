import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('route-entry camera request is consumed when map becomes available', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildRealNotifier();
    await _pumpApp(tester, notifier);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    final target = const LatLng(-41.6, 146.6);

    container.read(mapProvider.notifier).requestCameraMove(
      center: target,
      zoom: MapConstants.defaultZoom,
      selectedLocation: target,
      updateSelectedLocation: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(mapProvider).cameraRequestCenter, target);
    expect(container.read(mapProvider).cameraRequestZoom, MapConstants.defaultZoom);

    router.go('/map');
    await tester.pumpAndSettle();

    final state = container.read(mapProvider);
    expect(state.cameraRequestCenter, isNull);
    expect(state.cameraRequestZoom, isNull);
    expect(state.center.latitude, closeTo(target.latitude, 0.000001));
    expect(state.center.longitude, closeTo(target.longitude, 0.000001));
    expect(state.zoom, MapConstants.defaultZoom);
    expect(state.selectedLocation, target);
  });

  testWidgets('same-camera request is consumed as a no-op', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildRealNotifier();
    await _pumpApp(tester, notifier);

    router.go('/map');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    final state = container.read(mapProvider);

    container.read(mapProvider.notifier).requestCameraMove(
      center: state.center,
      zoom: state.zoom,
      selectedLocation: state.selectedLocation,
      updateSelectedLocation: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final updated = container.read(mapProvider);
    expect(updated.cameraRequestCenter, isNull);
    expect(updated.cameraRequestZoom, isNull);
    expect(updated.center, state.center);
    expect(updated.zoom, state.zoom);
    expect(updated.selectedLocation, state.selectedLocation);
  });
}

Future<MapNotifier> _buildRealNotifier() async {
  return MapNotifier(
    peakRepository: PeakRepository.test(InMemoryPeakStorage()),
    overpassService: OverpassService(),
    tasmapRepository: await TestTasmapRepository.create(),
    gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
    peaksBaggedRepository: PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
    migrationMarkerStore: const MigrationMarkerStore(),
    loadPositionOnBuild: false,
    loadPeaksOnBuild: false,
    loadTracksOnBuild: false,
  );
}

Future<void> _pumpApp(WidgetTester tester, MapNotifier notifier) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
