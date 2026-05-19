import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_refresh_result.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/gpx_track_statistics_calculator.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

class TestMapNotifier extends MapNotifier {
  TestMapNotifier(
    this.initialState, {
    this.rescanStatus =
        'Imported 1, replaced 0, unchanged 0, non-Tasmanian 2, errors 0',
    this.rescanWarning,
    this.rescanSnackbarMessage,
    this.startupBackfillWarningMessage,
    this.recalcUpdatedCount = 1,
    this.recalcSkippedCount = 0,
    this.recalcWarning,
    this.recalcTracks,
    this.peakRepository,
    this.peaksBaggedRepository,
    this.gpxTrackRepository,
    this.routeRepository,
    this.routeSaveErrorMessage,
    Set<int> correlatedPeakIds = const {},
  }) : _correlatedPeakIds = correlatedPeakIds,
        _startupBackfillWarningMessage = startupBackfillWarningMessage;

  final MapState initialState;
  final String rescanStatus;
  final String? rescanWarning;
  final String? rescanSnackbarMessage;
  final String? startupBackfillWarningMessage;
  final int recalcUpdatedCount;
  final int recalcSkippedCount;
  final String? recalcWarning;
  final List<GpxTrack>? recalcTracks;
  final PeakRepository? peakRepository;
  final PeaksBaggedRepository? peaksBaggedRepository;
  final GpxTrackRepository? gpxTrackRepository;
  final RouteRepository? routeRepository;
  final String? routeSaveErrorMessage;
  final Set<int> _correlatedPeakIds;
  bool _snackbarConsumed = false;
  String? _trackSnackbarMessage;
  String? _startupBackfillWarningMessage;
  String? _routeSnackbarMessage;
  int refreshCallCount = 0;

  void setTracks(List<GpxTrack> tracks) {
    state = state.copyWith(
      tracks: tracks,
      isLoadingTracks: false,
      hasTrackRecoveryIssue: false,
    );
    if (peaksBaggedRepository != null) {
      unawaited(peaksBaggedRepository!.rebuildFromTracks(tracks));
    }
  }

  @override
  MapState build() => initialState;

  @override
  Set<int> get correlatedPeakIds => _correlatedPeakIds;

  @override
  Future<void> reloadPeakMarkers() async {
    final peaks = peakRepository?.getAllPeaks() ?? state.peaks;
    final refreshedPeakInfo = _refreshedPeakInfo(peaks);
    state = state.copyWith(
      peaks: peaks,
      isLoadingPeaks: false,
      clearError: true,
      peakInfo: refreshedPeakInfo,
      clearPeakInfoPopup: state.peakInfo != null && refreshedPeakInfo == null,
    );
  }

  @override
  Future<PeakRefreshResult> refreshPeaks() async {
    refreshCallCount += 1;
    final peaks = peakRepository?.getAllPeaks() ?? state.peaks;
    final refreshedPeakInfo = _refreshedPeakInfo(peaks);
    state = state.copyWith(
      peaks: peaks,
      isLoadingPeaks: false,
      clearError: true,
      peakInfo: refreshedPeakInfo,
      clearPeakInfoPopup: state.peakInfo != null && refreshedPeakInfo == null,
    );
    return PeakRefreshResult(importedCount: peaks.length, skippedCount: 0);
  }

  @override
  Future<void> deleteTrack(int trackId) async {
    final remainingVisibleTracks = state.tracks
        .where((track) => track.gpxTrackId != trackId)
        .toList(growable: false);
    final trackWasLoaded = remainingVisibleTracks.length != state.tracks.length;
    final trackWasSelected = state.selectedTrackId == trackId;
    final trackWasHovered = state.hoveredTrackId == trackId;

    if (trackWasLoaded || trackWasSelected || trackWasHovered) {
      state = state.copyWith(
        tracks: remainingVisibleTracks,
        clearSelectedTrackId: trackWasSelected,
        clearSelectedLocation: trackWasSelected,
        clearHoveredTrackId: trackWasHovered,
        selectedTrackFocusSerial: state.selectedTrackFocusSerial + 1,
      );
    }

    final remainingTracks = gpxTrackRepository?.getAllTracks() ?? remainingVisibleTracks;
    if (peaksBaggedRepository != null) {
      await peaksBaggedRepository!.syncFromTracks(remainingTracks);
    }
  }

  PeakInfoContent? _refreshedPeakInfo(List<Peak> peaks) {
    final existing = state.peakInfo;
    if (existing == null) {
      return null;
    }

    for (final peak in peaks) {
      if (peak.osmId == existing.peak.osmId) {
        return PeakInfoContent(
          peak: peak,
          mapName: existing.mapName,
          listNames: existing.listNames,
        );
      }
    }
    return null;
  }

  @override
  void toggleTracks() {
    if (state.isLoadingTracks || state.hasTrackRecoveryIssue) {
      return;
    }
    state = state.copyWith(
      showTracks: !state.showTracks,
      clearHoveredTrackId: true,
      clearSelectedTrackId: state.showTracks,
    );
  }

  @override
  void updatePosition(LatLng center, double zoom) {
    state = state.copyWith(
      center: center,
      zoom: zoom,
      clearHoveredTrackId: true,
      clearPeakInfoPopup: zoom < MapConstants.clearPeakInfo,
    );
  }

  @override
  void requestCameraMove({
    required LatLng center,
    required double zoom,
    LatLng? selectedLocation,
    bool updateSelectedLocation = false,
    List<Peak>? selectedPeaks,
    bool updateSelectedPeaks = false,
    bool persist = true,
    bool clearGotoMgrs = false,
    bool clearHoveredPeakId = true,
    bool clearHoveredTrackId = true,
  }) {
    final nextSerial = state.cameraRequestSerial + 1;
    state = state.copyWith(
      pendingCameraRequest: PendingCameraRequest(
        center: center,
        zoom: zoom,
        serial: nextSerial,
        selectedLocationBehavior: updateSelectedLocation
            ? (selectedLocation == null
                  ? PendingCameraSelectionBehavior.clear
                  : PendingCameraSelectionBehavior.replace)
            : PendingCameraSelectionBehavior.preserve,
        selectedLocation: selectedLocation,
        selectedPeaksBehavior: updateSelectedPeaks
            ? ((selectedPeaks == null || selectedPeaks.isEmpty)
                  ? PendingCameraSelectionBehavior.clear
                  : PendingCameraSelectionBehavior.replace)
            : PendingCameraSelectionBehavior.preserve,
        selectedPeaks: selectedPeaks ?? const [],
        persist: persist,
        clearGotoMgrs: clearGotoMgrs,
        clearHoveredPeakId: clearHoveredPeakId,
        clearHoveredTrackId: clearHoveredTrackId,
      ),
      cameraRequestSerial: nextSerial,
    );
  }

  @override
  void acceptCameraIntent(PendingCameraRequest request) {
    state = state.copyWith(
      center: request.center,
      zoom: request.zoom,
      selectedLocation: switch (request.selectedLocationBehavior) {
        PendingCameraSelectionBehavior.preserve => null,
        PendingCameraSelectionBehavior.replace => request.selectedLocation,
        PendingCameraSelectionBehavior.clear => null,
      },
      clearSelectedLocation:
          request.selectedLocationBehavior == PendingCameraSelectionBehavior.clear,
      selectedPeaks: switch (request.selectedPeaksBehavior) {
        PendingCameraSelectionBehavior.preserve => null,
        PendingCameraSelectionBehavior.replace => request.selectedPeaks,
        PendingCameraSelectionBehavior.clear => const <Peak>[],
      },
      clearGotoMgrs: request.clearGotoMgrs,
      clearHoveredPeakId: request.clearHoveredPeakId,
      clearHoveredTrackId: request.clearHoveredTrackId,
      clearPeakInfoPopup: request.zoom < MapConstants.clearPeakInfo,
    );
  }

  @override
  Future<void> persistCameraPosition() async {}

  @override
  Future<void> persistPeakListSelection() async {}

  @override
  Future<void> persistTracksRoutesVisibility() async {}

  @override
  Future<void> saveRouteDraft() async {
    final trimmedName = state.routeDraftName.trim();
    if (trimmedName.isEmpty || state.routeDraftMarkers.length < 2) {
      state = state.copyWith(routeDraftNameError: 'A Route name must be entered');
      return;
    }
    if (routeSaveErrorMessage != null) {
      _routeSnackbarMessage = routeSaveErrorMessage;
      state = state.copyWith(isSavingRoute: false);
      return;
    }
    routeRepository?.saveRoute(
      Route(
        name: trimmedName,
        gpxRoute: List<LatLng>.from(state.routeDraftMarkers, growable: false),
        displayRoutePointsByZoom: TrackDisplayCacheBuilder.buildJson([
          List<LatLng>.from(state.routeDraftMarkers, growable: false),
        ]),
        colour: 0xFFFF0000,
      ),
    );
    endRouteDraft();
  }

  @override
  String? consumeRouteSnackbarMessage() {
    final message = _routeSnackbarMessage;
    _routeSnackbarMessage = null;
    return message;
  }

  @override
  void searchPeaks(String query) {
    final lowered = query.toLowerCase();
    final results = state.peaks
        .where((peak) {
          final nameMatch = peak.name.toLowerCase().contains(lowered);
          final elevMatch =
              peak.elevation != null &&
              peak.elevation!.toString().contains(query);
          return query.isEmpty || nameMatch || elevMatch;
        })
        .toList(growable: false);

    state = state.copyWith(searchQuery: query, searchResults: results);
  }

  @override
  void clearSearch() {
    state = state.copyWith(searchQuery: '', searchResults: const []);
  }

  @override
  void toggleInfoPopup() {
    final isVisible = state.showInfoPopup;
    state = state.copyWith(
      showInfoPopup: !isVisible,
      clearInfoPopup: isVisible,
      clearPeakInfoPopup: !isVisible,
    );
  }

  @override
  void centerOnPeak(Peak peak) {
    requestCameraMove(
      center: LatLng(peak.latitude, peak.longitude),
      zoom: MapConstants.singlePointZoom,
      selectedPeaks: [peak],
      updateSelectedPeaks: true,
      clearHoveredPeakId: true,
      clearHoveredTrackId: true,
    );
  }

  @override
  void centerOnLocation(LatLng location) {
    requestCameraMove(
      center: location,
      zoom: state.zoom,
      selectedLocation: location,
      updateSelectedLocation: true,
      clearGotoMgrs: true,
      clearHoveredPeakId: true,
      clearHoveredTrackId: true,
    );
  }

  @override
  void centerOnSelectedLocation() {
    final selected = state.selectedLocation;
    if (selected == null) {
      return;
    }
    requestCameraMove(
      center: selected,
      zoom: state.zoom,
      clearGotoMgrs: true,
      clearHoveredPeakId: true,
      clearHoveredTrackId: true,
    );
  }

  @override
  void clearSelectedLocation() {
    state = state.copyWith(clearSelectedLocation: true);
  }

  @override
  void showTrack(int trackId, {LatLng? selectedLocation}) {
    final track = gpxTrackRepository?.findById(trackId);
    if (gpxTrackRepository != null && track == null) {
      state = state.copyWith(clearSelectedTrackId: true, clearHoveredTrackId: true);
      return;
    }

    final tracks =
        track != null &&
            state.tracks.every((existing) => existing.gpxTrackId != trackId)
        ? [...state.tracks, track]
        : null;

    state = state.copyWith(
      tracks: tracks,
      selectedTrackId: trackId,
      selectedLocation: selectedLocation,
      showTracks: true,
      selectedTrackFocusSerial: state.selectedTrackFocusSerial + 1,
    );
  }

  @override
  void selectMap(Tasmap50k map) {
    state = state.copyWith(
      selectedMap: map,
      tasmapDisplayMode: TasmapDisplayMode.selectedMap,
      clearSelectedLocation: true,
      selectedMapFocusSerial: state.selectedMapFocusSerial + 1,
    );
  }

  @override
  Future<void> rescanTracks() async {
    _trackSnackbarMessage = rescanSnackbarMessage ?? rescanStatus;
    state = state.copyWith(
      trackOperationStatus: rescanStatus,
      trackOperationWarning: rescanWarning,
      clearSelectedTrackId: true,
    );
  }

  @override
  Future<TrackImportResult?> resetTrackData() async {
    state = state.copyWith(
      hasTrackRecoveryIssue: false,
      showTracks: false,
      tracks: const [],
      trackOperationStatus:
          'Imported 1, replaced 0, unchanged 0, non-Tasmanian 0, errors 0',
      trackOperationWarning: null,
      clearHoveredTrackId: true,
      clearSelectedTrackId: true,
    );
    _snackbarConsumed = false;
    _startupBackfillWarningMessage = null;
    return const TrackImportResult(
      tracks: [],
      importedCount: 1,
      replacedCount: 0,
      unchangedCount: 0,
      nonTasmanianCount: 0,
      errorSkippedCount: 0,
    );
  }

  @override
  Future<TrackStatisticsRecalcResult?> recalculateTrackStatistics() async {
    _startupBackfillWarningMessage = null;
    state = state.copyWith(
      isLoadingTracks: false,
      tracks: recalcTracks ?? state.tracks,
      trackOperationStatus:
          'Updated $recalcUpdatedCount tracks, refreshed peak correlation, skipped $recalcSkippedCount tracks',
      trackOperationWarning: recalcWarning,
      clearSelectedTrackId: true,
    );
    return TrackStatisticsRecalcResult(
      updatedCount: recalcUpdatedCount,
      skippedCount: recalcSkippedCount,
      warning: recalcWarning,
    );
  }

  @override
  bool consumeRecoverySnackbarSignal() {
    if (!state.hasTrackRecoveryIssue || _snackbarConsumed) {
      return false;
    }
    _snackbarConsumed = true;
    return true;
  }

  @override
  String? consumeTrackSnackbarMessage() {
    final message = _trackSnackbarMessage;
    _trackSnackbarMessage = null;
    return message;
  }

  @override
  String? consumeStartupBackfillWarningMessage() {
    final message = _startupBackfillWarningMessage;
    _startupBackfillWarningMessage = null;
    return message;
  }
}
