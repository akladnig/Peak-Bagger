import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('recovery state shows banner and disables track controls', (
    tester,
  ) async {
    final state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 10,
      basemap: Basemap.tracestrack,
      hasTrackRecoveryIssue: true,
      tracks: [
        GpxTrack(contentHash: '', trackName: 'Broken Track', trackDate: null),
      ],
    );

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

    expect(find.text('Some tracks need to be rebuilt.'), findsWidgets);

    final showTracksFab = tester.widget<FloatingActionButton>(
      find.byKey(const Key('show-tracks-fab')),
    );
    final importFab = tester.widget<FloatingActionButton>(
      find.byKey(const Key('import-tracks-fab')),
    );

    expect(showTracksFab.onPressed, isNull);
    expect(importFab.onPressed, isNull);
  });

  testWidgets('hovering a visible track sets hover state and clears on exit', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithVisibleTrack());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    final center = tester.getCenter(region);
    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();

    expect(container.read(mapProvider).hoveredTrackId, 7);
    expect(container.read(mapProvider).cursorMgrs, isNotNull);
    expect(_mapRegion(tester).cursor, SystemMouseCursors.click);

    await gesture.moveTo(tester.getBottomRight(region) + const Offset(20, 20));
    await tester.pump();

    expect(container.read(mapProvider).hoveredTrackId, isNull);
    expect(container.read(mapProvider).cursorMgrs, isNull);
    expect(_mapRegion(tester).cursor, SystemMouseCursors.grab);
  });

  testWidgets('hovering away from a track clears hover inside map', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithVisibleTrack());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() async {
      try {
        await gesture.removePointer();
      } catch (_) {}
    });

    final center = tester.getCenter(region);
    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();

    expect(container.read(mapProvider).hoveredTrackId, 7);
    expect(_mapRegion(tester).cursor, SystemMouseCursors.click);

    await gesture.moveTo(tester.getTopLeft(region) + const Offset(20, 20));
    await tester.pump();

    expect(container.read(mapProvider).hoveredTrackId, isNull);
    expect(_mapRegion(tester).cursor, SystemMouseCursors.grab);
  });

  testWidgets('dragging clears hover and keeps grabbing cursor', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithVisibleTrack());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    final center = tester.getCenter(region);
    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();

    expect(container.read(mapProvider).hoveredTrackId, 7);

    await gesture.down(center);
    await tester.pump();

    expect(container.read(mapProvider).hoveredTrackId, isNull);
    expect(_mapRegion(tester).cursor, SystemMouseCursors.grabbing);

    await gesture.moveTo(center + const Offset(0, 30));
    await tester.pump();

    expect(container.read(mapProvider).hoveredTrackId, isNull);
    expect(_mapRegion(tester).cursor, SystemMouseCursors.grabbing);

    await gesture.up();
    await tester.pump();

    expect(container.read(mapProvider).hoveredTrackId, isNull);
    expect(_mapRegion(tester).cursor, SystemMouseCursors.grab);
  });

  testWidgets('hidden tracks and recovery mode disable hover detection', (
    tester,
  ) async {
    final hiddenState = _mapStateWithVisibleTrack(showTracks: false);
    await _pumpMapApp(tester, hiddenState);

    final hiddenRegion = find.byKey(const Key('map-interaction-region'));
    final hiddenContainer = ProviderScope.containerOf(
      tester.element(hiddenRegion),
    );
    final hiddenGesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(() async {
      try {
        await hiddenGesture.removePointer();
      } catch (_) {}
    });

    final hiddenCenter = tester.getCenter(hiddenRegion);
    await hiddenGesture.addPointer(location: hiddenCenter);
    await tester.pump();
    await hiddenGesture.moveTo(hiddenCenter);
    await tester.pump();

    expect(hiddenContainer.read(mapProvider).hoveredTrackId, isNull);
    expect(_mapRegion(tester).cursor, SystemMouseCursors.grab);

    await hiddenGesture.removePointer();

    await _pumpMapApp(
      tester,
      _mapStateWithVisibleTrack(hasRecoveryIssue: true),
    );

    final recoveryRegion = find.byKey(const Key('map-interaction-region'));
    final recoveryContainer = ProviderScope.containerOf(
      tester.element(recoveryRegion),
    );
    final recoveryGesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(() async {
      try {
        await recoveryGesture.removePointer();
      } catch (_) {}
    });

    final recoveryCenter = tester.getCenter(recoveryRegion);
    await recoveryGesture.addPointer(location: recoveryCenter);
    await tester.pump();
    await recoveryGesture.moveTo(recoveryCenter);
    await tester.pump();

    expect(recoveryContainer.read(mapProvider).hoveredTrackId, isNull);
    expect(_mapRegion(tester).cursor, SystemMouseCursors.grab);
  });

  testWidgets('camera changes clear stale hovered track state', (tester) async {
    await _pumpMapApp(tester, _mapStateWithVisibleTrack());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);

    final center = tester.getCenter(region);
    await gesture.addPointer(location: center);
    await tester.pump();
    await gesture.moveTo(center);
    await tester.pump();

    expect(container.read(mapProvider).hoveredTrackId, 7);

    container
        .read(mapProvider.notifier)
        .updatePosition(const LatLng(-41.4, 146.4), 14);
    await tester.pump();

    expect(container.read(mapProvider).hoveredTrackId, isNull);
    expect(_mapRegion(tester).cursor, SystemMouseCursors.grab);
  });

  testWidgets('trackpad pan moves the map camera', (tester) async {
    await _pumpMapApp(tester, _mapStateWithVisibleTrack());

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));
    final initialCenter = container.read(mapProvider).center;

    final gesture = await tester.startGesture(
      tester.getCenter(region),
      kind: PointerDeviceKind.trackpad,
    );
    addTearDown(() async {
      try {
        await gesture.up();
      } catch (_) {}
    });

    await gesture.panZoomUpdate(
      tester.getCenter(region),
      pan: const Offset(0, 120),
    );
    await tester.pump();

    expect(container.read(mapProvider).center, isNot(initialCenter));
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

MapState _mapStateWithVisibleTrack({
  bool showTracks = true,
  bool hasRecoveryIssue = false,
}) {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    showTracks: showTracks,
    hasTrackRecoveryIssue: hasRecoveryIssue,
    tracks: [
      GpxTrack(
        gpxTrackId: 7,
        contentHash: 'hash',
        trackName: 'Hover Track',
        trackDate: DateTime(2024, 1, 15),
        gpxFile: '<gpx></gpx>',
        displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
          [const LatLng(-41.5, 146.49), const LatLng(-41.5, 146.51)],
        ]),
      ),
    ],
  );
}

MouseRegion _mapRegion(WidgetTester tester) {
  return tester.widget<MouseRegion>(
    find.byKey(const Key('map-interaction-region')),
  );
}
