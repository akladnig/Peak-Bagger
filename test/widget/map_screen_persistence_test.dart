import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/services.dart';
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
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test('transient updatePosition does not write prefs immediately', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildRealNotifier();
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(mapProvider.notifier).updatePosition(
      const LatLng(-41.7, 146.7),
      14,
    );
    await _drainAsync();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('map_position_lat'), isNull);
    expect(prefs.getDouble('map_position_lng'), isNull);
    expect(prefs.getDouble('map_zoom'), isNull);
  });

  testWidgets('drag gesture persists camera only after debounce', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildRealNotifier();
    await _pumpApp(tester, notifier);

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );

    final gesture = await tester.startGesture(tester.getCenter(region));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final prefsBeforeDebounce = await SharedPreferences.getInstance();
    expect(prefsBeforeDebounce.getDouble('map_position_lat'), isNull);
    expect(prefsBeforeDebounce.getDouble('map_position_lng'), isNull);
    expect(prefsBeforeDebounce.getDouble('map_zoom'), isNull);

    await tester.pump(const Duration(milliseconds: 100));

    final state = container.read(mapProvider);
    final prefsAfterDebounce = await SharedPreferences.getInstance();
    expect(
      prefsAfterDebounce.getDouble('map_position_lat'),
      closeTo(state.center.latitude, 0.000001),
    );
    expect(
      prefsAfterDebounce.getDouble('map_position_lng'),
      closeTo(state.center.longitude, 0.000001),
    );
    expect(prefsAfterDebounce.getDouble('map_zoom'), state.zoom);

    await gesture.up();
  });

  testWidgets('drag updates live MGRS before canonical provider sync', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildCountingNotifier();
    await _pumpApp(tester, notifier);

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    final initialMgrs = container.read(mapProvider).currentMgrs;

    final gesture = await tester.startGesture(tester.getCenter(region));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(mapProvider).currentMgrs, initialMgrs);
    expect(_mgrsReadoutText(tester), isNot(initialMgrs));

    await gesture.up();
  });

  testWidgets('drag debounce commits fewer canonical syncs than motion updates', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildCountingNotifier();
    await _pumpApp(tester, notifier);

    final region = find.byKey(const Key('map-interaction-region'));
    final gesture = await tester.startGesture(tester.getCenter(region));

    await gesture.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 16));

    expect(notifier.canonicalCameraSyncCallCount, 0);

    await tester.pump(const Duration(milliseconds: 200));

    expect(notifier.canonicalCameraSyncCallCount, 1);

    await gesture.up();
    await tester.pump();

    expect(notifier.canonicalCameraSyncCallCount, 1);
  });

  testWidgets('trackpad gesture commits once at pan-zoom end', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildCountingNotifier();
    await _pumpApp(tester, notifier);

    final region = find.byKey(const Key('map-interaction-region'));
    final gesture = await tester.startGesture(
      tester.getCenter(region),
      kind: PointerDeviceKind.trackpad,
    );

    await gesture.panZoomUpdate(
      tester.getCenter(region),
      pan: const Offset(0, 120),
    );
    await tester.pump();

    expect(notifier.persistCameraPositionCallCount, 0);

    await gesture.up();
    await tester.pump();

    expect(notifier.persistCameraPositionCallCount, 1);
  });

  testWidgets('mouse wheel zoom commits once on debounce without end sync', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildCountingNotifier();
    await _pumpApp(tester, notifier);

    final region = find.byKey(const Key('map-interaction-region'));
    final center = tester.getCenter(region);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: center);
    await tester.pump();

    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, -20),
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pump();

    expect(notifier.canonicalCameraSyncCallCount, 0);

    await tester.pump(MapConstants.cameraSaveDebounce);

    expect(notifier.canonicalCameraSyncCallCount, 1);

    await tester.pump(const Duration(milliseconds: 100));

    expect(notifier.canonicalCameraSyncCallCount, 1);
  });

  testWidgets('held-key pan commits once at stop scrolling', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildCountingNotifier();
    await _pumpApp(tester, notifier);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 64));

    expect(notifier.persistCameraPositionCallCount, 0);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(notifier.persistCameraPositionCallCount, 1);
  });

  testWidgets('discrete keyboard zoom commits once per keydown', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildCountingNotifier();
    await _pumpApp(tester, notifier);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.period);
    await tester.pump();

    expect(notifier.persistCameraPositionCallCount, 1);
  });

  testWidgets('pause flush consumes pending save before dispose', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await _buildCountingNotifier();
    await _pumpApp(tester, notifier);

    final region = find.byKey(const Key('map-interaction-region'));
    final gesture = await tester.startGesture(tester.getCenter(region));
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(notifier.persistCameraPositionCallCount, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(notifier.persistCameraPositionCallCount, 1);

    await gesture.up();
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(notifier.persistCameraPositionCallCount, 1);
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

Future<_CountingMapNotifier> _buildCountingNotifier() async {
  return _CountingMapNotifier(
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
  router.go('/map');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

String _mgrsReadoutText(WidgetTester tester) {
  final readout = find.descendant(
    of: find.byKey(const Key('map-mgrs-readout')),
    matching: find.byType(RichText),
  );
  final richText = tester.widget<RichText>(readout);
  return richText.text.toPlainText();
}

class _CountingMapNotifier extends MapNotifier {
  _CountingMapNotifier({
    required super.peakRepository,
    required super.overpassService,
    required super.tasmapRepository,
    required super.gpxTrackRepository,
    required super.peaksBaggedRepository,
    required super.migrationMarkerStore,
    required super.loadPositionOnBuild,
    required super.loadPeaksOnBuild,
    required super.loadTracksOnBuild,
  });

  // Phase 1 seam plan: keep persistence counting for the current behavior, but
  // move continuous-path frequency assertions to the future accepted-camera sync
  // boundary once MapScreen routes every winning camera intent through it.
  int canonicalCameraSyncCallCount = 0;
  int persistCameraPositionCallCount = 0;

  @override
  void updatePosition(LatLng center, double zoom) {
    canonicalCameraSyncCallCount += 1;
    super.updatePosition(center, zoom);
  }

  @override
  Future<void> persistCameraPosition() async {
    persistCameraPositionCallCount += 1;
    await super.persistCameraPosition();
  }
}
