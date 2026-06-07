import 'dart:async';
import 'dart:convert' as convert;
import 'dart:developer' as developer;
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gdal_dart/gdal_dart.dart' show GdalException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/route_marker_display.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/models/route_waypoint.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/providers/route_planner_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/import_path_helpers.dart';
import 'package:peak_bagger/services/import/gpx_track_import_models.dart';
import 'package:peak_bagger/services/item_visibility_backfill_service.dart';
import 'package:peak_bagger/services/gpx_track_repair_service.dart';
import 'package:peak_bagger/services/gpx_track_statistics_calculator.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peak_refresh_result.dart';
import 'package:peak_bagger/services/peak_refresh_service.dart';
import 'package:peak_bagger/services/peak_info_content_resolver.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';
import 'package:peak_bagger/services/track_peak_correlation_service.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/services/grid_reference_parser.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:xml/xml.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_correlation_settings_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/main.dart';
import 'package:peak_bagger/providers/peak_provider.dart';

import '../core/constants.dart';

export 'package:peak_bagger/services/peak_info_content_resolver.dart';
export 'package:peak_bagger/services/region_manifest_catalog.dart';

const _distance = Distance();

Peak? _peakAtPoint(Iterable<Peak> peaks, LatLng point) {
  for (final peak in peaks) {
    final peakLocation = LatLng(peak.latitude, peak.longitude);
    if (_distance.as(LengthUnit.Meter, point, peakLocation) <= 5) {
      return peak;
    }
  }
  return null;
}

Set<int> _immutablePeakListIds(Iterable<int> values) {
  return Set<int>.unmodifiable(values.toSet());
}

bool _samePeakListIds(Set<int> left, Set<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (final value in left) {
    if (!right.contains(value)) {
      return false;
    }
  }
  return true;
}

String _encodePeakListIds(Iterable<int> values) {
  final sorted = values.toSet().toList()..sort();
  return convert.jsonEncode(sorted);
}

Set<int>? _decodePeakListIds(String? payload) {
  if (payload == null) {
    return const <int>{};
  }

  final decoded = convert.jsonDecode(payload);
  if (decoded is! List) {
    return null;
  }

  final ids = <int>{};
  for (final entry in decoded) {
    if (entry is! int) {
      return null;
    }
    ids.add(entry);
  }
  return _immutablePeakListIds(ids);
}

const _latKey = 'map_position_lat';
const _lngKey = 'map_position_lng';
const _zoomKey = 'map_zoom';
const _peakListSelectionModeV2Key = 'peak_list_selection_mode_v2';
const _peakListSelectedIdsV2Key = 'peak_list_selected_ids_v2';
const _peakListPreviousSpecificIdsV2Key = 'peak_list_previous_specific_ids_v2';
const _legacyPeakListSelectionModeKey = 'peak_list_selection_mode';
const _legacyPeakListIdKey = 'peak_list_id';
const _showTracksKey = 'show_tracks';
const _showRoutesKey = 'show_routes';
const _showTrailsKey = 'show_trails';
const _routeDraftMarkerLimitError =
    'Peak Bagger only supports a maximum of 99 route points';

enum TasmapDisplayMode { overlay, none, selectedMap }

enum MapGridVisibility { hidden, mapGridOnly, mapGridAndDistanceGrid }

enum PeakListSelectionMode { none, allPeaks, specificList }

enum EndDrawerMode { basemaps, peakLists, tracksRoutes }

enum RouteMode { snapToTrail, straightLine, routeToPeak }

enum PeakInfoPopupMode { hover, pinned }

enum DriveEtaPopupStatus { loading, success, error }

class DriveEtaPopupState {
  const DriveEtaPopupState({
    required this.requestId,
    required this.anchor,
    required this.title,
    required this.status,
    this.distanceMeters,
    this.durationSeconds,
    this.errorMessage,
  });

  final int requestId;
  final LatLng anchor;
  final String title;
  final DriveEtaPopupStatus status;
  final double? distanceMeters;
  final int? durationSeconds;
  final String? errorMessage;

  DriveEtaPopupState copyWith({
    int? requestId,
    LatLng? anchor,
    String? title,
    DriveEtaPopupStatus? status,
    double? distanceMeters,
    int? durationSeconds,
    String? errorMessage,
    bool clearDistanceMeters = false,
    bool clearDurationSeconds = false,
    bool clearErrorMessage = false,
  }) {
    return DriveEtaPopupState(
      requestId: requestId ?? this.requestId,
      anchor: anchor ?? this.anchor,
      title: title ?? this.title,
      status: status ?? this.status,
      distanceMeters: clearDistanceMeters
          ? null
          : (distanceMeters ?? this.distanceMeters),
      durationSeconds: clearDurationSeconds
          ? null
          : (durationSeconds ?? this.durationSeconds),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

enum RouteDraftStage {
  inactive,
  awaitingStart,
  awaitingNextPoint,
  routingSegment,
  segmentFailure,
}

enum RouteDraftEndpointKind { tapped, snappedNode, projectedAnchor, peakTarget }

class RouteDraftControlEndpoint {
  const RouteDraftControlEndpoint({
    required this.id,
    required this.point,
    required this.kind,
  });

  final String id;
  final LatLng point;
  final RouteDraftEndpointKind kind;

  RouteDraftControlEndpoint copyWith({
    String? id,
    LatLng? point,
    RouteDraftEndpointKind? kind,
  }) {
    return RouteDraftControlEndpoint(
      id: id ?? this.id,
      point: point ?? this.point,
      kind: kind ?? this.kind,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteDraftControlEndpoint &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          point == other.point &&
          kind == other.kind;

  @override
  int get hashCode => Object.hash(id, point, kind);
}

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
  final LatLng? cursorPoint;
  final String? gotoMgrs;
  final bool showGotoInput;
  final bool showPeakSearch;
  final bool showInfoPopup;
  final String? infoMapName;
  final String? infoMgrs;
  final String? infoPeakName;
  final double? infoPeakElevation;
  final LatLng? selectedLocation;
  final bool isRouteDrafting;
  final bool isSavingRoute;
  final String routeDraftName;
  final String? routeDraftNameError;
  final RouteMode routeDraftMode;
  final Peak? routeDraftPeak;
  final List<RouteDraftControlEndpoint> routeDraftControlEndpoints;
  final List<RouteDraftDisplayMarker> routeDraftDisplayMarkers;
  final List<LatLng> routeDraftMarkers;
  final RouteDraftStage routeDraftStage;
  final String? routeDraftError;
  final RoutePlanningFailureKind routeDraftFailureKind;
  final int routeDraftColour;
  final List<LatLng> routeDraftCommittedPoints;
  final List<LatLng> routeDraftProvisionalPoints;
  final double routeDraftDistanceMeters;
  final bool routeDraftOffTrackProbeActive;
  final bool routeDraftStraightLineFallback;
  final int routeDraftNextMarkerId;
  final int routeDraftRequestId;
  final RouteElevationSummary? routeDraftElevationSummary;
  final bool routeDraftElevationLoading;
  final String? routeDraftElevationError;
  final List<double?> routeDraftPointElevations;
  final int routeDraftElevationRequestId;
  final int routeDraftGeometryVersion;
  final bool routeDraftNameFieldFocused;
  final bool routeDraftPeakTargetLocked;
  final bool routeDraftCanUndo;
  final bool routeDraftCanRedo;
  final bool syncEnabled;
  final List<Peak> peaks;
  final bool isLoadingPeaks;
  final List<Peak> searchResults;
  final String searchQuery;
  final List<Peak> selectedPeaks;
  final Tasmap50k? selectedMap;
  final TasmapDisplayMode tasmapDisplayMode;
  final MapGridVisibility gridVisibility;
  final List<Tasmap50k> mapSuggestions;
  final String mapSearchQuery;
  final int selectedMapFocusSerial;
  final int selectedTrackFocusSerial;
  final int selectedRouteFocusSerial;
  final int? hoveredRouteId;
  final String? hoveredRouteDraftMarkerId;
  final int? hoveredRouteDraftSegmentIndex;
  final int? hoveredRouteDraftCommittedSegmentIndex;
  final LatLng? hoveredRouteDraftSegmentPoint;
  final List<GpxTrack> tracks;
  final bool showTracks;
  final bool showRoutes;
  final bool showTrails;
  final PeakListSelectionMode peakListSelectionMode;
  final Set<int> selectedPeakListIds;
  final Set<int> previousSpecificPeakListIds;
  final EndDrawerMode endDrawerMode;
  final bool isLoadingTracks;
  final String? trackImportError;
  final bool hasTrackRecoveryIssue;
  final String? trackOperationStatus;
  final String? trackOperationWarning;
  final int? hoveredPeakId;
  final PeakInfoContent? peakInfo;
  final PeakInfoPopupMode? peakInfoPopupMode;
  final DriveEtaPopupState? driveEtaPopup;
  final int? hoveredTrackId;
  final int? selectedTrackId;
  final int? selectedRouteId;
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
    this.cursorPoint,
    this.gotoMgrs,
    this.showGotoInput = false,
    this.showPeakSearch = false,
    this.showInfoPopup = false,
    this.infoMapName,
    this.infoMgrs,
    this.infoPeakName,
    this.infoPeakElevation,
    this.selectedLocation,
    this.isRouteDrafting = false,
    this.isSavingRoute = false,
    this.routeDraftName = '',
    this.routeDraftNameError,
    this.routeDraftMode = RouteMode.snapToTrail,
    this.routeDraftPeak,
    this.routeDraftControlEndpoints = const [],
    this.routeDraftDisplayMarkers = const [],
    this.routeDraftMarkers = const [],
    this.routeDraftStage = RouteDraftStage.inactive,
    this.routeDraftError,
    this.routeDraftFailureKind = RoutePlanningFailureKind.generic,
    this.routeDraftColour = 0xFFFF0000,
    this.routeDraftCommittedPoints = const [],
    this.routeDraftProvisionalPoints = const [],
    this.routeDraftDistanceMeters = 0,
    this.routeDraftOffTrackProbeActive = false,
    this.routeDraftStraightLineFallback = false,
    this.routeDraftNextMarkerId = 0,
    this.routeDraftRequestId = 0,
    this.routeDraftElevationSummary,
    this.routeDraftElevationLoading = false,
    this.routeDraftElevationError,
    this.routeDraftPointElevations = const [],
    this.routeDraftElevationRequestId = 0,
    this.routeDraftGeometryVersion = 0,
    this.routeDraftNameFieldFocused = false,
    this.routeDraftPeakTargetLocked = false,
    this.routeDraftCanUndo = false,
    this.routeDraftCanRedo = false,
    this.syncEnabled = true,
    this.peaks = const [],
    this.isLoadingPeaks = false,
    this.searchResults = const [],
    this.searchQuery = '',
    this.selectedPeaks = const [],
    this.selectedMap,
    this.tasmapDisplayMode = TasmapDisplayMode.none,
    MapGridVisibility? gridVisibility,
    this.mapSuggestions = const [],
    this.mapSearchQuery = '',
    this.selectedMapFocusSerial = 0,
    this.selectedTrackFocusSerial = 0,
    this.selectedRouteFocusSerial = 0,
    this.hoveredRouteId,
    this.hoveredRouteDraftMarkerId,
    this.hoveredRouteDraftSegmentIndex,
    this.hoveredRouteDraftCommittedSegmentIndex,
    this.hoveredRouteDraftSegmentPoint,
    this.tracks = const [],
    this.showTracks = false,
    this.showRoutes = false,
    this.showTrails = false,
    this.peakListSelectionMode = PeakListSelectionMode.allPeaks,
    this.selectedPeakListIds = const <int>{},
    this.previousSpecificPeakListIds = const <int>{},
    this.endDrawerMode = EndDrawerMode.basemaps,
    this.isLoadingTracks = false,
    this.trackImportError,
    this.hasTrackRecoveryIssue = false,
    this.trackOperationStatus,
    this.trackOperationWarning,
    this.hoveredPeakId,
    this.peakInfo,
    this.peakInfoPopupMode,
    this.driveEtaPopup,
    this.hoveredTrackId,
    this.selectedTrackId,
    this.selectedRouteId,
    this.pendingCameraRequest,
    this.cameraRequestSerial = 0,
  }) : gridVisibility =
           gridVisibility ??
           (tasmapDisplayMode == TasmapDisplayMode.none
               ? MapGridVisibility.hidden
               : MapGridVisibility.mapGridOnly);

  Peak? get peakInfoPeak => peakInfo?.peak;

  bool get isPeakInfoPinned =>
      peakInfo != null && peakInfoPopupMode == PeakInfoPopupMode.pinned;

  bool get isPeakInfoHovered =>
      peakInfo != null && peakInfoPopupMode == PeakInfoPopupMode.hover;

  bool get hasDriveEtaPopup => driveEtaPopup != null;

  Peak? get routeDraftPeakTarget {
    if (routeDraftPeakTargetLocked) {
      return null;
    }

    final popupPeak = routeDraftPeak ?? peakInfoPeak;
    if (popupPeak != null) {
      return popupPeak;
    }

    final markerLocation = selectedLocation;
    if (markerLocation == null) {
      return null;
    }

    return _peakAtPoint(peaks, markerLocation);
  }

  bool get showMapGrid => gridVisibility != MapGridVisibility.hidden;

  bool get showMapOverlay => showMapGrid && selectedMap == null;

  bool get showSelectedMapLayer => showMapGrid && selectedMap != null;

  bool get showDistanceGrid =>
      gridVisibility == MapGridVisibility.mapGridAndDistanceGrid;

  String get mapGridTooltipMessage => switch (gridVisibility) {
    MapGridVisibility.hidden => 'Show Map Grid',
    MapGridVisibility.mapGridOnly => 'Show Map and MGRS Grid',
    MapGridVisibility.mapGridAndDistanceGrid => 'Hide Grids',
  };

  bool get showPeaks => peakListSelectionMode != PeakListSelectionMode.none;

  int? get selectedPeakListId =>
      selectedPeakListIds.length == 1 ? selectedPeakListIds.first : null;

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
    LatLng? cursorPoint,
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
    bool? isRouteDrafting,
    bool? isSavingRoute,
    String? routeDraftName,
    String? routeDraftNameError,
    bool clearRouteDraftNameError = false,
    RouteMode? routeDraftMode,
    Peak? routeDraftPeak,
    List<RouteDraftControlEndpoint>? routeDraftControlEndpoints,
    List<RouteDraftDisplayMarker>? routeDraftDisplayMarkers,
    List<LatLng>? routeDraftMarkers,
    RouteDraftStage? routeDraftStage,
    String? routeDraftError,
    RoutePlanningFailureKind? routeDraftFailureKind,
    bool clearRouteDraftError = false,
    int? routeDraftColour,
    List<LatLng>? routeDraftCommittedPoints,
    List<LatLng>? routeDraftProvisionalPoints,
    double? routeDraftDistanceMeters,
    bool? routeDraftOffTrackProbeActive,
    bool? routeDraftStraightLineFallback,
    int? routeDraftNextMarkerId,
    int? routeDraftRequestId,
    RouteElevationSummary? routeDraftElevationSummary,
    bool clearRouteDraftElevationSummary = false,
    bool? routeDraftElevationLoading,
    String? routeDraftElevationError,
    bool clearRouteDraftElevationError = false,
    List<double?>? routeDraftPointElevations,
    bool clearRouteDraftPointElevations = false,
    bool clearRouteDraftPeak = false,
    int? routeDraftElevationRequestId,
    int? routeDraftGeometryVersion,
    bool? routeDraftNameFieldFocused,
    bool? routeDraftPeakTargetLocked,
    bool? routeDraftCanUndo,
    bool? routeDraftCanRedo,
    bool? syncEnabled,
    List<Peak>? peaks,
    bool? isLoadingPeaks,
    List<Peak>? searchResults,
    String? searchQuery,
    List<Peak>? selectedPeaks,
    Tasmap50k? selectedMap,
    TasmapDisplayMode? tasmapDisplayMode,
    MapGridVisibility? gridVisibility,
    List<Tasmap50k>? mapSuggestions,
    String? mapSearchQuery,
    int? selectedMapFocusSerial,
    int? selectedTrackFocusSerial,
    int? selectedRouteFocusSerial,
    List<GpxTrack>? tracks,
    bool? showTracks,
    bool? showRoutes,
    bool? showTrails,
    PeakListSelectionMode? peakListSelectionMode,
    Set<int>? selectedPeakListIds,
    bool clearSelectedPeakListIds = false,
    Set<int>? previousSpecificPeakListIds,
    bool clearPreviousSpecificPeakListIds = false,
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
    PeakInfoPopupMode? peakInfoPopupMode,
    bool clearPeakInfoPopup = false,
    DriveEtaPopupState? driveEtaPopup,
    bool clearDriveEtaPopup = false,
    int? hoveredTrackId,
    bool clearHoveredTrackId = false,
    int? hoveredRouteId,
    bool clearHoveredRouteId = false,
    String? hoveredRouteDraftMarkerId,
    bool clearHoveredRouteDraftMarkerId = false,
    int? hoveredRouteDraftSegmentIndex,
    int? hoveredRouteDraftCommittedSegmentIndex,
    bool clearHoveredRouteDraftSegmentPreview = false,
    LatLng? hoveredRouteDraftSegmentPoint,
    int? selectedTrackId,
    bool clearSelectedTrackId = false,
    int? selectedRouteId,
    bool clearSelectedRouteId = false,
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
      cursorPoint: clearCursorMgrs ? null : (cursorPoint ?? this.cursorPoint),
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
      isRouteDrafting: isRouteDrafting ?? this.isRouteDrafting,
      isSavingRoute: isSavingRoute ?? this.isSavingRoute,
      routeDraftName: routeDraftName ?? this.routeDraftName,
      routeDraftNameError: clearRouteDraftNameError
          ? null
          : (routeDraftNameError ?? this.routeDraftNameError),
      routeDraftMode: routeDraftMode ?? this.routeDraftMode,
      routeDraftPeak: clearRouteDraftPeak
          ? null
          : (routeDraftPeak ?? this.routeDraftPeak),
      routeDraftControlEndpoints:
          routeDraftControlEndpoints ?? this.routeDraftControlEndpoints,
      routeDraftDisplayMarkers:
          routeDraftDisplayMarkers ?? this.routeDraftDisplayMarkers,
      routeDraftMarkers: routeDraftMarkers ?? this.routeDraftMarkers,
      routeDraftStage: routeDraftStage ?? this.routeDraftStage,
      routeDraftError: clearRouteDraftError
          ? null
          : (routeDraftError ?? this.routeDraftError),
      routeDraftFailureKind:
          routeDraftFailureKind ?? this.routeDraftFailureKind,
      routeDraftColour: routeDraftColour ?? this.routeDraftColour,
      routeDraftCommittedPoints:
          routeDraftCommittedPoints ?? this.routeDraftCommittedPoints,
      routeDraftProvisionalPoints:
          routeDraftProvisionalPoints ?? this.routeDraftProvisionalPoints,
      routeDraftDistanceMeters:
          routeDraftDistanceMeters ?? this.routeDraftDistanceMeters,
      routeDraftOffTrackProbeActive:
          routeDraftOffTrackProbeActive ?? this.routeDraftOffTrackProbeActive,
      routeDraftStraightLineFallback:
          routeDraftStraightLineFallback ?? this.routeDraftStraightLineFallback,
      routeDraftNextMarkerId:
          routeDraftNextMarkerId ?? this.routeDraftNextMarkerId,
      routeDraftRequestId: routeDraftRequestId ?? this.routeDraftRequestId,
      routeDraftElevationSummary: clearRouteDraftElevationSummary
          ? null
          : (routeDraftElevationSummary ?? this.routeDraftElevationSummary),
      routeDraftElevationLoading:
          routeDraftElevationLoading ?? this.routeDraftElevationLoading,
      routeDraftElevationError: clearRouteDraftElevationError
          ? null
          : (routeDraftElevationError ?? this.routeDraftElevationError),
      routeDraftPointElevations: clearRouteDraftPointElevations
          ? const []
          : (routeDraftPointElevations ?? this.routeDraftPointElevations),
      routeDraftElevationRequestId:
          routeDraftElevationRequestId ?? this.routeDraftElevationRequestId,
      routeDraftGeometryVersion:
          routeDraftGeometryVersion ?? this.routeDraftGeometryVersion,
      routeDraftNameFieldFocused:
          routeDraftNameFieldFocused ?? this.routeDraftNameFieldFocused,
      routeDraftPeakTargetLocked:
          routeDraftPeakTargetLocked ?? this.routeDraftPeakTargetLocked,
      routeDraftCanUndo: routeDraftCanUndo ?? this.routeDraftCanUndo,
      routeDraftCanRedo: routeDraftCanRedo ?? this.routeDraftCanRedo,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      peaks: peaks ?? this.peaks,
      isLoadingPeaks: isLoadingPeaks ?? this.isLoadingPeaks,
      searchResults: searchResults ?? this.searchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedPeaks: selectedPeaks ?? this.selectedPeaks,
      selectedMap: selectedMap ?? this.selectedMap,
      tasmapDisplayMode: tasmapDisplayMode ?? this.tasmapDisplayMode,
      gridVisibility: gridVisibility ?? this.gridVisibility,
      mapSuggestions: mapSuggestions ?? this.mapSuggestions,
      mapSearchQuery: mapSearchQuery ?? this.mapSearchQuery,
      selectedMapFocusSerial:
          selectedMapFocusSerial ?? this.selectedMapFocusSerial,
      selectedTrackFocusSerial:
          selectedTrackFocusSerial ?? this.selectedTrackFocusSerial,
      selectedRouteFocusSerial:
          selectedRouteFocusSerial ?? this.selectedRouteFocusSerial,
      hoveredRouteId: clearHoveredRouteId
          ? null
          : (hoveredRouteId ?? this.hoveredRouteId),
      hoveredRouteDraftMarkerId: clearHoveredRouteDraftMarkerId
          ? null
          : (hoveredRouteDraftMarkerId ?? this.hoveredRouteDraftMarkerId),
      hoveredRouteDraftSegmentIndex: clearHoveredRouteDraftSegmentPreview
          ? null
          : (hoveredRouteDraftSegmentIndex ??
                this.hoveredRouteDraftSegmentIndex),
      hoveredRouteDraftCommittedSegmentIndex:
          clearHoveredRouteDraftSegmentPreview
          ? null
          : (hoveredRouteDraftCommittedSegmentIndex ??
                this.hoveredRouteDraftCommittedSegmentIndex),
      hoveredRouteDraftSegmentPoint: clearHoveredRouteDraftSegmentPreview
          ? null
          : (hoveredRouteDraftSegmentPoint ??
                this.hoveredRouteDraftSegmentPoint),
      tracks: tracks ?? this.tracks,
      showTracks: showTracks ?? this.showTracks,
      showRoutes: showRoutes ?? this.showRoutes,
      showTrails: showTrails ?? this.showTrails,
      peakListSelectionMode:
          peakListSelectionMode ?? this.peakListSelectionMode,
      selectedPeakListIds: clearSelectedPeakListIds
          ? const <int>{}
          : selectedPeakListIds == null
          ? this.selectedPeakListIds
          : _immutablePeakListIds(selectedPeakListIds),
      previousSpecificPeakListIds: clearPreviousSpecificPeakListIds
          ? const <int>{}
          : previousSpecificPeakListIds == null
          ? this.previousSpecificPeakListIds
          : _immutablePeakListIds(previousSpecificPeakListIds),
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
      peakInfoPopupMode: clearPeakInfoPopup
          ? null
          : (peakInfoPopupMode ?? this.peakInfoPopupMode),
      driveEtaPopup: clearDriveEtaPopup
          ? null
          : (driveEtaPopup ?? this.driveEtaPopup),
      hoveredTrackId: clearHoveredTrackId
          ? null
          : (hoveredTrackId ?? this.hoveredTrackId),
      selectedTrackId: clearSelectedTrackId
          ? null
          : (selectedTrackId ?? this.selectedTrackId),
      selectedRouteId: clearSelectedRouteId
          ? null
          : (selectedRouteId ?? this.selectedRouteId),
      pendingCameraRequest: clearPendingCameraRequest
          ? null
          : (pendingCameraRequest ?? this.pendingCameraRequest),
      cameraRequestSerial: cameraRequestSerial ?? this.cameraRequestSerial,
    );
  }
}

final mapProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);

final mapPreferencesLoaderProvider =
    Provider<Future<SharedPreferences> Function()>((ref) {
      return SharedPreferences.getInstance;
    });

typedef _RouteDraftSnapshot = ({
  bool isRouteDrafting,
  bool isSavingRoute,
  String? routeDraftNameError,
  RouteMode routeDraftMode,
  Peak? routeDraftPeak,
  bool routeDraftPeakTargetLocked,
  List<RouteDraftControlEndpoint> routeDraftControlEndpoints,
  List<RouteDraftDisplayMarker> routeDraftDisplayMarkers,
  List<LatLng> routeDraftMarkers,
  RouteDraftStage routeDraftStage,
  String? routeDraftError,
  RoutePlanningFailureKind routeDraftFailureKind,
  int routeDraftColour,
  List<LatLng> routeDraftCommittedPoints,
  List<LatLng> routeDraftProvisionalPoints,
  double routeDraftDistanceMeters,
  bool routeDraftOffTrackProbeActive,
  bool routeDraftStraightLineFallback,
  int routeDraftNextMarkerId,
  int routeDraftRequestId,
  RouteElevationSummary? routeDraftElevationSummary,
  bool routeDraftElevationLoading,
  String? routeDraftElevationError,
  List<double?> routeDraftPointElevations,
  int routeDraftElevationRequestId,
  int routeDraftGeometryVersion,
  bool routeDraftNameFieldFocused,
  bool routeDraftCanUndo,
  bool routeDraftCanRedo,
});

final routeElevationSamplerProvider = Provider<RouteElevationSampler>((ref) {
  return BundledDemRouteElevationSampler();
});

final gpxTrackRepositoryProvider = Provider<GpxTrackRepository>((ref) {
  return GpxTrackRepository(objectboxStore);
});

final trackAvailabilityProvider = Provider<TrackAvailabilityState>((ref) {
  final (:tracks, :isLoadingTracks, :hasTrackRecoveryIssue) = ref.watch(
    mapProvider.select(
      (state) => (
        tracks: state.tracks,
        isLoadingTracks: state.isLoadingTracks,
        hasTrackRecoveryIssue: state.hasTrackRecoveryIssue,
      ),
    ),
  );

  if (isLoadingTracks) {
    return const TrackAvailabilityState.loading();
  }
  if (hasTrackRecoveryIssue) {
    return const TrackAvailabilityState.recoveryDisabled();
  }
  if (tracks.isEmpty) {
    return const TrackAvailabilityState.empty();
  }
  return const TrackAvailabilityState.available();
});

enum TrackAvailabilityStatus { loading, recoveryDisabled, empty, available }

class TrackAvailabilityState {
  const TrackAvailabilityState._(this.status);

  const TrackAvailabilityState.loading()
    : this._(TrackAvailabilityStatus.loading);

  const TrackAvailabilityState.recoveryDisabled()
    : this._(TrackAvailabilityStatus.recoveryDisabled);

  const TrackAvailabilityState.empty() : this._(TrackAvailabilityStatus.empty);

  const TrackAvailabilityState.available()
    : this._(TrackAvailabilityStatus.available);

  final TrackAvailabilityStatus status;

  bool get isEnabled => status == TrackAvailabilityStatus.available;

  String? get helperText {
    return switch (status) {
      TrackAvailabilityStatus.loading => 'Loading tracks...',
      TrackAvailabilityStatus.recoveryDisabled =>
        'Tracks unavailable during recovery',
      TrackAvailabilityStatus.empty => 'No tracks loaded',
      TrackAvailabilityStatus.available => null,
    };
  }
}

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
  Future<void> _peakListSelectionPersistChain = Future<void>.value();

  MapNotifier({
    PeakRepository? peakRepository,
    OverpassService? overpassService,
    TasmapRepository? tasmapRepository,
    GpxTrackRepository? gpxTrackRepository,
    RouteRepository? routeRepository,
    RouteElevationSampler? routeElevationSampler,
    RoutePlanner? routePlanner,
    PeaksBaggedRepository? peaksBaggedRepository,
    MigrationMarkerStore? migrationMarkerStore,
    bool loadPositionOnBuild = true,
    bool loadPeaksOnBuild = true,
    bool loadTracksOnBuild = true,
  }) : _injectedPeakRepository = peakRepository,
       _injectedOverpassService = overpassService,
       _injectedTasmapRepository = tasmapRepository,
       _injectedGpxTrackRepository = gpxTrackRepository,
       _injectedRouteRepository = routeRepository,
       _injectedRouteElevationSampler = routeElevationSampler,
       _injectedRoutePlanner = routePlanner,
       _injectedPeaksBaggedRepository = peaksBaggedRepository,
       _injectedMigrationMarkerStore = migrationMarkerStore,
       _loadPositionOnBuild = loadPositionOnBuild,
       _loadPeaksOnBuild = loadPeaksOnBuild,
       _loadTracksOnBuild = loadTracksOnBuild;

  final PeakRepository? _injectedPeakRepository;
  final OverpassService? _injectedOverpassService;
  final TasmapRepository? _injectedTasmapRepository;
  final GpxTrackRepository? _injectedGpxTrackRepository;
  final RouteRepository? _injectedRouteRepository;
  final RouteElevationSampler? _injectedRouteElevationSampler;
  final RoutePlanner? _injectedRoutePlanner;
  final PeaksBaggedRepository? _injectedPeaksBaggedRepository;
  final MigrationMarkerStore? _injectedMigrationMarkerStore;
  final bool _loadPositionOnBuild;
  final bool _loadPeaksOnBuild;
  final bool _loadTracksOnBuild;

  late final PeakRepository _peakRepository;
  late final PeakRefreshService _peakRefreshService;
  late final TasmapRepository _tasmapRepository;
  late final GpxTrackRepository _gpxTrackRepository;
  late final RouteRepository _routeRepository;
  late final RouteElevationSampler _routeElevationSampler;
  late final RoutePlanner _routePlanner;
  late final PeaksBaggedRepository _peaksBaggedRepository;
  late final MigrationMarkerStore _migrationMarkerStore;
  late final ItemVisibilityBackfillService _itemVisibilityBackfillService;
  late final Future<SharedPreferences> Function() _prefsLoader;
  bool _recoverySnackbarShown = false;
  String? _pendingTrackSnackbarMessage;
  String? _pendingStartupBackfillWarningMessage;
  String? _pendingRouteSnackbarMessage;
  final List<_RouteDraftSnapshot> _routeDraftUndoStack = [];
  final List<_RouteDraftSnapshot> _routeDraftRedoStack = [];
  String? _activeRouteDraftDragMarkerId;
  bool _isRestoringRouteDraftHistory = false;
  bool _isRestoringVisibilityPrefs = false;
  bool _showTracksRestoreOverridden = false;
  bool _showRoutesRestoreOverridden = false;
  bool _showTrailsRestoreOverridden = false;

  TasmapRepository get tasmapRepository =>
      _injectedTasmapRepository ?? _tasmapRepository;

  String mapNameForMgrs(String mgrsText) {
    try {
      return _tasmapRepository.findByMgrsCodeAndCoordinates(mgrsText)?.name ??
          'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  String mapNameForPoint(LatLng point) {
    try {
      return _tasmapRepository.findByPoint(point)?.name ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  Set<int> get correlatedPeakIds => buildCorrelatedPeakIds(state.tracks);

  @override
  MapState build() {
    ref.listen<int>(peaksBaggedRevisionProvider, (previous, next) {
      refreshPeakInfoPopupContent();
    });
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
    _routeRepository =
        _injectedRouteRepository ?? ref.read(routeRepositoryProvider);
    _routeElevationSampler =
        _injectedRouteElevationSampler ??
        ref.read(routeElevationSamplerProvider);
    _routePlanner = _injectedRoutePlanner ?? ref.read(routePlannerProvider);
    _peaksBaggedRepository =
        _injectedPeaksBaggedRepository ?? PeaksBaggedRepository(objectboxStore);
    _migrationMarkerStore =
        _injectedMigrationMarkerStore ?? const MigrationMarkerStore();
    _itemVisibilityBackfillService = ItemVisibilityBackfillService(
      routeRepository: _routeRepository,
      gpxTrackRepository: _gpxTrackRepository,
      migrationMarkerStore: _migrationMarkerStore,
    );
    _prefsLoader = ref.read(mapPreferencesLoaderProvider);
    Future.microtask(_runStartupLoad);
    return MapState(
      center: MapConstants.defaultCenter,
      zoom: MapConstants.defaultZoom,
      basemap: Basemap.tracestrack,
      isFirstLaunch: true,
      selectedLocation: MapConstants.defaultCenter,
    );
  }

  Future<void> _runStartupLoad() async {
    await _backfillItemVisibility();
    await _restoreVisibilityPrefs();
    if (_loadPositionOnBuild) {
      await _loadPosition();
    }
    if (_loadPeaksOnBuild) {
      await _loadPeaks();
    }
    if (_loadTracksOnBuild) {
      await _loadTracks();
    }
  }

  Future<void> _backfillItemVisibility() async {
    try {
      final changed = await _itemVisibilityBackfillService
          .backfillVisibleItems();
      if (changed) {
        ref.read(routeRevisionProvider.notifier).increment();
      }
    } catch (e) {
      _pendingStartupBackfillWarningMessage =
          'Failed to restore route/track visibility: $e';
    }
  }

  Future<void> _restoreVisibilityPrefs() async {
    _isRestoringVisibilityPrefs = true;
    try {
      final prefs = await _prefsLoader();
      final showTracks = prefs.getBool(_showTracksKey) ?? false;
      final showRoutes = prefs.getBool(_showRoutesKey) ?? false;
      final showTrails = prefs.getBool(_showTrailsKey) ?? false;
      state = state.copyWith(
        showTracks: _showTracksRestoreOverridden ? null : showTracks,
        showRoutes: _showRoutesRestoreOverridden ? null : showRoutes,
        showTrails: _showTrailsRestoreOverridden ? null : showTrails,
      );
    } catch (_) {
      // Continue with defaults on read failure.
    } finally {
      _isRestoringVisibilityPrefs = false;
    }
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
        addedItems.add(GpxTrackImportItem(track: item.track));
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
            // Placement failed - track is persisted, recovery is pending.
          }
        }
      }

      // Refresh tracks from repository
      final allTracks = _gpxTrackRepository.getAllTracks();
      if (addedItems.isNotEmpty) {
        await _peaksBaggedRepository.syncFromTracks(allTracks);
        ref.read(peaksBaggedRevisionProvider.notifier).increment();
      }

      final selectedImportedTrack = addedItems.isNotEmpty
          ? addedItems.first.track
          : null;

      state = state.copyWith(
        tracks: allTracks,
        selectedTrackId:
            selectedImportedTrack?.gpxTrackId ?? state.selectedTrackId,
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
      state = state.copyWith(isLoadingTracks: false, clearHoveredTrackId: true);
      rethrow;
    }
  }

  Future<GpxImportResult<GpxRouteImportItem>> importRouteFiles({
    required Map<String, String> pathToEditedNames,
  }) async {
    if (state.isLoadingTracks) {
      throw Exception('Import already in progress');
    }

    state = state.copyWith(
      isLoadingTracks: true,
      clearTrackImportError: true,
      clearTrackOperationStatus: true,
      clearTrackOperationWarning: true,
      clearHoveredTrackId: true,
      clearSelectedTrackId: true,
      clearSelectedRouteId: true,
    );

    try {
      final importer = GpxImporter();
      final addedItems = <GpxRouteImportItem>[];
      var errorCount = 0;

      for (final entry in pathToEditedNames.entries) {
        final route = importer.parseRouteFile(entry.key);
        if (route == null) {
          errorCount += 1;
          continue;
        }

        final editedName = entry.value.trim();
        if (editedName.isNotEmpty) {
          route.name = editedName;
        }

        route.colour = 0xFFFF0000;

        await _enrichImportedRoute(route);

        final savedRoute = _routeRepository.saveRoute(route);
        addedItems.add(GpxRouteImportItem(route: savedRoute));
      }

      if (addedItems.isNotEmpty) {
        ref.read(routeRevisionProvider.notifier).increment();
      }

      final importedRoute = addedItems.isNotEmpty
          ? addedItems.first.route
          : null;
      final statusMessage = addedItems.isEmpty
          ? 'No routes were imported'
          : 'Imported ${addedItems.length} route(s), errors $errorCount';
      _pendingRouteSnackbarMessage = statusMessage;
      state = state.copyWith(
        isLoadingTracks: false,
        showRoutes: addedItems.isNotEmpty ? true : state.showRoutes,
        selectedRouteId: importedRoute?.id ?? state.selectedRouteId,
        clearSelectedTrackId: true,
        clearHoveredTrackId: true,
      );

      return GpxImportResult<GpxRouteImportItem>(
        items: addedItems,
        addedCount: addedItems.length,
        unchangedCount: 0,
        nonTasmanianCount: 0,
        errorCount: errorCount,
        warningMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingTracks: false,
        trackImportError: 'Failed to import routes: $e',
        clearHoveredTrackId: true,
        clearSelectedTrackId: true,
        clearSelectedRouteId: true,
      );
      rethrow;
    }
  }

  Future<void> _enrichImportedRoute(Route route) async {
    if (route.gpxRoute.isEmpty) {
      return;
    }

    route.distance2d = _polylineDistanceMeters(route.gpxRoute).roundToDouble();

    final fallbackElevations = List<int?>.from(route.gpxRouteElevations);
    try {
      final sampledElevations = await _routeElevationSampler
          .samplePointElevations(route.gpxRoute);
      if (sampledElevations.isNotEmpty) {
        final mergedElevations = List<int?>.generate(route.gpxRoute.length, (
          index,
        ) {
          final sampledElevation = index < sampledElevations.length
              ? sampledElevations[index]
              : null;
          if (sampledElevation != null) {
            return sampledElevation.round();
          }
          return index < fallbackElevations.length
              ? fallbackElevations[index]
              : null;
        }, growable: false);

        if (mergedElevations.any((elevation) => elevation != null)) {
          route.gpxRouteElevations = mergedElevations;
        }
      }
    } catch (_) {
      // Keep file elevations if point sampling is unavailable.
    }

    try {
      final summary = await _routeElevationSampler.sampleRoute(
        points: route.gpxRoute,
        requestId: 0,
        geometryVersion: 0,
      );
      route.distance3d = summary.distance3d;
      route.ascent = summary.ascent;
      route.descent = summary.descent;
      route.startElevation = summary.startElevation;
      route.endElevation = summary.endElevation;
      route.lowestElevation = summary.lowestElevation;
      route.highestElevation = summary.highestElevation;
      return;
    } catch (_) {
      // Fall back to elevations parsed from the GPX file.
    }

    final fallbackSummary = _routeSummaryFromElevations(
      route.gpxRoute,
      route.gpxRouteElevations,
    );
    if (fallbackSummary == null) {
      return;
    }

    route.distance3d = fallbackSummary.distance3d;
    route.ascent = fallbackSummary.ascent;
    route.descent = fallbackSummary.descent;
    route.startElevation = fallbackSummary.startElevation;
    route.endElevation = fallbackSummary.endElevation;
    route.lowestElevation = fallbackSummary.lowestElevation;
    route.highestElevation = fallbackSummary.highestElevation;
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
    } else {
      await io.File(sourcePath).rename(targetPath);
    }

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

    state = state.copyWith(clearHoveredTrackId: true);
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
    track.averageSpeedKmh = result.stats.averageSpeedKmh ?? 0.0;
    track.movingSpeedKmh = result.stats.movingSpeedKmh ?? 0.0;
    track.maxSpeedKmh = result.stats.maxSpeedKmh ?? 0.0;
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

  String? consumeRouteSnackbarMessage() {
    final message = _pendingRouteSnackbarMessage;
    _pendingRouteSnackbarMessage = null;
    return message;
  }

  String? consumeStartupBackfillWarningMessage() {
    final message = _pendingStartupBackfillWarningMessage;
    _pendingStartupBackfillWarningMessage = null;
    return message;
  }

  Future<void> _loadPosition() async {
    try {
      final prefs = await _prefsLoader();
      final lat = prefs.getDouble(_latKey);
      final lng = prefs.getDouble(_lngKey);
      final zoom = prefs.getDouble(_zoomKey);
      final peakListSelectionMode = _parsePeakListSelectionMode(
        prefs.getString(_peakListSelectionModeV2Key),
      );
      final selectedPeakListIds = _decodePeakListIds(
        prefs.getString(_peakListSelectedIdsV2Key),
      );
      final previousSpecificPeakListIds = _decodePeakListIds(
        prefs.getString(_peakListPreviousSpecificIdsV2Key),
      );

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

      if (selectedPeakListIds == null || previousSpecificPeakListIds == null) {
        developer.log(
          'Resetting corrupt v2 peak list selection prefs.',
          name: 'map_provider',
        );
        state = state.copyWith(
          peakListSelectionMode: PeakListSelectionMode.allPeaks,
          clearSelectedPeakListIds: true,
          clearPreviousSpecificPeakListIds: true,
        );
        return;
      }

      state = state.copyWith(
        peakListSelectionMode: peakListSelectionMode,
        selectedPeakListIds: selectedPeakListIds,
        previousSpecificPeakListIds: previousSpecificPeakListIds,
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
      final prefs = await _prefsLoader();
      await prefs.setDouble(_latKey, state.center.latitude);
      await prefs.setDouble(_lngKey, state.center.longitude);
      await prefs.setDouble(_zoomKey, state.zoom);
      state = state.copyWith(isFirstLaunch: false);
    } catch (e) {
      // Continue without saving
    }
  }

  Future<void> persistPeakListSelection() async {
    final mode = state.peakListSelectionMode;
    final selectedPeakListIds = state.selectedPeakListIds;
    final previousSpecificPeakListIds = state.previousSpecificPeakListIds;
    _peakListSelectionPersistChain = _peakListSelectionPersistChain.then((
      _,
    ) async {
      try {
        final prefs = await _prefsLoader();
        await prefs.setString(_peakListSelectionModeV2Key, mode.name);
        await prefs.setString(
          _peakListSelectedIdsV2Key,
          _encodePeakListIds(selectedPeakListIds),
        );
        await prefs.setString(
          _peakListPreviousSpecificIdsV2Key,
          _encodePeakListIds(previousSpecificPeakListIds),
        );
        await prefs.remove(_legacyPeakListSelectionModeKey);
        await prefs.remove(_legacyPeakListIdKey);
      } catch (e) {
        // Continue without saving
      }
    });
    await _peakListSelectionPersistChain;
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
          request.selectedLocationBehavior ==
          PendingCameraSelectionBehavior.clear,
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

  RouteDraftControlEndpoint _createControlEndpoint({
    required LatLng point,
    required RouteDraftEndpointKind kind,
    String? id,
  }) {
    return RouteDraftControlEndpoint(
      id: id ?? '${state.routeDraftNextMarkerId}',
      point: point,
      kind: kind,
    );
  }

  RouteDraftEndpointKind _manualEndpointKindForPoint(LatLng point) {
    return _peakAtPoint(state.peaks, point) == null
        ? RouteDraftEndpointKind.tapped
        : RouteDraftEndpointKind.peakTarget;
  }

  String _routeDraftEndpointId(int serial) => '$serial';

  int _visibleNumberedRouteMarkerCount(
    List<RouteDraftControlEndpoint> controlEndpoints,
  ) {
    if (controlEndpoints.length < 3) {
      return 0;
    }

    var count = 0;
    for (var index = 1; index < controlEndpoints.length - 1; index++) {
      if (controlEndpoints[index].kind != RouteDraftEndpointKind.peakTarget) {
        count += 1;
      }
    }
    return count;
  }

  bool _hasReachedRouteDraftMarkerLimit() {
    return state.routeDraftControlEndpoints.length >= 2 &&
        _visibleNumberedRouteMarkerCount(state.routeDraftControlEndpoints) >=
            99;
  }

  List<RouteDraftDisplayMarker> _buildDisplayMarkers(
    List<RouteDraftControlEndpoint> controlEndpoints, {
    String? provisionalEndpointId,
  }) {
    var nextNumber = 1;

    return [
      for (var index = 0; index < controlEndpoints.length; index++)
        RouteDraftDisplayMarker(
          id: controlEndpoints[index].id,
          point: controlEndpoints[index].point,
          kind: switch ((index, controlEndpoints[index].kind)) {
            (0, _) => RouteMarkerKind.circle,
            (_, RouteDraftEndpointKind.peakTarget) => RouteMarkerKind.target,
            (_, _) when index == controlEndpoints.length - 1 =>
              RouteMarkerKind.target,
            (_, _) => RouteMarkerKind.numbered,
          },
          number: switch ((index, controlEndpoints[index].kind)) {
            (0, _) => null,
            (_, RouteDraftEndpointKind.peakTarget) => null,
            (_, _) when index == controlEndpoints.length - 1 => null,
            (_, _) => nextNumber++,
          },
          isCommitted: controlEndpoints[index].id != provisionalEndpointId,
        ),
    ];
  }

  LatLng? _lastRouteDraftControlPoint() {
    if (state.routeDraftControlEndpoints.isEmpty) {
      return null;
    }
    return state.routeDraftControlEndpoints.last.point;
  }

  RouteDraftEndpointKind _endpointKindFromAnchor(
    RouteEndpointAnchor? anchor, {
    bool isPeakTarget = false,
  }) {
    if (isPeakTarget) {
      return RouteDraftEndpointKind.peakTarget;
    }
    return switch (anchor?.type) {
      RouteEndpointAnchorType.node => RouteDraftEndpointKind.snappedNode,
      RouteEndpointAnchorType.edgeProjection =>
        RouteDraftEndpointKind.projectedAnchor,
      _ => RouteDraftEndpointKind.tapped,
    };
  }

  List<LatLng> _appendPeakTerminalLegIfNeeded(
    List<LatLng> points,
    LatLng peakPoint,
  ) {
    if (points.isEmpty || points.last == peakPoint) {
      return List<LatLng>.from(points, growable: false);
    }
    return [...points, peakPoint];
  }

  double _polylineDistanceMeters(List<LatLng> points) {
    if (points.length < 2) {
      return 0;
    }
    var distance = 0.0;
    for (var index = 0; index < points.length - 1; index++) {
      distance += _distance.as(
        LengthUnit.Meter,
        points[index],
        points[index + 1],
      );
    }
    return distance;
  }

  _RouteSummary? _routeSummaryFromElevations(
    List<LatLng> points,
    List<int?> elevations,
  ) {
    if (points.length < 2 || elevations.isEmpty) {
      return null;
    }

    final elevationSamples = elevations
        .map((value) => value?.toDouble())
        .toList(growable: false);
    final filteredElevations = elevationSamples.whereType<double>().toList(
      growable: false,
    );
    if (filteredElevations.isEmpty) {
      return null;
    }

    var distance3d = 0.0;
    for (var index = 1; index < points.length; index++) {
      final distance2d = _distance.as(
        LengthUnit.Meter,
        points[index - 1],
        points[index],
      );
      final previousElevation = index - 1 < elevationSamples.length
          ? elevationSamples[index - 1]
          : null;
      final currentElevation = index < elevationSamples.length
          ? elevationSamples[index]
          : null;
      if (previousElevation == null || currentElevation == null) {
        distance3d += distance2d;
      } else {
        final elevationDelta = currentElevation - previousElevation;
        distance3d += math.sqrt(
          distance2d * distance2d + elevationDelta * elevationDelta,
        );
      }
    }

    final uphillDownhill = calculateUphillDownhill(elevationSamples);
    return _RouteSummary(
      distance3d: distance3d.roundToDouble(),
      ascent: uphillDownhill.uphill.roundToDouble(),
      descent: uphillDownhill.downhill.roundToDouble(),
      startElevation: filteredElevations.first.roundToDouble(),
      endElevation: filteredElevations.last.roundToDouble(),
      lowestElevation: filteredElevations.reduce(math.min).roundToDouble(),
      highestElevation: filteredElevations.reduce(math.max).roundToDouble(),
    );
  }

  _RouteDraftSnapshot _captureRouteDraftSnapshot() {
    return (
      isRouteDrafting: state.isRouteDrafting,
      isSavingRoute: state.isSavingRoute,
      routeDraftNameError: state.routeDraftNameError,
      routeDraftMode: state.routeDraftMode,
      routeDraftPeak: state.routeDraftPeak,
      routeDraftPeakTargetLocked: state.routeDraftPeakTargetLocked,
      routeDraftControlEndpoints: List<RouteDraftControlEndpoint>.unmodifiable(
        state.routeDraftControlEndpoints,
      ),
      routeDraftDisplayMarkers: List<RouteDraftDisplayMarker>.unmodifiable(
        state.routeDraftDisplayMarkers,
      ),
      routeDraftMarkers: List<LatLng>.unmodifiable(state.routeDraftMarkers),
      routeDraftStage: state.routeDraftStage,
      routeDraftError: state.routeDraftError,
      routeDraftFailureKind: state.routeDraftFailureKind,
      routeDraftColour: state.routeDraftColour,
      routeDraftCommittedPoints: List<LatLng>.unmodifiable(
        state.routeDraftCommittedPoints,
      ),
      routeDraftProvisionalPoints: List<LatLng>.unmodifiable(
        state.routeDraftProvisionalPoints,
      ),
      routeDraftDistanceMeters: state.routeDraftDistanceMeters,
      routeDraftOffTrackProbeActive: state.routeDraftOffTrackProbeActive,
      routeDraftStraightLineFallback: state.routeDraftStraightLineFallback,
      routeDraftNextMarkerId: state.routeDraftNextMarkerId,
      routeDraftRequestId: state.routeDraftRequestId,
      routeDraftElevationSummary: state.routeDraftElevationSummary,
      routeDraftElevationLoading: state.routeDraftElevationLoading,
      routeDraftElevationError: state.routeDraftElevationError,
      routeDraftPointElevations: List<double?>.unmodifiable(
        state.routeDraftPointElevations,
      ),
      routeDraftElevationRequestId: state.routeDraftElevationRequestId,
      routeDraftGeometryVersion: state.routeDraftGeometryVersion,
      routeDraftNameFieldFocused: state.routeDraftNameFieldFocused,
      routeDraftCanUndo: state.routeDraftCanUndo,
      routeDraftCanRedo: state.routeDraftCanRedo,
    );
  }

  void _syncRouteDraftHistoryAvailability() {
    state = state.copyWith(
      routeDraftCanUndo: _routeDraftUndoStack.isNotEmpty,
      routeDraftCanRedo: _routeDraftRedoStack.isNotEmpty,
    );
  }

  void _pushRouteDraftHistory() {
    if (!state.isRouteDrafting || _isRestoringRouteDraftHistory) {
      return;
    }

    _routeDraftUndoStack.add(_captureRouteDraftSnapshot());
    _routeDraftRedoStack.clear();
    _syncRouteDraftHistoryAvailability();
  }

  void _restoreRouteDraftSnapshot(_RouteDraftSnapshot snapshot) {
    final requestIdFloor = math.max(
      state.routeDraftRequestId,
      snapshot.routeDraftRequestId,
    );
    final elevationRequestIdFloor = math.max(
      state.routeDraftElevationRequestId,
      snapshot.routeDraftElevationRequestId,
    );
    final geometryVersionFloor = math.max(
      state.routeDraftGeometryVersion,
      snapshot.routeDraftGeometryVersion,
    );

    _isRestoringRouteDraftHistory = true;
    try {
      state = state.copyWith(
        isRouteDrafting: snapshot.isRouteDrafting,
        isSavingRoute: snapshot.isSavingRoute,
        routeDraftNameError: snapshot.routeDraftNameError,
        routeDraftMode: snapshot.routeDraftMode,
        routeDraftPeak: snapshot.routeDraftPeak,
        routeDraftPeakTargetLocked: snapshot.routeDraftPeakTargetLocked,
        routeDraftControlEndpoints: snapshot.routeDraftControlEndpoints,
        routeDraftDisplayMarkers: snapshot.routeDraftDisplayMarkers,
        routeDraftMarkers: snapshot.routeDraftMarkers,
        routeDraftStage: snapshot.routeDraftStage,
        routeDraftError: snapshot.routeDraftError,
        routeDraftFailureKind: snapshot.routeDraftFailureKind,
        routeDraftColour: snapshot.routeDraftColour,
        routeDraftCommittedPoints: snapshot.routeDraftCommittedPoints,
        routeDraftProvisionalPoints: snapshot.routeDraftProvisionalPoints,
        routeDraftDistanceMeters: snapshot.routeDraftDistanceMeters,
        routeDraftOffTrackProbeActive: snapshot.routeDraftOffTrackProbeActive,
        routeDraftStraightLineFallback: snapshot.routeDraftStraightLineFallback,
        routeDraftNextMarkerId: snapshot.routeDraftNextMarkerId,
        routeDraftRequestId: requestIdFloor,
        routeDraftElevationSummary: snapshot.routeDraftElevationSummary,
        routeDraftElevationLoading: snapshot.routeDraftElevationLoading,
        routeDraftElevationError: snapshot.routeDraftElevationError,
        routeDraftPointElevations: snapshot.routeDraftPointElevations,
        routeDraftElevationRequestId: elevationRequestIdFloor,
        routeDraftGeometryVersion: geometryVersionFloor,
        routeDraftNameFieldFocused: snapshot.routeDraftNameFieldFocused,
        routeDraftCanUndo: snapshot.routeDraftCanUndo,
        routeDraftCanRedo: snapshot.routeDraftCanRedo,
      );
    } finally {
      _isRestoringRouteDraftHistory = false;
    }

    _resampleRouteDraftElevation();
  }

  void undoRouteDraftEdit() {
    if (!state.isRouteDrafting || _routeDraftUndoStack.isEmpty) {
      return;
    }

    _routeDraftRedoStack.add(_captureRouteDraftSnapshot());
    final snapshot = _routeDraftUndoStack.removeLast();
    _restoreRouteDraftSnapshot(snapshot);
    _syncRouteDraftHistoryAvailability();
  }

  void redoRouteDraftEdit() {
    if (!state.isRouteDrafting || _routeDraftRedoStack.isEmpty) {
      return;
    }

    _routeDraftUndoStack.add(_captureRouteDraftSnapshot());
    final snapshot = _routeDraftRedoStack.removeLast();
    _restoreRouteDraftSnapshot(snapshot);
    _syncRouteDraftHistoryAvailability();
  }

  void beginRouteDraft({Peak? peakTarget}) {
    if (state.isRouteDrafting) {
      return;
    }

    _routeDraftUndoStack.clear();
    _routeDraftRedoStack.clear();
    _activeRouteDraftDragMarkerId = null;
    _syncRouteDraftHistoryAvailability();

    state = state.copyWith(
      isRouteDrafting: true,
      isSavingRoute: false,
      routeDraftName: '',
      routeDraftNameError: 'A Route name must be entered',
      routeDraftMode: RouteMode.snapToTrail,
      routeDraftPeak: peakTarget,
      clearHoveredRouteId: true,
      clearHoveredRouteDraftMarkerId: true,
      clearHoveredRouteDraftSegmentPreview: true,
      routeDraftControlEndpoints: const [],
      routeDraftDisplayMarkers: const [],
      routeDraftMarkers: const [],
      routeDraftStage: RouteDraftStage.awaitingStart,
      clearRouteDraftError: true,
      routeDraftColour: 0xFFFF0000,
      routeDraftCommittedPoints: const [],
      routeDraftProvisionalPoints: const [],
      routeDraftDistanceMeters: 0,
      routeDraftOffTrackProbeActive: false,
      routeDraftStraightLineFallback: false,
      routeDraftNextMarkerId: 0,
      routeDraftRequestId: 0,
      clearRouteDraftElevationSummary: true,
      routeDraftElevationLoading: false,
      clearRouteDraftElevationError: true,
      clearRouteDraftPointElevations: true,
      routeDraftElevationRequestId: 0,
      routeDraftGeometryVersion: 0,
      routeDraftNameFieldFocused: false,
      routeDraftPeakTargetLocked: false,
      routeDraftCanUndo: false,
      routeDraftCanRedo: false,
      clearSelectedTrackId: true,
    );
  }

  void endRouteDraft() {
    if (!state.isRouteDrafting &&
        state.routeDraftName.isEmpty &&
        state.routeDraftControlEndpoints.isEmpty &&
        state.routeDraftMode == RouteMode.snapToTrail &&
        state.routeDraftPeak == null) {
      return;
    }

    state = state.copyWith(
      isRouteDrafting: false,
      isSavingRoute: false,
      routeDraftName: '',
      clearRouteDraftNameError: true,
      routeDraftMode: RouteMode.snapToTrail,
      clearRouteDraftPeak: true,
      clearHoveredRouteDraftMarkerId: true,
      clearHoveredRouteDraftSegmentPreview: true,
      routeDraftControlEndpoints: const [],
      routeDraftDisplayMarkers: const [],
      routeDraftMarkers: const [],
      routeDraftStage: RouteDraftStage.inactive,
      clearRouteDraftError: true,
      routeDraftCommittedPoints: const [],
      routeDraftProvisionalPoints: const [],
      routeDraftDistanceMeters: 0,
      routeDraftOffTrackProbeActive: false,
      routeDraftStraightLineFallback: false,
      routeDraftNextMarkerId: 0,
      clearRouteDraftElevationSummary: true,
      routeDraftElevationLoading: false,
      clearRouteDraftElevationError: true,
      clearRouteDraftPointElevations: true,
      routeDraftElevationRequestId: 0,
      routeDraftGeometryVersion: 0,
      routeDraftNameFieldFocused: false,
      routeDraftPeakTargetLocked: false,
      routeDraftCanUndo: false,
      routeDraftCanRedo: false,
    );
    _routeDraftUndoStack.clear();
    _routeDraftRedoStack.clear();
    _activeRouteDraftDragMarkerId = null;
    _syncRouteDraftHistoryAvailability();
  }

  String? _validateRouteDraftName(String value) {
    return value.trim().isEmpty ? 'A Route name must be entered' : null;
  }

  void setRouteDraftNameFieldFocused(bool focused) {
    if (state.routeDraftNameFieldFocused == focused) {
      return;
    }

    state = state.copyWith(routeDraftNameFieldFocused: focused);
  }

  void setRouteDraftMode(RouteMode mode) {
    if (!state.isRouteDrafting ||
        state.routeDraftMode == mode ||
        state.routeDraftStage == RouteDraftStage.routingSegment) {
      return;
    }

    if (mode == RouteMode.routeToPeak && state.routeDraftPeakTarget == null) {
      return;
    }

    _pushRouteDraftHistory();

    state = state.copyWith(routeDraftMode: mode);
    if (mode == RouteMode.routeToPeak && state.routeDraftPeak == null) {
      state = state.copyWith(routeDraftPeak: state.routeDraftPeakTarget);
    }
    if (mode == RouteMode.routeToPeak &&
        state.routeDraftControlEndpoints.isNotEmpty) {
      _startRouteDraftToPeakFrom(_lastRouteDraftControlPoint()!);
    }
  }

  void setRouteDraftName(String value) {
    if (!state.isRouteDrafting || state.routeDraftName == value) {
      return;
    }

    final routeNameError = _validateRouteDraftName(value);

    state = state.copyWith(
      routeDraftName: value,
      routeDraftNameError: routeNameError,
      clearRouteDraftNameError: routeNameError == null,
    );
  }

  void applyRouteDraftOutAndBack() {
    if (!state.isRouteDrafting ||
        state.isSavingRoute ||
        state.routeDraftStage == RouteDraftStage.routingSegment ||
        state.routeDraftCommittedPoints.length < 2) {
      return;
    }

    _pushRouteDraftHistory();

    final committedPoints = List<LatLng>.from(
      state.routeDraftCommittedPoints,
      growable: false,
    );
    if (committedPoints.first == committedPoints.last) {
      return;
    }

    final controlEndpoints = state.routeDraftControlEndpoints;
    if (controlEndpoints.isEmpty ||
        controlEndpoints.first.point != committedPoints.first ||
        controlEndpoints.last.point != committedPoints.last) {
      state = state.copyWith(
        routeDraftError: 'Route draft is inconsistent.',
        routeDraftFailureKind: RoutePlanningFailureKind.generic,
      );
      return;
    }

    _completeRouteDraftReturnLeg(
      committedPoints: committedPoints,
      controlEndpoints: controlEndpoints,
      returnSegment: List<LatLng>.from(committedPoints.reversed),
      nextMarkerId: state.routeDraftNextMarkerId + 1,
      appendReturnEndpoint: true,
    );
  }

  Future<void> applyRouteDraftCloseLoop() async {
    if (!state.isRouteDrafting ||
        state.isSavingRoute ||
        state.routeDraftStage == RouteDraftStage.routingSegment ||
        state.routeDraftStage == RouteDraftStage.segmentFailure ||
        state.routeDraftCommittedPoints.length < 2) {
      return;
    }

    _pushRouteDraftHistory();

    final committedPoints = List<LatLng>.from(
      state.routeDraftCommittedPoints,
      growable: false,
    );
    if (committedPoints.first == committedPoints.last) {
      return;
    }

    final controlEndpoints = state.routeDraftControlEndpoints;
    if (controlEndpoints.isEmpty ||
        controlEndpoints.first.point != committedPoints.first ||
        controlEndpoints.last.point != committedPoints.last) {
      state = state.copyWith(
        routeDraftError: 'Route draft is inconsistent.',
        routeDraftFailureKind: RoutePlanningFailureKind.generic,
      );
      return;
    }

    final requestId = state.routeDraftRequestId + 1;
    final returnEndpoint = controlEndpoints.first.copyWith(
      id: _routeDraftEndpointId(state.routeDraftNextMarkerId),
    );
    state = state.copyWith(
      routeDraftControlEndpoints: [...controlEndpoints, returnEndpoint],
      routeDraftDisplayMarkers: List<RouteDraftDisplayMarker>.unmodifiable(
        _buildDisplayMarkers([
          ...controlEndpoints,
          returnEndpoint,
        ], provisionalEndpointId: returnEndpoint.id),
      ),
      routeDraftMarkers: List<LatLng>.unmodifiable([
        ...controlEndpoints.map((endpoint) => endpoint.point),
        returnEndpoint.point,
      ]),
      routeDraftStage: RouteDraftStage.routingSegment,
      routeDraftProvisionalPoints: [
        committedPoints.last,
        committedPoints.first,
      ],
      clearRouteDraftError: true,
      routeDraftRequestId: requestId,
      routeDraftNextMarkerId: state.routeDraftNextMarkerId + 1,
    );

    final result = await _routePlanner.planSegmentResult(
      start: committedPoints.last,
      end: committedPoints.first,
    );
    if (!_isActiveRouteDraftRequest(requestId)) {
      return;
    }

    switch (result.status) {
      case RoutePlanningStatus.routed:
        _completeRouteDraftReturnLeg(
          committedPoints: committedPoints,
          controlEndpoints: state.routeDraftControlEndpoints,
          returnSegment: _normalizeCloseLoopSegment(
            result.points,
            currentPoint: committedPoints.last,
            startPoint: committedPoints.first,
          ),
          nextMarkerId: null,
          appendReturnEndpoint: false,
        );
        return;
      case RoutePlanningStatus.noPath:
        _completeRouteDraftReturnLeg(
          committedPoints: committedPoints,
          controlEndpoints: state.routeDraftControlEndpoints,
          returnSegment: List<LatLng>.from(committedPoints.reversed),
          nextMarkerId: null,
          appendReturnEndpoint: false,
        );
        return;
      case RoutePlanningStatus.offTrack:
        _completeRouteDraftReturnLeg(
          committedPoints: committedPoints,
          controlEndpoints: state.routeDraftControlEndpoints,
          returnSegment: [committedPoints.last, committedPoints.first],
          nextMarkerId: null,
          appendReturnEndpoint: false,
        );
        return;
      case RoutePlanningStatus.failed:
        _setRouteDraftControlState(
          controlEndpoints: state.routeDraftControlEndpoints,
          stage: RouteDraftStage.segmentFailure,
          provisionalPoints: const [],
          offTrackProbeActive: state.routeDraftOffTrackProbeActive,
          routeDraftError: result.errorMessage ?? 'Failed to calculate route.',
          routeDraftFailureKind: result.failureKind,
        );
        return;
    }
  }

  void _completeRouteDraftReturnLeg({
    required List<LatLng> committedPoints,
    required List<RouteDraftControlEndpoint> controlEndpoints,
    required List<LatLng> returnSegment,
    required int? nextMarkerId,
    bool appendReturnEndpoint = true,
  }) {
    final updatedControlEndpoints = appendReturnEndpoint
        ? [
            ...controlEndpoints,
            controlEndpoints.first.copyWith(
              id: _routeDraftEndpointId(
                nextMarkerId ?? state.routeDraftNextMarkerId,
              ),
            ),
          ]
        : controlEndpoints;
    _setRouteDraftControlState(
      controlEndpoints: updatedControlEndpoints,
      stage: RouteDraftStage.awaitingNextPoint,
      provisionalPoints: const [],
      distanceMeters:
          state.routeDraftDistanceMeters +
          _polylineDistanceMeters(returnSegment),
      offTrackProbeActive: false,
      clearRouteDraftError: true,
      nextMarkerId: nextMarkerId,
    );
    state = state.copyWith(
      routeDraftCommittedPoints: _appendRouteSegment(
        committedPoints,
        returnSegment,
      ),
    );
    _resampleRouteDraftElevation();
  }

  void _setRouteDraftControlState({
    required List<RouteDraftControlEndpoint> controlEndpoints,
    String? provisionalEndpointId,
    required RouteDraftStage stage,
    required List<LatLng> provisionalPoints,
    double? distanceMeters,
    bool? offTrackProbeActive,
    String? routeDraftError,
    bool clearRouteDraftError = false,
    RoutePlanningFailureKind routeDraftFailureKind =
        RoutePlanningFailureKind.generic,
    RouteMode? routeDraftMode,
    bool clearRouteDraftPeak = false,
    int? requestId,
    int? nextMarkerId,
  }) {
    state = state.copyWith(
      routeDraftControlEndpoints: List<RouteDraftControlEndpoint>.unmodifiable(
        controlEndpoints,
      ),
      routeDraftDisplayMarkers: List<RouteDraftDisplayMarker>.unmodifiable(
        _buildDisplayMarkers(
          controlEndpoints,
          provisionalEndpointId: provisionalEndpointId,
        ),
      ),
      routeDraftMarkers: List<LatLng>.unmodifiable(
        controlEndpoints.map((endpoint) => endpoint.point),
      ),
      routeDraftStage: stage,
      routeDraftProvisionalPoints: List<LatLng>.unmodifiable(provisionalPoints),
      routeDraftDistanceMeters:
          distanceMeters ?? state.routeDraftDistanceMeters,
      routeDraftOffTrackProbeActive:
          offTrackProbeActive ?? state.routeDraftOffTrackProbeActive,
      routeDraftStraightLineFallback:
          offTrackProbeActive ?? state.routeDraftOffTrackProbeActive,
      routeDraftError: routeDraftError,
      clearRouteDraftError: clearRouteDraftError,
      routeDraftFailureKind: routeDraftFailureKind,
      routeDraftMode: routeDraftMode,
      clearRouteDraftPeak: clearRouteDraftPeak,
      routeDraftRequestId: requestId,
      routeDraftNextMarkerId: nextMarkerId,
    );
  }

  RouteDraftControlEndpoint _lastControlEndpoint() {
    return state.routeDraftControlEndpoints.last;
  }

  RouteDraftControlEndpoint _movedEndpoint(
    RouteDraftControlEndpoint endpoint,
    RouteEndpointAnchor? anchor, {
    bool isPeakTarget = false,
  }) {
    if (endpoint.kind == RouteDraftEndpointKind.peakTarget) {
      return endpoint;
    }
    if (anchor == null) {
      return endpoint;
    }
    return endpoint.copyWith(
      point: anchor.point,
      kind: _endpointKindFromAnchor(anchor, isPeakTarget: isPeakTarget),
    );
  }

  List<RouteDraftControlEndpoint> _replaceEndpoints({
    required List<RouteDraftControlEndpoint> controlEndpoints,
    required RouteDraftControlEndpoint startEndpoint,
    RouteEndpointAnchor? startAnchor,
    required RouteDraftControlEndpoint endEndpoint,
    RouteEndpointAnchor? endAnchor,
    required bool keepEndRaw,
    bool endIsPeakTarget = false,
  }) {
    final movedStart = _movedEndpoint(startEndpoint, startAnchor);
    final movedEnd = keepEndRaw
        ? endEndpoint
        : _movedEndpoint(endEndpoint, endAnchor, isPeakTarget: endIsPeakTarget);
    return controlEndpoints
        .map((endpoint) {
          if (endpoint.id == movedStart.id) {
            return movedStart;
          }
          if (endpoint.id == movedEnd.id) {
            return movedEnd;
          }
          return endpoint;
        })
        .toList(growable: false);
  }

  Future<void> _probeRouteDraftEndpoint({
    required int requestId,
    required RouteDraftControlEndpoint startEndpoint,
    required RouteDraftControlEndpoint endEndpoint,
  }) async {
    final probe = await _routePlanner.probeEndpoint(point: endEndpoint.point);
    if (!_isActiveRouteDraftRequest(requestId)) {
      return;
    }
    if (probe.errorMessage != null) {
      _setRouteDraftControlState(
        controlEndpoints: state.routeDraftControlEndpoints,
        stage: RouteDraftStage.segmentFailure,
        provisionalPoints: const [],
        offTrackProbeActive: state.routeDraftOffTrackProbeActive,
        routeDraftError: probe.errorMessage,
        routeDraftFailureKind: probe.failureKind,
      );
      return;
    }

    if (probe.isOnTrack && probe.anchor != null) {
      final updated = _replaceEndpoints(
        controlEndpoints: state.routeDraftControlEndpoints,
        startEndpoint: startEndpoint,
        endEndpoint: endEndpoint,
        endAnchor: probe.anchor,
        keepEndRaw: false,
      );
      final segmentPoints = [startEndpoint.point, probe.anchor!.point];
      _setRouteDraftControlState(
        controlEndpoints: updated,
        stage: RouteDraftStage.awaitingNextPoint,
        provisionalPoints: const [],
        distanceMeters:
            state.routeDraftDistanceMeters +
            _polylineDistanceMeters(segmentPoints),
        offTrackProbeActive: false,
        clearRouteDraftError: true,
      );
      state = state.copyWith(
        routeDraftCommittedPoints: _appendRouteSegment(
          state.routeDraftCommittedPoints,
          segmentPoints,
        ),
      );
      _resampleRouteDraftElevation();
      return;
    }

    final segmentPoints = [startEndpoint.point, endEndpoint.point];
    _setRouteDraftControlState(
      controlEndpoints: state.routeDraftControlEndpoints,
      stage: RouteDraftStage.awaitingNextPoint,
      provisionalPoints: const [],
      distanceMeters:
          state.routeDraftDistanceMeters +
          _polylineDistanceMeters(segmentPoints),
      offTrackProbeActive: true,
      clearRouteDraftError: true,
    );
    state = state.copyWith(
      routeDraftCommittedPoints: _appendRouteSegment(
        state.routeDraftCommittedPoints,
        segmentPoints,
      ),
    );
    _resampleRouteDraftElevation();
  }

  void addRouteDraftMarker(LatLng point, {bool straightLine = false}) {
    if (!state.isRouteDrafting) {
      return;
    }

    final useStraightLine =
        straightLine || state.routeDraftMode == RouteMode.straightLine;

    switch (state.routeDraftStage) {
      case RouteDraftStage.inactive:
        return;
      case RouteDraftStage.awaitingStart:
        if (state.routeDraftMode == RouteMode.routeToPeak) {
          _pushRouteDraftHistory();
          _startRouteDraftToPeakFrom(point);
          return;
        }
        final endpoint = _createControlEndpoint(
          point: point,
          kind: _manualEndpointKindForPoint(point),
        );
        _pushRouteDraftHistory();
        _setRouteDraftControlState(
          controlEndpoints: [endpoint],
          stage: RouteDraftStage.awaitingNextPoint,
          provisionalPoints: const [],
          offTrackProbeActive: false,
          clearRouteDraftError: true,
          nextMarkerId: state.routeDraftNextMarkerId + 1,
        );
        if (useStraightLine) {
          state = state.copyWith(routeDraftCommittedPoints: [point]);
        }
      case RouteDraftStage.awaitingNextPoint:
      case RouteDraftStage.segmentFailure:
        final start = state.routeDraftControlEndpoints.isEmpty
            ? null
            : _lastControlEndpoint();
        if (start == null) {
          final endpoint = _createControlEndpoint(
            point: point,
            kind: _manualEndpointKindForPoint(point),
          );
          _pushRouteDraftHistory();
          _setRouteDraftControlState(
            controlEndpoints: [endpoint],
            stage: RouteDraftStage.awaitingNextPoint,
            provisionalPoints: const [],
            offTrackProbeActive: false,
            clearRouteDraftError: true,
            nextMarkerId: state.routeDraftNextMarkerId + 1,
          );
          return;
        }
        if (start.point == point) {
          final duplicate = _createControlEndpoint(
            point: point,
            kind: _manualEndpointKindForPoint(point),
          );
          _pushRouteDraftHistory();
          _setRouteDraftControlState(
            controlEndpoints: [...state.routeDraftControlEndpoints, duplicate],
            stage: RouteDraftStage.segmentFailure,
            provisionalPoints: const [],
            routeDraftError:
                'Start and end points must be different to calculate a route.',
            nextMarkerId: state.routeDraftNextMarkerId + 1,
          );
          return;
        }
        if (_hasReachedRouteDraftMarkerLimit()) {
          state = state.copyWith(
            routeDraftError: _routeDraftMarkerLimitError,
            routeDraftFailureKind: RoutePlanningFailureKind.generic,
          );
          return;
        }
        final nextEndpoint = _createControlEndpoint(
          point: point,
          kind: _manualEndpointKindForPoint(point),
        );
        if (useStraightLine) {
          final segmentPoints = [start.point, point];
          _pushRouteDraftHistory();
          _setRouteDraftControlState(
            controlEndpoints: [
              ...state.routeDraftControlEndpoints,
              nextEndpoint,
            ],
            stage: RouteDraftStage.awaitingNextPoint,
            provisionalPoints: const [],
            distanceMeters:
                state.routeDraftDistanceMeters +
                _polylineDistanceMeters(segmentPoints),
            offTrackProbeActive: false,
            clearRouteDraftError: true,
            nextMarkerId: state.routeDraftNextMarkerId + 1,
          );
          state = state.copyWith(
            routeDraftCommittedPoints: _appendRouteSegment(
              state.routeDraftCommittedPoints,
              segmentPoints,
            ),
          );
          _resampleRouteDraftElevation();
          return;
        }
        final requestId = state.routeDraftRequestId + 1;
        _pushRouteDraftHistory();
        _setRouteDraftControlState(
          controlEndpoints: [...state.routeDraftControlEndpoints, nextEndpoint],
          provisionalEndpointId: nextEndpoint.id,
          stage: RouteDraftStage.routingSegment,
          provisionalPoints: [start.point, point],
          clearRouteDraftError: true,
          requestId: requestId,
          nextMarkerId: state.routeDraftNextMarkerId + 1,
        );
        if (state.routeDraftOffTrackProbeActive) {
          unawaited(
            _probeRouteDraftEndpoint(
              requestId: requestId,
              startEndpoint: start,
              endEndpoint: nextEndpoint,
            ),
          );
        } else {
          unawaited(
            _planRouteDraftSegment(
              requestId: requestId,
              startEndpoint: start,
              endEndpoint: nextEndpoint,
            ),
          );
        }
      case RouteDraftStage.routingSegment:
        return;
    }
  }

  void _startRouteDraftToPeakFrom(LatLng start) {
    final routeToPeakTarget = state.routeDraftPeakTarget;
    if (routeToPeakTarget == null) {
      return;
    }

    if (_hasReachedRouteDraftMarkerLimit()) {
      state = state.copyWith(
        routeDraftError: _routeDraftMarkerLimitError,
        routeDraftFailureKind: RoutePlanningFailureKind.generic,
      );
      return;
    }

    final peakPoint = LatLng(
      routeToPeakTarget.latitude,
      routeToPeakTarget.longitude,
    );
    final startEndpoint = state.routeDraftControlEndpoints.isEmpty
        ? _createControlEndpoint(
            point: start,
            kind: RouteDraftEndpointKind.tapped,
            id: _routeDraftEndpointId(state.routeDraftNextMarkerId),
          )
        : state.routeDraftControlEndpoints.last;
    if (peakPoint == startEndpoint.point) {
      final duplicatePeak = _createControlEndpoint(
        point: peakPoint,
        kind: RouteDraftEndpointKind.peakTarget,
        id: _routeDraftEndpointId(
          state.routeDraftControlEndpoints.isEmpty
              ? state.routeDraftNextMarkerId + 1
              : state.routeDraftNextMarkerId,
        ),
      );
      final endpoints = state.routeDraftControlEndpoints.isEmpty
          ? [startEndpoint, duplicatePeak]
          : [...state.routeDraftControlEndpoints, duplicatePeak];
      _setRouteDraftControlState(
        controlEndpoints: endpoints,
        stage: RouteDraftStage.segmentFailure,
        provisionalPoints: const [],
        routeDraftError:
            'Start and end points must be different to calculate a route.',
        nextMarkerId:
            state.routeDraftNextMarkerId +
            (state.routeDraftControlEndpoints.isEmpty ? 2 : 1),
      );
      return;
    }

    final requestId = state.routeDraftRequestId + 1;
    final peakEndpoint = _createControlEndpoint(
      point: peakPoint,
      kind: RouteDraftEndpointKind.peakTarget,
      id: _routeDraftEndpointId(
        state.routeDraftControlEndpoints.isEmpty
            ? state.routeDraftNextMarkerId + 1
            : state.routeDraftNextMarkerId,
      ),
    );
    final endpoints = state.routeDraftControlEndpoints.isEmpty
        ? [startEndpoint, peakEndpoint]
        : [...state.routeDraftControlEndpoints, peakEndpoint];
    _setRouteDraftControlState(
      controlEndpoints: endpoints,
      provisionalEndpointId: peakEndpoint.id,
      stage: RouteDraftStage.routingSegment,
      provisionalPoints: [startEndpoint.point, peakPoint],
      clearRouteDraftError: true,
      requestId: requestId,
      nextMarkerId:
          state.routeDraftNextMarkerId +
          (state.routeDraftControlEndpoints.isEmpty ? 2 : 1),
    );
    unawaited(
      _planRouteDraftSegment(
        requestId: requestId,
        startEndpoint: startEndpoint,
        endEndpoint: peakEndpoint,
      ),
    );
  }

  Future<void> saveRouteDraft() async {
    if (!state.isRouteDrafting || state.isSavingRoute) {
      return;
    }

    final trimmedName = state.routeDraftName.trim();
    final routeNameError = _validateRouteDraftName(trimmedName);
    if (routeNameError != null || state.routeDraftCommittedPoints.length < 2) {
      state = state.copyWith(routeDraftNameError: routeNameError);
      return;
    }

    state = state.copyWith(isSavingRoute: true, clearRouteDraftNameError: true);
    try {
      final committedPoints = List<LatLng>.from(
        state.routeDraftCommittedPoints,
        growable: false,
      );
      final pointElevations = await _sampleRoutePointElevationsForSave(
        committedPoints,
      );
      final elevationSummary = _routeDraftElevationSummaryForSave();
      final route = Route(
        name: trimmedName,
        gpxRoute: committedPoints,
        gpxRouteElevations: pointElevations,
        routeWaypoints: _buildRouteDraftWaypointsForSave(),
        displayRoutePointsByZoom: TrackDisplayCacheBuilder.buildJson([
          committedPoints,
        ]),
        colour: state.routeDraftColour,
        distance2d: state.routeDraftDistanceMeters,
        distance3d: elevationSummary.distance3d,
        ascent: elevationSummary.ascent,
        descent: elevationSummary.descent,
        startElevation: elevationSummary.startElevation,
        endElevation: elevationSummary.endElevation,
        lowestElevation: elevationSummary.lowestElevation,
        highestElevation: elevationSummary.highestElevation,
      );
      _routeRepository.saveRoute(route);
      ref.read(routeRevisionProvider.notifier).increment();
      state = state.copyWith(showRoutes: true);
      endRouteDraft();
    } catch (error) {
      state = state.copyWith(isSavingRoute: false);
      _pendingRouteSnackbarMessage = 'Failed to save route: $error';
    }
  }

  void retryRouteDraftSegment() {
    if (!state.isRouteDrafting ||
        state.routeDraftStage != RouteDraftStage.segmentFailure ||
        state.routeDraftFailureKind !=
            RoutePlanningFailureKind.routeGraphLoad ||
        state.routeDraftControlEndpoints.length < 2) {
      return;
    }

    unawaited(
      _rebuildRouteDraftFromControlEndpoints(
        List<RouteDraftControlEndpoint>.from(state.routeDraftControlEndpoints),
        invalidatePeakTarget: false,
      ),
    );
  }

  List<RouteWaypoint> _buildRouteDraftWaypointsForSave() {
    if (state.routeDraftControlEndpoints.length < 2) {
      return const [];
    }

    final waypoints = <RouteWaypoint>[];
    var genericWaypointSequence = 1;
    final routeTarget = state.routeDraftPeakTarget;
    final peakPoint = routeTarget == null
        ? null
        : LatLng(routeTarget.latitude, routeTarget.longitude);
    final startPoint = state.routeDraftControlEndpoints.first.point;

    for (
      var index = 1;
      index < state.routeDraftControlEndpoints.length;
      index++
    ) {
      final endpoint = state.routeDraftControlEndpoints[index];
      final isFinalReturnToStart =
          index == state.routeDraftControlEndpoints.length - 1 &&
          endpoint.point == startPoint;
      if (isFinalReturnToStart) {
        continue;
      }

      final isPeakDerived =
          endpoint.kind == RouteDraftEndpointKind.peakTarget ||
          (peakPoint != null && endpoint.point == peakPoint);
      if (isPeakDerived && routeTarget != null) {
        waypoints.add(
          RouteWaypoint(
            latitude: endpoint.point.latitude,
            longitude: endpoint.point.longitude,
            label: routeTarget.name,
            sequence: waypoints.length + 1,
            isPeakDerived: true,
            peakOsmId: routeTarget.osmId,
            peakName: routeTarget.name,
          ),
        );
        continue;
      }

      waypoints.add(
        RouteWaypoint(
          latitude: endpoint.point.latitude,
          longitude: endpoint.point.longitude,
          label: 'Waypoint $genericWaypointSequence',
          sequence: waypoints.length + 1,
          isPeakDerived: false,
        ),
      );
      genericWaypointSequence += 1;
    }

    return waypoints;
  }

  Future<List<int?>> _sampleRoutePointElevationsForSave(
    List<LatLng> points,
  ) async {
    try {
      final sampled = await _routeElevationSampler.samplePointElevations(
        points,
      );
      return List<int?>.generate(
        points.length,
        (index) => index < sampled.length ? sampled[index]?.round() : null,
        growable: false,
      );
    } catch (_) {
      return List<int?>.filled(points.length, null, growable: false);
    }
  }

  Future<List<double?>> _sampleRoutePointElevationsForDraft(
    List<LatLng> points,
  ) async {
    try {
      final sampled = await _routeElevationSampler.samplePointElevations(
        points,
      );
      return List<double?>.generate(
        points.length,
        (index) => index < sampled.length ? sampled[index] : null,
        growable: false,
      );
    } catch (_) {
      return List<double?>.filled(points.length, null, growable: false);
    }
  }

  Future<void> _planRouteDraftSegment({
    required int requestId,
    required RouteDraftControlEndpoint startEndpoint,
    required RouteDraftControlEndpoint endEndpoint,
  }) async {
    final result = await _routePlanner.planSegmentResult(
      start: startEndpoint.point,
      end: endEndpoint.point,
    );
    if (!_isActiveRouteDraftRequest(requestId)) {
      return;
    }

    final resetRouteToPeak = state.routeDraftMode == RouteMode.routeToPeak;
    final peakPoint = resetRouteToPeak && state.routeDraftPeakTarget != null
        ? LatLng(
            state.routeDraftPeakTarget!.latitude,
            state.routeDraftPeakTarget!.longitude,
          )
        : null;

    switch (result.status) {
      case RoutePlanningStatus.routed:
        final updatedEndpoints = _replaceEndpoints(
          controlEndpoints: state.routeDraftControlEndpoints,
          startEndpoint: startEndpoint,
          startAnchor: result.startAnchor,
          endEndpoint: endEndpoint,
          endAnchor: result.endAnchor,
          keepEndRaw: resetRouteToPeak,
          endIsPeakTarget: resetRouteToPeak,
        );
        final segmentPoints = peakPoint == null
            ? result.points
            : _appendPeakTerminalLegIfNeeded(result.points, peakPoint);
        _setRouteDraftControlState(
          controlEndpoints: updatedEndpoints,
          stage: RouteDraftStage.awaitingNextPoint,
          provisionalPoints: const [],
          distanceMeters:
              state.routeDraftDistanceMeters +
              _polylineDistanceMeters(segmentPoints),
          offTrackProbeActive: false,
          clearRouteDraftError: true,
          routeDraftMode: resetRouteToPeak ? RouteMode.snapToTrail : null,
          clearRouteDraftPeak: resetRouteToPeak,
        );
        state = state.copyWith(
          routeDraftCommittedPoints: _appendRouteSegment(
            state.routeDraftCommittedPoints,
            segmentPoints,
          ),
        );
        _resampleRouteDraftElevation();
        return;
      case RoutePlanningStatus.offTrack:
      case RoutePlanningStatus.noPath:
        final endPoint =
            result.status == RoutePlanningStatus.noPath &&
                result.endAnchor != null
            ? result.endAnchor!.point
            : endEndpoint.point;
        final updatedEndpoints = _replaceEndpoints(
          controlEndpoints: state.routeDraftControlEndpoints,
          startEndpoint: startEndpoint,
          startAnchor: result.startAnchor,
          endEndpoint: endEndpoint,
          endAnchor: result.endAnchor,
          keepEndRaw:
              result.status == RoutePlanningStatus.offTrack || resetRouteToPeak,
          endIsPeakTarget: resetRouteToPeak,
        );
        final baseSegmentPoints = [startEndpoint.point, endPoint];
        final segmentPoints = peakPoint != null && endPoint != peakPoint
            ? [...baseSegmentPoints, peakPoint]
            : baseSegmentPoints;
        _setRouteDraftControlState(
          controlEndpoints: updatedEndpoints,
          stage: RouteDraftStage.awaitingNextPoint,
          provisionalPoints: const [],
          distanceMeters:
              state.routeDraftDistanceMeters +
              _polylineDistanceMeters(segmentPoints),
          offTrackProbeActive: resetRouteToPeak ? false : true,
          clearRouteDraftError: true,
          routeDraftMode: resetRouteToPeak ? RouteMode.snapToTrail : null,
          clearRouteDraftPeak: resetRouteToPeak,
        );
        state = state.copyWith(
          routeDraftCommittedPoints: _appendRouteSegment(
            state.routeDraftCommittedPoints,
            segmentPoints,
          ),
        );
        _resampleRouteDraftElevation();
        return;
      case RoutePlanningStatus.failed:
        _setRouteDraftControlState(
          controlEndpoints: state.routeDraftControlEndpoints,
          stage: RouteDraftStage.segmentFailure,
          provisionalPoints: const [],
          offTrackProbeActive: state.routeDraftOffTrackProbeActive,
          routeDraftError: result.errorMessage ?? 'Failed to calculate route.',
          routeDraftFailureKind: result.failureKind,
        );
        return;
    }
  }

  bool _isActiveRouteDraftRequest(int requestId) {
    return state.isRouteDrafting && state.routeDraftRequestId == requestId;
  }

  RouteElevationSummary _routeDraftElevationSummaryForSave() {
    final summary = state.routeDraftElevationSummary;
    if (summary == null ||
        state.routeDraftElevationLoading ||
        summary.requestId != state.routeDraftElevationRequestId ||
        summary.geometryVersion != state.routeDraftGeometryVersion) {
      return RouteElevationSummary.zero(
        requestId: state.routeDraftElevationRequestId,
        geometryVersion: state.routeDraftGeometryVersion,
      );
    }

    return summary;
  }

  void _resampleRouteDraftElevation() {
    if (!state.isRouteDrafting || state.routeDraftCommittedPoints.length < 2) {
      state = state.copyWith(
        clearRouteDraftElevationSummary: true,
        routeDraftElevationLoading: false,
        clearRouteDraftElevationError: true,
        clearRouteDraftPointElevations: true,
      );
      return;
    }

    final requestId = state.routeDraftElevationRequestId + 1;
    final geometryVersion = state.routeDraftGeometryVersion + 1;
    final committedPoints = List<LatLng>.from(
      state.routeDraftCommittedPoints,
      growable: false,
    );

    state = state.copyWith(
      clearRouteDraftElevationSummary: true,
      routeDraftElevationLoading: true,
      clearRouteDraftElevationError: true,
      clearRouteDraftPointElevations: true,
      routeDraftElevationRequestId: requestId,
      routeDraftGeometryVersion: geometryVersion,
    );

    unawaited(
      _sampleRouteDraftElevation(
        points: committedPoints,
        requestId: requestId,
        geometryVersion: geometryVersion,
      ),
    );
  }

  Future<void> _sampleRouteDraftElevation({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  }) async {
    final sampledPointElevations = await _sampleRoutePointElevationsForDraft(
      points,
    );
    if (!_isActiveRouteDraftElevationRequest(
      requestId: requestId,
      geometryVersion: geometryVersion,
    )) {
      return;
    }

    state = state.copyWith(routeDraftPointElevations: sampledPointElevations);

    try {
      final summary = await _routeElevationSampler.sampleRoute(
        points: points,
        requestId: requestId,
        geometryVersion: geometryVersion,
      );
      if (!_isActiveRouteDraftElevationRequest(
        requestId: requestId,
        geometryVersion: geometryVersion,
      )) {
        return;
      }

      state = state.copyWith(
        routeDraftElevationSummary: summary,
        routeDraftElevationLoading: false,
        clearRouteDraftElevationError: true,
      );
    } on GdalException catch (error, stackTrace) {
      if (!_isActiveRouteDraftElevationRequest(
        requestId: requestId,
        geometryVersion: geometryVersion,
      )) {
        return;
      }

      developer.log(
        'GDAL route elevation sampling failed.',
        error: error,
        stackTrace: stackTrace,
      );
      debugPrint('GDAL route elevation sampling failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      state = state.copyWith(
        clearRouteDraftElevationSummary: true,
        routeDraftElevationLoading: false,
        clearRouteDraftElevationError: true,
      );
    } catch (error) {
      if (!_isActiveRouteDraftElevationRequest(
        requestId: requestId,
        geometryVersion: geometryVersion,
      )) {
        return;
      }

      state = state.copyWith(
        clearRouteDraftElevationSummary: true,
        routeDraftElevationLoading: false,
        routeDraftElevationError: 'Failed to sample elevation: $error',
      );
    }
  }

  bool _isActiveRouteDraftElevationRequest({
    required int requestId,
    required int geometryVersion,
  }) {
    if (!ref.mounted) {
      return false;
    }

    return state.isRouteDrafting &&
        state.routeDraftElevationRequestId == requestId &&
        state.routeDraftGeometryVersion == geometryVersion;
  }

  List<LatLng> _appendRouteSegment(
    List<LatLng> existing,
    List<LatLng> segment,
  ) {
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

  List<LatLng> _normalizeCloseLoopSegment(
    List<LatLng> points, {
    required LatLng currentPoint,
    required LatLng startPoint,
  }) {
    final normalized = List<LatLng>.from(points, growable: true);
    if (normalized.isEmpty) {
      return [currentPoint, startPoint];
    }
    if (normalized.first != currentPoint) {
      normalized.insert(0, currentPoint);
    }
    if (normalized.last != startPoint) {
      normalized.add(startPoint);
    }
    return List<LatLng>.unmodifiable(normalized);
  }

  void setEndDrawerMode(EndDrawerMode mode) {
    if (state.endDrawerMode == mode) {
      return;
    }
    state = state.copyWith(endDrawerMode: mode);
  }

  Future<void> persistTracksRoutesVisibility() async {
    try {
      final prefs = await _prefsLoader();
      await prefs.setBool(_showTracksKey, state.showTracks);
      await prefs.setBool(_showRoutesKey, state.showRoutes);
      await prefs.setBool(_showTrailsKey, state.showTrails);
    } catch (_) {
      // Continue without saving.
    }
  }

  void setShowRoutes(bool value) {
    if (state.showRoutes == value) {
      return;
    }
    if (_isRestoringVisibilityPrefs) {
      _showRoutesRestoreOverridden = true;
    }
    state = state.copyWith(
      showRoutes: value,
      clearSelectedRouteId: !value,
      clearHoveredRouteId: !value,
    );
    persistTracksRoutesVisibility();
  }

  void setShowTrails(bool value) {
    if (state.showTrails == value) {
      return;
    }
    if (_isRestoringVisibilityPrefs) {
      _showTrailsRestoreOverridden = true;
    }
    state = state.copyWith(showTrails: value);
    persistTracksRoutesVisibility();
  }

  void toggleTrails() {
    setShowTrails(!state.showTrails);
  }

  void selectPeakList(PeakListSelectionMode mode, {int? peakListId}) {
    if (mode == PeakListSelectionMode.specificList && peakListId == null) {
      return;
    }

    switch (mode) {
      case PeakListSelectionMode.none:
        _updatePeakListSelection(
          mode: PeakListSelectionMode.none,
          selectedPeakListIds: const <int>{},
        );
      case PeakListSelectionMode.allPeaks:
        setAllPeaksSelected(true);
      case PeakListSelectionMode.specificList:
        _updatePeakListSelection(
          mode: PeakListSelectionMode.specificList,
          selectedPeakListIds: {peakListId!},
          previousSpecificPeakListIds: {peakListId},
        );
    }
  }

  void togglePeakListSelection(int peakListId) {
    if (state.peakListSelectionMode == PeakListSelectionMode.allPeaks) {
      _updatePeakListSelection(
        mode: PeakListSelectionMode.specificList,
        selectedPeakListIds: {peakListId},
        previousSpecificPeakListIds: {peakListId},
      );
      return;
    }

    final nextSelectedPeakListIds = Set<int>.of(state.selectedPeakListIds);
    if (!nextSelectedPeakListIds.add(peakListId)) {
      nextSelectedPeakListIds.remove(peakListId);
    }

    if (nextSelectedPeakListIds.isEmpty) {
      _updatePeakListSelection(
        mode: PeakListSelectionMode.none,
        selectedPeakListIds: const <int>{},
      );
      return;
    }

    _updatePeakListSelection(
      mode: PeakListSelectionMode.specificList,
      selectedPeakListIds: nextSelectedPeakListIds,
      previousSpecificPeakListIds: nextSelectedPeakListIds,
    );
  }

  void setAllPeaksSelected(bool value) {
    if (!value) {
      if (state.peakListSelectionMode != PeakListSelectionMode.allPeaks ||
          state.previousSpecificPeakListIds.isEmpty) {
        return;
      }
      _updatePeakListSelection(
        mode: PeakListSelectionMode.specificList,
        selectedPeakListIds: state.previousSpecificPeakListIds,
        previousSpecificPeakListIds: state.previousSpecificPeakListIds,
      );
      return;
    }

    final snapshot =
        state.peakListSelectionMode == PeakListSelectionMode.specificList
        ? state.selectedPeakListIds
        : null;
    _updatePeakListSelection(
      mode: PeakListSelectionMode.allPeaks,
      selectedPeakListIds: const <int>{},
      previousSpecificPeakListIds: snapshot,
    );
  }

  void _updatePeakListSelection({
    required PeakListSelectionMode mode,
    required Set<int> selectedPeakListIds,
    Set<int>? previousSpecificPeakListIds,
  }) {
    final nextSelectedPeakListIds = _immutablePeakListIds(selectedPeakListIds);
    final nextPreviousSpecificPeakListIds = previousSpecificPeakListIds == null
        ? state.previousSpecificPeakListIds
        : _immutablePeakListIds(previousSpecificPeakListIds);
    if (state.peakListSelectionMode == mode &&
        _samePeakListIds(state.selectedPeakListIds, nextSelectedPeakListIds) &&
        _samePeakListIds(
          state.previousSpecificPeakListIds,
          nextPreviousSpecificPeakListIds,
        )) {
      return;
    }

    state = state.copyWith(
      peakListSelectionMode: mode,
      selectedPeakListIds: nextSelectedPeakListIds,
      previousSpecificPeakListIds: nextPreviousSpecificPeakListIds,
      clearPeakInfoPopup: true,
      clearHoveredPeakId: true,
    );
    unawaited(persistPeakListSelection());
  }

  void reconcileSelectedPeakList() {
    if (state.peakListSelectionMode != PeakListSelectionMode.specificList) {
      return;
    }

    if (state.selectedPeakListIds.isEmpty) {
      _resetToNoPeaks();
      return;
    }

    final repo = ref.read(peakListRepositoryProvider);
    List<PeakList> peakLists;
    try {
      peakLists = repo.getAllPeakLists();
    } catch (_) {
      return;
    }

    final validPeakListIds = <int>{};
    for (final peakList in peakLists) {
      if (!state.selectedPeakListIds.contains(peakList.peakListId)) {
        continue;
      }
      try {
        decodePeakListItems(peakList.peakList);
        validPeakListIds.add(peakList.peakListId);
      } catch (_) {}
    }

    if (validPeakListIds.isEmpty) {
      _resetToNoPeaks();
      return;
    }

    if (!_samePeakListIds(validPeakListIds, state.selectedPeakListIds)) {
      _updatePeakListSelection(
        mode: PeakListSelectionMode.specificList,
        selectedPeakListIds: validPeakListIds,
        previousSpecificPeakListIds: validPeakListIds,
      );
    }
  }

  void _resetToNoPeaks() {
    _updatePeakListSelection(
      mode: PeakListSelectionMode.none,
      selectedPeakListIds: const <int>{},
    );
  }

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

  void clearSelectedLocation() {
    state = state.copyWith(clearSelectedLocation: true);
  }

  void setCursorMgrs(LatLng location) {
    final mgrs = _convertToMgrs(location);
    if (state.cursorMgrs == mgrs && state.cursorPoint == location) {
      return;
    }
    state = state.copyWith(cursorMgrs: mgrs, cursorPoint: location);
  }

  void setSelectedLocation(LatLng location) {
    state = state.copyWith(
      cursorMgrs: _convertToMgrs(location),
      cursorPoint: location,
      selectedLocation: location,
      syncEnabled: false,
    );
  }

  void restoreSelectedLocation(LatLng? location) {
    state = state.copyWith(
      selectedLocation: location,
      clearSelectedLocation: location == null,
      cursorMgrs: location == null
          ? state.cursorMgrs
          : _convertToMgrs(location),
      cursorPoint: location ?? state.cursorPoint,
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
    if (state.cursorMgrs == null) {
      return;
    }
    state = state.copyWith(clearCursorMgrs: true);
  }

  void setHoveredPeakId(int? peakId) {
    if (peakId == null) {
      clearHoveredPeak();
      return;
    }
    if (state.hoveredPeakId == peakId) {
      return;
    }
    state = state.copyWith(hoveredPeakId: peakId);
  }

  void clearHoveredPeak() {
    if (state.hoveredPeakId == null) {
      return;
    }
    state = state.copyWith(clearHoveredPeakId: true);
  }

  void openPeakInfoPopup(Peak peak) {
    state = state.copyWith(
      peakInfo: _resolvePeakInfoContentForPeak(peak),
      peakInfoPopupMode: PeakInfoPopupMode.pinned,
      clearDriveEtaPopup: true,
      clearInfoPopup: true,
      clearHoveredTrackId: true,
    );
  }

  void openHoveredPeakInfoPopup(Peak peak) {
    if (state.peakInfoPeak?.osmId == peak.osmId && state.isPeakInfoPinned) {
      return;
    }
    if (state.peakInfoPeak?.osmId == peak.osmId && state.isPeakInfoHovered) {
      return;
    }
    state = state.copyWith(
      peakInfo: _resolvePeakInfoContentForPeak(peak),
      peakInfoPopupMode: PeakInfoPopupMode.hover,
      clearDriveEtaPopup: true,
      clearInfoPopup: true,
    );
  }

  void showDriveEtaPopupLoading({
    required int requestId,
    required LatLng anchor,
    required String title,
  }) {
    state = state.copyWith(
      driveEtaPopup: DriveEtaPopupState(
        requestId: requestId,
        anchor: anchor,
        title: title,
        status: DriveEtaPopupStatus.loading,
      ),
      clearPeakInfoPopup: true,
      clearInfoPopup: true,
      clearHoveredPeakId: true,
    );
  }

  void showDriveEtaPopupSuccess({
    required int requestId,
    required double distanceMeters,
    required int durationSeconds,
  }) {
    final popup = state.driveEtaPopup;
    if (popup == null || popup.requestId != requestId) {
      return;
    }

    state = state.copyWith(
      driveEtaPopup: popup.copyWith(
        status: DriveEtaPopupStatus.success,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        clearErrorMessage: true,
      ),
    );
  }

  void openDriveEtaPopupError({
    required int requestId,
    required LatLng anchor,
    required String title,
    required String message,
  }) {
    state = state.copyWith(
      driveEtaPopup: DriveEtaPopupState(
        requestId: requestId,
        anchor: anchor,
        title: title,
        status: DriveEtaPopupStatus.error,
        errorMessage: message,
      ),
      clearPeakInfoPopup: true,
      clearInfoPopup: true,
      clearHoveredPeakId: true,
    );
  }

  void showDriveEtaPopupError({
    required int requestId,
    required String message,
  }) {
    final popup = state.driveEtaPopup;
    if (popup == null || popup.requestId != requestId) {
      return;
    }

    state = state.copyWith(
      driveEtaPopup: popup.copyWith(
        status: DriveEtaPopupStatus.error,
        errorMessage: message,
        clearDistanceMeters: true,
        clearDurationSeconds: true,
      ),
    );
  }

  void closeDriveEtaPopup() {
    if (state.driveEtaPopup == null) {
      return;
    }
    state = state.copyWith(clearDriveEtaPopup: true);
  }

  void closePeakInfoPopup() {
    state = state.copyWith(clearPeakInfoPopup: true, clearHoveredPeakId: true);
  }

  void closeHoveredPeakInfoPopup() {
    if (!state.isPeakInfoHovered) {
      return;
    }
    state = state.copyWith(clearPeakInfoPopup: true, clearHoveredPeakId: true);
  }

  void setHoveredTrackId(int? trackId) {
    if (trackId == null) {
      clearHoveredTrack();
      return;
    }
    if (state.hoveredTrackId == trackId) {
      return;
    }
    state = state.copyWith(hoveredTrackId: trackId);
  }

  void clearHoveredTrack() {
    if (state.hoveredTrackId == null) {
      return;
    }
    state = state.copyWith(clearHoveredTrackId: true);
  }

  void setHoveredRouteDraftMarkerId(String? markerId) {
    if (markerId == null) {
      clearHoveredRouteDraftMarker();
      return;
    }
    if (state.hoveredRouteDraftMarkerId == markerId) {
      return;
    }
    state = state.copyWith(hoveredRouteDraftMarkerId: markerId);
  }

  void clearHoveredRouteDraftMarker([String? markerId]) {
    if (markerId != null && state.hoveredRouteDraftMarkerId != markerId) {
      return;
    }
    if (state.hoveredRouteDraftMarkerId == null) {
      return;
    }
    state = state.copyWith(clearHoveredRouteDraftMarkerId: true);
  }

  void setHoveredRouteDraftSegmentPreview({
    required int segmentIndex,
    required int committedSegmentIndex,
    required LatLng point,
  }) {
    if (!state.isRouteDrafting) {
      return;
    }

    if (state.hoveredRouteDraftSegmentIndex == segmentIndex &&
        state.hoveredRouteDraftCommittedSegmentIndex == committedSegmentIndex &&
        state.hoveredRouteDraftSegmentPoint == point) {
      return;
    }

    state = state.copyWith(
      hoveredRouteDraftSegmentIndex: segmentIndex,
      hoveredRouteDraftCommittedSegmentIndex: committedSegmentIndex,
      hoveredRouteDraftSegmentPoint: point,
    );
  }

  void clearHoveredRouteDraftSegmentPreview() {
    if (state.hoveredRouteDraftSegmentIndex == null &&
        state.hoveredRouteDraftCommittedSegmentIndex == null &&
        state.hoveredRouteDraftSegmentPoint == null) {
      return;
    }
    state = state.copyWith(clearHoveredRouteDraftSegmentPreview: true);
  }

  void commitHoveredRouteDraftSegmentPreview() {
    final segmentIndex = state.hoveredRouteDraftSegmentIndex;
    final committedSegmentIndex = state.hoveredRouteDraftCommittedSegmentIndex;
    final point = state.hoveredRouteDraftSegmentPoint;
    if (!state.isRouteDrafting ||
        segmentIndex == null ||
        committedSegmentIndex == null ||
        point == null) {
      return;
    }

    _pushRouteDraftHistory();
    _insertRouteDraftPointIntoChain(
      segmentIndex: segmentIndex,
      committedSegmentIndex: committedSegmentIndex,
      point: point,
    );
    clearHoveredRouteDraftSegmentPreview();
  }

  Future<void> deleteRouteDraftMarker(String markerId) async {
    if (!state.isRouteDrafting ||
        state.isSavingRoute ||
        state.routeDraftStage == RouteDraftStage.routingSegment) {
      return;
    }

    _activeRouteDraftDragMarkerId = null;

    final controlEndpoints = List<RouteDraftControlEndpoint>.from(
      state.routeDraftControlEndpoints,
    );
    final markerIndex = controlEndpoints.indexWhere(
      (endpoint) => endpoint.id == markerId,
    );
    if (markerIndex == -1) {
      return;
    }

    _pushRouteDraftHistory();
    controlEndpoints.removeAt(markerIndex);
    final invalidatePeakTarget = _shouldInvalidateRouteDraftPeakTarget(
      controlEndpoints,
    );
    await _rebuildRouteDraftFromControlEndpoints(
      controlEndpoints,
      invalidatePeakTarget: invalidatePeakTarget,
    );
  }

  void beginRouteDraftMarkerDrag(String markerId) {
    if (!state.isRouteDrafting ||
        state.isSavingRoute ||
        state.routeDraftStage == RouteDraftStage.routingSegment ||
        state.routeDraftControlEndpoints.every(
          (endpoint) => endpoint.id != markerId,
        )) {
      return;
    }

    _pushRouteDraftHistory();
    _activeRouteDraftDragMarkerId = markerId;
  }

  Future<void> updateRouteDraftMarkerDrag(String markerId, LatLng point) async {
    if (_activeRouteDraftDragMarkerId != markerId) {
      return;
    }

    await _moveRouteDraftMarker(
      markerId,
      point,
      pushHistory: false,
      allowWhileRouting: true,
    );
  }

  void endRouteDraftMarkerDrag([String? markerId]) {
    if (markerId != null && _activeRouteDraftDragMarkerId != markerId) {
      return;
    }

    _activeRouteDraftDragMarkerId = null;
  }

  Future<void> moveRouteDraftMarker(String markerId, LatLng point) async {
    _activeRouteDraftDragMarkerId = null;
    await _moveRouteDraftMarker(
      markerId,
      point,
      pushHistory: true,
      allowWhileRouting: false,
    );
  }

  Future<void> _moveRouteDraftMarker(
    String markerId,
    LatLng point, {
    required bool pushHistory,
    required bool allowWhileRouting,
  }) async {
    if (!state.isRouteDrafting ||
        state.isSavingRoute ||
        (!allowWhileRouting &&
            state.routeDraftStage == RouteDraftStage.routingSegment)) {
      return;
    }

    final controlEndpoints = List<RouteDraftControlEndpoint>.from(
      state.routeDraftControlEndpoints,
    );
    final markerIndex = controlEndpoints.indexWhere(
      (endpoint) => endpoint.id == markerId,
    );
    if (markerIndex == -1 || controlEndpoints[markerIndex].point == point) {
      return;
    }

    if (pushHistory) {
      _pushRouteDraftHistory();
    }
    controlEndpoints[markerIndex] = controlEndpoints[markerIndex].copyWith(
      point: point,
      kind: _manualEndpointKindForPoint(point),
    );
    final invalidatePeakTarget = _shouldInvalidateRouteDraftPeakTarget(
      controlEndpoints,
    );
    await _rebuildRouteDraftFromControlEndpoints(
      controlEndpoints,
      invalidatePeakTarget: invalidatePeakTarget,
    );
  }

  bool _shouldInvalidateRouteDraftPeakTarget(
    List<RouteDraftControlEndpoint> controlEndpoints,
  ) {
    final routeTarget = state.routeDraftPeakTarget;
    if (routeTarget == null) {
      return false;
    }

    final peakPoint = LatLng(routeTarget.latitude, routeTarget.longitude);
    return !controlEndpoints.any(
      (endpoint) =>
          endpoint.kind == RouteDraftEndpointKind.peakTarget ||
          endpoint.point == peakPoint,
    );
  }

  Future<void> _rebuildRouteDraftFromControlEndpoints(
    List<RouteDraftControlEndpoint> controlEndpoints, {
    required bool invalidatePeakTarget,
  }) async {
    final requestId = state.routeDraftRequestId + 1;
    final routeMode =
        invalidatePeakTarget && state.routeDraftMode == RouteMode.routeToPeak
        ? RouteMode.snapToTrail
        : state.routeDraftMode;

    if (controlEndpoints.isEmpty) {
      state = state.copyWith(
        routeDraftControlEndpoints: const [],
        routeDraftDisplayMarkers: const [],
        routeDraftMarkers: const [],
        routeDraftStage: RouteDraftStage.awaitingStart,
        routeDraftCommittedPoints: const [],
        routeDraftProvisionalPoints: const [],
        routeDraftDistanceMeters: 0,
        routeDraftOffTrackProbeActive: false,
        routeDraftStraightLineFallback: false,
        clearRouteDraftError: true,
        routeDraftMode: routeMode,
        clearRouteDraftPeak: invalidatePeakTarget,
        routeDraftPeakTargetLocked: invalidatePeakTarget
            ? true
            : state.routeDraftPeakTargetLocked,
        routeDraftRequestId: requestId,
      );
      _resampleRouteDraftElevation();
      return;
    }

    if (controlEndpoints.length == 1) {
      state = state.copyWith(
        routeDraftControlEndpoints:
            List<RouteDraftControlEndpoint>.unmodifiable(controlEndpoints),
        routeDraftDisplayMarkers: List<RouteDraftDisplayMarker>.unmodifiable(
          _buildDisplayMarkers(controlEndpoints),
        ),
        routeDraftMarkers: List<LatLng>.unmodifiable(
          controlEndpoints.map((endpoint) => endpoint.point),
        ),
        routeDraftStage: RouteDraftStage.awaitingNextPoint,
        routeDraftCommittedPoints: [controlEndpoints.single.point],
        routeDraftProvisionalPoints: const [],
        routeDraftDistanceMeters: 0,
        routeDraftOffTrackProbeActive: false,
        routeDraftStraightLineFallback: false,
        clearRouteDraftError: true,
        routeDraftMode: routeMode,
        clearRouteDraftPeak: invalidatePeakTarget,
        routeDraftPeakTargetLocked: invalidatePeakTarget
            ? true
            : state.routeDraftPeakTargetLocked,
        routeDraftRequestId: requestId,
      );
      _resampleRouteDraftElevation();
      return;
    }

    if (routeMode == RouteMode.straightLine) {
      final committedPoints = List<LatLng>.unmodifiable(
        controlEndpoints.map((endpoint) => endpoint.point),
      );
      state = state.copyWith(
        routeDraftControlEndpoints:
            List<RouteDraftControlEndpoint>.unmodifiable(controlEndpoints),
        routeDraftDisplayMarkers: List<RouteDraftDisplayMarker>.unmodifiable(
          _buildDisplayMarkers(controlEndpoints),
        ),
        routeDraftMarkers: List<LatLng>.unmodifiable(
          controlEndpoints.map((endpoint) => endpoint.point),
        ),
        routeDraftStage: RouteDraftStage.awaitingNextPoint,
        routeDraftCommittedPoints: committedPoints,
        routeDraftProvisionalPoints: const [],
        routeDraftDistanceMeters: _polylineDistanceMeters(committedPoints),
        routeDraftOffTrackProbeActive: false,
        routeDraftStraightLineFallback: false,
        clearRouteDraftError: true,
        routeDraftMode: routeMode,
        clearRouteDraftPeak: invalidatePeakTarget,
        routeDraftPeakTargetLocked: invalidatePeakTarget
            ? true
            : state.routeDraftPeakTargetLocked,
        routeDraftRequestId: requestId,
      );
      _resampleRouteDraftElevation();
      return;
    }

    state = state.copyWith(
      routeDraftStage: RouteDraftStage.routingSegment,
      routeDraftProvisionalPoints: const [],
      clearRouteDraftError: true,
      routeDraftMode: routeMode,
      clearRouteDraftPeak: invalidatePeakTarget,
      routeDraftPeakTargetLocked: invalidatePeakTarget
          ? true
          : state.routeDraftPeakTargetLocked,
      routeDraftRequestId: requestId,
    );

    final rebuiltEndpoints = List<RouteDraftControlEndpoint>.from(
      controlEndpoints,
    );
    var committedPoints = const <LatLng>[];
    var distanceMeters = 0.0;
    var usedFallback = false;

    for (var index = 0; index < rebuiltEndpoints.length - 1; index++) {
      final startEndpoint = rebuiltEndpoints[index];
      final endEndpoint = rebuiltEndpoints[index + 1];
      final result = await _routePlanner.planSegmentResult(
        start: startEndpoint.point,
        end: endEndpoint.point,
      );
      if (!_isActiveRouteDraftRequest(requestId)) {
        return;
      }

      switch (result.status) {
        case RoutePlanningStatus.routed:
          rebuiltEndpoints[index] = _movedEndpoint(
            startEndpoint,
            result.startAnchor,
            isPeakTarget:
                startEndpoint.kind == RouteDraftEndpointKind.peakTarget,
          );
          rebuiltEndpoints[index + 1] = _movedEndpoint(
            endEndpoint,
            endEndpoint.kind == RouteDraftEndpointKind.peakTarget
                ? null
                : result.endAnchor,
            isPeakTarget: endEndpoint.kind == RouteDraftEndpointKind.peakTarget,
          );
          final segmentPoints =
              rebuiltEndpoints[index + 1].kind ==
                  RouteDraftEndpointKind.peakTarget
              ? _appendPeakTerminalLegIfNeeded(
                  result.points,
                  rebuiltEndpoints[index + 1].point,
                )
              : result.points;
          committedPoints = _appendRouteSegment(committedPoints, segmentPoints);
          distanceMeters += _polylineDistanceMeters(segmentPoints);
          break;
        case RoutePlanningStatus.offTrack:
        case RoutePlanningStatus.noPath:
          usedFallback = true;
          rebuiltEndpoints[index] = _movedEndpoint(
            startEndpoint,
            result.startAnchor,
            isPeakTarget:
                startEndpoint.kind == RouteDraftEndpointKind.peakTarget,
          );
          rebuiltEndpoints[index + 1] = switch (result.status) {
            RoutePlanningStatus.noPath
                when endEndpoint.kind != RouteDraftEndpointKind.peakTarget =>
              _movedEndpoint(endEndpoint, result.endAnchor),
            _ => endEndpoint,
          };
          final segmentPoints = _appendPeakTerminalLegIfNeeded([
            rebuiltEndpoints[index].point,
            rebuiltEndpoints[index + 1].point,
          ], rebuiltEndpoints[index + 1].point);
          committedPoints = _appendRouteSegment(committedPoints, segmentPoints);
          distanceMeters += _polylineDistanceMeters(segmentPoints);
          break;
        case RoutePlanningStatus.failed:
          state = state.copyWith(
            routeDraftStage: RouteDraftStage.segmentFailure,
            routeDraftProvisionalPoints: const [],
            routeDraftError:
                result.errorMessage ?? 'Failed to calculate route.',
            routeDraftMode: routeMode,
            clearRouteDraftPeak: invalidatePeakTarget,
            routeDraftPeakTargetLocked: invalidatePeakTarget
                ? true
                : state.routeDraftPeakTargetLocked,
          );
          return;
      }
    }

    state = state.copyWith(
      routeDraftControlEndpoints: List<RouteDraftControlEndpoint>.unmodifiable(
        rebuiltEndpoints,
      ),
      routeDraftDisplayMarkers: List<RouteDraftDisplayMarker>.unmodifiable(
        _buildDisplayMarkers(rebuiltEndpoints),
      ),
      routeDraftMarkers: List<LatLng>.unmodifiable(
        rebuiltEndpoints.map((endpoint) => endpoint.point),
      ),
      routeDraftStage: RouteDraftStage.awaitingNextPoint,
      routeDraftCommittedPoints: List<LatLng>.unmodifiable(committedPoints),
      routeDraftProvisionalPoints: const [],
      routeDraftDistanceMeters: distanceMeters,
      routeDraftOffTrackProbeActive: usedFallback,
      routeDraftStraightLineFallback: usedFallback,
      clearRouteDraftError: true,
      routeDraftMode: routeMode,
      clearRouteDraftPeak: invalidatePeakTarget,
      routeDraftPeakTargetLocked: invalidatePeakTarget
          ? true
          : state.routeDraftPeakTargetLocked,
      routeDraftRequestId: requestId,
    );
    _resampleRouteDraftElevation();
  }

  void _insertRouteDraftPointIntoChain({
    required int segmentIndex,
    required int committedSegmentIndex,
    required LatLng point,
  }) {
    final controlEndpoints = List<RouteDraftControlEndpoint>.from(
      state.routeDraftControlEndpoints,
    );
    if (segmentIndex < 0 || segmentIndex >= controlEndpoints.length - 1) {
      return;
    }

    final insertedEndpoint = _createControlEndpoint(
      point: point,
      kind: RouteDraftEndpointKind.projectedAnchor,
      id: _routeDraftEndpointId(state.routeDraftNextMarkerId),
    );
    controlEndpoints.insert(segmentIndex + 1, insertedEndpoint);

    final committedPoints = List<LatLng>.from(state.routeDraftCommittedPoints);
    if (committedSegmentIndex >= 0 &&
        committedSegmentIndex < committedPoints.length) {
      committedPoints.insert(committedSegmentIndex + 1, point);
    } else if (segmentIndex + 1 <= committedPoints.length) {
      committedPoints.insert(segmentIndex + 1, point);
    } else {
      committedPoints.add(point);
    }

    state = state.copyWith(
      routeDraftControlEndpoints: List<RouteDraftControlEndpoint>.unmodifiable(
        controlEndpoints,
      ),
      routeDraftDisplayMarkers: List<RouteDraftDisplayMarker>.unmodifiable(
        _buildDisplayMarkers(controlEndpoints),
      ),
      routeDraftMarkers: List<LatLng>.unmodifiable(
        controlEndpoints.map((endpoint) => endpoint.point),
      ),
      routeDraftCommittedPoints: List<LatLng>.unmodifiable(committedPoints),
      routeDraftNextMarkerId: state.routeDraftNextMarkerId + 1,
      routeDraftGeometryVersion: state.routeDraftGeometryVersion + 1,
    );
    _resampleRouteDraftElevation();
  }

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

    final remainingTracks = _gpxTrackRepository.getAllTracks();
    await _peaksBaggedRepository.syncFromTracks(remainingTracks);
    ref.read(peaksBaggedRevisionProvider.notifier).increment();
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

  void reconcileSelectedRouteState() {
    final selectedRouteId = state.selectedRouteId;
    if (selectedRouteId == null) {
      return;
    }

    final hasVisibleRoute =
        state.showRoutes &&
        _routeRepository.getAllRoutes().any(
          (route) => route.id == selectedRouteId,
        );
    if (!hasVisibleRoute) {
      state = state.copyWith(clearSelectedRouteId: true);
    }
  }

  void selectTrack(int trackId) {
    final hasVisibleTrack =
        state.showTracks &&
        state.tracks.any(
          (track) => track.gpxTrackId == trackId && track.visible,
        );
    if (!hasVisibleTrack) {
      return;
    }
    state = state.copyWith(
      selectedTrackId: trackId,
      clearSelectedRouteId: true,
      selectedTrackFocusSerial: state.selectedTrackFocusSerial + 1,
    );
  }

  void showTrack(int trackId, {LatLng? selectedLocation}) {
    final track = _gpxTrackRepository.findById(trackId);
    if (track == null) {
      state = state.copyWith(
        clearSelectedTrackId: true,
        clearHoveredTrackId: true,
      );
      return;
    }

    setTrackVisibility(trackId, true);

    final tracks = _upsertTrackInState(track);

    state = state.copyWith(
      tracks: tracks,
      selectedTrackId: trackId,
      clearSelectedRouteId: true,
      selectedLocation: selectedLocation,
      showTracks: true,
      clearHoveredTrackId: true,
      clearGotoMgrs: true,
      selectedTrackFocusSerial: state.selectedTrackFocusSerial + 1,
    );
  }

  void setTrackVisibility(int trackId, bool visible) {
    final track = _gpxTrackRepository.findById(trackId);
    if (track == null || track.visible == visible) {
      return;
    }

    if (_isRestoringVisibilityPrefs) {
      _showTracksRestoreOverridden = true;
    }

    track.visible = visible;
    _gpxTrackRepository.saveTrack(track);

    final tracks = _upsertTrackInState(track);
    state = state.copyWith(
      tracks: tracks,
      clearHoveredTrackId: !visible && state.hoveredTrackId == trackId,
    );
  }

  void clearSelectedTrack() {
    state = state.copyWith(clearSelectedTrackId: true);
  }

  void selectRoute(int routeId) {
    final hasVisibleRoute =
        state.showRoutes &&
        _routeRepository.getAllRoutes().any(
          (route) => route.id == routeId && route.visible,
        );
    if (!hasVisibleRoute) {
      return;
    }

    state = state.copyWith(
      selectedRouteId: routeId,
      clearSelectedTrackId: true,
      selectedRouteFocusSerial: state.selectedRouteFocusSerial + 1,
    );
  }

  void showRoute(int routeId) {
    final route = _routeRepository.findById(routeId);
    if (route == null) {
      state = state.copyWith(
        clearSelectedRouteId: true,
        clearSelectedTrackId: true,
        clearHoveredRouteId: true,
      );
      return;
    }

    setRouteVisibility(routeId, true);

    state = state.copyWith(
      selectedRouteId: routeId,
      clearSelectedTrackId: true,
      showRoutes: true,
      clearHoveredRouteId: true,
      clearGotoMgrs: true,
      selectedRouteFocusSerial: state.selectedRouteFocusSerial + 1,
    );
  }

  void setRouteVisibility(int routeId, bool visible) {
    final route = _routeRepository.findById(routeId);
    if (route == null || route.visible == visible) {
      return;
    }

    if (_isRestoringVisibilityPrefs) {
      _showRoutesRestoreOverridden = true;
    }

    route.visible = visible;
    _routeRepository.saveRoute(route);
    ref.read(routeRevisionProvider.notifier).increment();

    if (!visible && state.hoveredRouteId == routeId) {
      state = state.copyWith(clearHoveredRouteId: true);
    }
  }

  void clearSelectedRoute() {
    state = state.copyWith(clearSelectedRouteId: true);
  }

  void setHoveredRouteId(int? routeId) {
    if (state.hoveredRouteId == routeId) {
      return;
    }
    state = state.copyWith(hoveredRouteId: routeId);
  }

  void clearHoveredRoute() {
    if (state.hoveredRouteId == null) {
      return;
    }
    state = state.copyWith(hoveredRouteId: null);
  }

  List<GpxTrack> _upsertTrackInState(GpxTrack track) {
    final updatedTracks = <GpxTrack>[];
    var replaced = false;

    for (final existing in state.tracks) {
      if (existing.gpxTrackId == track.gpxTrackId) {
        updatedTracks.add(track);
        replaced = true;
      } else {
        updatedTracks.add(existing);
      }
    }

    if (!replaced) {
      updatedTracks.add(track);
    }

    return List<GpxTrack>.unmodifiable(updatedTracks);
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

  Future<void> prefetchRouteGraphVisibleBounds(LatLngBounds bounds) async {
    final queryService = ref.read(routeGraphQueryServiceProvider);
    if (queryService == null) {
      return;
    }

    try {
      await queryService.prefetchBounds(
        minLat: bounds.south,
        minLon: bounds.west,
        maxLat: bounds.north,
        maxLon: bounds.east,
      );
    } catch (_) {
      // Prefetch is best-effort only.
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
    cycleMapGridVisibility();
  }

  void cycleMapGridVisibility() {
    final nextVisibility = switch (state.gridVisibility) {
      MapGridVisibility.hidden => MapGridVisibility.mapGridOnly,
      MapGridVisibility.mapGridOnly => MapGridVisibility.mapGridAndDistanceGrid,
      MapGridVisibility.mapGridAndDistanceGrid => MapGridVisibility.hidden,
    };

    final nextMode = switch (nextVisibility) {
      MapGridVisibility.hidden => TasmapDisplayMode.none,
      MapGridVisibility.mapGridOnly =>
        state.selectedMap == null
            ? TasmapDisplayMode.overlay
            : TasmapDisplayMode.selectedMap,
      MapGridVisibility.mapGridAndDistanceGrid =>
        state.selectedMap == null
            ? TasmapDisplayMode.overlay
            : TasmapDisplayMode.selectedMap,
    };

    state = state.copyWith(
      gridVisibility: nextVisibility,
      tasmapDisplayMode: nextMode,
    );
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
    final map = _tasmapRepository.findByPoint(state.center);
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

  void setGotoInputVisible(bool visible) {
    state = state.copyWith(showGotoInput: visible);
  }

  void togglePeakSearch() {
    state = state.copyWith(showPeakSearch: !state.showPeakSearch);
  }

  void toggleTracks() {
    if (state.isLoadingTracks || state.hasTrackRecoveryIssue) {
      return;
    }
    if (_isRestoringVisibilityPrefs) {
      _showTracksRestoreOverridden = true;
    }
    state = state.copyWith(
      showTracks: !state.showTracks,
      clearHoveredTrackId: true,
      clearSelectedTrackId: state.showTracks,
    );
    persistTracksRoutesVisibility();
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
        return _resolvePeakInfoContentForPeak(peak);
      }
    }
    return null;
  }

  void refreshPeakInfoPopupContent() {
    if (state.peakInfo == null) {
      return;
    }

    final refreshedPeakInfo = _refreshedPeakInfo(state.peaks);
    state = state.copyWith(
      peakInfo: refreshedPeakInfo,
      clearPeakInfoPopup: refreshedPeakInfo == null,
    );
  }

  PeakInfoContent _resolvePeakInfoContentForPeak(Peak peak) {
    try {
      return resolvePeakInfoContent(
        peak: peak,
        peakListRepository: ref.read(peakListRepositoryProvider),
        tasmapRepository: ref.read(tasmapRepositoryProvider),
        peaksBaggedRepository: _readPeaksBaggedRepository(),
        gpxTrackRepository: _readGpxTrackRepository(),
      );
    } catch (_) {
      return PeakInfoContent(
        peak: peak,
        mapName: 'Unknown',
        listNames: const [],
        ascentRows: const [],
      );
    }
  }

  PeaksBaggedRepository _readPeaksBaggedRepository() {
    try {
      return ref.read(peaksBaggedRepositoryProvider);
    } catch (_) {
      return PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage());
    }
  }

  GpxTrackRepository _readGpxTrackRepository() {
    try {
      return ref.read(gpxTrackRepositoryProvider);
    } catch (_) {
      return GpxTrackRepository.test(InMemoryGpxTrackStorage());
    }
  }

  bool _inRange(int value, int min, int max) {
    if (min <= max) {
      return value >= min && value <= max;
    } else {
      return value >= min || value <= max;
    }
  }
}

class _RouteSummary {
  const _RouteSummary({
    required this.distance3d,
    required this.ascent,
    required this.descent,
    required this.startElevation,
    required this.endElevation,
    required this.lowestElevation,
    required this.highestElevation,
  });

  final double distance3d;
  final double ascent;
  final double descent;
  final double startElevation;
  final double endElevation;
  final double lowestElevation;
  final double highestElevation;
}
