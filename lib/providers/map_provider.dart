import 'dart:io' as io;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/import_path_helpers.dart';
import 'package:peak_bagger/services/import/gpx_track_import_models.dart';
import 'package:peak_bagger/services/gpx_track_repair_service.dart';
import 'package:peak_bagger/services/gpx_track_statistics_calculator.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peak_refresh_result.dart';
import 'package:peak_bagger/services/peak_refresh_service.dart';
import 'package:peak_bagger/services/peak_info_content_resolver.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/track_peak_correlation_service.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/services/grid_reference_parser.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:xml/xml.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_correlation_settings_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/main.dart';
import 'package:peak_bagger/providers/peak_provider.dart';

import '../core/constants.dart';

export 'package:peak_bagger/services/peak_info_content_resolver.dart';

const _distance = Distance();

const _latKey = 'map_position_lat';
const _lngKey = 'map_position_lng';
const _zoomKey = 'map_zoom';
const _peakListSelectionModeKey = 'peak_list_selection_mode';
const _peakListIdKey = 'peak_list_id';

enum Basemap { tasmapTopo, tasmap50k, tasmap25k, tracestrack, openstreetmap }

enum TasmapDisplayMode { overlay, none, selectedMap }

enum PeakListSelectionMode { none, allPeaks, specificList }

enum EndDrawerMode { basemaps, peakLists }

enum PendingCameraSelectionBehavior { preserve, replace, clear }

class PendingCameraRequest {
  const PendingCameraRequest({
    required this.center,
    required this.zoom,
    required this.serial,
    this.selectedLocationBehavior = PendingCameraSelectionBehavior.preserve,
    this.selectedLocation,
    this.selectedPeaksBehavior = PendingCameraSelectionBehavior.preserve,
    this.selectedPeaks = const [],
    this.persist = true,
    this.clearGotoMgrs = false,
    this.clearHoveredPeakId = true,
    this.clearHoveredTrackId = true,
  });

  final LatLng center;
  final double zoom;
  final int serial;
  final PendingCameraSelectionBehavior selectedLocationBehavior;
  final LatLng? selectedLocation;
  final PendingCameraSelectionBehavior selectedPeaksBehavior;
  final List<Peak> selectedPeaks;
  final bool persist;
  final bool clearGotoMgrs;
  final bool clearHoveredPeakId;
  final bool clearHoveredTrackId;

  PendingCameraRequest copyWith({
    LatLng? center,
    double? zoom,
    int? serial,
    PendingCameraSelectionBehavior? selectedLocationBehavior,
    LatLng? selectedLocation,
    PendingCameraSelectionBehavior? selectedPeaksBehavior,
    List<Peak>? selectedPeaks,
    bool? persist,
    bool? clearGotoMgrs,
    bool? clearHoveredPeakId,
    bool? clearHoveredTrackId,
  }) {
    return PendingCameraRequest(
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      serial: serial ?? this.serial,
      selectedLocationBehavior:
          selectedLocationBehavior ?? this.selectedLocationBehavior,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      selectedPeaksBehavior:
          selectedPeaksBehavior ?? this.selectedPeaksBehavior,
      selectedPeaks: selectedPeaks ?? this.selectedPeaks,
      persist: persist ?? this.persist,
      clearGotoMgrs: clearGotoMgrs ?? this.clearGotoMgrs,
      clearHoveredPeakId: clearHoveredPeakId ?? this.clearHoveredPeakId,
      clearHoveredTrackId: clearHoveredTrackId ?? this.clearHoveredTrackId,
    );
  }
}

class MapState {
  final LatLng center;
  final double zoom;
  final Basemap basemap;
  final bool isFirstLaunch;
  final bool isLoading;
  final String? error;
  final String currentMgrs;
  final String? cursorMgrs;
  final String? gotoMgrs;
  final bool showGotoInput;
  final bool showPeakSearch;
  final bool showInfoPopup;
  final String? infoMapName;
  final String? infoMgrs;
  final String? infoPeakName;
  final double? infoPeakElevation;
  final LatLng? selectedLocation;
  final bool syncEnabled;
  final List<Peak> peaks;
  final bool isLoadingPeaks;
  final List<Peak> searchResults;
  final String searchQuery;
  final List<Peak> selectedPeaks;
  final Tasmap50k? selectedMap;
  final TasmapDisplayMode tasmapDisplayMode;
  final List<Tasmap50k> mapSuggestions;
  final String mapSearchQuery;
  final int selectedMapFocusSerial;
  final int selectedTrackFocusSerial;
  final List<GpxTrack> tracks;
  final bool showTracks;
  final PeakListSelectionMode peakListSelectionMode;
  final int? selectedPeakListId;
  final EndDrawerMode endDrawerMode;
  final bool isLoadingTracks;
  final String? trackImportError;
  final bool hasTrackRecoveryIssue;
  final String? trackOperationStatus;
  final String? trackOperationWarning;
  final int? hoveredPeakId;
  final PeakInfoContent? peakInfo;
  final int? hoveredTrackId;
  final int? selectedTrackId;
  final PendingCameraRequest? pendingCameraRequest;
  final int cameraRequestSerial;

  const MapState({
    required this.center,
    required this.zoom,
    required this.basemap,
    this.isFirstLaunch = true,
    this.isLoading = false,
    this.error,
    this.currentMgrs = '55G FN\n00000 00000',
    this.cursorMgrs,
    this.gotoMgrs,
    this.showGotoInput = false,
    this.showPeakSearch = false,
    this.showInfoPopup = false,
    this.infoMapName,
    this.infoMgrs,
    this.infoPeakName,
    this.infoPeakElevation,
    this.selectedLocation,
    this.syncEnabled = true,
    this.peaks = const [],
    this.isLoadingPeaks = false,
    this.searchResults = const [],
    this.searchQuery = '',
    this.selectedPeaks = const [],
    this.selectedMap,
    this.tasmapDisplayMode = TasmapDisplayMode.none,
    this.mapSuggestions = const [],
    this.mapSearchQuery = '',
    this.selectedMapFocusSerial = 0,
    this.selectedTrackFocusSerial = 0,
    this.tracks = const [],
    this.showTracks = false,
    this.peakListSelectionMode = PeakListSelectionMode.allPeaks,
    this.selectedPeakListId,
    this.endDrawerMode = EndDrawerMode.basemaps,
    this.isLoadingTracks = false,
    this.trackImportError,
    this.hasTrackRecoveryIssue = false,
    this.trackOperationStatus,
    this.trackOperationWarning,
    this.hoveredPeakId,
    this.peakInfo,
    this.hoveredTrackId,
    this.selectedTrackId,
    this.pendingCameraRequest,
    this.cameraRequestSerial = 0,
  });

  Peak? get peakInfoPeak => peakInfo?.peak;

  bool get showMapOverlay => tasmapDisplayMode == TasmapDisplayMode.overlay;

  bool get showSelectedMapLayer =>
      tasmapDisplayMode == TasmapDisplayMode.selectedMap && selectedMap != null;

  bool get showPeaks => peakListSelectionMode != PeakListSelectionMode.none;

  LatLng? get cameraRequestCenter => pendingCameraRequest?.center;

  double? get cameraRequestZoom => pendingCameraRequest?.zoom;

  MapState copyWith({
    LatLng? center,
    double? zoom,
    Basemap? basemap,
    bool? isFirstLaunch,
    bool? isLoading,
    String? error,
    String? currentMgrs,
    String? cursorMgrs,
    String? gotoMgrs,
    bool? showGotoInput,
    bool? showPeakSearch,
    bool? showInfoPopup,
    String? infoMapName,
    String? infoMgrs,
    String? infoPeakName,
    double? infoPeakElevation,
    bool clearInfoPopup = false,
    LatLng? selectedLocation,
    bool clearSelectedLocation = false,
    bool? syncEnabled,
    List<Peak>? peaks,
    bool? isLoadingPeaks,
    List<Peak>? searchResults,
    String? searchQuery,
    List<Peak>? selectedPeaks,
    Tasmap50k? selectedMap,
    TasmapDisplayMode? tasmapDisplayMode,
    List<Tasmap50k>? mapSuggestions,
    String? mapSearchQuery,
    int? selectedMapFocusSerial,
    int? selectedTrackFocusSerial,
    List<GpxTrack>? tracks,
    bool? showTracks,
    PeakListSelectionMode? peakListSelectionMode,
    int? selectedPeakListId,
    bool clearSelectedPeakListId = false,
    EndDrawerMode? endDrawerMode,
    bool? isLoadingTracks,
    String? trackImportError,
    bool clearTrackImportError = false,
    bool? hasTrackRecoveryIssue,
    String? trackOperationStatus,
    bool clearTrackOperationStatus = false,
    String? trackOperationWarning,
    bool clearTrackOperationWarning = false,
    int? hoveredPeakId,
    bool clearHoveredPeakId = false,
    PeakInfoContent? peakInfo,
    bool clearPeakInfoPopup = false,
    int? hoveredTrackId,
    bool clearHoveredTrackId = false,
    int? selectedTrackId,
    bool clearSelectedTrackId = false,
    PendingCameraRequest? pendingCameraRequest,
    int? cameraRequestSerial,
    bool clearPendingCameraRequest = false,
    bool clearCursorMgrs = false,
    bool clearError = false,
    bool clearGotoMgrs = false,
  }) {
    return MapState(
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      basemap: basemap ?? this.basemap,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      currentMgrs: currentMgrs ?? this.currentMgrs,
      cursorMgrs: clearCursorMgrs ? null : (cursorMgrs ?? this.cursorMgrs),
      gotoMgrs: clearGotoMgrs ? null : (gotoMgrs ?? this.gotoMgrs),
      showGotoInput: showGotoInput ?? this.showGotoInput,
      showPeakSearch: showPeakSearch ?? this.showPeakSearch,
      showInfoPopup: clearInfoPopup
          ? false
          : (showInfoPopup ?? this.showInfoPopup),
      infoMapName: clearInfoPopup ? null : (infoMapName ?? this.infoMapName),
      infoMgrs: clearInfoPopup ? null : (infoMgrs ?? this.infoMgrs),
      infoPeakName: clearInfoPopup ? null : (infoPeakName ?? this.infoPeakName),
      infoPeakElevation: clearInfoPopup
          ? null
          : (infoPeakElevation ?? this.infoPeakElevation),
      selectedLocation: clearSelectedLocation
          ? null
          : (selectedLocation ?? this.selectedLocation),
      syncEnabled: syncEnabled ?? this.syncEnabled,
      peaks: peaks ?? this.peaks,
      isLoadingPeaks: isLoadingPeaks ?? this.isLoadingPeaks,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedPeaks: selectedPeaks ?? this.selectedPeaks,
      selectedMap: selectedMap ?? this.selectedMap,
      tasmapDisplayMode: tasmapDisplayMode ?? this.tasmapDisplayMode,
      mapSuggestions: mapSuggestions ?? this.mapSuggestions,
      mapSearchQuery: mapSearchQuery ?? this.mapSearchQuery,
      selectedMapFocusSerial:
          selectedMapFocusSerial ?? this.selectedMapFocusSerial,
      selectedTrackFocusSerial:
          selectedTrackFocusSerial ?? this.selectedTrackFocusSerial,
      tracks: tracks ?? this.tracks,
      showTracks: showTracks ?? this.showTracks,
      peakListSelectionMode:
          peakListSelectionMode ?? this.peakListSelectionMode,
      selectedPeakListId: clearSelectedPeakListId
          ? null
          : (selectedPeakListId ?? this.selectedPeakListId),
      endDrawerMode: endDrawerMode ?? this.endDrawerMode,
      isLoadingTracks: isLoadingTracks ?? this.isLoadingTracks,
      trackImportError: clearTrackImportError
          ? null
          : (trackImportError ?? this.trackImportError),
      hasTrackRecoveryIssue:
          hasTrackRecoveryIssue ?? this.hasTrackRecoveryIssue,
      trackOperationStatus: clearTrackOperationStatus
          ? null
          : (trackOperationStatus ?? this.trackOperationStatus),
      trackOperationWarning: clearTrackOperationWarning
          ? null
          : (trackOperationWarning ?? this.trackOperationWarning),
      hoveredPeakId: clearHoveredPeakId
          ? null
          : (hoveredPeakId ?? this.hoveredPeakId),
      peakInfo: clearPeakInfoPopup ? null : (peakInfo ?? this.peakInfo),
      hoveredTrackId: clearHoveredTrackId
          ? null
          : (hoveredTrackId ?? this.hoveredTrackId),
      selectedTrackId: clearSelectedTrackId
          ? null
          : (selectedTrackId ?? this.selectedTrackId),
      pendingCameraRequest: clearPendingCameraRequest
          ? null
          : (pendingCameraRequest ?? this.pendingCameraRequest),
      cameraRequestSerial: cameraRequestSerial ?? this.cameraRequestSerial,
    );
  }
}

final mapProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);

final gpxTrackRepositoryProvider = Provider<GpxTrackRepository>((ref) {
  return GpxTrackRepository(objectboxStore);
});

Set<int> buildCorrelatedPeakIds(Iterable<GpxTrack> tracks) {
  final ids = <int>{};

  for (final track in tracks) {
    if (!track.peakCorrelationProcessed) {
      continue;
    }

    for (final peak in track.peaks) {
      if (peak.osmId != 0) {
        ids.add(peak.osmId);
      }
    }
  }

  return ids;
}

class MapNotifier extends Notifier<MapState> {
  MapNotifier({
    PeakRepository? peakRepository,
    OverpassService? overpassService,
    TasmapRepository? tasmapRepository,
    GpxTrackRepository? gpxTrackRepository,
    PeaksBaggedRepository? peaksBaggedRepository,
    MigrationMarkerStore? migrationMarkerStore,
    bool loadPositionOnBuild = true,
    bool loadPeaksOnBuild = true,
    bool loadTracksOnBuild = true,
  }) : _injectedPeakRepository = peakRepository,
       _injectedOverpassService = overpassService,
       _injectedTasmapRepository = tasmapRepository,
       _injectedGpxTrackRepository = gpxTrackRepository,
       _injectedPeaksBaggedRepository = peaksBaggedRepository,
       _injectedMigrationMarkerStore = migrationMarkerStore,
       _loadPositionOnBuild = loadPositionOnBuild,
       _loadPeaksOnBuild = loadPeaksOnBuild,
       _loadTracksOnBuild = loadTracksOnBuild;

  final PeakRepository? _injectedPeakRepository;
  final OverpassService? _injectedOverpassService;
  final TasmapRepository? _injectedTasmapRepository;
  final GpxTrackRepository? _injectedGpxTrackRepository;
  final PeaksBaggedRepository? _injectedPeaksBaggedRepository;
  final MigrationMarkerStore? _injectedMigrationMarkerStore;
  final bool _loadPositionOnBuild;
  final bool _loadPeaksOnBuild;
  final bool _loadTracksOnBuild;

  late final PeakRepository _peakRepository;
  late final PeakRefreshService _peakRefreshService;
  late final TasmapRepository _tasmapRepository;
  late final GpxTrackRepository _gpxTrackRepository;
  late final PeaksBaggedRepository _peaksBaggedRepository;
  late final MigrationMarkerStore _migrationMarkerStore;
  bool _recoverySnackbarShown = false;
  String? _pendingTrackSnackbarMessage;
  String? _pendingStartupBackfillWarningMessage;
  Set<int> get correlatedPeakIds => buildCorrelatedPeakIds(state.tracks);

  @override
  MapState build() {
    _peakRepository =
        _injectedPeakRepository ?? ref.read(peakRepositoryProvider);
    _peakRefreshService = PeakRefreshService(
      _injectedOverpassService ?? ref.read(overpassServiceProvider),
      _peakRepository,
    );
    _tasmapRepository =
        _injectedTasmapRepository ?? ref.read(tasmapRepositoryProvider);
    _gpxTrackRepository =
        _injectedGpxTrackRepository ?? GpxTrackRepository(objectboxStore);
    _peaksBaggedRepository =
        _injectedPeaksBaggedRepository ?? PeaksBaggedRepository(objectboxStore);
    _migrationMarkerStore =
        _injectedMigrationMarkerStore ?? const MigrationMarkerStore();
    if (_loadPositionOnBuild) {
      _loadPosition();
    }
    if (_loadPeaksOnBuild) {
      Future.microtask(() => _loadPeaks());
    }
    if (_loadTracksOnBuild) {
      Future.microtask(() => _loadTracks());
    }
    return MapState(
      center: MapConstants.defaultCenter,
      zoom: MapConstants.defaultZoom,
      basemap: Basemap.tracestrack,
      isFirstLaunch: true,
      selectedLocation: MapConstants.defaultCenter,
    );
  }

  Future<void> _loadPeaks() async {
    if (_peakRepository.isEmpty()) {
      state = state.copyWith(isLoadingPeaks: true);
      try {
        await _peakRefreshService.refreshPeaks();
        ref.read(peakRevisionProvider.notifier).increment();
        state = state.copyWith(
          peaks: _peakRepository.getAllPeaks(),
          isLoadingPeaks: false,
          clearError: true,
        );
      } catch (e) {
        state = state.copyWith(
          isLoadingPeaks: false,
          error: 'Failed to load peaks: $e',
        );
      }
    } else {
      final changed = await _peakRefreshService.backfillStoredPeaks();
      if (changed) {
        ref.read(peakRevisionProvider.notifier).increment();
      }
      state = state.copyWith(peaks: _peakRepository.getAllPeaks());
    }
  }

  Future<void> _loadTracks() async {
    final tracks = _gpxTrackRepository.getAllTracks();
    final migrationMarked = await _migrationMarkerStore.isMarked();
    final hasRecoveryIssue = _hasTrackRecoveryIssue(tracks);
    final decision = MigrationMarkerStore.decideStartupAction(
      migrationMarked: migrationMarked,
      hasPersistedTracks: tracks.isNotEmpty,
      hasRecoveryIssue: hasRecoveryIssue,
    );

    if (decision.markMigrationComplete) {
      await _migrationMarkerStore.markComplete();
    }

    switch (decision.action) {
      case TrackStartupAction.wipeAndImport:
        _gpxTrackRepository.deleteAll();
        state = state.copyWith(
          tracks: const [],
          showTracks: false,
          hasTrackRecoveryIssue: false,
          clearHoveredTrackId: true,
          clearSelectedTrackId: true,
        );
        await _importTracks(
          includeTasmaniaFolder: true,
          syncPeaksBagged: true,
          markPeaksBaggedBackfillComplete: true,
        );
        return;
      case TrackStartupAction.importTracks:
        await _importTracks(
          includeTasmaniaFolder: true,
          syncPeaksBagged: true,
          markPeaksBaggedBackfillComplete: true,
        );
        return;
      case TrackStartupAction.showRecovery:
        if (!state.hasTrackRecoveryIssue) {
          _recoverySnackbarShown = false;
        }
        _refreshCorrelatedPeakIds(tracks);
        state = state.copyWith(
          tracks: tracks,
          showTracks: false,
          hasTrackRecoveryIssue: true,
          clearHoveredTrackId: true,
          clearSelectedTrackId: true,
        );
        await _maybeBackfillPeaksBaggedOnStartup(tracks);
        return;
      case TrackStartupAction.loadTracks:
        _refreshCorrelatedPeakIds(tracks);
        state = state.copyWith(
          tracks: tracks,
          showTracks: true,
          hasTrackRecoveryIssue: false,
          clearHoveredTrackId: true,
          clearSelectedTrackId: true,
        );
        await _maybeBackfillPeaksBaggedOnStartup(tracks);
        return;
    }
  }

  Future<void> _maybeBackfillPeaksBaggedOnStartup(List<GpxTrack> tracks) async {
    if (tracks.isEmpty) {
      return;
    }
    if (await _migrationMarkerStore.isPeaksBaggedBackfillMarked()) {
      _pendingStartupBackfillWarningMessage = null;
      return;
    }

    try {
      await _peaksBaggedRepository.rebuildFromTracks(tracks);
      await _migrationMarkerStore.markPeaksBaggedBackfillComplete();
      _pendingStartupBackfillWarningMessage = null;
      state = state.copyWith(clearTrackImportError: true);
    } catch (e) {
      _pendingStartupBackfillWarningMessage =
          'Bagged history is stale. Open Settings to rebuild it.';
      state = state.copyWith(
        trackImportError:
            'Failed to rebuild bagged peak history from stored tracks: $e',
      );
    }
  }

  bool _hasTrackRecoveryIssue(List<GpxTrack> tracks) {
    for (final track in tracks) {
      if (!track.hasValidOptimizedDisplayData()) {
        return true;
      }
      if (track.contentHash.isEmpty || track.trackDate == null) {
        return true;
      }
    }
    return false;
  }

  Future<TrackImportResult?> _importTracks({
    required bool includeTasmaniaFolder,
    bool resetExisting = false,
    bool refreshExistingTracks = false,
    bool syncPeaksBagged = false,
    bool markPeaksBaggedBackfillComplete = false,
  }) async {
    if (state.isLoadingTracks) {
      return null;
    }

    state = state.copyWith(
      isLoadingTracks: true,
      clearTrackImportError: true,
      clearTrackOperationStatus: true,
      clearTrackOperationWarning: true,
      clearHoveredTrackId: true,
      clearSelectedTrackId: true,
    );

    try {
      final existingTracks = resetExisting
          ? const <GpxTrack>[]
          : _gpxTrackRepository.getAllTracks();
      final existingTracksById = {
        for (final track in existingTracks)
          if (track.gpxTrackId != 0) track.gpxTrackId: _cloneTrack(track),
      };
      final surfaceNotifications = resetExisting || state.tracks.isNotEmpty;
      final importer = GpxImporter();
      final filterConfig = await ref.read(gpxFilterSettingsProvider.future);
      final result = await importer.importTracks(
        includeTasmaniaFolder: includeTasmaniaFolder,
        existingTracks: existingTracks,
        surfaceWarnings: surfaceNotifications,
        resetIds: resetExisting,
        refreshExistingTracks: refreshExistingTracks,
        filterConfig: filterConfig,
      );

      final thresholdMeters = await _peakCorrelationThresholdMeters();
      final correlatedTracks = <GpxTrack>[];
      final correlationService = TrackPeakCorrelationService(
        peaks: _peakRepository.getAllPeaks(),
        thresholdMeters: thresholdMeters,
      );

      for (final track in result.tracks) {
        final originalTrack = existingTracksById[track.gpxTrackId];
        try {
          _applyPeakCorrelation(
            track,
            correlationService,
            track.gpxFileRepaired.isNotEmpty
                ? track.gpxFileRepaired
                : track.gpxFile,
          );
          correlatedTracks.add(track);
        } catch (_) {
          if (originalTrack != null) {
            correlatedTracks.add(originalTrack);
          }
        }
      }

      if (resetExisting || state.tracks.isEmpty) {
        _gpxTrackRepository.deleteAll();
      }

      for (final track in correlatedTracks) {
        _gpxTrackRepository.putTrack(track);
      }

      final allTracks = _gpxTrackRepository.getAllTracks();
      if (syncPeaksBagged) {
        await _peaksBaggedRepository.rebuildFromTracks(allTracks);
        ref.read(peaksBaggedRevisionProvider.notifier).increment();
        if (markPeaksBaggedBackfillComplete) {
          await _migrationMarkerStore.markPeaksBaggedBackfillComplete();
        }
        _pendingStartupBackfillWarningMessage = null;
      }
      _refreshCorrelatedPeakIds(allTracks);
      final hasRecoveryIssue = _hasTrackRecoveryIssue(allTracks);
      if (hasRecoveryIssue && !state.hasTrackRecoveryIssue) {
        _recoverySnackbarShown = false;
      }
      final statusMessage = result.noGpxFilesFound
          ? 'No GPX files found in watched folder'
          : 'Imported ${result.importedCount}, replaced ${result.replacedCount}, unchanged ${result.unchangedCount}, non-Tasmanian ${result.nonTasmanianCount}, errors ${result.errorSkippedCount}';
      if (surfaceNotifications) {
        _pendingTrackSnackbarMessage = statusMessage;
      }
      state = state.copyWith(
        tracks: allTracks,
        showTracks: hasRecoveryIssue
            ? false
            : (resetExisting
                  ? false
                  : state.showTracks || allTracks.isNotEmpty),
        isLoadingTracks: false,
        hasTrackRecoveryIssue: hasRecoveryIssue,
        trackOperationStatus: statusMessage,
        trackOperationWarning: result.warning,
        clearHoveredTrackId: true,
        clearSelectedTrackId: true,
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoadingTracks: false,
        trackImportError: 'Failed to import tracks: $e',
        clearHoveredTrackId: true,
        clearSelectedTrackId: true,
      );
      return null;
    }
  }

  Future<void> rescanTracks() async {
    if (state.hasTrackRecoveryIssue) {
      return;
    }
    await _importTracks(
      includeTasmaniaFolder: true,
      refreshExistingTracks: true,
    );
  }

  Future<GpxTrackImportResult> importGpxFiles({
    required Map<String, String> pathToEditedNames,
  }) async {
    if (state.isLoadingTracks) {
      throw Exception('Import already in progress');
    }

    state = state.copyWith(
      isLoadingTracks: true,
      clearTrackOperationStatus: true,
      clearTrackOperationWarning: true,
    );

    try {
      final existingTracks = _gpxTrackRepository.getAllTracks();
      final existingContentHashes = existingTracks
          .map((t) => t.contentHash)
          .where((h) => h.isNotEmpty)
          .toSet();

      final importer = GpxImporter();
      final plan = importer.planSelectiveImport(
        paths: pathToEditedNames.keys.toList(),
        pathToEditedNames: pathToEditedNames,
        existingContentHashes: existingContentHashes,
      );

      // Apply filter config
      final filterConfig = await ref.read(gpxFilterSettingsProvider.future);

      // Apply processing to each planned track
      for (final item in plan.items) {
        final selection = importer.selectionForTrack(item.track);
        final processed = importer.processTrack(
          selection.xml,
          filterConfig: filterConfig,
        );
        importer.applyProcessedTrackResult(item.track, processed);
      }

      // Persist tracks additively
      final addedItems = <GpxTrackImportItem>[];
      for (final item in plan.items) {
        // Apply peak correlation
        try {
          final thresholdMeters = await _peakCorrelationThresholdMeters();
          final correlationService = TrackPeakCorrelationService(
            peaks: _peakRepository.getAllPeaks(),
            thresholdMeters: thresholdMeters,
          );
          _applyPeakCorrelation(
            item.track,
            correlationService,
            item.track.gpxFileRepaired.isNotEmpty
                ? item.track.gpxFileRepaired
                : item.track.gpxFile,
          );
        } catch (_) {
          // Correlation failed, but track is still valid - count as added
        }

        // Persist track
        _gpxTrackRepository.putTrack(item.track);
        addedItems.add(
          GpxTrackImportItem(
            track: item.track,
            managedRelativePath: item.plannedManagedRelativePath,
            managedPlacementPending: true,
          ),
        );
      }

      // Move files to managed storage
      for (final item in plan.items) {
        if (item.shouldPlaceInManagedStorage &&
            item.plannedManagedRelativePath != null) {
          try {
            await _placeFileInManagedStorage(
              sourcePath: item.sourcePath,
              relativePath: item.plannedManagedRelativePath!,
              track: item.track,
            );
          } catch (_) {
            // Placement failed - track is persisted, recovery is pending
          }
        }
      }

      // Refresh tracks from repository
      final allTracks = _gpxTrackRepository.getAllTracks();

      final selectedImportedTrack = addedItems.isNotEmpty
          ? addedItems.first.track
          : null;

      // Set showTracks to true if we added any tracks
      final showTracks = state.showTracks || addedItems.isNotEmpty;

      state = state.copyWith(
        tracks: allTracks,
        showTracks: showTracks,
        selectedTrackId: selectedImportedTrack?.gpxTrackId ?? state.selectedTrackId,
        selectedTrackFocusSerial: selectedImportedTrack == null
            ? state.selectedTrackFocusSerial
            : state.selectedTrackFocusSerial + 1,
        isLoadingTracks: false,
        clearHoveredTrackId: true,
      );

      return GpxTrackImportResult(
        items: addedItems,
        addedCount: addedItems.length,
        unchangedCount: plan.unchangedCount,
        nonTasmanianCount: plan.nonTasmanianCount,
        errorCount: plan.errorCount,
        warningMessage: plan.warningMessage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingTracks: false,
        clearHoveredTrackId: true,
      );
      rethrow;
    }
  }

  Future<void> _placeFileInManagedStorage({
    required String sourcePath,
    required String relativePath,
    required GpxTrack track,
  }) async {
    final root = resolveBushwalkingRoot();
    final targetPath = '$root${io.Platform.pathSeparator}$relativePath';
    final targetDir = io.Directory(root).parent;

    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    final targetFile = io.File(targetPath);
    if (targetFile.existsSync()) {
      // Add suffix for collision
      var suffix = 1;
      var newPath = targetPath;
      while (io.File(newPath).existsSync()) {
        final baseName = track.trackName.replaceAll(RegExp(r'[^\w\s-]'), '');
        newPath =
            '$root${io.Platform.pathSeparator}Tracks${io.Platform.pathSeparator}Tasmania${io.Platform.pathSeparator}${baseName}_$suffix.gpx';
        suffix++;
      }
      await io.File(sourcePath).rename(newPath);
      track.managedRelativePath = newPath.substring(root.length + 1);
    } else {
      await io.File(sourcePath).rename(targetPath);
      track.managedRelativePath = relativePath;
    }

    track.managedPlacementPending = false;
    _gpxTrackRepository.putTrack(track);
  }

  Future<TrackImportResult?> resetTrackData() async {
    final result = await _importTracks(
      includeTasmaniaFolder: true,
      resetExisting: true,
      syncPeaksBagged: true,
      markPeaksBaggedBackfillComplete: true,
    );
    if (result == null) {
      return null;
    }

    state = state.copyWith(showTracks: false, clearHoveredTrackId: true);
    if (!state.hasTrackRecoveryIssue) {
      _recoverySnackbarShown = false;
    }
    return result;
  }

  Future<TrackStatisticsRecalcResult?> recalculateTrackStatistics() async {
    if (state.isLoadingTracks) {
      return null;
    }

    state = state.copyWith(
      isLoadingTracks: true,
      clearTrackImportError: true,
      clearTrackOperationStatus: true,
      clearTrackOperationWarning: true,
      clearHoveredTrackId: true,
      clearSelectedTrackId: true,
    );

    try {
      final thresholdMeters = await _peakCorrelationThresholdMeters();
      final correlationService = TrackPeakCorrelationService(
        peaks: _peakRepository.getAllPeaks(),
        thresholdMeters: thresholdMeters,
      );
      final importer = GpxImporter();
      final repairService = GpxTrackRepairService();
      final filterConfig = await ref.read(gpxFilterSettingsProvider.future);
      final tracks = _gpxTrackRepository.getAllTracks();
      var updatedCount = 0;
      var skippedCount = 0;
      var filterFallbackCount = 0;

      for (final track in tracks) {
        try {
          final replacementTrack = _cloneTrack(track);
          final processingXml = _processingXmlForTrack(
            replacementTrack,
            repairService,
          );
          final processed = importer.processTrack(
            processingXml,
            filterConfig: filterConfig,
          );
          _applyProcessingResult(replacementTrack, processed);
          filterFallbackCount += processed.usedRawFallback ? 1 : 0;
          _applyPeakCorrelation(
            replacementTrack,
            correlationService,
            processingXml,
          );
          _gpxTrackRepository.replaceTrack(
            existing: track,
            replacement: replacementTrack,
          );
          updatedCount += 1;
        } catch (_) {
          skippedCount += 1;
        }
      }

      final refreshedTracks = _gpxTrackRepository.getAllTracks();
      try {
        await _peaksBaggedRepository.syncFromTracks(refreshedTracks);
        ref.read(peaksBaggedRevisionProvider.notifier).increment();
        await _migrationMarkerStore.markPeaksBaggedBackfillComplete();
        _pendingStartupBackfillWarningMessage = null;
      } catch (e) {
        _refreshCorrelatedPeakIds(refreshedTracks);
        final hasRecoveryIssue = _hasTrackRecoveryIssue(refreshedTracks);
        state = state.copyWith(
          tracks: refreshedTracks,
          showTracks: state.showTracks,
          isLoadingTracks: false,
          hasTrackRecoveryIssue: hasRecoveryIssue,
          trackImportError:
              'Track statistics were updated, but bagged history is stale: $e',
          clearTrackOperationStatus: true,
          clearTrackOperationWarning: true,
          clearHoveredTrackId: true,
          clearSelectedTrackId: true,
        );
        return null;
      }
      _refreshCorrelatedPeakIds(refreshedTracks);
      final warning = skippedCount > 0
          ? _buildRecalcWarning(
              skippedCount: skippedCount,
              filterFallbackCount: filterFallbackCount,
            )
          : null;
      final hasRecoveryIssue = _hasTrackRecoveryIssue(refreshedTracks);
      final statusMessage =
          'Updated $updatedCount tracks, refreshed peak correlation, skipped $skippedCount tracks';

      state = state.copyWith(
        tracks: refreshedTracks,
        showTracks: state.showTracks,
        isLoadingTracks: false,
        hasTrackRecoveryIssue: hasRecoveryIssue,
        trackOperationStatus: statusMessage,
        trackOperationWarning: warning,
        clearHoveredTrackId: true,
        clearSelectedTrackId: true,
      );
      return TrackStatisticsRecalcResult(
        updatedCount: updatedCount,
        skippedCount: skippedCount,
        warning: warning,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingTracks: false,
        trackImportError: 'Failed to recalculate track statistics: $e',
        clearHoveredTrackId: true,
        clearSelectedTrackId: true,
      );
      return null;
    }
  }

  String _processingXmlForTrack(
    GpxTrack track,
    GpxTrackRepairService repairService,
  ) {
    if (track.gpxFileRepaired.isNotEmpty) {
      return track.gpxFileRepaired;
    }

    final repairResult = repairService.analyzeAndRepair(track.gpxFile);
    if (repairResult.repairPerformed ||
        _hasInterpolatedSegmentInXml(track.gpxFile)) {
      track.gpxFileRepaired = repairResult.repairedXml;
      return repairResult.repairedXml;
    }

    return track.gpxFile;
  }

  void _applyProcessingResult(GpxTrack track, GpxTrackProcessingResult result) {
    track.filteredTrack = result.filteredXml ?? '';
    track.displayTrackPointsByZoom = TrackDisplayCacheBuilder.buildJson(
      result.displaySegments,
    );
    track.startDateTime = result.stats.startDateTime;
    track.endDateTime = result.stats.endDateTime;
    track.distance2d = result.stats.distance2d;
    track.distance3d = result.stats.distance3d;
    track.distanceToPeak = result.stats.distanceToPeak;
    track.distanceFromPeak = result.stats.distanceFromPeak;
    track.lowestElevation = result.stats.lowestElevation;
    track.highestElevation = result.stats.highestElevation;
    track.ascent = result.stats.ascent;
    track.descent = result.stats.descent;
    track.startElevation = result.stats.startElevation;
    track.endElevation = result.stats.endElevation;
    track.elevationProfile = result.stats.elevationProfile;
    track.totalTimeMillis = result.stats.totalTimeMillis;
    track.movingTime = result.stats.movingTime;
    track.restingTime = result.stats.restingTime;
    track.pausedTime = result.stats.pausedTime;
  }

  void _applyPeakCorrelation(
    GpxTrack track,
    TrackPeakCorrelationService correlationService,
    String correlationXml,
  ) {
    final matches = correlationService.matchPeaks(correlationXml);
    track.peaks.clear();
    track.peaks.addAll(matches);
    track.peakCorrelationProcessed = true;
  }

  Future<int> _peakCorrelationThresholdMeters() async {
    try {
      return await ref.read(peakCorrelationSettingsProvider.future);
    } catch (_) {
      return peakCorrelationDefaultDistanceMeters;
    }
  }

  GpxTrack _cloneTrack(GpxTrack track) {
    final clone = GpxTrack.fromMap(track.toMap());
    clone.peaks.addAll(track.peaks);
    return clone;
  }

  bool _hasInterpolatedSegmentInXml(String xml) {
    try {
      final document = XmlDocument.parse(xml);
      return document.findAllElements('trkseg').any((segment) {
        final typeElement = segment.getElement('type');
        return typeElement != null &&
            typeElement.innerText.trim().toLowerCase() == 'interpolated';
      });
    } catch (_) {
      return false;
    }
  }

  String _buildRecalcWarning({
    required int skippedCount,
    required int filterFallbackCount,
  }) {
    final parts = <String>[];
    if (skippedCount > 0) {
      parts.add(
        'Some tracks could not be recalculated, so their previous statistics and peak correlation were kept.',
      );
    }
    if (filterFallbackCount > 0) {
      parts.add('Some tracks used raw GPX fallback during filtering.');
    }
    return parts.join(' ');
  }

  bool consumeRecoverySnackbarSignal() {
    if (!state.hasTrackRecoveryIssue || _recoverySnackbarShown) {
      return false;
    }
    _recoverySnackbarShown = true;
    return true;
  }

  String? consumeTrackSnackbarMessage() {
    final message = _pendingTrackSnackbarMessage;
    _pendingTrackSnackbarMessage = null;
    return message;
  }

  String? consumeStartupBackfillWarningMessage() {
    final message = _pendingStartupBackfillWarningMessage;
    _pendingStartupBackfillWarningMessage = null;
    return message;
  }

  Future<void> _loadPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_latKey);
      final lng = prefs.getDouble(_lngKey);
      final zoom = prefs.getDouble(_zoomKey);
      final peakListSelectionMode = _parsePeakListSelectionMode(
        prefs.getString(_peakListSelectionModeKey),
      );
      final selectedPeakListId = prefs.getInt(_peakListIdKey);

      if (lat != null && lng != null && zoom != null) {
        final location = LatLng(lat, lng);
        state = state.copyWith(
          center: location,
          zoom: zoom,
          isFirstLaunch: false,
          currentMgrs: _convertToMgrs(location),
          selectedLocation: location,
        );
      }

      state = state.copyWith(
        peakListSelectionMode: peakListSelectionMode,
        selectedPeakListId: selectedPeakListId,
        clearSelectedPeakListId:
            peakListSelectionMode != PeakListSelectionMode.specificList,
      );
      reconcileSelectedPeakList();
    } catch (e) {
      // Keep default position on error
    }
  }

  String _convertToMgrs(LatLng location) {
    try {
      final mgrsString = mgrs.Mgrs.forward([
        location.longitude,
        location.latitude,
      ], 5);
      if (mgrsString.length >= 10) {
        final firstLine = mgrsString.substring(0, 5);
        final easting = mgrsString.substring(5, 10);
        final northing = mgrsString.substring(10);
        return '$firstLine\n$easting $northing';
      }
      return mgrsString;
    } catch (e) {
      return 'Invalid';
    }
  }

  Future<void> persistCameraPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_latKey, state.center.latitude);
      await prefs.setDouble(_lngKey, state.center.longitude);
      await prefs.setDouble(_zoomKey, state.zoom);
      state = state.copyWith(isFirstLaunch: false);
    } catch (e) {
      // Continue without saving
    }
  }

  Future<void> persistPeakListSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _peakListSelectionModeKey,
        state.peakListSelectionMode.name,
      );
      if (state.peakListSelectionMode == PeakListSelectionMode.specificList &&
          state.selectedPeakListId != null) {
        await prefs.setInt(_peakListIdKey, state.selectedPeakListId!);
      } else {
        await prefs.remove(_peakListIdKey);
      }
    } catch (e) {
      // Continue without saving
    }
  }

  PeakListSelectionMode _parsePeakListSelectionMode(String? value) {
    return switch (value) {
      'none' => PeakListSelectionMode.none,
      'specificList' => PeakListSelectionMode.specificList,
      _ => PeakListSelectionMode.allPeaks,
    };
  }

  void updatePosition(LatLng center, double zoom) {
    state = state.copyWith(
      center: center,
      zoom: zoom,
      currentMgrs: _convertToMgrs(center),
      clearCursorMgrs: true,
      clearHoveredPeakId: true,
      clearHoveredTrackId: true,
      clearPeakInfoPopup: zoom < MapConstants.clearPeakInfo,
    );
  }

  void acceptCameraIntent(PendingCameraRequest request) {
    state = state.copyWith(
      center: request.center,
      zoom: request.zoom,
      currentMgrs: _convertToMgrs(request.center),
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
      syncEnabled: true,
      clearCursorMgrs: true,
      clearGotoMgrs: request.clearGotoMgrs,
      clearHoveredPeakId: request.clearHoveredPeakId,
      clearHoveredTrackId: request.clearHoveredTrackId,
      clearPeakInfoPopup: request.zoom < MapConstants.clearPeakInfo,
    );
  }

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

  void consumeCameraRequest(int serial) {
    if (state.cameraRequestSerial != serial ||
        state.pendingCameraRequest?.serial != serial) {
      return;
    }
    state = state.copyWith(clearPendingCameraRequest: true);
  }

  void setBasemap(Basemap basemap) {
    state = state.copyWith(basemap: basemap);
  }

  void setEndDrawerMode(EndDrawerMode mode) {
    if (state.endDrawerMode == mode) {
      return;
    }
    state = state.copyWith(endDrawerMode: mode);
  }

  void selectPeakList(PeakListSelectionMode mode, {int? peakListId}) {
    if (mode == PeakListSelectionMode.specificList && peakListId == null) {
      return;
    }

    final nextPeakListId = mode == PeakListSelectionMode.specificList
        ? peakListId
        : null;
    if (state.peakListSelectionMode == mode &&
        state.selectedPeakListId == nextPeakListId) {
      return;
    }

    state = state.copyWith(
      peakListSelectionMode: mode,
      selectedPeakListId: nextPeakListId,
      clearSelectedPeakListId: mode != PeakListSelectionMode.specificList,
      clearPeakInfoPopup: true,
      clearHoveredPeakId: true,
    );
    persistPeakListSelection();
  }

  void reconcileSelectedPeakList() {
    if (state.peakListSelectionMode != PeakListSelectionMode.specificList) {
      return;
    }

    final peakListId = state.selectedPeakListId;
    if (peakListId == null) {
      _resetToAllPeaks();
      return;
    }

    final peakList = ref.read(peakListRepositoryProvider).findById(peakListId);
    if (peakList == null) {
      _resetToAllPeaks();
      return;
    }

    try {
      decodePeakListItems(peakList.peakList);
    } catch (_) {
      _resetToAllPeaks();
    }
  }

  void _resetToAllPeaks() {
    state = state.copyWith(
      peakListSelectionMode: PeakListSelectionMode.allPeaks,
      clearSelectedPeakListId: true,
      clearPeakInfoPopup: true,
      clearHoveredPeakId: true,
    );
    persistPeakListSelection();
  }

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

  void clearSelectedLocation() {
    state = state.copyWith(clearSelectedLocation: true);
  }

  void setCursorMgrs(LatLng location) {
    state = state.copyWith(cursorMgrs: _convertToMgrs(location));
  }

  void setSelectedLocation(LatLng location) {
    state = state.copyWith(
      cursorMgrs: _convertToMgrs(location),
      selectedLocation: location,
      syncEnabled: false,
    );
  }

  void enableSync() {
    state = state.copyWith(syncEnabled: true);
  }

  void centerOnSelectedLocation() {
    final selected = state.selectedLocation;
    if (selected != null) {
      requestCameraMove(
        center: selected,
        zoom: state.zoom,
        clearGotoMgrs: true,
        clearHoveredPeakId: true,
        clearHoveredTrackId: true,
      );
    }
  }

  void clearCursorMgrs() {
    state = state.copyWith(clearCursorMgrs: true);
  }

  void setHoveredPeakId(int? peakId) {
    if (peakId == null) {
      clearHoveredPeak();
      return;
    }
    state = state.copyWith(hoveredPeakId: peakId);
  }

  void clearHoveredPeak() {
    state = state.copyWith(clearHoveredPeakId: true);
  }

  void openPeakInfoPopup(Peak peak) {
    state = state.copyWith(
      peakInfo: resolvePeakInfoContent(
        peak: peak,
        peakListRepository: ref.read(peakListRepositoryProvider),
        tasmapRepository: ref.read(tasmapRepositoryProvider),
      ),
      clearInfoPopup: true,
      clearHoveredTrackId: true,
    );
  }

  void closePeakInfoPopup() {
    state = state.copyWith(clearPeakInfoPopup: true, clearHoveredPeakId: true);
  }

  void setHoveredTrackId(int? trackId) {
    if (trackId == null) {
      clearHoveredTrack();
      return;
    }
    state = state.copyWith(hoveredTrackId: trackId);
  }

  void clearHoveredTrack() {
    state = state.copyWith(clearHoveredTrackId: true);
  }

  void reconcileSelectedTrackState() {
    final selectedTrackId = state.selectedTrackId;
    if (selectedTrackId == null) {
      return;
    }
    final hasVisibleTrack =
        state.showTracks &&
        state.tracks.any((track) => track.gpxTrackId == selectedTrackId);
    if (!hasVisibleTrack) {
      state = state.copyWith(clearSelectedTrackId: true);
    }
  }

  void selectTrack(int trackId) {
    final hasVisibleTrack =
        state.showTracks &&
        state.tracks.any((track) => track.gpxTrackId == trackId);
    if (!hasVisibleTrack) {
      return;
    }
    state = state.copyWith(selectedTrackId: trackId);
  }

  void showTrack(int trackId, {LatLng? selectedLocation}) {
    final track = _gpxTrackRepository.findById(trackId);
    if (track == null) {
      state = state.copyWith(clearSelectedTrackId: true, clearHoveredTrackId: true);
      return;
    }

    final tracks = state.tracks.every((existing) => existing.gpxTrackId != trackId)
        ? [...state.tracks, track]
        : state.tracks;

    state = state.copyWith(
      tracks: tracks,
      selectedTrackId: trackId,
      selectedLocation: selectedLocation,
      showTracks: true,
      clearHoveredTrackId: true,
      clearGotoMgrs: true,
      selectedTrackFocusSerial: state.selectedTrackFocusSerial + 1,
    );
  }

  void clearSelectedTrack() {
    state = state.copyWith(clearSelectedTrackId: true);
  }

  (LatLng?, String?) parseGridReference(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return (null, null);

    // Check for map name only (no digits = no coordinates)
    if (!RegExp(r'[0-9]').hasMatch(trimmed)) {
      final maps = _tasmapRepository.searchMaps(trimmed);
      state = state.copyWith(mapSuggestions: maps, mapSearchQuery: trimmed);

      if (maps.isEmpty) {
        return (null, "No maps found matching '$trimmed'");
      }

      final exactMatch = maps
          .where((m) => m.name.toLowerCase() == trimmed.toLowerCase())
          .toList();

      if (exactMatch.length == 1) {
        final map = exactMatch.first;
        final center = _tasmapRepository.getMapCenter(map);
        if (center != null) {
          state = state.copyWith(
            selectedMap: map,
            tasmapDisplayMode: TasmapDisplayMode.selectedMap,
            mapSuggestions: [],
            mapSearchQuery: '',
          );
          return (center, null);
        }
        return (null, 'Cannot calculate center for ${map.name}');
      }

      return (null, null);
    }

    // Check for map name format: "MapName easting northing" or "MapName easting" or "MapName easting northing" (space separated)
    final parts = trimmed.split(RegExp(r'\s+'));

    if (parts.length >= 2) {
      // Determine if last part(s) are coordinates (digits only)
      String potentialName;
      String potentialCoords;

      // Check if last part is digits (coordinate)
      // Also check if second-to-last is digits (for "MapName easting northing")
      if (parts.length >= 3 &&
          RegExp(r'^[0-9]+$').hasMatch(parts[parts.length - 1]) &&
          RegExp(r'^[0-9]+$').hasMatch(parts[parts.length - 2])) {
        // Format: "MapName easting northing" - last two parts are coordinates
        potentialName = parts.sublist(0, parts.length - 2).join(' ');
        final eastingPart = parts[parts.length - 2];
        final northingPart = parts[parts.length - 1];
        // Validate matching digit counts for space-separated
        final validationError =
            GridReferenceParser.validateSpaceSeparatedDigits(
              eastingPart,
              northingPart,
            );
        if (validationError != null) {
          return (null, validationError);
        }
        // If both parts are 4-5 digits, treat as separate easting/northing
        if (eastingPart.length >= 4 &&
            eastingPart.length <= 5 &&
            northingPart.length >= 4 &&
            northingPart.length <= 5) {
          potentialCoords =
              '$eastingPart x$northingPart'; // Marker for separate coords
        } else {
          potentialCoords = eastingPart + northingPart;
        }
      } else if (RegExp(r'^[0-9]+$').hasMatch(parts.last)) {
        // Format: "MapName coordinates" - last part is coordinates
        potentialName = parts.sublist(0, parts.length - 1).join(' ');
        potentialCoords = parts.last;
      } else {
        potentialName = '';
        potentialCoords = '';
      }

      // Check if we have a map name and valid-looking coordinates (digits only or with 'x' marker)
      if (potentialName.isNotEmpty &&
          (RegExp(r'^[0-9]+$').hasMatch(potentialCoords) ||
              potentialCoords.contains('x'))) {
        // Check if potentialName is a 2-letter MGRS100k square (skip map lookup)
        final isMgrs100k = RegExp(r'^[A-Za-z]{2}$').hasMatch(potentialName);
        if (!isMgrs100k) {
          // Look up the map by name
          final maps = _tasmapRepository.findByName(potentialName);
          if (maps.isNotEmpty) {
            final map = maps.first;
            final mgrsCodes = map.mgrs100kIdList;
            if (mgrsCodes.isEmpty) {
              return (null, 'Map not found: $potentialName');
            }

            // Handle different input formats - convert to 5-digit coordinates
            String easting5digit;
            String northing5digit;

            // Check if separate easting/northing format (marked with 'x')
            if (potentialCoords.contains('x')) {
              final sepParts = potentialCoords.split('x');
              if (sepParts.length == 2) {
                final eastingPart = sepParts[0];
                final northingPart = sepParts[1];
                // Use GridReferenceParser for interpretation
                easting5digit = GridReferenceParser.interpretDigit(
                  eastingPart,
                  eastingPart.length,
                );
                northing5digit = GridReferenceParser.interpretDigit(
                  northingPart,
                  northingPart.length,
                );
              } else {
                return (null, 'Invalid format. Use: MapName easting northing');
              }
            } else {
              final digitCount = potentialCoords.length;

              // Validate even digit count
              if (digitCount % 2 != 0) {
                return (null, 'Coordinate digits must be even count');
              }

              // Use GridReferenceParser for coordinate interpretation
              final parsed = GridReferenceParser.parseCoordinates(
                potentialCoords,
              );
              if (parsed == null) {
                return (null, 'Invalid coordinate format');
              }
              easting5digit = parsed.easting;
              northing5digit = parsed.northing;
            }

            final paddedEasting = easting5digit;
            final paddedNorthing = northing5digit;

            // Validate range (handle wrap-around)
            final eastingVal = int.tryParse(paddedEasting) ?? 0;
            final northingVal = int.tryParse(paddedNorthing) ?? 0;

            bool validEasting = _inRange(
              eastingVal,
              map.eastingMin,
              map.eastingMax,
            );
            bool validNorthing = _inRange(
              northingVal,
              map.northingMin,
              map.northingMax,
            );

            if (!validEasting) {
              final displayMin = map.eastingMin;
              final displayMax = map.eastingMax;
              final rangeDisplay = map.eastingMin > map.eastingMax
                  ? '$displayMin-99999 OR 0-$displayMax'
                  : '$displayMin-$displayMax';
              return (
                null,
                'Easting $eastingVal out of range for ${map.name}. Valid range: $rangeDisplay',
              );
            }

            if (!validNorthing) {
              final displayMin = map.northingMin;
              final displayMax = map.northingMax;
              final rangeDisplay = map.northingMin > map.northingMax
                  ? '$displayMin-99999 OR 0-$displayMax'
                  : '$displayMin-$displayMax';
              return (
                null,
                'Northing $northingVal out of range for ${map.name}. Valid range: $rangeDisplay',
              );
            }

            // Determine correct MGRS100k square based on easting
            String mgrsCode;
            if (mgrsCodes.length == 2 && map.eastingMin > map.eastingMax) {
              // Wrap-around: first code for high eastings, second for low
              if (eastingVal >= map.eastingMin) {
                mgrsCode = mgrsCodes[0];
              } else {
                mgrsCode = mgrsCodes[1];
              }
            } else {
              mgrsCode = mgrsCodes.first;
            }

            final fullMgrs =
                '55G${mgrsCode.substring(0, 2)}$paddedEasting$paddedNorthing';

            try {
              final coords = mgrs.Mgrs.toPoint(fullMgrs);
              final location = LatLng(coords[1], coords[0]);
              final mgrsOutputRaw = mgrs.Mgrs.forward([
                coords[0],
                coords[1],
              ], 5);
              String mgrsOutput;
              if (mgrsOutputRaw.length >= 10) {
                final firstLine = mgrsOutputRaw.substring(0, 5);
                final easting = mgrsOutputRaw.substring(5, 10);
                final northing = mgrsOutputRaw.substring(10);
                mgrsOutput = '$firstLine\n$easting $northing';
              } else {
                mgrsOutput = mgrsOutputRaw;
              }
              state = state.copyWith(gotoMgrs: mgrsOutput);
              return (location, null);
            } catch (e) {
              return (null, 'Invalid grid reference');
            }
          }
        }
      }
    }

    // Check for MGRS 100k square only format: "EN 194507" or "EN194507"
    final mgrs100kMatch = RegExp(
      r'^([A-Z]{2})\s*([0-9]+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (mgrs100kMatch != null) {
      final mgrsCode = mgrs100kMatch.group(1)!.toUpperCase();
      final coords = mgrs100kMatch.group(2)!;
      final maps = _tasmapRepository.findByMgrs100kId(mgrsCode);
      if (maps.isEmpty) {
        return (null, 'Unknown MGRS square: $mgrsCode');
      }

      // Validate even digit count
      if (coords.length % 2 != 0) {
        return (null, 'Coordinate digits must be even count');
      }

      // Use GridReferenceParser for coordinate interpretation
      final parsed = GridReferenceParser.parseCoordinates(coords);
      if (parsed == null) {
        return (null, 'Invalid coordinate format');
      }
      final easting5digit = parsed.easting;
      final northing5digit = parsed.northing;

      final eastingVal = int.tryParse(easting5digit) ?? 0;
      final northingVal = int.tryParse(northing5digit) ?? 0;

      // Find the correct map by checking which one contains the coordinates
      Tasmap50k? correctMap;
      for (final map in maps) {
        if (_inRange(eastingVal, map.eastingMin, map.eastingMax) &&
            _inRange(northingVal, map.northingMin, map.northingMax)) {
          correctMap = map;
          break;
        }
      }

      if (correctMap == null) {
        return (null, 'Coordinates out of range for MGRS square $mgrsCode');
      }

      final fullMgrs = '55G$mgrsCode$easting5digit$northing5digit';

      try {
        final coords = mgrs.Mgrs.toPoint(fullMgrs);
        final location = LatLng(coords[1], coords[0]);
        final mgrsOutputRaw = mgrs.Mgrs.forward([coords[0], coords[1]], 5);
        String mgrsOutput;
        if (mgrsOutputRaw.length >= 10) {
          final firstLine = mgrsOutputRaw.substring(0, 5);
          final easting = mgrsOutputRaw.substring(5, 10);
          final northing = mgrsOutputRaw.substring(10);
          mgrsOutput = '$firstLine\n$easting $northing';
        } else {
          mgrsOutput = mgrsOutputRaw;
        }
        state = state.copyWith(gotoMgrs: mgrsOutput);
        return (location, null);
      } catch (e) {
        return (null, 'Invalid grid reference');
      }
    }

    // Check for space-separated coordinates only (no map name, no MGRS square): "194 507"
    // Use current MGRS100k square from the display
    final spaceOnlyMatch = RegExp(r'^([0-9]+)\s+([0-9]+)$').firstMatch(trimmed);
    if (spaceOnlyMatch != null) {
      final eastingPart = spaceOnlyMatch.group(1)!;
      final northingPart = spaceOnlyMatch.group(2)!;

      // Validate matching digit counts
      final validationError = GridReferenceParser.validateSpaceSeparatedDigits(
        eastingPart,
        northingPart,
      );
      if (validationError != null) {
        return (null, validationError);
      }

      // Extract current MGRS100k square from state.currentMgrs
      final currentMgrsParts = state.currentMgrs.split('\n');
      if (currentMgrsParts.isEmpty || currentMgrsParts[0].length < 5) {
        return (null, 'Cannot determine current MGRS square');
      }
      final mgrsCode = currentMgrsParts[0].substring(3, 5);

      final maps = _tasmapRepository.findByMgrs100kId(mgrsCode);
      if (maps.isEmpty) {
        return (null, 'Unknown MGRS square: $mgrsCode');
      }

      // Use GridReferenceParser for coordinate interpretation
      final easting5digit = GridReferenceParser.interpretDigit(
        eastingPart,
        eastingPart.length,
      );
      final northing5digit = GridReferenceParser.interpretDigit(
        northingPart,
        northingPart.length,
      );

      final eastingVal = int.tryParse(easting5digit) ?? 0;
      final northingVal = int.tryParse(northing5digit) ?? 0;

      // Find the correct map
      Tasmap50k? correctMap;
      for (final map in maps) {
        if (_inRange(eastingVal, map.eastingMin, map.eastingMax) &&
            _inRange(northingVal, map.northingMin, map.northingMax)) {
          correctMap = map;
          break;
        }
      }

      if (correctMap == null) {
        return (
          null,
          'Coordinates out of range for current MGRS square $mgrsCode',
        );
      }

      final fullMgrs = '55G$mgrsCode$easting5digit$northing5digit';

      try {
        final coordsResult = mgrs.Mgrs.toPoint(fullMgrs);
        final location = LatLng(coordsResult[1], coordsResult[0]);
        final mgrsOutputRaw = mgrs.Mgrs.forward([
          coordsResult[0],
          coordsResult[1],
        ], 5);
        String mgrsOutput;
        if (mgrsOutputRaw.length >= 10) {
          final firstLine = mgrsOutputRaw.substring(0, 5);
          final easting = mgrsOutputRaw.substring(5, 10);
          final northing = mgrsOutputRaw.substring(10);
          mgrsOutput = '$firstLine\n$easting $northing';
        } else {
          mgrsOutput = mgrsOutputRaw;
        }
        state = state.copyWith(gotoMgrs: mgrsOutput);
        return (location, null);
      } catch (e) {
        return (null, 'Invalid grid reference');
      }
    }

    // Check for coordinates only (no map name, no MGRS square): "194507"
    // Use current MGRS100k square from the display
    if (RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
      final coords = trimmed;

      // Validate even digit count
      if (coords.length % 2 != 0) {
        return (null, 'Coordinate digits must be even count');
      }

      // Extract current MGRS100k square from state.currentMgrs
      // Format: "55G XX\nYYYYY YYYYY"
      final currentMgrsParts = state.currentMgrs.split('\n');
      if (currentMgrsParts.isEmpty || currentMgrsParts[0].length < 5) {
        return (null, 'Cannot determine current MGRS square');
      }
      final mgrsCode = currentMgrsParts[0].substring(3, 5);

      final maps = _tasmapRepository.findByMgrs100kId(mgrsCode);
      if (maps.isEmpty) {
        return (null, 'Unknown MGRS square: $mgrsCode');
      }

      // Use GridReferenceParser for coordinate interpretation
      final parsed = GridReferenceParser.parseCoordinates(coords);
      if (parsed == null) {
        return (null, 'Invalid coordinate format');
      }
      final easting5digit = parsed.easting;
      final northing5digit = parsed.northing;

      final eastingVal = int.tryParse(easting5digit) ?? 0;
      final northingVal = int.tryParse(northing5digit) ?? 0;

      // Find the correct map
      Tasmap50k? correctMap;
      for (final map in maps) {
        if (_inRange(eastingVal, map.eastingMin, map.eastingMax) &&
            _inRange(northingVal, map.northingMin, map.northingMax)) {
          correctMap = map;
          break;
        }
      }

      if (correctMap == null) {
        return (
          null,
          'Coordinates out of range for current MGRS square $mgrsCode',
        );
      }

      final fullMgrs = '55G$mgrsCode$easting5digit$northing5digit';

      try {
        final coordsResult = mgrs.Mgrs.toPoint(fullMgrs);
        final location = LatLng(coordsResult[1], coordsResult[0]);
        final mgrsOutputRaw = mgrs.Mgrs.forward([
          coordsResult[0],
          coordsResult[1],
        ], 5);
        String mgrsOutput;
        if (mgrsOutputRaw.length >= 10) {
          final firstLine = mgrsOutputRaw.substring(0, 5);
          final easting = mgrsOutputRaw.substring(5, 10);
          final northing = mgrsOutputRaw.substring(10);
          mgrsOutput = '$firstLine\n$easting $northing';
        } else {
          mgrsOutput = mgrsOutputRaw;
        }
        state = state.copyWith(gotoMgrs: mgrsOutput);
        return (location, null);
      } catch (e) {
        return (null, 'Invalid grid reference');
      }
    }

    // Original MGRS format parsing
    final upper = trimmed.toUpperCase();
    final cleaned = upper.replaceAll(' ', '');

    String gridZone = '55G';
    String coords;

    if (RegExp(r'^[0-9]{1,2}[A-Z]\s*[A-Z]{2}\s*[0-9]+$').hasMatch(input) ||
        RegExp(r'^[0-9]{1,2}[A-Z][A-Z][0-9]+$').hasMatch(cleaned)) {
      final parts = input.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        gridZone = parts[0];
        coords = parts.sublist(1).join();
      } else if (parts.length == 2 && parts[1].length >= 4) {
        gridZone = parts[0];
        coords = parts[1];
      } else {
        coords = input.replaceAll(
          RegExp(r'^[0-9]{1,2}[A-Z]\s*', caseSensitive: false),
          '',
        );
      }
    } else {
      coords = cleaned;
    }

    final digitCount = coords.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digitCount != 6 && digitCount != 8) {
      return (null, 'Invalid grid reference');
    }

    final easting = digitCount == 6
        ? coords.substring(0, 3)
        : coords.substring(0, 4);
    final northing = digitCount == 6
        ? coords.substring(3)
        : coords.substring(4);

    final paddedEasting = easting.padLeft(5, '0');
    final paddedNorthing = northing.padLeft(5, '0');

    final fullMgrs = '$gridZone $paddedEasting $paddedNorthing';

    try {
      final coords = mgrs.Mgrs.toPoint(fullMgrs);
      final location = LatLng(coords[1], coords[0]);
      final mgrsOutputRaw = mgrs.Mgrs.forward([coords[0], coords[1]], 5);
      String mgrsOutput;
      if (mgrsOutputRaw.length >= 10) {
        final firstLine = mgrsOutputRaw.substring(0, 5);
        final easting = mgrsOutputRaw.substring(5, 10);
        final northing = mgrsOutputRaw.substring(10);
        mgrsOutput = '$firstLine\n$easting $northing';
      } else {
        mgrsOutput = mgrsOutputRaw;
      }
      state = state.copyWith(gotoMgrs: mgrsOutput);
      return (location, null);
    } catch (e) {
      return (null, 'Invalid grid reference');
    }
  }

  void searchMapSuggestions(String query) {
    if (query.isEmpty) {
      state = state.copyWith(mapSuggestions: [], mapSearchQuery: '');
      return;
    }
    final maps = _tasmapRepository.searchMaps(query);
    state = state.copyWith(mapSuggestions: maps, mapSearchQuery: query);
  }

  void selectMap(Tasmap50k map) {
    final center = _tasmapRepository.getMapCenter(map);
    if (center != null) {
      state = state.copyWith(
        selectedMap: map,
        tasmapDisplayMode: TasmapDisplayMode.selectedMap,
        clearSelectedLocation: true,
        selectedMapFocusSerial: state.selectedMapFocusSerial + 1,
        mapSuggestions: [],
        mapSearchQuery: '',
      );
    }
  }

  void centerOnLocationWithZoom(LatLng location, Tasmap50k map) {
    requestCameraMove(
      center: location,
      zoom: state.zoom,
      clearHoveredPeakId: true,
      clearHoveredTrackId: true,
    );
  }

  void toggleMapOverlay() {
    cycleTasmapDisplayMode();
  }

  void cycleTasmapDisplayMode() {
    final nextMode = switch (state.tasmapDisplayMode) {
      TasmapDisplayMode.overlay => TasmapDisplayMode.none,
      TasmapDisplayMode.none =>
        state.selectedMap == null
            ? TasmapDisplayMode.overlay
            : TasmapDisplayMode.selectedMap,
      TasmapDisplayMode.selectedMap => TasmapDisplayMode.overlay,
    };

    state = state.copyWith(tasmapDisplayMode: nextMode);
  }

  void clearGotoMgrs() {
    state = state.copyWith(
      clearGotoMgrs: true,
      mapSuggestions: [],
      mapSearchQuery: '',
    );
  }

  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error, clearError: error == null);
  }

  void toggleGotoInput() {
    state = state.copyWith(showGotoInput: !state.showGotoInput);
  }

  void toggleInfoPopup() {
    if (state.showInfoPopup) {
      state = state.copyWith(clearInfoPopup: true);
    } else {
      _showInfoPopup();
    }
  }

  void _showInfoPopup() {
    final mgrs = _convertToMgrs(state.center);
    final map = _findMapByMgrsWithCoordinates(mgrs);
    final (peakName, peakElevation) = _findNearbyPeak(state.center);
    state = state.copyWith(
      showInfoPopup: true,
      infoMapName: map?.name ?? 'Outside Tasmania 50k coverage',
      infoMgrs: mgrs,
      infoPeakName: peakName,
      infoPeakElevation: peakElevation,
      clearPeakInfoPopup: true,
    );
  }

  void closeInfoPopup() {
    if (state.showInfoPopup) {
      state = state.copyWith(clearInfoPopup: true);
    }
  }

  (String?, double?) _findNearbyPeak(LatLng location) {
    for (final peak in state.peaks) {
      final distance = _distance.as(
        LengthUnit.Meter,
        location,
        LatLng(peak.latitude, peak.longitude),
      );
      if (distance <= MapConstants.searchRadiusMeters) {
        return (peak.name, peak.elevation);
      }
    }
    return (null, null);
  }

  Tasmap50k? _findMapByMgrsWithCoordinates(String mgrsString) {
    if (mgrsString.length < 10) return null;
    return _tasmapRepository.findByMgrsCodeAndCoordinates(mgrsString);
  }

  void setGotoInputVisible(bool visible) {
    state = state.copyWith(showGotoInput: visible);
  }

  void togglePeakSearch() {
    state = state.copyWith(showPeakSearch: !state.showPeakSearch);
  }

  void toggleTracks() {
    if (state.tracks.isEmpty ||
        state.isLoadingTracks ||
        state.hasTrackRecoveryIssue) {
      return;
    }
    state = state.copyWith(
      showTracks: !state.showTracks,
      clearHoveredTrackId: true,
      clearSelectedTrackId: state.showTracks,
    );
  }

  void setPeakSearchVisible(bool visible) {
    state = state.copyWith(showPeakSearch: visible);
  }

  void searchPeaks(String query) {
    final results = _peakRepository.searchPeaks(query).take(20).toList();
    state = state.copyWith(searchQuery: query, searchResults: results);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '', searchResults: []);
  }

  void selectAllSearchResults() {
    if (state.searchResults.isNotEmpty) {
      final peaks = state.searchResults;
      double minLat = peaks.first.latitude;
      double maxLat = peaks.first.latitude;
      double minLng = peaks.first.longitude;
      double maxLng = peaks.first.longitude;

      for (final peak in peaks) {
        if (peak.latitude < minLat) minLat = peak.latitude;
        if (peak.latitude > maxLat) maxLat = peak.latitude;
        if (peak.longitude < minLng) minLng = peak.longitude;
        if (peak.longitude > maxLng) maxLng = peak.longitude;
      }

      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;

      final latDiff = maxLat - minLat;
      final lngDiff = maxLng - minLng;
      final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

      double zoom = 12;
      if (maxDiff > 0) {
        zoom = 10 - (maxDiff / 10).clamp(0, 3);
      }

      requestCameraMove(
        center: LatLng(centerLat, centerLng),
        zoom: zoom,
        selectedPeaks: List.from(peaks),
        updateSelectedPeaks: true,
        clearHoveredPeakId: true,
        clearHoveredTrackId: true,
      );
      state = state.copyWith(
        showPeakSearch: false,
        searchQuery: '',
        searchResults: [],
      );
    }
  }

  void clearSelectedPeaks() {
    state = state.copyWith(selectedPeaks: []);
  }

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

  Future<void> reloadPeakMarkers() async {
    final peaks = _peakRepository.getAllPeaks();
    final refreshedPeakInfo = _refreshedPeakInfo(peaks);
    state = state.copyWith(
      peaks: peaks,
      isLoadingPeaks: false,
      clearError: true,
      peakInfo: refreshedPeakInfo,
      clearPeakInfoPopup: state.peakInfo != null && refreshedPeakInfo == null,
    );
  }

  Future<PeakRefreshResult> refreshPeaks() async {
    state = state.copyWith(isLoadingPeaks: true, clearError: true);
    try {
      final result = await _peakRefreshService.refreshPeaks();
      ref.read(peakRevisionProvider.notifier).increment();
      final peaks = _peakRepository.getAllPeaks();
      final refreshedPeakInfo = _refreshedPeakInfo(peaks);
      state = state.copyWith(
        peaks: peaks,
        isLoadingPeaks: false,
        clearError: true,
        peakInfo: refreshedPeakInfo,
        clearPeakInfoPopup: state.peakInfo != null && refreshedPeakInfo == null,
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoadingPeaks: false,
        error: 'Failed to refresh peaks: $e',
      );
      rethrow;
    }
  }

  Set<int> _refreshCorrelatedPeakIds(Iterable<GpxTrack> tracks) {
    return buildCorrelatedPeakIds(tracks);
  }

  PeakInfoContent? _refreshedPeakInfo(List<Peak> peaks) {
    final existing = state.peakInfo;
    if (existing == null) {
      return null;
    }

    for (final peak in peaks) {
      if (peak.osmId == existing.peak.osmId) {
        return resolvePeakInfoContent(
          peak: peak,
          peakListRepository: ref.read(peakListRepositoryProvider),
          tasmapRepository: ref.read(tasmapRepositoryProvider),
        );
      }
    }
    return null;
  }

  bool _inRange(int value, int min, int max) {
    if (min <= max) {
      return value >= min && value <= max;
    } else {
      return value >= min || value <= max;
    }
  }
}
