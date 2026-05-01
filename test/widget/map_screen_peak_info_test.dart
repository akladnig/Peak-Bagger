import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('hovering a peak sets click cursor and highlight', (
    tester,
  ) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    final center = tester.getCenter(region);
    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();

    expect(container.read(mapProvider).hoveredPeakId, 6406);
    expect(tester.widget<MouseRegion>(region).cursor, SystemMouseCursors.click);
    expect(find.byKey(const Key('peak-marker-hover-6406')), findsOneWidget);
  });

  testWidgets('clicking a peak opens peak popup without selecting location', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _mapStateWithPeak(
        selectedLocation: const LatLng(-42.0, 146.0),
        showInfoPopup: true,
      ),
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final beforeLocation = container.read(mapProvider).selectedLocation;

    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final state = container.read(mapProvider);
    expect(state.showInfoPopup, isFalse);
    expect(state.peakInfoPeak?.osmId, 6406);
    expect(state.selectedLocation, beforeLocation);
    expect(find.byKey(const Key('peak-info-popup')), findsOneWidget);
    expect(find.text('Bonnet Hill'), findsOneWidget);
  });

  testWidgets('moving off a peak clears hover without closing peak popup', (
    tester,
  ) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final center = tester.getCenter(region);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();
    await tester.tapAt(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(mapProvider).hoveredPeakId, 6406);
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);

    await gesture.moveTo(center + const Offset(100, 0));
    await tester.pump();

    expect(container.read(mapProvider).hoveredPeakId, isNull);
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);
    expect(tester.widget<MouseRegion>(region).cursor, SystemMouseCursors.grab);
  });

  testWidgets('non-peak click keeps selected-location behavior', (
    tester,
  ) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    await tester.tapAt(tester.getCenter(region) + const Offset(100, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final state = container.read(mapProvider);
    expect(state.peakInfoPeak, isNull);
    expect(state.selectedLocation, isNotNull);
    expect(state.selectedLocation!.longitude, isNot(closeTo(147.0, 0.001)));
  });

  testWidgets('background click closes open peak popup', (tester) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final center = tester.getCenter(region);

    await tester.tapAt(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);

    await tester.tapAt(center + const Offset(-100, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final state = container.read(mapProvider);
    expect(state.peakInfoPeak, isNull);
    expect(state.selectedLocation, isNotNull);
  });

  testWidgets('hiding peaks or zooming below threshold closes peak popup', (
    tester,
  ) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final center = tester.getCenter(region);

    await tester.tapAt(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);

    container.read(mapProvider.notifier).togglePeaks();
    await tester.pump();
    expect(container.read(mapProvider).peakInfoPeak, isNull);

    container.read(mapProvider.notifier).togglePeaks();
    await tester.pump();
    await tester.tapAt(center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);

    container
        .read(mapProvider.notifier)
        .updatePosition(const LatLng(-43.0, 147.0), 8);
    await tester.pump();
    expect(container.read(mapProvider).peakInfoPeak, isNull);
  });

  testWidgets('removing the open peak closes peak popup', (tester) async {
    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -43.0,
      longitude: 147.0,
    );
    final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
    await _pumpMap(
      tester,
      _mapStateWithPeak(peak: peak),
      peakRepository: peakRepository,
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);

    await peakRepository.clearAll();
    await container.read(mapProvider.notifier).reloadPeakMarkers();
    await tester.pump();

    expect(container.read(mapProvider).peakInfoPeak, isNull);
  });

  testWidgets('reload keeps open peak popup content fresh', (tester) async {
    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -43.0,
      longitude: 147.0,
    );
    final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
    await _pumpMap(
      tester,
      _mapStateWithPeak(peak: peak),
      peakRepository: peakRepository,
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapProvider).peakInfoPeak?.altName, '');

    await peakRepository.save(
      Peak(
        id: peak.id,
        osmId: 6406,
        name: 'Bonnet Hill',
        altName: 'Updated Alternate',
        latitude: -43.0,
        longitude: 147.0,
      ),
    );
    await container.read(mapProvider.notifier).reloadPeakMarkers();
    await tester.pump();

    final state = container.read(mapProvider);
    expect(state.peakInfoPeak?.altName, 'Updated Alternate');
    expect(state.peakInfo?.mapName, isNotEmpty);
    expect(state.peakInfo?.listNames, isEmpty);
  });

  testWidgets('opening peak search closes peak popup', (tester) async {
    await _pumpMap(tester, _mapStateWithPeak());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(mapProvider).peakInfoPeak?.osmId, 6406);

    await tester.tap(find.byKey(const Key('search-peaks-fab')));
    await tester.pump();

    expect(container.read(mapProvider).peakInfoPeak, isNull);
    expect(container.read(mapProvider).showPeakSearch, isTrue);
  });

  testWidgets('peak popup shows height map and sorted memberships', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'HWC',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 1),
          ]),
        )..peakListId = 1,
        PeakList(
          name: 'Abels',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 2),
          ]),
        )..peakListId = 2,
      ]),
    );

    await _pumpMap(
      tester,
      _mapStateWithPeak(
        peak: Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          elevation: 1234,
          latitude: -43.0,
          longitude: 147.0,
          gridZoneDesignator: '55G',
          mgrs100kId: 'DM',
          easting: '80000',
          northing: '95000',
        ),
      ),
      overrides: [
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
        peakListRepositoryProvider.overrideWithValue(peakListRepository),
      ],
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Height: 1234m'), findsOneWidget);
    expect(find.text('Map: Adamsons'), findsOneWidget);
    expect(find.text('List(s): Abels, HWC'), findsOneWidget);
  });

  testWidgets('peak popup shows non-empty alternate name after title', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      _mapStateWithPeak(
        peak: Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          altName: '  Kunanyi foothill  ',
          elevation: 1234,
          latitude: -43.0,
          longitude: 147.0,
        ),
      ),
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Bonnet Hill'), findsOneWidget);
    expect(find.text('Alt Name: Kunanyi foothill'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Bonnet Hill')).dy,
      lessThan(tester.getTopLeft(find.text('Alt Name: Kunanyi foothill')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Alt Name: Kunanyi foothill')).dy,
      lessThan(tester.getTopLeft(find.text('Height: 1234m')).dy),
    );
  });

  testWidgets('peak popup derives map from lat lng when MGRS is incomplete', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final mapCenter = tasmapRepository.getMapCenter(
      tasmapRepository.getAllMaps().first,
    )!;

    await _pumpMap(
      tester,
      _mapStateWithPeak(
        center: mapCenter,
        peak: Peak(
          osmId: 6406,
          name: 'Bonnet Hill',
          latitude: mapCenter.latitude,
          longitude: mapCenter.longitude,
        ),
      ),
      overrides: [
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
      ],
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Map: Adamsons'), findsOneWidget);
  });

  testWidgets('peak popup falls back to unknown map and omits empty lists', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create(maps: []);

    await _pumpMap(
      tester,
      _mapStateWithPeak(),
      overrides: [
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
      ],
    );

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Map: Unknown'), findsOneWidget);
    expect(find.textContaining('Alt Name:'), findsNothing);
    expect(find.textContaining('List(s):'), findsNothing);
  });
}

Future<void> _pumpMap(
  WidgetTester tester,
  MapState state, {
  overrides = const [],
  PeakRepository? peakRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(state, peakRepository: peakRepository),
        ),
        ...overrides,
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

MapState _mapStateWithPeak({
  LatLng center = const LatLng(-43.0, 147.0),
  LatLng? selectedLocation,
  bool showInfoPopup = false,
  Peak? peak,
}) {
  return MapState(
    center: center,
    zoom: 15,
    basemap: Basemap.tracestrack,
    selectedLocation: selectedLocation,
    showInfoPopup: showInfoPopup,
    peaks: [
      peak ??
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
    ],
  );
}
