import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/waypoints.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/waypoints_repository.dart';
import 'package:peak_bagger/theme.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('drop marker fab opens chooser and can save marker', (
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
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('map-tap-action-popup')), findsOneWidget);
    await tester.tap(find.byKey(const Key('map-tap-action-drop-marker')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));

    final marker = waypointsRepository.getCurrentMarker();
    expect(marker, isNotNull);
    expect(marker!.name, 'Marker');

    final state = ProviderScope.containerOf(
      tester.element(region),
    ).read(mapProvider);
    expect(state.selectedLocation, isNotNull);
    expect(find.byKey(const Key('home-marker-layer')), findsOneWidget);
  });

  testWidgets('drop marker chooser close button dismisses without changes', (
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
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('map-tap-action-popup')), findsOneWidget);
    expect(find.byKey(const Key('map-tap-action-close')), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-tap-action-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('map-tap-action-popup')), findsNothing);
    expect(waypointsRepository.getCurrentMarker(), isNull);

    final state = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    ).read(mapProvider);
    expect(state.selectedLocation, isNull);
  });

  testWidgets('pressing drop marker twice closes chooser', (tester) async {
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
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('drop-marker-fab')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('map-tap-action-popup')), findsNothing);
    expect(waypointsRepository.getCurrentMarker(), isNull);
  });

  testWidgets('drop marker chooser preserves peak tap behavior', (
    tester,
  ) async {
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
    await tester.pump(const Duration(milliseconds: 300));

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
    expect(find.byKey(const Key('map-tap-action-popup')), findsNothing);
    expect(waypointsRepository.getCurrentMarker(), isNull);
  });

  testWidgets('unarmed empty map tap opens chooser without moving marker', (
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

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('map-tap-action-popup')), findsOneWidget);
    expect(waypointsRepository.getCurrentMarker(), isNull);
    expect(
      ProviderScope.containerOf(
        tester.element(region),
      ).read(mapProvider).selectedLocation,
      isNull,
    );
  });

  testWidgets('drop favourite validates duplicate names and saves success', (
    tester,
  ) async {
    final waypointsRepository = WaypointsRepository.test(
      InMemoryWaypointsStorage([
        Waypoints(
          id: 1,
          name: 'Camp',
          type: Waypoints.typeFavourite,
          latitude: -42.0,
          longitude: 146.0,
          mgrs: '55G EN 10000 10000',
        ),
      ]),
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

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('map-tap-action-drop-favourite')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('favourite-name-input')),
      'Camp',
    );
    await tester.tap(find.byKey(const Key('favourite-name-save')));
    await tester.pump();

    expect(find.byKey(const Key('favourite-name-dialog')), findsOneWidget);
    expect(
      find.text('A favourite with that name already exists.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('favourite-name-input')),
      '  South Ridge  ',
    );
    await tester.tap(find.byKey(const Key('favourite-name-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('favourite-name-dialog')), findsNothing);
    expect(waypointsRepository.getFavourites(), hasLength(2));
    expect(waypointsRepository.getFavourites().last.name, 'South Ridge');
    expect(find.byKey(const Key('favourite-marker-layer')), findsOneWidget);
    expect(find.byKey(const Key('favourite-marker-2')), findsOneWidget);
    expect(find.byKey(const Key('favourite-marker-name-2')), findsOneWidget);
    expect(
      tester.widget<OutlinedText>(
        find.byKey(const Key('favourite-marker-name-2')),
      ),
      isA<OutlinedText>()
          .having((widget) => widget.text, 'text', 'South Ridge')
          .having((widget) => widget.maxLines, 'maxLines', 1),
    );
    expect(
      ProviderScope.containerOf(
        tester.element(region),
      ).read(mapProvider).selectedLocation,
      isNotNull,
    );
  });

  testWidgets(
    'goto favourite is camera only and keeps current marker selection',
    (tester) async {
      final waypointsRepository = WaypointsRepository.test(
        InMemoryWaypointsStorage([
          Waypoints(
            id: 1,
            name: 'Camp',
            type: Waypoints.typeFavourite,
            latitude: -42.1,
            longitude: 146.1,
            mgrs: '55G EN 10000 10000',
          ),
        ]),
      );
      const currentMarker = LatLng(-41.5, 146.5);
      await _pumpMap(
        tester,
        const MapState(
          center: LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          selectedLocation: currentMarker,
        ),
        waypointsRepository: waypointsRepository,
      );

      await tester.ensureVisible(find.byKey(const Key('goto-favourite-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goto-favourite-fab')));
      await tester.pump();

      expect(find.byKey(const Key('favourites-popup')), findsOneWidget);
      await tester.tap(find.byKey(const Key('favourites-popup-row-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final region = find.byKey(const Key('map-interaction-region'));
      final state = ProviderScope.containerOf(
        tester.element(region),
      ).read(mapProvider);
      expect(state.center.latitude, closeTo(-42.1, 1e-9));
      expect(state.center.longitude, closeTo(146.1, 1e-9));
      expect(state.zoom, MapConstants.defaultZoom);
      expect(state.selectedLocation, currentMarker);
    },
  );

  testWidgets('goto favourite popup shows empty state when none saved', (
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

    await tester.ensureVisible(find.byKey(const Key('goto-favourite-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goto-favourite-fab')));
    await tester.pump();

    expect(find.byKey(const Key('favourites-popup-empty')), findsOneWidget);
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
          () =>
              TestMapNotifier(state, waypointsRepository: waypointsRepository),
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
