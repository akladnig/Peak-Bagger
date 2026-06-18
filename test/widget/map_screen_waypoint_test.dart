import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/waypoints_repository.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('armed drop marker saves marker on next empty map tap', (
    tester,
  ) async {
    final waypointsRepository = WaypointsRepository.test(
      InMemoryWaypointsStorage(),
    );
    await _pumpMap(
      tester,
      const MapState(
        center: LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      waypointsRepository: waypointsRepository,
    );

    await tester.ensureVisible(find.byKey(const Key('drop-marker-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drop-marker-fab')));
    await tester.pump();

    final region = find.byKey(const Key('map-interaction-region'));
    final target = tester.getCenter(region);
    await tester.tapAt(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final marker = waypointsRepository.getCurrentMarker();
    expect(marker, isNotNull);
    expect(marker!.name, 'Marker');

    final state = ProviderScope.containerOf(tester.element(region)).read(
      mapProvider,
    );
    expect(state.selectedLocation, isNotNull);
  });

  testWidgets('pressing drop marker twice cancels armed mode', (tester) async {
    final waypointsRepository = WaypointsRepository.test(
      InMemoryWaypointsStorage(),
    );
    await _pumpMap(
      tester,
      const MapState(
        center: LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      waypointsRepository: waypointsRepository,
    );

    await tester.ensureVisible(find.byKey(const Key('drop-marker-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drop-marker-fab')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('drop-marker-fab')));
    await tester.pump();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(waypointsRepository.getCurrentMarker(), isNull);
  });

  testWidgets('armed drop marker preserves peak tap behavior', (tester) async {
    final waypointsRepository = WaypointsRepository.test(
      InMemoryWaypointsStorage(),
    );
    await _pumpMap(
      tester,
      MapState(
        center: const LatLng(-43.0, 147.0),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: [
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
        ],
      ),
      waypointsRepository: waypointsRepository,
    );

    await tester.ensureVisible(find.byKey(const Key('drop-marker-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drop-marker-fab')));
    await tester.pump();

    final region = find.byKey(const Key('map-interaction-region'));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    final target = tester.getCenter(region);
    await gesture.addPointer(location: target);
    await tester.pump();
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.down(target);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('peak-info-popup')), findsOneWidget);
    expect(waypointsRepository.getCurrentMarker(), isNull);
  });
}

Future<void> _pumpMap(
  WidgetTester tester,
  MapState state, {
  required WaypointsRepository waypointsRepository,
}) async {
  final tasmapRepository = await TestTasmapRepository.create();
  await tester.binding.setSurfaceSize(const Size(1000, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(state, waypointsRepository: waypointsRepository),
        ),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        peaksBaggedRepositoryProvider.overrideWithValue(
          PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
        ),
        gpxTrackRepositoryProvider.overrideWithValue(
          GpxTrackRepository.test(InMemoryGpxTrackStorage()),
        ),
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
}
