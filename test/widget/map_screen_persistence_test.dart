import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
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

    await tester.drag(region, const Offset(80, 0));
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
  router.go('/map');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(const Duration(milliseconds: 10));
}
