import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';
import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('create route opens draft sheet and clears selection state', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        selectedLocation: const LatLng(-41.6, 146.6),
        showTracks: true,
        tracks: [_track(10)],
        selectedTrackId: 10,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final container = _container(tester);
    final state = container.read(mapProvider);
    expect(state.isRouteDrafting, isTrue);
    expect(state.routeDraftMode, RouteMode.snapToTrail);
    expect(state.routeDraftName, isEmpty);
    expect(state.routeDraftMarkers, isEmpty);
    expect(state.selectedLocation, isNull);
    expect(state.selectedTrackId, isNull);

    expect(find.byKey(const Key('route-bottom-sheet')), findsOneWidget);
    expect(find.byKey(const Key('route-name-field')), findsOneWidget);
    expect(find.byKey(const Key('route-mode-snap-to-trail')), findsOneWidget);
    expect(find.byKey(const Key('route-mode-straight-line')), findsOneWidget);
    expect(find.byKey(const Key('route-elevation-placeholder')), findsOneWidget);
  });

  testWidgets('route sheet accepts name input and closes on cancel', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('route-name-field')), 'Ridge Loop');
    await tester.pump();

    expect(_container(tester).read(mapProvider).routeDraftName, 'Ridge Loop');

    await tester.tap(find.byKey(const Key('route-cancel-button')));
    await tester.pumpAndSettle();

    final state = _container(tester).read(mapProvider);
    expect(state.isRouteDrafting, isFalse);
    expect(state.routeDraftName, isEmpty);
    expect(state.routeDraftMarkers, isEmpty);
    expect(find.byKey(const Key('route-bottom-sheet')), findsNothing);
  });

  testWidgets('route taps append temporary markers and stay isolated', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    await tester.tap(find.byKey(const Key('create-route-fab')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final state = _container(tester).read(mapProvider);
    expect(state.routeDraftMarkers, hasLength(1));
    expect(state.routeDraftMarkers.first.latitude, closeTo(-41.5, 0.000001));
    expect(state.routeDraftMarkers.first.longitude, closeTo(146.5, 0.000001));
    expect(state.selectedLocation, isNull);
    expect(state.selectedTrackId, isNull);
    expect(find.byKey(const Key('route-draft-marker-layer')), findsOneWidget);
    expect(find.byKey(const Key('route-draft-marker-0')), findsOneWidget);
  });

  testWidgets('create route hides the entry button while drafting', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMap(tester, notifier);

    final fab = find.byKey(const Key('create-route-fab'));
    await tester.tap(fab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-bottom-sheet')), findsOneWidget);
    expect(fab, findsNothing);
  });
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byKey(const Key('map-interaction-region'))),
  );
}

Future<void> _pumpMap(
  WidgetTester tester,
  MapNotifier notifier,
) async {
  final tasmapRepository = await TestTasmapRepository.create();
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(() => TestTasmapNotifier(tasmapRepository)),
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

GpxTrack _track(int id) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    gpxFile: '<gpx></gpx>',
  );
}
