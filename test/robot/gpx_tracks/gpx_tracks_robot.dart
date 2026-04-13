import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';

import '../../harness/test_map_notifier.dart';

class GpxTracksRobot {
  GpxTracksRobot(this.tester, this.initialState);

  final WidgetTester tester;
  final MapState initialState;
  TestGesture? _mouseGesture;
  bool _mouseAdded = false;

  Finder get showTracksFab => find.byKey(const Key('show-tracks-fab'));
  Finder get importFab => find.byKey(const Key('import-tracks-fab'));
  Finder get infoFab => find.byKey(const Key('map-info-fab'));
  Finder get mapInteractionRegion =>
      find.byKey(const Key('map-interaction-region'));

  Future<void> pumpApp() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => TestMapNotifier(initialState)),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  void expectTracksImportedAndVisible() {
    expect(initialState.tracks, isNotEmpty);
    expect(initialState.showTracks, isTrue);
    expect(showTracksFab, findsOneWidget);
    expect(importFab, findsOneWidget);
    expect(infoFab, findsOneWidget);
  }

  Future<void> toggleTracks() async {
    await tester.tap(showTracksFab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  void expectTracksHidden() {
    expect(
      ProviderScope.containerOf(
        tester.element(showTracksFab),
      ).read(mapProvider).showTracks,
      isFalse,
    );
  }

  void expectTracksShown() {
    expect(
      ProviderScope.containerOf(
        tester.element(showTracksFab),
      ).read(mapProvider).showTracks,
      isTrue,
    );
  }

  Future<void> hoverTrack() async {
    await _ensureMouse(tester.getCenter(mapInteractionRegion));
    await _mouseGesture!.moveTo(tester.getCenter(mapInteractionRegion));
    await tester.pump();
  }

  Future<void> moveMouseAway() async {
    await _ensureMouse(tester.getCenter(mapInteractionRegion));
    await _mouseGesture!.moveTo(
      tester.getBottomRight(mapInteractionRegion) + const Offset(20, 20),
    );
    await tester.pump();
  }

  void expectHoveredTrack(int trackId) {
    expect(
      ProviderScope.containerOf(
        tester.element(mapInteractionRegion),
      ).read(mapProvider).hoveredTrackId,
      trackId,
    );
    expect(_mapRegion.cursor, SystemMouseCursors.click);
  }

  void expectNoHoveredTrack() {
    expect(
      ProviderScope.containerOf(
        tester.element(mapInteractionRegion),
      ).read(mapProvider).hoveredTrackId,
      isNull,
    );
    expect(_mapRegion.cursor, SystemMouseCursors.grab);
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

  MouseRegion get _mapRegion {
    return tester.widget<MouseRegion>(mapInteractionRegion);
  }
}
