import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_chart_hover_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('chart hover marker appears and clears on the map', (tester) async {
    SharedPreferences.setMockInitialValues({
      'show_routes': true,
      'show_tracks': true,
    });

    final tasmapRepository = await TestTasmapRepository.create(maps: const []);
    final mapNotifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
        showTracks: true,
      ),
    );

    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => mapNotifier),
          routeRepositoryProvider.overrideWithValue(
            RouteRepository.test(InMemoryRouteStorage()),
          ),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          gpxTrackRepositoryProvider.overrideWithValue(
            GpxTrackRepository.test(InMemoryGpxTrackStorage()),
          ),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(tasmapRepository),
          ),
          tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        ],
        child: MaterialApp(theme: CatppuccinColors.dark, home: const MapScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final mapRegion = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(mapRegion));

    expect(find.byKey(const Key('map-chart-hover-marker')), findsNothing);

    container
        .read(mapChartHoverProvider.notifier)
        .show(const LatLng(-41.5, 146.5));
    await tester.pump();

    expect(find.byKey(const Key('map-chart-hover-marker')), findsOneWidget);

    container.read(mapChartHoverProvider.notifier).clear();
    await tester.pump();

    expect(find.byKey(const Key('map-chart-hover-marker')), findsNothing);
  });
}
