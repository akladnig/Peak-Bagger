import 'dart:async';

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_refresh_result.dart';
import 'package:peak_bagger/services/map_name_resolution.dart';
import 'package:peak_bagger/services/map_search_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/gpx_track_statistics_calculator.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/route_timing_service.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/services/waypoints_repository.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/models/waypoints.dart';

class TestMapNotifier extends MapNotifier {
  TestMapNotifier(
    this.initialState, {
    this.rescanStatus =
        'Imported 1, replaced 0, unchanged 0, unsupported 2, errors 0',
    this.rescanWarning,
    this.rescanSnackbarMessage,
    this.startupBackfillWarningMessage,
    this.recalcUpdatedCount = 1,
    this.recalcSkippedCount = 0,
    this.recalcWarning,
    this.recalcTracks,
    this.peakRepository,
    this.peaksBaggedRepository,
    this.waypointsRepository,
    this.gpxTrackRepository,
    this.routeRepository,
    this.routePlanningOutcomes = const [],
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
  final WaypointsRepository? waypointsRepository;
  final GpxTrackRepository? gpxTrackRepository;
  final RouteRepository? routeRepository;
  final List<Object> routePlanningOutcomes;
  final String? routeSaveErrorMessage;
  final Set<int> _correlatedPeakIds;
  bool _snackbarConsumed = false;
  String? _trackSnackbarMessage;
  String? _startupBackfillWarningMessage;
  String? _routeSnackbarMessage;
  var _routePlanningOutcomeIndex = 0;
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
  void setRouteVisibility(int routeId, bool visible) {
    final repository = routeRepository;
    if (repository == null) {
      return;
    }

    final route = repository.findById(routeId);
    if (route == null || route.visible == visible) {
      return;
    }

    route.visible = visible;
    repository.saveRoute(route);
    ref.read(routeRevisionProvider.notifier).increment();
  }

  @override
  void updateRouteWalkingSpeed(int routeId, double walkingSpeedKmh) {
    final repository = routeRepository;
    if (repository == null) {
      return;
    }

    final route = repository.findById(routeId);
    if (route == null) {
      return;
    }

    route.walkingSpeedKmh = walkingSpeedKmh;
    repository.saveRoute(route);
    ref.read(routeRevisionProvider.notifier).increment();
  }

  @override
  void recalculateRouteTiming(int routeId, RouteTimingAlgorithm algorithm) {
    final repository = routeRepository;
    if (repository == null) {
      return;
    }

    final route = repository.findById(routeId);
    if (route == null || route.gpxRoute.length < 2) {
      return;
    }

    final profile = buildRouteTimingProfileForAlgorithm(
      algorithm: algorithm,
      points: route.gpxRoute,
      elevations: route.gpxRouteElevations,
      walkingSpeedKmh:
          route.walkingSpeedKmh ?? routeTimingDefaultWalkingSpeedKmh,
    );
    route.routeTimingSource = routeTimingSourceForAlgorithm(algorithm);
    route.routeTimingProfileJson = encodeRouteTimingProfile(profile);
    route.routeTimingSegmentKindsJson = buildRouteTimingSegmentKindsJson(
      segmentCount: route.gpxRoute.length - 1,
      kind: RouteTimingSegmentKinds.manualEstimated,
    );
    route.estimatedTime = profileDurationSeconds(profile) * 1000;
    repository.saveRoute(route);
    ref.read(routeRevisionProvider.notifier).increment();
  }

  @override
  void setTrackVisibility(int trackId, bool visible) {
    final repository = gpxTrackRepository;
    if (repository != null) {
      final track = repository.findById(trackId);
      if (track != null && track.visible != visible) {
        track.visible = visible;
        repository.saveTrack(track);
      }
    }

    state = state.copyWith(
      tracks: [
        for (final existing in state.tracks)
          if (existing.gpxTrackId == trackId)
            existing..visible = visible
          else
            existing,
      ],
      clearHoveredTrackId: !visible && state.hoveredTrackId == trackId,
    );
  }

  @override
  MapState build() {
    ref.listen<int>(peaksBaggedRevisionProvider, (previous, next) {
      refreshPeakInfoPopupContent();
    });
    return initialState;
  }

  @override
  Set<int> get correlatedPeakIds => _correlatedPeakIds;

  @override
  List<Waypoints> favouriteWaypoints() {
    return waypointsRepository?.getFavourites() ?? const [];
  }

  @override
  Waypoints? getCurrentMarker() {
    return waypointsRepository?.getCurrentMarker();
  }

  @override
  bool favouriteNameExists(String name, {int? excludingId}) {
    return waypointsRepository?.favouriteNameExists(
          name,
          excludingId: excludingId,
        ) ??
        false;
  }

  @override
  Future<bool> saveFavouriteWaypoint(
    LatLng location, {
    required String name,
  }) async {
    final repository = waypointsRepository;
    if (repository != null) {
      await repository.saveFavourite(name: name, location: location);
    }
    setSelectedLocation(location);
    return true;
  }

  @override
  Future<bool> setCurrentMarker(
    LatLng location, {
    String name = 'Marker',
  }) async {
    final repository = waypointsRepository;
    if (repository != null) {
      await repository.saveMarker(location: location, name: name);
    }
    setSelectedLocation(location);
    return true;
  }

  @override
  String mapNameForMgrs(String mgrsText) {
    try {
      return resolveMapNameForMgrs(
        tasmapRepository: ref.read(tasmapRepositoryProvider),
        mgrsText: mgrsText,
      ).displayName;
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  String mapNameForPoint(LatLng point) {
    try {
      return resolveMapNameForPoint(
        tasmapRepository: ref.read(tasmapRepositoryProvider),
        point: point,
      ).displayName;
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  void addRouteDraftMarker(LatLng point, {bool straightLine = false}) {
    if (!state.isRouteDrafting) {
      return;
    }
    if (straightLine) {
      super.addRouteDraftMarker(point, straightLine: true);
      return;
    }
    if (state.routeDraftMode == RouteMode.routeToPeak) {
      final target = state.routeDraftPeak;
      if (target == null) {
        return;
      }

      final peakPoint = LatLng(target.latitude, target.longitude);
      if (peakPoint == point) {
        state = state.copyWith(
          routeDraftMarkers: [point, peakPoint],
          routeDraftStage: RouteDraftStage.segmentFailure,
          routeDraftError:
              'Start and end points must be different to calculate a route.',
          routeDraftProvisionalPoints: const [],
        );
        return;
      }

      state = state.copyWith(
        routeDraftMarkers: [point, peakPoint],
        routeDraftStage: RouteDraftStage.routingSegment,
        routeDraftProvisionalPoints: [point, peakPoint],
        clearRouteDraftError: true,
      );

      if (routePlanningOutcomes.isEmpty) {
        super.addRouteDraftMarker(point);
        return;
      }

      final outcome = routePlanningOutcomes[_routePlanningOutcomeIndex++];
      if (outcome is PlannedRouteSegment ||
          outcome is RoutePlanningResult &&
              outcome.status == RoutePlanningStatus.routed) {
        final segment = outcome is PlannedRouteSegment
            ? outcome
            : PlannedRouteSegment(
                points: (outcome as RoutePlanningResult).points,
                distanceMeters: outcome.distanceMeters,
              );
        final segmentPoints = _routeToPeakSegmentPoints(
          segment.points,
          point,
          peakPoint,
        );
        state = state.copyWith(
          routeDraftCommittedPoints: _appendRouteSegment(
            state.routeDraftCommittedPoints,
            segmentPoints,
          ),
          routeDraftDistanceMeters:
              state.routeDraftDistanceMeters +
              _polylineDistanceMeters(segmentPoints),
          routeDraftProvisionalPoints: const [],
          routeDraftStage: RouteDraftStage.awaitingNextPoint,
          routeDraftMode: RouteMode.snapToTrail,
          clearRouteDraftPeak: true,
          clearRouteDraftError: true,
        );
        return;
      }

      if (outcome is RoutePlanningResult &&
          (outcome.status == RoutePlanningStatus.offTrack ||
              outcome.status == RoutePlanningStatus.noPath ||
              outcome.status == RoutePlanningStatus.failed)) {
        final segmentPoints = _routeToPeakSegmentPoints(
          outcome.points,
          point,
          peakPoint,
        );
        state = state.copyWith(
          routeDraftCommittedPoints: _appendRouteSegment(
            state.routeDraftCommittedPoints,
            segmentPoints,
          ),
          routeDraftDistanceMeters:
              state.routeDraftDistanceMeters +
              _polylineDistanceMeters(segmentPoints),
          routeDraftProvisionalPoints: const [],
          routeDraftStage: RouteDraftStage.awaitingNextPoint,
          routeDraftMode: RouteMode.snapToTrail,
          clearRouteDraftPeak: true,
          clearRouteDraftError: true,
        );
        return;
      }

      final message = switch (outcome) {
        RoutePlanningResult(:final errorMessage) =>
          errorMessage ?? 'Failed to calculate route.',
        RoutePlanningException(:final message) => message,
        String() => outcome,
        _ => 'Failed to calculate route.',
      };
      state = state.copyWith(
        routeDraftStage: RouteDraftStage.segmentFailure,
        routeDraftError: message,
        routeDraftProvisionalPoints: const [],
      );
      return;
    }
    if (routePlanningOutcomes.isEmpty) {
      super.addRouteDraftMarker(point);
      return;
    }

    switch (state.routeDraftStage) {
      case RouteDraftStage.inactive:
        return;
      case RouteDraftStage.awaitingStart:
        state = state.copyWith(
          routeDraftMarkers: [point],
          routeDraftStage: RouteDraftStage.awaitingNextPoint,
          clearRouteDraftError: true,
        );
      case RouteDraftStage.awaitingNextPoint:
      case RouteDraftStage.segmentFailure:
        final start = state.routeDraftMarkers.isEmpty
            ? null
            : state.routeDraftMarkers.last;
        if (start == null) {
          state = state.copyWith(
            routeDraftMarkers: [point],
            routeDraftStage: RouteDraftStage.awaitingNextPoint,
            clearRouteDraftError: true,
          );
          return;
        }
        if (start == point) {
          state = state.copyWith(
            routeDraftMarkers: [...state.routeDraftMarkers, point],
            routeDraftStage: RouteDraftStage.segmentFailure,
            routeDraftError:
                'Start and end points must be different to calculate a route.',
            routeDraftProvisionalPoints: const [],
          );
          return;
        }
        state = state.copyWith(
          routeDraftMarkers: [...state.routeDraftMarkers, point],
          routeDraftStage: RouteDraftStage.routingSegment,
          routeDraftProvisionalPoints: [start, point],
          clearRouteDraftError: true,
        );

        final outcome = routePlanningOutcomes[_routePlanningOutcomeIndex++];
        if (outcome is PlannedRouteSegment ||
            outcome is RoutePlanningResult &&
                outcome.status == RoutePlanningStatus.routed) {
          final segment = outcome is PlannedRouteSegment
              ? outcome
              : PlannedRouteSegment(
                  points: (outcome as RoutePlanningResult).points,
                  distanceMeters: outcome.distanceMeters,
                );
          state = state.copyWith(
            routeDraftCommittedPoints: _appendRouteSegment(
              state.routeDraftCommittedPoints,
              segment.points,
            ),
            routeDraftDistanceMeters:
                state.routeDraftDistanceMeters + segment.distanceMeters,
            routeDraftProvisionalPoints: const [],
            routeDraftStage: RouteDraftStage.awaitingNextPoint,
            clearRouteDraftError: true,
          );
          return;
        }

        if (outcome is RoutePlanningResult &&
            (outcome.status == RoutePlanningStatus.offTrack ||
                outcome.status == RoutePlanningStatus.noPath)) {
          state = state.copyWith(
            routeDraftCommittedPoints: _appendRouteSegment(
              state.routeDraftCommittedPoints,
              [start, point],
            ),
            routeDraftDistanceMeters:
                state.routeDraftDistanceMeters +
                const Distance().as(LengthUnit.Meter, start, point),
            routeDraftProvisionalPoints: const [],
            routeDraftStage: RouteDraftStage.awaitingNextPoint,
            clearRouteDraftError: true,
          );
          return;
        }

        final message = switch (outcome) {
          RoutePlanningResult(:final errorMessage) =>
            errorMessage ?? 'Failed to calculate route.',
          RoutePlanningException(:final message) => message,
          String() => outcome,
          _ => 'Failed to calculate route.',
        };
        state = state.copyWith(
          routeDraftStage: RouteDraftStage.segmentFailure,
          routeDraftError: message,
          routeDraftProvisionalPoints: const [],
        );
      case RouteDraftStage.routingSegment:
        return;
    }
  }

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
  Future<PeakRefreshResult> refreshPeaks({
    String region = Peak.defaultRegion,
    LatLngBounds? bounds,
  }) async {
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

    final remainingTracks =
        gpxTrackRepository?.getAllTracks() ?? remainingVisibleTracks;
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
        final resolvedPeaksBaggedRepository =
            peaksBaggedRepository ??
            PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage());
        final resolvedGpxTrackRepository =
            gpxTrackRepository ??
            GpxTrackRepository.test(InMemoryGpxTrackStorage());
        return resolvePeakInfoContent(
          peak: peak,
          peakListRepository: ref.read(peakListRepositoryProvider),
          tasmapRepository: ref.read(tasmapRepositoryProvider),
          peaksBaggedRepository: resolvedPeaksBaggedRepository,
          gpxTrackRepository: resolvedGpxTrackRepository,
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
          request.selectedLocationBehavior ==
          PendingCameraSelectionBehavior.clear,
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
  void setShowRoutes(bool value) {
    if (state.showRoutes == value) {
      return;
    }
    state = state.copyWith(
      showRoutes: value,
      clearSelectedRouteId: !value,
      clearHoveredRouteId: !value,
    );
  }

  @override
  Future<void> saveRouteDraft() async {
    final trimmedName = state.routeDraftName.trim();
    if (trimmedName.isEmpty || state.routeDraftCommittedPoints.length < 2) {
      state = state.copyWith(
        routeDraftNameError: 'A Route name must be entered',
      );
      return;
    }
    state = state.copyWith(isSavingRoute: true, clearRouteDraftNameError: true);
    if (routeSaveErrorMessage != null) {
      _routeSnackbarMessage = routeSaveErrorMessage;
      state = state.copyWith(isSavingRoute: false);
      return;
    }
    final sourceRouteId = state.sourceRouteId;
    final existingRoute = sourceRouteId == null
        ? null
        : routeRepository?.findById(sourceRouteId);
    try {
      routeRepository?.saveRoute(
        Route(
          id: sourceRouteId ?? 0,
          name: trimmedName,
          desc: existingRoute?.desc ?? '',
          gpxRoute: List<LatLng>.from(
            state.routeDraftCommittedPoints,
            growable: false,
          ),
          gpxRouteElevations:
              existingRoute?.gpxRouteElevations ??
              List<int?>.filled(
                state.routeDraftCommittedPoints.length,
                null,
                growable: false,
              ),
          routeWaypoints: existingRoute?.routeWaypoints ?? const [],
          displayRoutePointsByZoom:
              existingRoute?.displayRoutePointsByZoom ??
              TrackDisplayCacheBuilder.buildJson([
                List<LatLng>.from(
                  state.routeDraftCommittedPoints,
                  growable: false,
                ),
              ]),
          colour: state.routeDraftColour,
          visible: existingRoute?.visible ?? true,
          distance2d: state.routeDraftDistanceMeters,
          distance3d:
              existingRoute?.distance3d ?? state.routeDraftDistanceMeters,
          ascent: existingRoute?.ascent ?? 0,
          descent: existingRoute?.descent ?? 0,
          startElevation: existingRoute?.startElevation ?? 0,
          endElevation: existingRoute?.endElevation ?? 0,
          lowestElevation: existingRoute?.lowestElevation ?? 0,
          highestElevation: existingRoute?.highestElevation ?? 0,
        ),
      );
      ref.read(routeRevisionProvider.notifier).increment();
    } catch (error) {
      _routeSnackbarMessage = 'Failed to save route: $error';
      state = state.copyWith(isSavingRoute: false);
      return;
    }
    if (sourceRouteId != null) {
      endRouteDraft();
      state = state.copyWith(
        selectedRouteId: sourceRouteId,
        selectedRouteFocusSerial: state.selectedRouteFocusSerial + 1,
      );
      return;
    }
    state = state.copyWith(showRoutes: true);
    endRouteDraft();
  }

  @override
  String? consumeRouteSnackbarMessage() {
    final message = _routeSnackbarMessage;
    _routeSnackbarMessage = null;
    return message;
  }

  @override
  void updateSearchPopupQuery(String query) {
    final service = MapSearchService(
      peakRepository:
          peakRepository ??
          PeakRepository.test(InMemoryPeakStorage(state.peaks)),
      gpxTrackRepository:
          gpxTrackRepository ??
          GpxTrackRepository.test(InMemoryGpxTrackStorage(state.tracks)),
      routeRepository:
          routeRepository ?? RouteRepository.test(InMemoryRouteStorage()),
      tasmapRepository: ref.read(tasmapRepositoryProvider),
    );
    final results = service.search(
      query: query,
      entityFilter: state.searchPopupEntityFilter,
      regionKey: state.searchPopupRegionKey,
      sort: state.searchPopupSort,
    );
    final peakResults = results
        .where((result) => result.type == MapSearchResultType.peak)
        .map((result) => result.peak!)
        .toList(growable: false);
    state = state.copyWith(
      searchPopupQuery: query,
      searchPopupResults: results,
      searchQuery: query,
      searchResults: peakResults,
    );
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
    if (isVisible) {
      state = state.copyWith(clearInfoPopup: true);
      return;
    }

    final mapName =
        ref.read(tasmapRepositoryProvider).findByPoint(state.center)?.name ??
        'Outside Tasmania 50k coverage';
    state = state.copyWith(
      showInfoPopup: true,
      infoMapName: mapName,
      infoMgrs: state.currentMgrs,
      clearPeakInfoPopup: true,
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
      zoom: MapConstants.defaultZoom,
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
      state = state.copyWith(
        clearSelectedTrackId: true,
        clearHoveredTrackId: true,
      );
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
  void selectRoute(int routeId) {
    final hasVisibleRoute =
        state.showRoutes &&
        routeRepository?.getAllRoutes().any(
              (route) => route.id == routeId && route.visible,
            ) ==
            true;
    if (!hasVisibleRoute) {
      return;
    }

    state = state.copyWith(
      selectedRouteId: routeId,
      clearSelectedTrackId: true,
      selectedRouteFocusSerial: state.selectedRouteFocusSerial + 1,
    );
  }

  @override
  void showRoute(int routeId, {LatLng? selectedLocation}) {
    final route = routeRepository?.findById(routeId);
    if (route == null) {
      state = state.copyWith(
        clearSelectedRouteId: true,
        clearSelectedTrackId: true,
        clearHoveredRouteId: true,
      );
      return;
    }

    state = state.copyWith(
      selectedRouteId: routeId,
      clearSelectedTrackId: true,
      selectedLocation: selectedLocation,
      showRoutes: true,
      clearHoveredRouteId: true,
      clearGotoMgrs: true,
      selectedRouteFocusSerial: state.selectedRouteFocusSerial + 1,
    );
  }

  @override
  void reconcileSelectedRouteState() {
    final selectedRouteId = state.selectedRouteId;
    if (selectedRouteId == null) {
      final sourceRouteId = state.sourceRouteId;
      if (state.isRouteDrafting && sourceRouteId != null) {
        final hasSourceRoute = routeRepository?.findById(sourceRouteId) != null;
        if (!hasSourceRoute) {
          _routeSnackbarMessage = 'Route is no longer available.';
          endRouteDraft();
        }
      }
      return;
    }

    final hasVisibleRoute =
        state.showRoutes &&
        routeRepository?.getAllRoutes().any(
              (route) => route.id == selectedRouteId,
            ) ==
            true;
    if (!hasVisibleRoute) {
      state = state.copyWith(clearSelectedRouteId: true);
    }

    final sourceRouteId = state.sourceRouteId;
    if (state.isRouteDrafting && sourceRouteId != null) {
      final hasSourceRoute = routeRepository?.findById(sourceRouteId) != null;
      if (!hasSourceRoute) {
        _routeSnackbarMessage = 'Route is no longer available.';
        endRouteDraft();
      }
    }
  }

  @override
  void clearSelectedRoute() {
    state = state.copyWith(clearSelectedRouteId: true);
  }

  @override
  void setHoveredRouteId(int? routeId) {
    state = state.copyWith(hoveredRouteId: routeId);
  }

  @override
  void clearHoveredRoute() {
    state = state.copyWith(hoveredRouteId: null);
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
          'Imported 1, replaced 0, unchanged 0, unsupported 0, errors 0',
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
      unsupportedCount: 0,
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

List<LatLng> _appendRouteSegment(List<LatLng> existing, List<LatLng> segment) {
  if (existing.isEmpty) {
    return List<LatLng>.from(segment, growable: false);
  }
  if (segment.isEmpty) {
    return List<LatLng>.from(existing, growable: false);
  }
  final nextSegment = existing.last == segment.first
      ? segment.skip(1)
      : segment;
  return [...existing, ...nextSegment];
}

List<LatLng> _routeToPeakSegmentPoints(
  List<LatLng> points,
  LatLng start,
  LatLng peakPoint,
) {
  final routedPoints = points.isEmpty ? [start] : points;
  if (routedPoints.last == peakPoint) {
    return List<LatLng>.from(routedPoints, growable: false);
  }
  return [...routedPoints, peakPoint];
}

double _polylineDistanceMeters(List<LatLng> points) {
  if (points.length < 2) {
    return 0;
  }

  var distance = 0.0;
  for (var index = 0; index < points.length - 1; index++) {
    distance += const Distance().as(
      LengthUnit.Meter,
      points[index],
      points[index + 1],
    );
  }
  return distance;
}
