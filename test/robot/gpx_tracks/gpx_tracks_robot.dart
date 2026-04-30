import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_correlation_settings_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';

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
  Finder get showPeaksFab => find.byKey(const Key('show-peaks-fab'));
  Finder get peakMarkerLayer => find.byKey(const Key('peak-marker-layer'));
  Finder get recalcStatsTile =>
      find.byKey(const Key('recalculate-track-statistics-tile'));
  Finder get recalcStatsConfirm =>
      find.byKey(const Key('recalculate-stats-confirm'));
  Finder get filterSettingsTile =>
      find.byKey(const Key('gpx-filter-settings-section'));
  Finder get outlierFilterField =>
      find.byKey(const Key('gpx-filter-outlier-filter'));
  Finder get hampelWindowField =>
      find.byKey(const Key('gpx-filter-hampel-window'));
  Finder get elevationSmootherField =>
      find.byKey(const Key('gpx-filter-elevation-smoother'));
  Finder get elevationWindowField =>
      find.byKey(const Key('gpx-filter-elevation-window'));
  Finder get positionSmootherField =>
      find.byKey(const Key('gpx-filter-position-smoother'));
  Finder get positionWindowField =>
      find.byKey(const Key('gpx-filter-position-window'));
  Finder get peakCorrelationSettingsTile =>
      find.byKey(const Key('peak-correlation-settings-section'));
  Finder get peakCorrelationDistanceField =>
      find.byKey(const Key('peak-correlation-distance-meters'));
  Finder get startupBackfillWarningOpenSettings =>
      find.byKey(const Key('startup-backfill-warning-open-settings'));
  Finder get mapInteractionRegion =>
      find.byKey(const Key('map-interaction-region'));

  Future<void> pumpApp() async {
    final gpxTrackRepository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage(initialState.tracks),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          gpxTrackRepositoryProvider.overrideWithValue(gpxTrackRepository),
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

  Future<void> togglePeaks() async {
    await tester.tap(showPeaksFab);
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
    await tester.tap(recalcStatsConfirm);
    await tester.pumpAndSettle();
  }

  Future<void> openSettingsFromStartupWarning() async {
    await tester.pump(const Duration(milliseconds: 100));
    expect(startupBackfillWarningOpenSettings, findsOneWidget);
    await tester.tap(startupBackfillWarningOpenSettings, warnIfMissed: false);
    await tester.pumpAndSettle();
    if (router.routerDelegate.currentConfiguration.uri.path != '/settings') {
      await openSettings();
    }
  }

  Future<void> openFilterSettings() async {
    await tester.tap(filterSettingsTile);
    await tester.pumpAndSettle();
  }

  Future<void> setOutlierFilterNone() async {
    await tester.scrollUntilVisible(
      outlierFilterField,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(outlierFilterField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
  }

  Future<void> setElevationSmootherNone() async {
    await tester.scrollUntilVisible(
      elevationSmootherField,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(elevationSmootherField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
  }

  Future<void> setPositionSmootherNone() async {
    await tester.scrollUntilVisible(
      positionSmootherField,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(positionSmootherField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
  }

  Future<void> openPeakCorrelationSettings() async {
    await tester.ensureVisible(peakCorrelationSettingsTile);
    await tester.tap(peakCorrelationSettingsTile, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> setHampelWindow(int value) async {
    await tester.scrollUntilVisible(
      hampelWindowField,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(hampelWindowField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('$value').last);
    await tester.pumpAndSettle();
  }

  Future<void> setPeakCorrelationDistance(int value) async {
    final container = ProviderScope.containerOf(
      tester.element(peakCorrelationDistanceField),
    );
    await container
        .read(peakCorrelationSettingsProvider.notifier)
        .setDistanceMeters(value);
    await tester.pumpAndSettle();
  }

  int currentHampelWindow(BuildContext context) {
    return ProviderScope.containerOf(
      context,
    ).read(gpxFilterSettingsProvider).value!.hampelWindow;
  }

  int currentPeakCorrelationDistance(BuildContext context) {
    return ProviderScope.containerOf(
      context,
    ).read(peakCorrelationSettingsProvider).value!;
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

  void expectPeaksShown() {
    expect(peakMarkerLayer, findsOneWidget);
  }

  void expectPeaksHidden() {
    expect(peakMarkerLayer, findsNothing);
  }

  List<String> peakMarkerAssetNames() {
    final markerLayer = tester.widget<MarkerLayer>(peakMarkerLayer);
    return markerLayer.markers.map((marker) {
      final child = marker.child;
      final visualMarker = child is KeyedSubtree ? child.child : child;
      return (visualMarker as SvgPicture).bytesLoader.toString();
    }).toList();
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

  Future<void> clickHoveredTrack() async {
    await _mouseGesture!.down(tester.getCenter(mapInteractionRegion));
    await tester.pump();
    await _mouseGesture!.up();
    await tester.pump();
  }

  Future<void> clickMapBackground() async {
    final background =
        tester.getTopLeft(mapInteractionRegion) + const Offset(120, 120);
    await _ensureMouse(background);
    await _mouseGesture!.moveTo(background);
    await tester.pump();
    await _mouseGesture!.down(background);
    await tester.pump();
    await _mouseGesture!.up();
    await tester.pump();
  }

  Future<void> panMap() async {
    final gesture = await tester.startGesture(
      tester.getCenter(mapInteractionRegion),
      kind: PointerDeviceKind.trackpad,
    );
    addTearDown(() async {
      try {
        await gesture.up();
      } catch (_) {}
    });
    await gesture.panZoomUpdate(
      tester.getCenter(mapInteractionRegion),
      pan: const Offset(0, 120),
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

  void expectSelectedTrack(int trackId) {
    expect(
      ProviderScope.containerOf(
        tester.element(mapInteractionRegion),
      ).read(mapProvider).selectedTrackId,
      trackId,
    );
  }

  void expectNoSelectedTrack() {
    expect(
      ProviderScope.containerOf(
        tester.element(mapInteractionRegion),
      ).read(mapProvider).selectedTrackId,
      isNull,
    );
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
          'Updated $updatedCount tracks, refreshed peak correlation, skipped $skippedCount tracks',
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

  void expectMirroredStartupFailureDetail(String message) {
    expect(find.text('Settings'), findsWidgets);
    expect(find.text(message), findsOneWidget);
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
