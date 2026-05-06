import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
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

  testWidgets('keyboard c recenters through the direct controller-owned path', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildRealNotifier();
    await _pumpApp(tester, notifier);

    router.go('/map');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    const target = LatLng(-41.6, 146.6);
    final serialBefore = container.read(mapProvider).cameraRequestSerial;

    container.read(mapProvider.notifier).setSelectedLocation(target);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
    await tester.pump();

    final state = container.read(mapProvider);
    expect(state.cameraRequestSerial, serialBefore);
    expect(state.cameraRequestCenter, isNull);
    expect(state.cameraRequestZoom, isNull);
    expect(state.center.latitude, closeTo(target.latitude, 0.000001));
    expect(state.center.longitude, closeTo(target.longitude, 0.000001));
  });

  testWidgets('center on marker fab remains request-driven', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildRealNotifier();
    await _pumpApp(tester, notifier);

    router.go('/map');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    const target = LatLng(-41.6, 146.6);
    final serialBefore = container.read(mapProvider).cameraRequestSerial;

    container.read(mapProvider.notifier).setSelectedLocation(target);
    await tester.pump();

    await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.my_location));
    await tester.pumpAndSettle();

    final state = container.read(mapProvider);
    expect(state.cameraRequestSerial, greaterThan(serialBefore));
    expect(state.center.latitude, closeTo(target.latitude, 0.000001));
    expect(state.center.longitude, closeTo(target.longitude, 0.000001));
  });

  testWidgets('secondary tap recenters through the direct controller-owned path', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildRealNotifier();
    await _pumpApp(tester, notifier);

    router.go('/map');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    final region = find.byKey(const Key('map-interaction-region'));
    const target = LatLng(-41.6, 146.6);
    final serialBefore = container.read(mapProvider).cameraRequestSerial;

    container.read(mapProvider.notifier).setSelectedLocation(target);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(region),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pump();

    final state = container.read(mapProvider);
    expect(state.cameraRequestSerial, serialBefore);
    expect(state.cameraRequestCenter, isNull);
    expect(state.cameraRequestZoom, isNull);
    expect(state.center.latitude, closeTo(target.latitude, 0.000001));
    expect(state.center.longitude, closeTo(target.longitude, 0.000001));
  });

  testWidgets('visible-map goto uses the direct camera path', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildRealNotifier();
    await _pumpApp(tester, notifier);

    router.go('/map');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    final serialBefore = container.read(mapProvider).cameraRequestSerial;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyG);
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('goto-map-input')),
      '55GDM8000095000',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('goto-map-submit')));
    await tester.pumpAndSettle();

    final state = container.read(mapProvider);
    expect(state.cameraRequestSerial, serialBefore);
    expect(state.cameraRequestCenter, isNull);
    expect(state.cameraRequestZoom, isNull);
    expect(state.selectedLocation, isNotNull);
  });

  testWidgets('selected-map goto keeps fit-derived zoom without request replay', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = await TestTasmapRepository.create();
    final notifier = await _buildRealNotifier(repository: repository);
    await _pumpApp(tester, notifier, repository: repository);

    router.go('/map');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    final map = repository.getAllMaps().first;

    container.read(mapProvider.notifier).selectMap(map);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final zoomBeforeGoto = container.read(mapProvider).zoom;
    final serialBefore = container.read(mapProvider).cameraRequestSerial;

    container.read(mapProvider.notifier).toggleGotoInput();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('goto-map-input')),
      'Adamsons 80000 95000',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('goto-map-submit')));
    await tester.pumpAndSettle();

    final state = container.read(mapProvider);
    expect(state.cameraRequestSerial, serialBefore);
    expect(state.cameraRequestCenter, isNull);
    expect(state.cameraRequestZoom, isNull);
    expect(state.zoom, closeTo(zoomBeforeGoto, 0.000001));
    expect(state.selectedLocation, isNotNull);
    expect(state.selectedMap?.name, 'Adamsons');
  });
}

Future<MapNotifier> _buildRealNotifier({
  TestTasmapRepository? repository,
}) async {
  return MapNotifier(
    peakRepository: PeakRepository.test(InMemoryPeakStorage()),
    overpassService: OverpassService(),
    tasmapRepository: repository ?? await TestTasmapRepository.create(),
    gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
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
}) async {
  return _pumpConfiguredApp(tester, notifier, repository: repository);
}

Future<void> _pumpConfiguredApp(
  WidgetTester tester,
  MapNotifier notifier, {
  TestTasmapRepository? repository,
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
      ],
      child: const App(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
