import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';

import '../../harness/test_map_notifier.dart';

class GpxTracksRobot {
  GpxTracksRobot(this.tester, this.initialState, {TestMapNotifier? notifier})
    : notifier = notifier ?? TestMapNotifier(initialState);

  final WidgetTester tester;
  final MapState initialState;
  final TestMapNotifier notifier;
  TestGesture? _mouseGesture;
  bool _mouseAdded = false;

  Finder get showTracksFab => find.byKey(const Key('show-tracks-fab'));
  Finder get importFab => find.byKey(const Key('import-tracks-fab'));
  Finder get infoFab => find.byKey(const Key('map-info-fab'));
  Finder get recalcStatsTile =>
      find.byKey(const Key('recalculate-track-statistics-tile'));
  Finder get filterSettingsTile =>
      find.byKey(const Key('gpx-filter-settings-section'));
  Finder get hampelWindowField =>
      find.byKey(const Key('gpx-filter-hampel-window'));
  Finder get mapInteractionRegion =>
      find.byKey(const Key('map-interaction-region'));

  Future<void> pumpApp() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mapProvider.overrideWith(() => notifier)],
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

  Future<void> openSettings() async {
    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> recalculateTrackStatistics() async {
    await tester.tap(recalcStatsTile);
    await tester.pumpAndSettle();
  }

  Future<void> openFilterSettings() async {
    await tester.tap(filterSettingsTile);
    await tester.pumpAndSettle();
  }

  Future<void> setHampelWindow(int value) async {
    await tester.tap(hampelWindowField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('$value').last);
    await tester.pumpAndSettle();
  }

  int currentHampelWindow(BuildContext context) {
    return ProviderScope.containerOf(
      context,
    ).read(gpxFilterSettingsProvider).value!.hampelWindow;
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

  void expectTrackStatisticsDialog({
    required int updatedCount,
    required int skippedCount,
    String? warning,
  }) {
    expect(find.text('Track Statistics Recalculated'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining(
          'Updated $updatedCount tracks, skipped $skippedCount tracks',
        ),
      ),
      findsOneWidget,
    );
    if (warning != null) {
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining(warning),
        ),
        findsOneWidget,
      );
    }
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
