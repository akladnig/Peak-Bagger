import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_correlation_settings_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/gpx_file_picker.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_gpx_file_picker.dart';
import '../../harness/test_ready_route_graph_store.dart';

class GpxTracksRobot {
  GpxTracksRobot(
    this.tester,
    this.initialState, {
    MapNotifier? notifier,
    PeakListRepository? peakListRepository,
    PeakRepository? peakRepository,
    PeaksBaggedRepository? peaksBaggedRepository,
    RouteRepository? routeRepository,
    this.tasmapRepository,
    GpxFilePicker? gpxFilePicker,
    this.prefsLoader,
    this.surfaceSize = const Size(1600, 900),
  }) : notifier = notifier ?? TestMapNotifier(initialState),
       peakListRepository =
           peakListRepository ??
           PeakListRepository.test(InMemoryPeakListStorage()),
       peakRepository =
           peakRepository ?? PeakRepository.test(InMemoryPeakStorage()),
       peaksBaggedRepository =
           peaksBaggedRepository ??
           PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
       routeRepository =
           routeRepository ?? RouteRepository.test(InMemoryRouteStorage()),
       gpxFilePicker = gpxFilePicker ?? FakeGpxFilePicker();

  final WidgetTester tester;
  final MapState initialState;
  final MapNotifier notifier;
  final PeakListRepository peakListRepository;
  final PeakRepository peakRepository;
  final PeaksBaggedRepository peaksBaggedRepository;
  final RouteRepository routeRepository;
  final TasmapRepository? tasmapRepository;
  final GpxFilePicker gpxFilePicker;
  final Future<SharedPreferences> Function()? prefsLoader;
  final Size surfaceSize;
  TestGesture? _mouseGesture;
  bool _mouseAdded = false;

  Finder get showTracksFab => find.byKey(const Key('show-tracks-fab'));
  Finder get tracksRoutesDrawer =>
      find.byKey(const Key('tracks-routes-drawer'));
  Finder get importFab => find.byKey(const Key('import-tracks-fab'));
  Finder get importDialog => find.byKey(const Key('gpx-import-dialog'));
  Finder get backgroundJobsEntry =>
      find.byKey(const Key('background-jobs-entry'));
  Finder get backgroundJobsPanel =>
      find.byKey(const Key('background-jobs-panel'));
  Finder get backgroundJobsClearFinished =>
      find.byKey(const Key('background-jobs-clear-finished'));
  Finder get snackbarOpenJobs =>
      find.byKey(const Key('background-jobs-snackbar-open-jobs'));
  Finder get infoFab => find.byKey(const Key('map-info-fab'));
  Finder get mapInfoPopup => find.byKey(const Key('map-info-popup'));
  Finder get mapInfoPopupClose => find.byKey(const Key('map-info-popup-close'));
  Finder get showPeaksFab => find.byKey(const Key('show-peaks-fab'));
  Finder get peakListsDrawer => find.byKey(const Key('peak-lists-drawer'));
  Finder get peakListSelectionSummary =>
      find.byKey(const Key('peak-list-selection-summary'));
  Finder get peakListAllPeaksRow =>
      find.byKey(const Key('peak-list-selection-all-peaks-row'));
  Finder get peakListAllPeaksButton =>
      find.byKey(const Key('peak-list-item-All Peaks'));
  Finder get peakListChipAllPeaks =>
      find.byKey(const Key('peak-list-selection-chip-all-peaks'));
  Finder get peakListChipNone =>
      find.byKey(const Key('peak-list-selection-chip-none'));
  Finder get peakListUnavailableMessage =>
      find.byKey(const Key('peak-list-selection-unavailable-message'));
  Finder get dashboardMyAscentsCard =>
      find.byKey(const Key('dashboard-card-my-ascents'));
  Finder get importResultSummary => find.byKey(const Key('gpx-import-summary'));
  Finder get importResultClose =>
      find.byKey(const Key('gpx-import-result-close'));
  Finder get importAsRouteSwitch => find.descendant(
    of: find.byKey(const Key('gpx-import-as-route')),
    matching: find.byType(Switch),
  );
  Finder get importSelectedRow => find.byKey(const Key('gpx-import-row-0'));
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
  Finder get mapTapActionPopup => find.byKey(const Key('map-tap-action-popup'));
  Finder get trackInfoPanel => find.byKey(const Key('track-info-panel'));
  Finder get trackInfoPanelClose =>
      find.byKey(const Key('track-info-panel-close'));
  Finder get visibilitySwitch =>
      find.byKey(const Key('track-info-panel-visibility-switch'));
  Finder backgroundJobRow(int index) =>
      find.byKey(Key('background-jobs-row-background-job-$index'));
  Finder backgroundJobStatus(int index) =>
      find.byKey(Key('background-jobs-status-background-job-$index'));
  Finder backgroundJobProgress(int index) =>
      find.byKey(Key('background-jobs-progress-background-job-$index'));
  Finder backgroundJobDismiss(int index) =>
      find.byKey(Key('background-jobs-dismiss-background-job-$index'));
  Finder backgroundJobExpand(int index) =>
      find.byKey(Key('background-jobs-expand-background-job-$index'));

  Future<void> pumpApp() async {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gpxTrackRepository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage(initialState.tracks),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          routeGraphStoreProvider.overrideWithValue(TestReadyRouteGraphStore()),
          gpxTrackRepositoryProvider.overrideWithValue(gpxTrackRepository),
          peakListRepositoryProvider.overrideWithValue(peakListRepository),
          peakRepositoryProvider.overrideWithValue(peakRepository),
          peaksBaggedRepositoryProvider.overrideWithValue(
            peaksBaggedRepository,
          ),
          routeRepositoryProvider.overrideWithValue(routeRepository),
          if (prefsLoader != null)
            mapPreferencesLoaderProvider.overrideWithValue(prefsLoader!),
          if (tasmapRepository != null)
            tasmapRepositoryProvider.overrideWithValue(tasmapRepository!),
          gpxFilePickerProvider.overrideWithValue(gpxFilePicker),
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
    await tester.ensureVisible(showTracksFab);
    await tester.pumpAndSettle();
    tester.widget<FloatingActionButton>(showTracksFab).onPressed!.call();
    await tester.pumpAndSettle();
    expect(tracksRoutesDrawer, findsOneWidget);
    await tester.tap(find.text('Show Tracks'));
    await tester.pumpAndSettle();
  }

  Future<void> openMapInfoPopup() async {
    await tester.ensureVisible(infoFab);
    await tester.pumpAndSettle();
    await tester.tap(infoFab);
    await tester.pumpAndSettle();
  }

  Future<void> closeMapInfoPopup() async {
    await tester.tap(mapInfoPopupClose);
    await tester.pumpAndSettle();
  }

  Future<void> dismissMapInfoPopupWithEscape() async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  }

  Future<void> dismissMapInfoPopupWithCtrlC() async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  void expectMapInfoPopupVisible() {
    expect(mapInfoPopup, findsOneWidget);
    expect(mapInfoPopupClose, findsOneWidget);
  }

  void expectMapInfoPopupHidden() {
    expect(mapInfoPopup, findsNothing);
  }

  Future<void> toggleRoutes() async {
    await tester.ensureVisible(showTracksFab);
    await tester.pumpAndSettle();
    tester.widget<FloatingActionButton>(showTracksFab).onPressed!.call();
    await tester.pumpAndSettle();
    expect(tracksRoutesDrawer, findsOneWidget);
    await tester.tap(find.text('Show Routes'));
    await tester.pumpAndSettle();
  }

  Future<void> selectNoPeaks() async {
    await tester.ensureVisible(showPeaksFab);
    await tester.pumpAndSettle();
    tester.widget<FloatingActionButton>(showPeaksFab).onPressed!.call();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-item-None')));
    await tester.pumpAndSettle();
  }

  Future<void> selectAllPeaks() async {
    await tester.ensureVisible(showPeaksFab);
    await tester.pumpAndSettle();
    tester.widget<FloatingActionButton>(showPeaksFab).onPressed!.call();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-item-All Peaks')));
    await tester.pumpAndSettle();
  }

  Finder peakListRow(int peakListId) {
    return find.byKey(Key('peak-list-selection-row-$peakListId'));
  }

  Finder peakListButton(String name) {
    return find.byKey(Key('peak-list-item-$name'));
  }

  Finder peakListChip(int peakListId) {
    return find.byKey(Key('peak-list-selection-chip-$peakListId'));
  }

  Future<void> selectSpecificPeakList(String name) async {
    await tester.ensureVisible(showPeaksFab);
    await tester.pumpAndSettle();
    tester.widget<FloatingActionButton>(showPeaksFab).onPressed!.call();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('peak-list-item-$name')));
    await tester.pumpAndSettle();
  }

  Future<void> openSettings() async {
    router.go('/settings');
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> recalculateTrackStatistics() async {
    await tester.tap(recalcStatsTile);
    await tester.pumpAndSettle();
    await tester.tap(recalcStatsConfirm);
    await tester.pumpAndSettle();
  }

  Future<void> openImportDialog() async {
    await tester.tap(importFab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> selectImportFiles() async {
    final selectFilesButton = find.byKey(const Key('gpx-import-select-files'));
    await tester.ensureVisible(selectFilesButton);
    await tester.pumpAndSettle();
    await tester.tap(selectFilesButton, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> setImportAsRoute(bool value) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final currentValue = tester.widget<Switch>(importAsRouteSwitch).value;
      if (currentValue == value) {
        return;
      }

      await tester.ensureVisible(importAsRouteSwitch);
      await tester.pumpAndSettle();
      await tester.tap(importAsRouteSwitch, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(tester.widget<Switch>(importAsRouteSwitch).value, value);
  }

  Future<void> confirmImport() async {
    await tester.tap(find.byKey(const Key('gpx-import-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> importSelectedFiles() async {
    await openImportDialog();
    await selectImportFiles();
    await waitForImportSelection();
    for (var i = 0; i < 50; i++) {
      final importButton = tester.widget<FilledButton>(
        find.byKey(const Key('gpx-import-button')),
      );
      if (importButton.onPressed != null) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await confirmImport();
  }

  Future<void> importSelectedRouteFiles() async {
    await openImportDialog();
    await setImportAsRoute(true);
    await selectImportFiles();
    await waitForImportSelection();
    for (var i = 0; i < 50; i++) {
      final importButton = tester.widget<FilledButton>(
        find.byKey(const Key('gpx-import-button')),
      );
      if (importButton.onPressed != null) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await confirmImport();
  }

  Future<void> waitForImportSelection() async {
    for (var i = 0; i < 50; i++) {
      if (importSelectedRow.evaluate().isNotEmpty) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> waitForImportResult() async {
    for (var i = 0; i < 50; i++) {
      if (notifier.state.selectedTrackId != null) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> waitForRouteImportResult() async {
    for (var i = 0; i < 50; i++) {
      if (notifier.state.selectedRouteId != null) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> closeImportResult() async {
    await tester.tap(importResultClose);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> openDashboard() async {
    await tester.tap(find.byKey(const Key('nav-dashboard')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openPeakLists() async {
    await tester.tap(find.byKey(const Key('nav-peak-lists')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> openBackgroundJobsFromSnackbar() async {
    await tester.tap(snackbarOpenJobs, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openBackgroundJobsPanel() async {
    await tester.tap(backgroundJobsEntry, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> expandBackgroundJob(int index) async {
    await tester.tap(backgroundJobExpand(index), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> dismissBackgroundJob(int index) async {
    await tester.tap(backgroundJobDismiss(index), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> clearFinishedBackgroundJobs() async {
    await tester.tap(backgroundJobsClearFinished, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void expectBackgroundJobStatus(int index, String text) {
    expect(backgroundJobStatus(index), findsOneWidget);
    expect(
      find.descendant(
        of: backgroundJobStatus(index),
        matching: find.text(text),
      ),
      findsOneWidget,
    );
  }

  void expectBackgroundJobProgressText(int index, String text) {
    expect(backgroundJobProgress(index), findsOneWidget);
    expect(
      find.descendant(
        of: backgroundJobProgress(index),
        matching: find.text(text),
      ),
      findsOneWidget,
    );
  }

  void expectImportDialogVisible() {
    expect(find.byKey(const Key('gpx-import-dialog')), findsOneWidget);
  }

  void expectImportResultSummary(String text) {
    expect(importResultSummary, findsOneWidget);
    expect(tester.widget<Text>(importResultSummary).data, text);
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
    await tester.scrollUntilVisible(
      filterSettingsTile,
      300.0,
      scrollable: _settingsScrollable,
    );
    await tester.tap(filterSettingsTile);
    await tester.pumpAndSettle();
  }

  Future<void> setOutlierFilterNone() async {
    await tester.scrollUntilVisible(
      outlierFilterField,
      200.0,
      scrollable: _settingsScrollable,
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
      scrollable: _settingsScrollable,
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
      scrollable: _settingsScrollable,
    );
    await tester.tap(positionSmootherField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('None').last);
    await tester.pumpAndSettle();
  }

  Future<void> openPeakCorrelationSettings() async {
    await tester.scrollUntilVisible(
      peakCorrelationSettingsTile,
      300.0,
      scrollable: _settingsScrollable,
    );
    await tester.tap(peakCorrelationSettingsTile, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> setHampelWindow(int value) async {
    await tester.scrollUntilVisible(
      hampelWindowField,
      200.0,
      scrollable: _settingsScrollable,
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

  Finder get _settingsScrollable => find
      .descendant(
        of: find.byKey(const Key('settings-scrollable')),
        matching: find.byType(Scrollable),
      )
      .first;

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

  List<int> peakMarkerIds() {
    final container = ProviderScope.containerOf(
      tester.element(mapInteractionRegion),
    );
    final peaks = container.read(filteredPeaksProvider);
    final correlatedPeakIds = notifier.correlatedPeakIds;
    final unticked = <int>[];
    final ticked = <int>[];

    for (final peak in peaks) {
      if (correlatedPeakIds.contains(peak.osmId)) {
        ticked.add(peak.osmId);
      } else {
        unticked.add(peak.osmId);
      }
    }

    return [...unticked, ...ticked];
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

  Future<void> setMapCenter(LatLng center) async {
    final notifier = ProviderScope.containerOf(
      tester.element(mapInteractionRegion),
    ).read(mapProvider.notifier);
    notifier.state = notifier.state.copyWith(center: center);
    await tester.pumpAndSettle();
  }

  Future<void> clickHoveredTrack() async {
    await _mouseGesture!.down(tester.getCenter(mapInteractionRegion));
    await tester.pump();
    await _mouseGesture!.up();
    await tester.pump();
  }

  Future<void> clickMapBackground() async {
    final regionTopLeft = tester.getTopLeft(mapInteractionRegion);
    final regionSize = tester.getSize(mapInteractionRegion);
    final background = Offset(
      regionTopLeft.dx + regionSize.width - 160,
      regionTopLeft.dy + 160,
    );
    await _ensureMouse(background);
    await _mouseGesture!.moveTo(background);
    await tester.pump();
    await _mouseGesture!.down(background);
    await tester.pump();
    await _mouseGesture!.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> zoomMapWithTrackpad() async {
    final gesture = await tester.startGesture(
      tester.getCenter(mapInteractionRegion),
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomUpdate(
      tester.getCenter(mapInteractionRegion),
      pan: const Offset(0, 120),
    );
    await tester.pump();
    await gesture.up();
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

  void expectTrackInfoPanelVisible([String? trackName]) {
    expect(trackInfoPanel, findsOneWidget);
    if (trackName != null) {
      expect(find.text(trackName), findsOneWidget);
    }
  }

  void expectNoTrackInfoPanel() {
    expect(trackInfoPanel, findsNothing);
  }

  Future<void> closeTrackInfoPanel() async {
    await tester.tap(trackInfoPanelClose);
    await tester.pumpAndSettle();
  }

  Future<void> toggleTrackVisibility() async {
    await tester.ensureVisible(visibilitySwitch);
    await tester.pumpAndSettle();
    await tester.tap(visibilitySwitch, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  void expectTrackPolylineVisible(bool visible) {
    final layer = tester.widget<PolylineLayer>(
      find.byKey(const Key('track-polyline-layer')),
    );
    expect(layer.polylines, visible ? isNotEmpty : isEmpty);
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
          'Updated ${formatCount(updatedCount)} tracks, refreshed peak correlation, skipped ${formatCount(skippedCount)} tracks',
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
