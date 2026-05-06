import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('trackpad scroll down zooms in without moving center', (
    tester,
  ) async {
    final initialState = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 10,
      basemap: Basemap.tracestrack,
    );

    await _pumpMapApp(tester, initialState);

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    final gesture = await tester.startGesture(
      tester.getCenter(region),
      kind: PointerDeviceKind.trackpad,
    );

    await gesture.panZoomUpdate(
      tester.getCenter(region),
      pan: const Offset(0, 120),
    );
    await tester.pump();

    final state = container.read(mapProvider);
    expect(state.zoom, greaterThan(initialState.zoom));
    expect(
      state.center.latitude,
      moreOrLessEquals(initialState.center.latitude, epsilon: 0.000001),
    );
    expect(
      state.center.longitude,
      moreOrLessEquals(initialState.center.longitude, epsilon: 0.000001),
    );

    await gesture.up();
  });

  testWidgets('trackpad pinch zoom still changes zoom after gesture update', (
    tester,
  ) async {
    final initialState = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 10,
      basemap: Basemap.tracestrack,
    );

    await _pumpMapApp(tester, initialState);

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    final gesture = await tester.startGesture(
      tester.getCenter(region),
      kind: PointerDeviceKind.trackpad,
    );

    await gesture.panZoomUpdate(
      tester.getCenter(region),
      pan: const Offset(0, 120),
      scale: 1.5,
    );
    await tester.pump();

    final state = container.read(mapProvider);
    expect(state.zoom, greaterThan(initialState.zoom));
    expect(
      state.center.latitude,
      moreOrLessEquals(initialState.center.latitude, epsilon: 0.000001),
    );
    expect(
      state.center.longitude,
      moreOrLessEquals(initialState.center.longitude, epsilon: 0.000001),
    );

    await gesture.up();
  });

  testWidgets('trackpad horizontal gesture is a no-op', (tester) async {
    final initialState = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 10,
      basemap: Basemap.tracestrack,
    );

    await _pumpMapApp(tester, initialState);

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    final gesture = await tester.startGesture(
      tester.getCenter(region),
      kind: PointerDeviceKind.trackpad,
    );

    await gesture.panZoomUpdate(
      tester.getCenter(region),
      pan: const Offset(120, 0),
    );
    await tester.pump();

    final state = container.read(mapProvider);
    expect(state.zoom, initialState.zoom);
    expect(
      state.center.latitude,
      moreOrLessEquals(initialState.center.latitude, epsilon: 0.000001),
    );
    expect(
      state.center.longitude,
      moreOrLessEquals(initialState.center.longitude, epsilon: 0.000001),
    );

    await gesture.up();
  });

  testWidgets('trackpad diagonal scroll down uses the vertical component', (
    tester,
  ) async {
    final initialState = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 10,
      basemap: Basemap.tracestrack,
    );

    await _pumpMapApp(tester, initialState);

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    final gesture = await tester.startGesture(
      tester.getCenter(region),
      kind: PointerDeviceKind.trackpad,
    );

    await gesture.panZoomUpdate(
      tester.getCenter(region),
      pan: const Offset(40, 120),
    );
    await tester.pump();

    final state = container.read(mapProvider);
    expect(state.zoom, greaterThan(initialState.zoom));
    expect(
      state.center.latitude,
      moreOrLessEquals(initialState.center.latitude, epsilon: 0.000001),
    );
    expect(
      state.center.longitude,
      moreOrLessEquals(initialState.center.longitude, epsilon: 0.000001),
    );

    await gesture.up();
  });

  testWidgets('trackpad vertical zoom clamps at the max zoom bound', (
    tester,
  ) async {
    final initialState = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 18,
      basemap: Basemap.tracestrack,
    );

    await _pumpMapApp(tester, initialState);

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    final gesture = await tester.startGesture(
      tester.getCenter(region),
      kind: PointerDeviceKind.trackpad,
    );

    await gesture.panZoomUpdate(
      tester.getCenter(region),
      pan: const Offset(0, 120),
    );
    await tester.pump();

    final state = container.read(mapProvider);
    expect(state.zoom, 18);
    expect(
      state.center.latitude,
      moreOrLessEquals(initialState.center.latitude, epsilon: 0.000001),
    );
    expect(
      state.center.longitude,
      moreOrLessEquals(initialState.center.longitude, epsilon: 0.000001),
    );

    await gesture.up();
  });
}

Future<void> _pumpMapApp(WidgetTester tester, MapState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mapProvider.overrideWith(() => TestMapNotifier(state))],
      child: const App(),
    ),
  );
  await tester.pump();
  router.go('/map');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}
