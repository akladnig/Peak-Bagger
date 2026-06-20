import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('basemap drawer snapshot stays fixed while open', (tester) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        cursorPoint: const LatLng(-44.0, 148.8867),
        zoom: 12,
        basemap: Basemap.tasmap50k,
      ),
    );

    await _pumpRawMapScreen(tester, notifier, size: const Size(1600, 900));

    await tester.tap(find.byKey(const Key('show-basemaps-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('basemaps-drawer')), findsOneWidget);
    expect(find.byKey(const Key('basemap-option-tasmap50k')), findsOneWidget);
    expect(find.byKey(const Key('basemap-option-nswTopo')), findsNothing);

    notifier.state = notifier.state.copyWith(
      cursorPoint: const LatLng(-37.75984, 158.7979),
    );
    await tester.pump();

    expect(find.byKey(const Key('basemap-option-tasmap50k')), findsOneWidget);
    expect(find.byKey(const Key('basemap-option-nswTopo')), findsNothing);
  });

  testWidgets('opening a region-only drawer falls back to tracestrack', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-37.75984, 158.7979),
        cursorPoint: const LatLng(-37.75984, 158.7979),
        zoom: 12,
        basemap: Basemap.tasmap50k,
      ),
    );

    await _pumpRawMapScreen(tester, notifier, size: const Size(1600, 900));

    await tester.tap(find.byKey(const Key('show-basemaps-fab')));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );

    expect(container.read(mapProvider).basemap, Basemap.tracestrack);
    expect(find.byKey(const Key('basemap-option-nswImagery')), findsOneWidget);
    expect(find.byKey(const Key('basemap-option-tasmap50k')), findsNothing);
  });

  testWidgets('empty region shows unavailable state', (tester) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(0, 0),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
    );

    await _pumpRawMapScreen(tester, notifier, size: const Size(1600, 900));

    await tester.tap(find.byKey(const Key('show-basemaps-fab')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('basemaps-drawer-empty-state')),
      findsOneWidget,
    );
  });

  testWidgets('slovenia region shows slovenia topo option', (tester) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(46.05, 14.5),
        cursorPoint: const LatLng(46.05, 14.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
    );

    await _pumpRawMapScreen(tester, notifier, size: const Size(1600, 900));

    await tester.tap(find.byKey(const Key('show-basemaps-fab')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('basemap-option-sloveniaTopo')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('basemap-option-nswTopo')), findsNothing);
  });

  testWidgets('friuli venezia giulia point shows fvg topo option', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(46.1, 13.2),
        cursorPoint: const LatLng(46.1, 13.2),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
    );

    await _pumpRawMapScreen(tester, notifier, size: const Size(1600, 900));

    await tester.tap(find.byKey(const Key('show-basemaps-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('basemap-option-fvgTopo')), findsOneWidget);
    expect(find.byKey(const Key('basemap-option-nswTopo')), findsNothing);
  });

  testWidgets('tasmania region gates mapy.cz behind API key config', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        cursorPoint: const LatLng(-44.0, 148.8867),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
    );

    await _pumpRawMapScreen(tester, notifier, size: const Size(1600, 900));

    await tester.tap(find.byKey(const Key('show-basemaps-fab')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('basemap-option-mapyCz')),
      hasMapyCzApiKey ? findsOneWidget : findsNothing,
    );
  });
}

Future<void> _pumpRawMapScreen(
  WidgetTester tester,
  TestMapNotifier notifier, {
  required Size size,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final tasmapRepository = await TestTasmapRepository.create();
  final gpxTrackRepository = GpxTrackRepository.test(InMemoryGpxTrackStorage());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        gpxTrackRepositoryProvider.overrideWithValue(gpxTrackRepository),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}
