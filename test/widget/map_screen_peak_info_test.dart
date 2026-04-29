import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';

import '../harness/test_map_notifier.dart';

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
}

Future<void> _pumpMap(WidgetTester tester, MapState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mapProvider.overrideWith(() => TestMapNotifier(state))],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

MapState _mapStateWithPeak({
  LatLng? selectedLocation,
  bool showInfoPopup = false,
}) {
  return MapState(
    center: const LatLng(-43.0, 147.0),
    zoom: 15,
    basemap: Basemap.tracestrack,
    selectedLocation: selectedLocation,
    showInfoPopup: showInfoPopup,
    peaks: [
      Peak(osmId: 6406, name: 'Bonnet Hill', latitude: -43.0, longitude: 147.0),
    ],
  );
}
