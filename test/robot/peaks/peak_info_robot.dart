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
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class PeakInfoRobot {
  PeakInfoRobot(this.tester);

  final WidgetTester tester;
  TestGesture? _mouseGesture;
  bool _mouseAdded = false;

  Finder get mapInteractionRegion =>
      find.byKey(const Key('map-interaction-region'));
  Finder get peakInfoPopup => find.byKey(const Key('peak-info-popup'));
  Finder get peakInfoPopupClose =>
      find.byKey(const Key('peak-info-popup-close'));

  Finder peakMarker(int peakOsmId) => find.byKey(Key('peak-marker-$peakOsmId'));
  Finder peakMarkerHitbox(int peakOsmId) =>
      find.byKey(Key('peak-marker-hitbox-$peakOsmId'));
  Finder peakMarkerHover(int peakOsmId) =>
      find.byKey(Key('peak-marker-hover-$peakOsmId'));

  Future<void> pumpMap({
    MapState? initialState,
    PeakListRepository? peakListRepository,
    TasmapRepository? tasmapRepository,
  }) async {
    final resolvedPeakListRepository =
        peakListRepository ?? PeakListRepository.test(InMemoryPeakListStorage());
    final resolvedTasmapRepository =
        tasmapRepository ?? await TestTasmapRepository.create();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(initialState ?? _defaultMapState()),
          ),
          peakListRepositoryProvider.overrideWithValue(resolvedPeakListRepository),
          tasmapRepositoryProvider.overrideWithValue(resolvedTasmapRepository),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(resolvedTasmapRepository),
          ),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> hoverPeak(int peakOsmId) async {
    final point = tester.getCenter(mapInteractionRegion);
    await _ensureMouse(point);
    await _mouseGesture!.moveTo(point);
    await tester.pump();
  }

  Future<void> clickPeak(int peakOsmId) async {
    final point = tester.getCenter(mapInteractionRegion);
    await _ensureMouse(point);
    await _mouseGesture!.moveTo(point);
    await tester.pump();
    await _mouseGesture!.down(point);
    await tester.pump();
    await _mouseGesture!.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> closePeakPopup() async {
    await tester.tap(peakInfoPopupClose);
    await tester.pump();
  }

  Future<void> clickMapBackground() async {
    final point =
        tester.getCenter(mapInteractionRegion) + const Offset(-100, 0);
    await _ensureMouse(point);
    await _mouseGesture!.moveTo(point);
    await tester.pump();
    await _mouseGesture!.down(point);
    await tester.pump();
    await _mouseGesture!.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  void expectPeakMarkerSelectors(int peakOsmId) {
    expect(peakMarker(peakOsmId), findsOneWidget);
    expect(peakMarkerHitbox(peakOsmId), findsOneWidget);
  }

  void expectPeakHover(int peakOsmId) {
    final state = ProviderScope.containerOf(
      tester.element(mapInteractionRegion),
    ).read(mapProvider);
    expect(state.hoveredPeakId, peakOsmId);
    expect(
      tester.widget<MouseRegion>(mapInteractionRegion).cursor,
      SystemMouseCursors.click,
    );
    expect(peakMarkerHover(peakOsmId), findsOneWidget);
  }

  void expectPeakPopupWithContent(String peakName) {
    expectPeakPopupWithLines([peakName, 'Height: —', 'Map: Unknown']);
  }

  void expectPeakPopupWithLines(List<String> expectedLines) {
    expect(peakInfoPopup, findsOneWidget);
    expect(peakInfoPopupClose, findsOneWidget);
    for (final line in expectedLines) {
      expect(find.text(line), findsOneWidget);
    }
  }

  void expectNoPeakPopup() {
    expect(peakInfoPopup, findsNothing);
    expect(
      ProviderScope.containerOf(
        tester.element(mapInteractionRegion),
      ).read(mapProvider).peakInfoPeak,
      isNull,
    );
  }

  void expectSelectedLocation() {
    expect(
      ProviderScope.containerOf(
        tester.element(mapInteractionRegion),
      ).read(mapProvider).selectedLocation,
      isNotNull,
    );
  }

  Future<void> dispose() async {
    if (_mouseGesture != null && _mouseAdded) {
      await _mouseGesture!.removePointer();
      _mouseAdded = false;
    }
  }

  Future<void> _ensureMouse(Offset location) async {
    _mouseGesture ??= await tester.createGesture(kind: PointerDeviceKind.mouse);
    if (_mouseAdded) {
      return;
    }
    await _mouseGesture!.addPointer(location: location);
    await tester.pump();
    _mouseAdded = true;
  }
}

MapState _defaultMapState() {
  return MapState(
    center: const LatLng(-43.0, 147.0),
    zoom: 15,
    basemap: Basemap.tracestrack,
    peaks: [
      Peak(osmId: 6406, name: 'Bonnet Hill', latitude: -43.0, longitude: 147.0),
    ],
  );
}
