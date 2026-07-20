import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/gestures.dart'
    show
        PointerPanZoomEndEvent,
        PointerPanZoomStartEvent,
        PointerPanZoomUpdateEvent,
        kPrimaryMouseButton;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/map_polygon_asset.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/models/route_marker_display.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_ownership_ring_segment.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/drive_eta_provider.dart';
import 'package:peak_bagger/providers/polygon_assets_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/map_chart_hover_provider.dart';
import 'package:peak_bagger/providers/peak_marker_info_settings_provider.dart';
import 'package:peak_bagger/providers/peak_ownership_ring_settings_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/show_polygons_settings_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/providers/gpx_export_provider.dart';
import 'package:peak_bagger/services/peak_hover_detector.dart';
import 'package:peak_bagger/services/peak_cluster_engine.dart';
import 'package:peak_bagger/services/peak_hit_test.dart';
import 'package:peak_bagger/services/peak_projection_cache.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/route_graph_trail_provider.dart';
import 'package:peak_bagger/services/route_hover_detector.dart';
import 'package:peak_bagger/services/track_hover_detector.dart';
import 'package:peak_bagger/services/map_chart_hover_resolver.dart';
import 'package:peak_bagger/services/map_trackpad_gesture_classifier.dart';
import 'package:peak_bagger/services/live_location_service.dart';
import 'package:peak_bagger/services/map_search_region_filter.dart';
import 'package:peak_bagger/services/open_route_service.dart';
import 'package:peak_bagger/services/route_graph_drive_eta_hit_service.dart';
import 'package:peak_bagger/services/tile_cache_service.dart';
import '../core/constants.dart';
import 'package:peak_bagger/widgets/map_action_rail.dart';
import 'package:peak_bagger/widgets/map_basemaps_drawer.dart';
import 'package:peak_bagger/widgets/map_peak_lists_drawer.dart';
import 'package:peak_bagger/widgets/map_tracks_routes_drawer.dart';
import 'package:peak_bagger/widgets/map_route_bottom_sheet.dart';
import 'package:peak_bagger/widgets/map_rebuild_debug_counters.dart';
import 'package:peak_bagger/widgets/map_chart_hover_marker.dart';
import 'package:peak_bagger/widgets/map_marker.dart';
import 'package:peak_bagger/widgets/map_metadata_filter_popup.dart';
import 'package:peak_bagger/widgets/tasmap_polygon_label.dart';
import 'package:peak_bagger/widgets/map_search_popup.dart';
import 'package:peak_bagger/widgets/dialog_helpers.dart';
import 'package:peak_bagger/theme.dart';

import 'map_screen_layers.dart';
import 'map_screen_peak_layer.dart';
import 'map_screen_panels.dart';

class DismissSurfaceIntent extends Intent {
  const DismissSurfaceIntent();
}

class _RouteDraftHoverCandidate {
  const _RouteDraftHoverCandidate({
    required this.controlSegmentIndex,
    required this.committedSegmentIndex,
    required this.start,
    required this.end,
    required this.startsAtControlEndpoint,
    required this.endsAtControlEndpoint,
  });

  final int controlSegmentIndex;
  final int committedSegmentIndex;
  final Offset start;
  final Offset end;
  final bool startsAtControlEndpoint;
  final bool endsAtControlEndpoint;
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  static const _chartHoverResolver = MapChartHoverResolver();

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final MapController _mapController;
  late final MapNotifier _mapNotifier;
  late final MapChartHoverNotifier _mapChartHoverNotifier;
  final _gotoController = TextEditingController();
  final _gotoFocusNode = FocusNode();
  final _searchFocusNode = FocusNode();
  final _mapFocusNode = FocusNode();
  String? _gotoError;
  bool _mapReady = false;
  bool _wasRouteDrafting = false;
  Tasmap50k? _pendingSelectedMap;
  int? _pendingSelectedMapSerial;
  int? _appliedSelectedMapSerial;
  GpxTrack? _pendingSelectedTrack;
  int? _pendingSelectedTrackSerial;
  int? _appliedSelectedTrackSerial;
  app_route.Route? _pendingSelectedRoute;
  int? _pendingSelectedRouteSerial;
  int? _appliedSelectedRouteSerial;
  int? _pendingCameraRequestSerial;
  int? _appliedCameraRequestSerial;
  List<String>? _basemapDrawerBasemapKeys;
  bool _isPointerDown = false;
  Offset? _pointerDownPosition;
  bool _primaryClickPending = false;
  bool _driveEtaClickConsumed = false;
  bool _routeDraftMarkerTapConsumed = false;
  String? _routeDraftDeletePopupMarkerId;
  int? _routeDraftDeletePopupViewportRevision;
  Offset? _mapTapActionPopupAnchor;
  LatLng? _mapTapActionPopupLocation;
  RouteGraphDriveEtaHitResult? _mapTapActionPopupDriveEtaHit;
  bool _showFavouritesPopup = false;
  List<TrackRouteChooserItem>? _trackRouteChooserItems;
  Offset? _trackRouteChooserAnchor;
  int? _trackRouteChooserViewportRevision;
  bool _trackRouteChooserSuppressReopen = false;
  String? _pendingRouteDraftDragMarkerId;
  double _pendingRouteDraftDragDistance = 0;
  bool _pendingHoveredRouteDraftSegmentDrag = false;
  double _pendingHoveredRouteDraftSegmentDragDistance = 0;
  String? _draggingRouteDraftMarkerId;
  Offset? _draggingRouteDraftMarkerScreenOffset;
  LatLng? _trackpadGestureCenter;
  double? _trackpadGestureZoom;
  Timer? _scrollTimer;
  Timer? _routeGraphPrefetchTimer;
  double _scrollDx = 0;
  double _scrollDy = 0;
  _LiveCameraState? _liveCamera;
  int _cameraIntentToken = 0;
  final _viewportUiRevision = ValueNotifier<int>(0);
  Timer? _pendingCameraSaveTimer;
  bool _hasPendingCameraSave = false;
  String? _dragFrozenReadoutMgrs;
  String? _dragFrozenReadoutMapName;
  OverlayEntry? _routeGraphOverlayEntry;
  bool _routeDraftOverlayVisible = false;
  bool _routeDraftOverlaySyncScheduled = false;
  int? _cachedTrackHoverViewportRevision;
  int? _cachedTrackHoverDisplayZoom;
  List<GpxTrack>? _cachedTrackHoverTracks;
  List<TrackHoverCandidate>? _cachedTrackHoverCandidates;
  final _peakProjectionCache = PeakProjectionCache();
  _SettledPeakViewportFrame? _settledPeakViewportFrame;
  PolygonLayer? _cachedPolygonAssetLayer;
  List<MapPolygonAsset>? _cachedPolygonAssetLayerAssets;
  int? _cachedRouteHoverViewportRevision;
  int? _cachedRouteHoverDisplayZoom;
  List<app_route.Route>? _cachedRouteHoverRoutes;
  List<RouteHoverCandidate>? _cachedRouteHoverCandidates;
  Basemap? _cachedTileProviderBasemap;
  TileProvider? _cachedTileProvider;
  int _driveEtaRequestId = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapController = MapController();
    _mapNotifier = ref.read(mapProvider.notifier);
    _mapChartHoverNotifier = ref.read(mapChartHoverProvider.notifier);
    ref.listenManual<
      ({
        bool isRouteDrafting,
        List<RouteDraftDisplayMarker> routeDraftDisplayMarkers,
        int routeDraftRequestId,
      })
    >(
      mapProvider.select(
        (state) => (
          isRouteDrafting: state.isRouteDrafting,
          routeDraftDisplayMarkers: state.routeDraftDisplayMarkers,
          routeDraftRequestId: state.routeDraftRequestId,
        ),
      ),
      (previous, next) {
        final popupMarkerId = _routeDraftDeletePopupMarkerId;
        if (popupMarkerId == null) {
          return;
        }

        final markerStillVisible = next.routeDraftDisplayMarkers.any(
          (marker) => marker.id == popupMarkerId,
        );
        if (!next.isRouteDrafting ||
            !markerStillVisible ||
            previous?.routeDraftDisplayMarkers !=
                next.routeDraftDisplayMarkers ||
            previous?.routeDraftRequestId != next.routeDraftRequestId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _dismissRouteDraftMarkerDeletePopup();
            }
          });
        }
      },
    );
    ref.listenManual<bool>(mapProvider.select((state) => state.showTrails), (
      previous,
      next,
    ) {
      if (next && next != previous && mounted && _mapReady) {
        unawaited(
          _mapNotifier.prefetchRouteGraphVisibleBounds(
            _mapController.camera.visibleBounds,
          ),
        );
      }
    });
    ref.listenManual(routeListProvider, (previous, next) {
      _mapNotifier.reconcileSelectedRouteState();
    });
    ref.listenManual<({int? selectedRouteId, int? selectedTrackId})>(
      mapProvider.select(
        (state) => (
          selectedRouteId: state.selectedRouteId,
          selectedTrackId: state.selectedTrackId,
        ),
      ),
      (previous, next) {
        if (previous != next) {
          ref.read(mapChartHoverProvider.notifier).clear();
        }
      },
    );
    _searchFocusNode.addListener(_onSearchFocusChange);
    _gotoFocusNode.addListener(_onGotoFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _mapNotifier.reconcileSelectedTrackState();
      _mapNotifier.reconcileSelectedRouteState();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _flushPendingCameraPosition();
    }
  }

  Future<void> _exportInfoSelection({
    GpxTrack? track,
    app_route.Route? route,
  }) async {
    final service = ref.read(gpxExportServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      var plan = track != null
          ? service.planTrackExport(track)
          : await service.planRouteExport(route!);
      if (!mounted) {
        return;
      }

      if (service.fileExists(plan)) {
        final action = await showExportConflictDialog(
          context: context,
          title: 'Overwrite Export?',
          message:
              'This file already exists. Do you want to overwrite it or add a new version?',
          cancelKey: 'tracks-routes-export-cancel',
          overwriteKey: 'tracks-routes-export-confirm',
          newVersionKey: 'tracks-routes-export-new-version',
        );
        if (action == ExportConflictAction.cancel || !mounted) {
          return;
        }

        if (action == ExportConflictAction.newVersion) {
          plan = service.planNewVersionExport(plan);
        }
      }

      await service.writeExport(plan);
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Exported to ${plan.path}')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      messenger.showSnackBar(SnackBar(content: Text('Export failed: $error')));
    }
  }

  void _handleGotoSubmit(MapState mapState) {
    if (mapState.mapSuggestions.isNotEmpty) {
      final firstMap = mapState.mapSuggestions.first;
      _gotoController.text = firstMap.name;
      ref.read(mapProvider.notifier).selectMap(firstMap);
      _zoomToMapExtent(firstMap);
      ref.read(mapProvider.notifier).setGotoInputVisible(false);
    } else if (_gotoError == null) {
      _navigateToGridReference();
    }
  }

  void _handleGotoTab() {
    final mapState = ref.read(mapProvider);
    if (mapState.mapSuggestions.isNotEmpty) {
      final firstMap = mapState.mapSuggestions.first;
      final newText = '${firstMap.name} ';
      _gotoController.text = newText;
      _gotoController.selection = TextSelection.collapsed(
        offset: newText.length,
      );
      ref.read(mapProvider.notifier).parseGridReference(newText);
    }
  }

  void _onSearchFocusChange() {
    if (!_searchFocusNode.hasFocus && mounted) {
      _mapFocusNode.requestFocus();
    }
  }

  void _onGotoFocusChange() {
    if (!_gotoFocusNode.hasFocus && mounted) {
      _mapFocusNode.requestFocus();
    }
  }

  bool _dismissHighestPrioritySurface() {
    final mapState = ref.read(mapProvider);
    final notifier = ref.read(mapProvider.notifier);
    final panelVisible =
        (mapState.showTracks &&
            mapState.tracks.any(
              (track) => track.gpxTrackId == mapState.selectedTrackId,
            )) ||
        (mapState.showRoutes && mapState.selectedRouteId != null);
    final scaffoldState = _scaffoldKey.currentState;
    final scaffoldContext = _scaffoldKey.currentContext;
    if ((scaffoldState?.isEndDrawerOpen ?? false) && scaffoldContext != null) {
      Navigator.of(scaffoldContext).pop();
      _mapFocusNode.requestFocus();
      return true;
    }
    if (_routeDraftDeletePopupMarkerId != null) {
      _dismissRouteDraftMarkerDeletePopup();
      return true;
    }
    if (_trackRouteChooserItems != null) {
      _dismissTrackRouteChooser(suppressReopen: true);
      return true;
    }
    if (_mapTapActionPopupAnchor != null ||
        _mapTapActionPopupLocation != null) {
      _dismissMapTapActionPopup();
      return true;
    }
    if (_showFavouritesPopup) {
      setState(() {
        _showFavouritesPopup = false;
      });
      return true;
    }
    if (mapState.driveEtaPopup != null) {
      notifier.closeDriveEtaPopup();
      return true;
    }
    if (mapState.peakInfoPeak != null) {
      notifier.closePeakInfoPopup();
      return true;
    }
    if (mapState.showInfoPopup) {
      notifier.toggleInfoPopup();
      return true;
    }
    if (mapState.showPeakMetadataFilters) {
      notifier.closePeakMetadataFilters();
      return true;
    }
    if (mapState.showPeakSearch) {
      notifier.closeSearchPopup();
      return true;
    }
    if (panelVisible) {
      notifier.clearSelectedRoute();
      notifier.clearSelectedTrack();
      _mapFocusNode.requestFocus();
      return true;
    }
    return false;
  }

  void _showDropMarkerPopupForCurrentLocation() {
    if (_mapTapActionPopupAnchor != null ||
        _mapTapActionPopupLocation != null) {
      _dismissMapTapActionPopup();
      return;
    }
    final location = switch (_mapController.camera.nonRotatedSize) {
      MapCamera.kImpossibleSize => ref.read(mapProvider).center,
      _ => _mapController.camera.center,
    };
    final anchor = switch (_mapController.camera.nonRotatedSize) {
      MapCamera.kImpossibleSize => Offset(
        MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height / 2,
      ),
      _ => _screenOffsetForLatLng(location),
    };
    _openMapTapActionPopup(
      anchor: anchor,
      location: location,
      driveEtaHit: _driveEtaHitForTap(
        localPosition: anchor,
        tappedLocation: location,
        hoveredTrackId: null,
        hoveredRouteId: null,
      ),
    );
  }

  void _openMapTapActionPopup({
    required Offset anchor,
    required LatLng location,
    RouteGraphDriveEtaHitResult? driveEtaHit,
  }) {
    setState(() {
      _mapTapActionPopupAnchor = anchor;
      _mapTapActionPopupLocation = location;
      _mapTapActionPopupDriveEtaHit = driveEtaHit;
      _showFavouritesPopup = false;
    });
    _mapFocusNode.requestFocus();
  }

  void _dismissMapTapActionPopup() {
    if (_mapTapActionPopupAnchor == null &&
        _mapTapActionPopupLocation == null) {
      return;
    }
    setState(() {
      _mapTapActionPopupAnchor = null;
      _mapTapActionPopupLocation = null;
      _mapTapActionPopupDriveEtaHit = null;
    });
  }

  Future<void> _handleDropMarkerFromPopup() async {
    final location = _mapTapActionPopupLocation;
    if (location == null) {
      return;
    }
    final saved = await ref
        .read(mapProvider.notifier)
        .setCurrentMarker(location);
    if (saved && mounted) {
      _dismissMapTapActionPopup();
    }
  }

  Future<void> _handleDropFavouriteFromPopup() async {
    final location = _mapTapActionPopupLocation;
    if (location == null || !mounted) {
      return;
    }
    final notifier = ref.read(mapProvider.notifier);
    final name = await showFavouriteNameDialog(
      context,
      nameExists: notifier.favouriteNameExists,
    );
    if (!mounted || name == null) {
      return;
    }
    final saved = await notifier.saveFavouriteWaypoint(location, name: name);
    if (saved && mounted) {
      _dismissMapTapActionPopup();
    }
  }

  void _toggleFavouritesPopup() {
    _dismissMapTapActionPopup();
    _mapFocusNode.requestFocus();
    setState(() {
      _showFavouritesPopup = !_showFavouritesPopup;
    });
  }

  RouteGraphDriveEtaHitResult? _driveEtaHitForTap({
    required Offset localPosition,
    required LatLng tappedLocation,
    required int? hoveredTrackId,
    required int? hoveredRouteId,
  }) {
    if (hoveredTrackId != null || hoveredRouteId != null) {
      return null;
    }
    try {
      final hitService = ref.read(routeGraphDriveEtaHitServiceProvider);
      if (hitService == null) {
        return null;
      }
      final hit = hitService.hitTest(
        pointerPosition: localPosition,
        camera: _mapController.camera,
        tappedLocation: tappedLocation,
      );
      return hit.status == RouteGraphDriveEtaHitStatus.hit ? hit : null;
    } catch (error, stackTrace) {
      debugPrintStack(
        label: 'Drive ETA hit-test failed: $error',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  LatLng? _homeLocation() {
    try {
      final coords = mgrs.Mgrs.toPoint(
        MapConstants.homeMgrs.replaceAll(RegExp(r'\s+'), ''),
      );
      return LatLng(coords[1], coords[0]);
    } catch (_) {
      return null;
    }
  }

  String _driveEtaPopupTitleForHit(RouteGraphDriveEtaHitResult hit) {
    return hit.wayName?.trim().isNotEmpty == true
        ? hit.wayName!.trim()
        : 'Drive ETA';
  }

  Future<void> _handleDriveEtaFromHome() async {
    final hit = _mapTapActionPopupDriveEtaHit;
    if (hit?.snappedPoint == null) {
      return;
    }
    final requestId = ++_driveEtaRequestId;
    final title = _driveEtaPopupTitleForHit(hit!);
    final origin = _homeLocation();
    if (origin == null) {
      ref
          .read(mapProvider.notifier)
          .openDriveEtaPopupError(
            requestId: requestId,
            anchor: hit.snappedPoint!,
            title: title,
            message: 'Home location is unavailable.',
          );
      _dismissMapTapActionPopup();
      return;
    }
    ref
        .read(mapProvider.notifier)
        .showDriveEtaPopupLoading(
          requestId: requestId,
          anchor: hit.snappedPoint!,
          title: title,
        );
    _dismissMapTapActionPopup();
    unawaited(
      _resolveDriveEta(
        requestId: requestId,
        origin: origin,
        destination: hit.snappedPoint!,
      ),
    );
  }

  Future<void> _handleDriveEtaFromMarker() async {
    final hit = _mapTapActionPopupDriveEtaHit;
    final origin = ref.read(mapProvider).selectedLocation;
    if (hit?.snappedPoint == null || origin == null) {
      return;
    }
    final requestId = ++_driveEtaRequestId;
    ref
        .read(mapProvider.notifier)
        .showDriveEtaPopupLoading(
          requestId: requestId,
          anchor: hit!.snappedPoint!,
          title: _driveEtaPopupTitleForHit(hit),
        );
    _dismissMapTapActionPopup();
    unawaited(
      _resolveDriveEta(
        requestId: requestId,
        origin: origin,
        destination: hit.snappedPoint!,
      ),
    );
  }

  void _beginRouteDraft() {
    final scaffoldState = _scaffoldKey.currentState;
    final scaffoldContext = _scaffoldKey.currentContext;
    final mapState = ref.read(mapProvider);
    final notifier = ref.read(mapProvider.notifier);
    final peakTarget = mapState.routeDraftPeakTarget;

    if ((scaffoldState?.isEndDrawerOpen ?? false) && scaffoldContext != null) {
      Navigator.of(scaffoldContext).pop();
    }

    if (peakTarget != null) {
      notifier.closePeakInfoPopup();
    }
    if (mapState.driveEtaPopup != null) {
      notifier.closeDriveEtaPopup();
    }
    if (mapState.showInfoPopup) {
      notifier.toggleInfoPopup();
    }
    if (mapState.showPeakSearch) {
      notifier.closeSearchPopup();
    }
    if (mapState.showGotoInput) {
      notifier.setGotoInputVisible(false);
    }

    notifier.clearSelectedTrack();
    notifier.clearSelectedRoute();
    _dismissMapTapActionPopup();
    if (_showFavouritesPopup) {
      setState(() {
        _showFavouritesPopup = false;
      });
    }
    _dismissTrackRouteChooser(suppressReopen: true);
    notifier.beginRouteDraft(peakTarget: peakTarget);
    _dismissRouteDraftMarkerDeletePopup();
    _mapFocusNode.requestFocus();
  }

  void _consumeRouteDraftMarkerTap(String markerId) {
    _routeDraftMarkerTapConsumed = true;
    _pendingRouteDraftDragMarkerId = markerId;
    _pendingRouteDraftDragDistance = 0;
    if (_routeDraftDeletePopupMarkerId != markerId) {
      _dismissRouteDraftMarkerDeletePopup();
    }
  }

  void _trackRouteDraftMarkerDrag(String markerId, Offset delta) {
    if (_pendingRouteDraftDragMarkerId != markerId &&
        _draggingRouteDraftMarkerId != markerId) {
      return;
    }

    _routeDraftMarkerTapConsumed = true;
    if (_draggingRouteDraftMarkerId == null) {
      _pendingRouteDraftDragDistance += delta.distance;
      if (_pendingRouteDraftDragDistance <= 5) {
        return;
      }
      _startRouteDraftMarkerDrag(markerId);
    }

    _updateRouteDraftMarkerDrag(markerId, delta);
  }

  void _finishRouteDraftMarkerInteraction(String markerId) {
    if (_draggingRouteDraftMarkerId == markerId) {
      _endRouteDraftMarkerDrag(markerId);
    }
    if (_pendingRouteDraftDragMarkerId == markerId) {
      _pendingRouteDraftDragMarkerId = null;
      _pendingRouteDraftDragDistance = 0;
    }
  }

  void _openRouteDraftMarkerDeletePopup(String markerId) {
    setState(() {
      _routeDraftDeletePopupMarkerId = markerId;
      _routeDraftDeletePopupViewportRevision = _viewportUiRevision.value;
    });
    _mapFocusNode.requestFocus();
  }

  void _dismissRouteDraftMarkerDeletePopup() {
    if (_routeDraftDeletePopupMarkerId == null &&
        _routeDraftDeletePopupViewportRevision == null) {
      return;
    }

    setState(() {
      _routeDraftDeletePopupMarkerId = null;
      _routeDraftDeletePopupViewportRevision = null;
    });
  }

  void _openTrackRouteChooser({
    required Offset anchor,
    required List<TrackRouteChooserItem> items,
  }) {
    final notifier = ref.read(mapProvider.notifier);
    notifier.clearHoveredPeak();
    notifier.clearHoveredTrack();
    notifier.clearHoveredRoute();
    setState(() {
      _trackRouteChooserAnchor = anchor;
      _trackRouteChooserItems = items;
      _trackRouteChooserViewportRevision = _viewportUiRevision.value;
      _trackRouteChooserSuppressReopen = false;
    });
  }

  void _dismissTrackRouteChooser({bool suppressReopen = false}) {
    if (_trackRouteChooserItems == null &&
        _trackRouteChooserAnchor == null &&
        _trackRouteChooserViewportRevision == null &&
        (!suppressReopen || !_trackRouteChooserSuppressReopen)) {
      return;
    }

    setState(() {
      _trackRouteChooserAnchor = null;
      _trackRouteChooserItems = null;
      _trackRouteChooserViewportRevision = null;
      _trackRouteChooserSuppressReopen = suppressReopen;
    });
  }

  void _selectTrackRouteChooserItem(TrackRouteChooserItem item) {
    final notifier = ref.read(mapProvider.notifier);
    _dismissTrackRouteChooser(suppressReopen: true);
    switch (item.kind) {
      case TrackRouteChooserItemKind.track:
        notifier.selectTrack(item.track!.gpxTrackId);
        break;
      case TrackRouteChooserItemKind.route:
        notifier.selectRoute(item.route!.id);
        break;
    }
  }

  void _startRouteDraftMarkerDrag(String markerId) {
    final mapState = ref.read(mapProvider);
    if (!mapState.isRouteDrafting ||
        mapState.isSavingRoute ||
        mapState.routeDraftStage == RouteDraftStage.routingSegment) {
      return;
    }

    RouteDraftDisplayMarker? marker;
    for (final candidate in mapState.routeDraftDisplayMarkers) {
      if (candidate.id == markerId) {
        marker = candidate;
        break;
      }
    }
    final camera = _mapController.camera;
    if (marker == null || camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return;
    }

    _routeDraftMarkerTapConsumed = true;
    _dismissRouteDraftMarkerDeletePopup();
    _pendingRouteDraftDragMarkerId = null;
    _pendingRouteDraftDragDistance = 0;
    _draggingRouteDraftMarkerId = markerId;
    _draggingRouteDraftMarkerScreenOffset = camera.latLngToScreenOffset(
      marker.point,
    );
    ref.read(mapProvider.notifier).beginRouteDraftMarkerDrag(markerId);
    _bumpViewportUiRevision();
  }

  void _startHoveredRouteDraftSegmentDrag() {
    final mapState = ref.read(mapProvider);
    final hoveredPoint = mapState.hoveredRouteDraftSegmentPoint;
    final camera = _mapController.camera;
    if (!mapState.isRouteDrafting ||
        mapState.isSavingRoute ||
        hoveredPoint == null ||
        camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return;
    }

    final notifier = ref.read(mapProvider.notifier);
    final insertedMarkerId = notifier.commitHoveredRouteDraftSegmentPreview();
    if (insertedMarkerId == null) {
      return;
    }

    _routeDraftMarkerTapConsumed = true;
    _dismissRouteDraftMarkerDeletePopup();
    _pendingHoveredRouteDraftSegmentDrag = false;
    _pendingHoveredRouteDraftSegmentDragDistance = 0;
    _pendingRouteDraftDragMarkerId = null;
    _pendingRouteDraftDragDistance = 0;
    _draggingRouteDraftMarkerId = insertedMarkerId;
    _draggingRouteDraftMarkerScreenOffset = camera.latLngToScreenOffset(
      hoveredPoint,
    );
    notifier.beginRouteDraftMarkerDrag(insertedMarkerId, pushHistory: false);
    _bumpViewportUiRevision();
  }

  void _beginHoveredRouteDraftSegmentInteraction() {
    _routeDraftMarkerTapConsumed = true;
    _pendingHoveredRouteDraftSegmentDrag = true;
    _pendingHoveredRouteDraftSegmentDragDistance = 0;
    _dismissRouteDraftMarkerDeletePopup();
  }

  void _trackHoveredRouteDraftSegmentDrag(Offset delta) {
    if (!_pendingHoveredRouteDraftSegmentDrag &&
        _draggingRouteDraftMarkerId == null) {
      return;
    }

    _routeDraftMarkerTapConsumed = true;
    if (_draggingRouteDraftMarkerId == null) {
      _pendingHoveredRouteDraftSegmentDragDistance += delta.distance;
      if (_pendingHoveredRouteDraftSegmentDragDistance <= 5) {
        return;
      }
      _startHoveredRouteDraftSegmentDrag();
    }

    final markerId = _draggingRouteDraftMarkerId;
    if (markerId == null) {
      return;
    }
    _updateRouteDraftMarkerDrag(markerId, delta);
  }

  void _endHoveredRouteDraftSegmentInteraction() {
    final markerId = _draggingRouteDraftMarkerId;
    if (markerId != null) {
      _endRouteDraftMarkerDrag(markerId);
      return;
    }
    _pendingHoveredRouteDraftSegmentDrag = false;
    _pendingHoveredRouteDraftSegmentDragDistance = 0;
  }

  void _updateRouteDraftMarkerDrag(String markerId, Offset delta) {
    if (_draggingRouteDraftMarkerId != markerId ||
        _draggingRouteDraftMarkerScreenOffset == null) {
      return;
    }

    _routeDraftMarkerTapConsumed = true;
    final nextScreenOffset = _draggingRouteDraftMarkerScreenOffset! + delta;
    _draggingRouteDraftMarkerScreenOffset = nextScreenOffset;
    final nextPoint = _mapController.camera.screenOffsetToLatLng(
      nextScreenOffset,
    );
    unawaited(
      ref
          .read(mapProvider.notifier)
          .updateRouteDraftMarkerDrag(markerId, nextPoint),
    );
    _bumpViewportUiRevision();
  }

  void _endRouteDraftMarkerDrag(String markerId) {
    if (_draggingRouteDraftMarkerId != markerId) {
      return;
    }

    final screenOffset = _draggingRouteDraftMarkerScreenOffset;
    _draggingRouteDraftMarkerId = null;
    _draggingRouteDraftMarkerScreenOffset = null;
    _pendingRouteDraftDragMarkerId = null;
    _pendingRouteDraftDragDistance = 0;
    if (screenOffset != null) {
      final point = _mapController.camera.screenOffsetToLatLng(screenOffset);
      unawaited(
        ref.read(mapProvider.notifier).moveRouteDraftMarker(markerId, point),
      );
    }
    _bumpViewportUiRevision();
  }

  Future<void> _resolveDriveEta({
    required int requestId,
    LatLng? origin,
    required LatLng destination,
  }) async {
    try {
      final openRouteService = ref.read(openRouteServiceProvider);
      final resolvedOrigin =
          origin ??
          await ref.read(liveLocationServiceProvider).getCurrentLocation();
      final summary = await openRouteService.fetchDrivingSummary(
        origin: resolvedOrigin,
        destination: destination,
      );
      if (!mounted) {
        return;
      }
      ref
          .read(mapProvider.notifier)
          .showDriveEtaPopupSuccess(
            requestId: requestId,
            distanceMeters: summary.distanceMeters,
            durationSeconds: summary.durationSeconds,
          );
    } catch (error, stackTrace) {
      debugPrintStack(
        label: 'Drive ETA failed: $error',
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      ref
          .read(mapProvider.notifier)
          .showDriveEtaPopupError(
            requestId: requestId,
            message: switch (error) {
              LiveLocationException(:final message) => message,
              OpenRouteServiceException(:final message) => message,
              _ => 'Drive ETA unavailable.',
            },
          );
    }
  }

  Future<void> _deleteRouteDraftMarker(String markerId) async {
    _dismissRouteDraftMarkerDeletePopup();
    await ref.read(mapProvider.notifier).deleteRouteDraftMarker(markerId);
    if (mounted) {
      _mapFocusNode.requestFocus();
    }
  }

  MouseCursor _mouseCursor({
    required String? hoveredRouteDraftMarkerId,
    required int? hoveredRouteDraftSegmentIndex,
    required int? hoveredTrackId,
    required int? hoveredRouteId,
    required int? hoveredPeakId,
  }) {
    if (_isPointerDown) {
      return SystemMouseCursors.grabbing;
    }
    if (hoveredRouteDraftMarkerId != null) {
      return SystemMouseCursors.grab;
    }
    if (hoveredRouteDraftSegmentIndex != null) {
      return SystemMouseCursors.click;
    }
    if (hoveredTrackId != null || hoveredRouteId != null) {
      return SystemMouseCursors.click;
    }
    if (hoveredPeakId != null) {
      return SystemMouseCursors.click;
    }
    return SystemMouseCursors.grab;
  }

  bool _handlePeakHover(
    Offset localPosition,
    MapState mapState,
    List<Peak> peaks,
  ) {
    if (_isPointerDown ||
        !mapState.showPeaks ||
        mapState.zoom < MapConstants.peakMinZoom) {
      ref.read(mapProvider.notifier).clearHoveredPeak();
      ref.read(mapProvider.notifier).closeHoveredPeakInfoPopup();
      return false;
    }

    final peak = _hitTestPeak(localPosition, mapState, peaks);
    ref.read(mapProvider.notifier).setHoveredPeakId(peak?.osmId);
    return peak != null;
  }

  void _handleRouteHover(
    Offset localPosition,
    MapState mapState,
    List<app_route.Route> routes,
  ) {
    final notifier = ref.read(mapProvider.notifier);

    if (ref.read(mapProvider).isRouteDrafting) {
      notifier.clearHoveredRoute();
      return;
    }

    if (_isPointerDown || !mapState.showRoutes) {
      notifier.clearHoveredRoute();
      return;
    }

    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      notifier.clearHoveredRoute();
      return;
    }

    final candidates = _buildRouteHoverCandidates(routes, camera);
    if (candidates.isEmpty) {
      notifier.clearHoveredRoute();
      return;
    }

    final result = RouteHoverDetector.findHoveredRoute(
      pointerPosition: localPosition,
      candidates: candidates,
    );
    notifier.setHoveredRouteId(result.hoveredRouteId);
  }

  int? _hitTestRouteId(
    Offset localPosition,
    MapState mapState,
    List<app_route.Route> routes,
  ) {
    if (!mapState.showRoutes) {
      return null;
    }

    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return null;
    }

    final candidates = _buildRouteHoverCandidates(routes, camera);
    if (candidates.isEmpty) {
      return null;
    }

    return RouteHoverDetector.findHoveredRoute(
      pointerPosition: localPosition,
      candidates: candidates,
    ).hoveredRouteId;
  }

  Peak? _hitTestPeak(
    Offset localPosition,
    MapState mapState,
    List<Peak> peaks,
  ) {
    if (!mapState.showPeaks || mapState.zoom < MapConstants.peakMinZoom) {
      return null;
    }

    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return null;
    }

    final peak = hitTestPeakFromViewportData(
      pointerPosition: localPosition,
      data: _buildPeakViewportData(peaks: peaks, camera: camera),
    );
    if (peak == null) {
      ref.read(mapProvider.notifier).closeHoveredPeakInfoPopup();
      return null;
    }
    ref.read(mapProvider.notifier).openHoveredPeakInfoPopup(peak);
    return peak;
  }

  PeakCluster? _hitTestPeakCluster(
    Offset localPosition,
    MapState mapState,
    List<Peak> peaks,
  ) {
    if (!mapState.showPeaks || mapState.zoom < MapConstants.peakMinZoom) {
      return null;
    }

    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return null;
    }

    final viewportData = _buildPeakViewportData(peaks: peaks, camera: camera);
    return hitTestPeakCluster(
      pointerPosition: localPosition,
      data: viewportData,
    );
  }

  PeakClusterViewportData _buildPeakViewportData({
    required List<Peak> peaks,
    required MapCamera camera,
    _PeakViewportInputs? inputs,
    bool allowContinuousMotionLag = false,
  }) {
    final resolvedInputs = inputs ?? _readPeakViewportInputs(peaks: peaks);
    final motionActive = allowContinuousMotionLag && _liveCamera != null;
    final settledFrame = _settledPeakViewportFrame;
    if (motionActive && settledFrame != null) {
      return transformPeakClusterViewportData(
        data: settledFrame.viewportData,
        camera: camera,
      );
    }

    final viewportData = _peakProjectionCache.getOrBuild(
      peaks: resolvedInputs.peaks,
      camera: camera,
      correlatedPeakIds: resolvedInputs.correlatedPeakIds,
      untickedPeakColours: resolvedInputs.untickedPeakColours,
      activeOwnershipSegments: resolvedInputs.activeOwnershipSegments,
      ownershipRingSegments: resolvedInputs.ownershipRingSegments,
      clusteringEnabled: resolvedInputs.clusteringEnabled,
    );
    if (!motionActive) {
      _settledPeakViewportFrame = _SettledPeakViewportFrame(
        viewportData: viewportData,
      );
    }
    return viewportData;
  }

  _PeakViewportInputs _readPeakViewportInputs({required List<Peak> peaks}) {
    return _PeakViewportInputs(
      peaks: peaks,
      correlatedPeakIds: ref.read(mapProvider.notifier).correlatedPeakIds,
      untickedPeakColours: ref.read(peakMarkerColourAssignmentsProvider),
      activeOwnershipSegments: ref.read(peakActiveOwnershipSegmentsProvider),
      ownershipRingSegments: ref.read(peakOwnershipRingSegmentsProvider),
      clusteringEnabled: ref.read(
        mapProvider.select((state) => state.peakClusteringEnabled),
      ),
    );
  }

  void _expandPeakCluster(PeakCluster cluster) {
    final notifier = ref.read(mapProvider.notifier);
    notifier.clearHoveredPeak();
    notifier.clearHoveredTrack();
    notifier.clearHoveredRoute();
    if (ref.read(mapProvider).peakInfoPeak != null) {
      notifier.closePeakInfoPopup();
    }

    final points = cluster.points;
    if (points.isEmpty) {
      return;
    }

    final request = PendingCameraRequest(
      center: points.first,
      zoom: _mapController.camera.zoom,
      serial: ref.read(mapProvider).cameraRequestSerial + 1,
      persist: true,
      clearHoveredPeakId: true,
      clearHoveredTrackId: true,
    );

    if (peakClusterNeedsZoomFallback(points)) {
      _applyAcceptedCameraMove(
        request.copyWith(
          zoom: (_mapController.camera.zoom + 2).clamp(
            MapConstants.peakMinZoom.toDouble(),
            MapConstants.peakMaxZoom.toDouble(),
          ),
        ),
      );
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _applyAcceptedCameraFit(
      request,
      () => _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(MapConstants.peakClusterExpandPadding),
        ),
      ),
    );
  }

  List<RouteHoverCandidate> _buildRouteHoverCandidates(
    List<app_route.Route> routes,
    MapCamera camera,
  ) {
    final displayZoom = _mapController.camera.zoom.round().clamp(
      MapConstants.trackMinZoom,
      MapConstants.trackMaxZoom,
    );
    final viewportRevision = _viewportUiRevision.value;
    if (_cachedRouteHoverCandidates != null &&
        _cachedRouteHoverViewportRevision == viewportRevision &&
        _cachedRouteHoverDisplayZoom == displayZoom &&
        identical(_cachedRouteHoverRoutes, routes)) {
      return _cachedRouteHoverCandidates!;
    }

    final candidates = <RouteHoverCandidate>[];

    for (final route in routes) {
      if (!route.visible) {
        continue;
      }
      try {
        final projectedSegments = <List<Offset>>[];
        for (final segment in route.getSegmentsForZoom(displayZoom)) {
          if (segment.length < 2) {
            continue;
          }
          projectedSegments.add(
            segment.map(camera.latLngToScreenOffset).toList(growable: false),
          );
        }
        if (projectedSegments.isEmpty) {
          continue;
        }
        candidates.add(
          RouteHoverCandidate(routeId: route.id, segments: projectedSegments),
        );
      } catch (_) {
        continue;
      }
    }

    _cachedRouteHoverViewportRevision = viewportRevision;
    _cachedRouteHoverDisplayZoom = displayZoom;
    _cachedRouteHoverRoutes = routes;
    _cachedRouteHoverCandidates = candidates;
    return candidates;
  }

  List<TrackRouteChooserItem> _buildTrackRouteChooserItems({
    required Offset localPosition,
    required MapState mapState,
    required List<app_route.Route> routes,
  }) {
    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return const [];
    }

    final displayZoom = mapState.zoom.round().clamp(
      MapConstants.trackMinZoom,
      MapConstants.trackMaxZoom,
    );
    final List<TrackHoverCandidateMatch> trackMatches =
        mapState.showTracks && !mapState.hasTrackRecoveryIssue
        ? TrackHoverDetector.findHoveredTrackCandidates(
            pointerPosition: localPosition,
            candidates: _buildTrackHoverCandidates(mapState, camera),
          )
        : <TrackHoverCandidateMatch>[];
    final routeMatches = RouteHoverDetector.findHoveredRouteCandidates(
      pointerPosition: localPosition,
      candidates: _buildRouteHoverCandidates(routes, camera),
    );

    final trackById = {
      for (final track in mapState.tracks) track.gpxTrackId: track,
    };
    final routeById = {for (final route in routes) route.id: route};

    final items = <TrackRouteChooserItem>[];
    for (final match in trackMatches) {
      final track = trackById[match.trackId];
      if (track == null || !track.visible) {
        continue;
      }
      items.add(
        TrackRouteChooserItem.track(
          track: track,
          segments: track.getSegmentsForZoom(displayZoom),
        ),
      );
    }

    for (final match in routeMatches) {
      final route = routeById[match.routeId];
      if (route == null || !route.visible) {
        continue;
      }
      items.add(
        TrackRouteChooserItem.route(
          route: route,
          segments: route.getSegmentsForZoom(displayZoom),
        ),
      );
    }

    items.sort((left, right) {
      if (left.kind != right.kind) {
        return left.kind == TrackRouteChooserItemKind.track ? -1 : 1;
      }

      if (left.kind == TrackRouteChooserItemKind.track) {
        final leftDate = left.track!.trackDate;
        final rightDate = right.track!.trackDate;
        if (leftDate == null && rightDate != null) {
          return 1;
        }
        if (leftDate != null && rightDate == null) {
          return -1;
        }
        if (leftDate != null && rightDate != null) {
          final dateComparison = rightDate.compareTo(leftDate);
          if (dateComparison != 0) {
            return dateComparison;
          }
        }
        return left.track!.gpxTrackId.compareTo(right.track!.gpxTrackId);
      }

      final leftName = _chooserRouteName(left.route!);
      final rightName = _chooserRouteName(right.route!);
      final nameComparison = leftName.compareTo(rightName);
      if (nameComparison != 0) {
        return nameComparison;
      }
      return left.route!.id.compareTo(right.route!.id);
    });

    return List<TrackRouteChooserItem>.unmodifiable(items);
  }

  String _chooserRouteName(app_route.Route route) {
    final trimmed = route.name.trim();
    return trimmed.isEmpty ? 'Unnamed Route' : trimmed;
  }

  void _handleMapHover(
    Offset localPosition,
    LatLng location,
    MapState mapState,
    List<Peak> peaks,
    List<app_route.Route> routes,
  ) {
    final notifier = ref.read(mapProvider.notifier);
    if (_isPointerDown || _trackRouteChooserItems != null) {
      return;
    }
    notifier.setCursorMgrs(location);
    if (ref.read(mapProvider).isRouteDrafting) {
      final hoveredDraftMarker = _handleRouteDraftMarkerHover(
        localPosition,
        mapState,
      );
      if (hoveredDraftMarker) {
        notifier.clearHoveredRouteDraftSegmentPreview();
      } else {
        _handleRouteDraftSegmentHover(localPosition, mapState);
      }
      notifier.clearHoveredRoute();
      _dismissTrackRouteChooser(suppressReopen: true);
      return;
    }
    if (_handlePeakHover(localPosition, mapState, peaks)) {
      notifier.clearHoveredTrack();
      notifier.clearHoveredRoute();
      _dismissTrackRouteChooser(suppressReopen: true);
      return;
    }
    _handleTrackHover(localPosition, location, mapState);
    if (ref.read(mapProvider).hoveredTrackId != null) {
      notifier.clearHoveredRoute();
      return;
    }
    _handleRouteHover(localPosition, mapState, routes);
    if (ref.read(mapProvider).hoveredRouteId != null) {
      notifier.clearHoveredTrack();
    }
  }

  void _handleTrackHover(
    Offset localPosition,
    LatLng location,
    MapState mapState,
  ) {
    final notifier = ref.read(mapProvider.notifier);

    if (_isPointerDown ||
        !mapState.showTracks ||
        mapState.hasTrackRecoveryIssue) {
      notifier.clearHoveredTrack();
      return;
    }

    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      notifier.clearHoveredTrack();
      return;
    }

    final candidates = _buildTrackHoverCandidates(mapState, camera);
    if (candidates.isEmpty) {
      notifier.clearHoveredTrack();
      return;
    }

    final result = TrackHoverDetector.findHoveredTrack(
      pointerPosition: localPosition,
      candidates: candidates,
    );
    notifier.setHoveredTrackId(result.hoveredTrackId);
  }

  int? _hitTestTrackId(Offset localPosition, MapState mapState) {
    if (!mapState.showTracks || mapState.hasTrackRecoveryIssue) {
      return null;
    }

    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return null;
    }

    final candidates = _buildTrackHoverCandidates(mapState, camera);
    if (candidates.isEmpty) {
      return null;
    }

    return TrackHoverDetector.findHoveredTrack(
      pointerPosition: localPosition,
      candidates: candidates,
    ).hoveredTrackId;
  }

  bool _handleRouteDraftMarkerHover(Offset localPosition, MapState mapState) {
    final notifier = ref.read(mapProvider.notifier);

    if (!mapState.isRouteDrafting ||
        mapState.routeDraftDisplayMarkers.isEmpty) {
      notifier.clearHoveredRouteDraftMarker();
      return false;
    }

    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      notifier.clearHoveredRouteDraftMarker();
      return false;
    }

    String? hoveredMarkerId;
    double? bestDistance;
    const hoverThreshold = PeakHoverDetector.threshold;

    for (final marker in mapState.routeDraftDisplayMarkers) {
      final screenPosition = camera.latLngToScreenOffset(marker.point);
      final distance = (localPosition - screenPosition).distance;
      if (distance > hoverThreshold) {
        continue;
      }
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        hoveredMarkerId = marker.id;
      }
    }

    if (hoveredMarkerId == null) {
      notifier.clearHoveredRouteDraftMarker();
      return false;
    } else {
      notifier.setHoveredRouteDraftMarkerId(hoveredMarkerId);
      return true;
    }
  }

  void _handleRouteDraftSegmentHover(Offset localPosition, MapState mapState) {
    final notifier = ref.read(mapProvider.notifier);

    if (!mapState.isRouteDrafting ||
        mapState.routeDraftControlEndpoints.length < 2 ||
        mapState.routeDraftCommittedPoints.length < 2) {
      notifier.clearHoveredRouteDraftSegmentPreview();
      return;
    }

    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      notifier.clearHoveredRouteDraftSegmentPreview();
      return;
    }

    final candidates = _buildRouteDraftHoverCandidates(mapState, camera);
    if (candidates.isEmpty) {
      notifier.clearHoveredRouteDraftSegmentPreview();
      return;
    }

    int? bestSegmentIndex;
    int? bestCommittedSegmentIndex;
    LatLng? bestPoint;
    double? bestDistance;
    final endpointExclusionRadius = RouteUI.markerSize * RouteUI.markerZoom / 2;

    for (final candidate in candidates) {
      final closest = _closestPointOnSegment(
        localPosition,
        candidate.start,
        candidate.end,
      );
      if (candidate.startsAtControlEndpoint &&
          (closest - candidate.start).distance < endpointExclusionRadius) {
        continue;
      }
      if (candidate.endsAtControlEndpoint &&
          (closest - candidate.end).distance < endpointExclusionRadius) {
        continue;
      }
      final distance = (localPosition - closest).distance;
      if (distance > 12) {
        continue;
      }
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        bestSegmentIndex = candidate.controlSegmentIndex;
        bestCommittedSegmentIndex = candidate.committedSegmentIndex;
        bestPoint = camera.screenOffsetToLatLng(closest);
      }
    }

    if (bestSegmentIndex == null ||
        bestCommittedSegmentIndex == null ||
        bestPoint == null) {
      notifier.clearHoveredRouteDraftSegmentPreview();
      return;
    }

    notifier.setHoveredRouteDraftSegmentPreview(
      segmentIndex: bestSegmentIndex,
      committedSegmentIndex: bestCommittedSegmentIndex,
      point: bestPoint,
    );
  }

  List<_RouteDraftHoverCandidate> _buildRouteDraftHoverCandidates(
    MapState mapState,
    MapCamera camera,
  ) {
    final controlEndpoints = mapState.routeDraftControlEndpoints;
    final committedPoints = mapState.routeDraftCommittedPoints;
    if (controlEndpoints.length < 2 || committedPoints.length < 2) {
      return const [];
    }

    final candidates = <_RouteDraftHoverCandidate>[];
    var committedSearchStart = 0;

    for (
      var controlIndex = 0;
      controlIndex < controlEndpoints.length - 1;
      controlIndex++
    ) {
      final startIndex = _indexOfCommittedRoutePoint(
        committedPoints,
        controlEndpoints[controlIndex].point,
        startAt: committedSearchStart,
      );
      if (startIndex == -1 || startIndex >= committedPoints.length - 1) {
        continue;
      }

      final endIndex = _indexOfCommittedRoutePoint(
        committedPoints,
        controlEndpoints[controlIndex + 1].point,
        startAt: startIndex + 1,
      );
      if (endIndex == -1 || endIndex <= startIndex) {
        continue;
      }

      for (
        var committedIndex = startIndex;
        committedIndex < endIndex;
        committedIndex++
      ) {
        candidates.add(
          _RouteDraftHoverCandidate(
            controlSegmentIndex: controlIndex,
            committedSegmentIndex: committedIndex,
            start: camera.latLngToScreenOffset(committedPoints[committedIndex]),
            end: camera.latLngToScreenOffset(
              committedPoints[committedIndex + 1],
            ),
            startsAtControlEndpoint: committedIndex == startIndex,
            endsAtControlEndpoint: committedIndex + 1 == endIndex,
          ),
        );
      }
      committedSearchStart = endIndex;
    }

    return candidates;
  }

  int _indexOfCommittedRoutePoint(
    List<LatLng> points,
    LatLng target, {
    required int startAt,
  }) {
    for (var index = startAt; index < points.length; index++) {
      if (points[index] == target) {
        return index;
      }
    }
    return -1;
  }

  Offset _closestPointOnSegment(Offset point, Offset start, Offset end) {
    final delta = end - start;
    final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
    if (lengthSquared == 0) {
      return start;
    }

    final projection =
        ((point.dx - start.dx) * delta.dx + (point.dy - start.dy) * delta.dy) /
        lengthSquared;
    final t = projection.clamp(0.0, 1.0);
    return Offset(start.dx + delta.dx * t, start.dy + delta.dy * t);
  }

  List<TrackHoverCandidate> _buildTrackHoverCandidates(
    MapState mapState,
    MapCamera camera,
  ) {
    final displayZoom = mapState.zoom.round().clamp(
      MapConstants.peakMinZoom,
      MapConstants.peakMaxZoom,
    );
    final viewportRevision = _viewportUiRevision.value;
    if (_cachedTrackHoverCandidates != null &&
        _cachedTrackHoverViewportRevision == viewportRevision &&
        _cachedTrackHoverDisplayZoom == displayZoom &&
        identical(_cachedTrackHoverTracks, mapState.tracks)) {
      return _cachedTrackHoverCandidates!;
    }

    final candidates = <TrackHoverCandidate>[];

    for (final track in mapState.tracks) {
      if (!track.visible) {
        continue;
      }
      try {
        final projectedSegments = <List<Offset>>[];
        for (final segment in track.getSegmentsForZoom(displayZoom)) {
          if (segment.length < 2) {
            continue;
          }
          projectedSegments.add(
            segment.map(camera.latLngToScreenOffset).toList(growable: false),
          );
        }
        if (projectedSegments.isEmpty) {
          continue;
        }
        candidates.add(
          TrackHoverCandidate(
            trackId: track.gpxTrackId,
            segments: projectedSegments,
          ),
        );
      } catch (e) {
        continue;
      }
    }

    _cachedTrackHoverViewportRevision = viewportRevision;
    _cachedTrackHoverDisplayZoom = displayZoom;
    _cachedTrackHoverTracks = mapState.tracks;
    _cachedTrackHoverCandidates = candidates;
    return candidates;
  }

  void _startScrolling(double dx, double dy) {
    _scrollDx = dx * UiConstants.scrollSpeed;
    _scrollDy = dy * UiConstants.scrollSpeed;
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(UiConstants.scrollInterval, (_) {
      if (_scrollDx != 0 || _scrollDy != 0) {
        _moveMap(_scrollDx, _scrollDy);
      }
    });
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    _scrollDx = 0;
    _scrollDy = 0;
    _flushPendingCameraPosition();
  }

  void _handleTrackpadPanZoomStart(PointerPanZoomStartEvent event) {
    _mapFocusNode.requestFocus();
    _trackpadGestureCenter = _mapController.camera.center;
    _trackpadGestureZoom = _mapController.camera.zoom;
  }

  void _handleTrackpadPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final gestureCenter = _trackpadGestureCenter;
    final gestureZoom = _trackpadGestureZoom;
    if (gestureCenter == null || gestureZoom == null) {
      return;
    }

    final intent = classifyMapTrackpadGesture(
      pan: event.pan,
      scale: event.scale,
    );
    if (intent.type == MapTrackpadGestureType.none) {
      _mapController.move(gestureCenter, gestureZoom);
      _updateContinuousCamera(
        center: gestureCenter,
        zoom: gestureZoom,
        debounce: false,
      );
      return;
    }

    final targetZoom = (gestureZoom + intent.zoomDelta).clamp(
      1.0,
      MapConstants.peakMaxZoom.toDouble(),
    );
    _mapController.move(gestureCenter, targetZoom);
    _updateContinuousCamera(
      center: gestureCenter,
      zoom: targetZoom,
      debounce: false,
    );
  }

  void _handleTrackpadPanZoomEnd(PointerPanZoomEndEvent event) {
    _trackpadGestureCenter = null;
    _trackpadGestureZoom = null;
    _flushPendingCameraPosition();
  }

  void _focusPeakDirect(Peak peak) {
    final location = LatLng(peak.latitude, peak.longitude);
    _applyAcceptedCameraMove(
      PendingCameraRequest(
        center: location,
        zoom: MapConstants.singlePointZoom,
        serial: 0,
        selectedPeaksBehavior: PendingCameraSelectionBehavior.replace,
        selectedPeaks: [peak],
      ),
    );
  }

  void _centerOnSelectedLocationDirect() {
    final selected = ref.read(mapProvider).selectedLocation;
    if (selected == null) {
      return;
    }

    _applyAcceptedCameraMove(
      PendingCameraRequest(
        center: selected,
        zoom: _mapController.camera.zoom,
        serial: 0,
        clearGotoMgrs: true,
      ),
    );
  }

  void _moveVisibleMapToLocation(
    LatLng location,
    double zoom, {
    bool updateSelectedLocation = false,
  }) {
    _applyAcceptedCameraMove(
      PendingCameraRequest(
        center: location,
        zoom: zoom,
        serial: 0,
        selectedLocationBehavior: updateSelectedLocation
            ? PendingCameraSelectionBehavior.replace
            : PendingCameraSelectionBehavior.preserve,
        selectedLocation: updateSelectedLocation ? location : null,
        clearGotoMgrs: true,
      ),
    );
  }

  void _scheduleCameraPositionSave() {
    _hasPendingCameraSave = true;
    _pendingCameraSaveTimer?.cancel();
    _pendingCameraSaveTimer = Timer(MapConstants.cameraSaveDebounce, () {
      _flushPendingCameraPosition();
    });
  }

  void _markPendingCameraSave() {
    _hasPendingCameraSave = true;
  }

  void _flushPendingCameraPosition() {
    if (!_hasPendingCameraSave) {
      _pendingCameraSaveTimer?.cancel();
      _pendingCameraSaveTimer = null;
      return;
    }
    _pendingCameraSaveTimer?.cancel();
    _pendingCameraSaveTimer = null;
    _hasPendingCameraSave = false;
    if (_commitLiveCameraToCanonicalState()) {
      unawaited(_mapNotifier.persistCameraPosition());
    }
  }

  void _applyAcceptedCameraMove(
    PendingCameraRequest request, {
    bool consumePendingRequest = false,
  }) {
    _supersedePendingContinuousCamera();
    if (!_isSameCamera(request.center, request.zoom)) {
      _mapController.move(request.center, request.zoom);
    }
    _syncVisibleBoundsFromCamera();
    _acceptCameraIntent(request, consumePendingRequest: consumePendingRequest);
  }

  void _applyAcceptedCameraFit(
    PendingCameraRequest request,
    VoidCallback applyController, {
    bool consumePendingRequest = false,
  }) {
    _supersedePendingContinuousCamera();
    applyController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _mapNotifier.updateVisibleBounds(null);
      _syncVisibleBoundsFromCamera();
      _acceptCameraIntent(
        request.copyWith(
          center: _mapController.camera.center,
          zoom: _mapController.camera.zoom,
        ),
        consumePendingRequest: consumePendingRequest,
      );
    });
  }

  void _syncVisibleBoundsFromCamera() {
    if (_mapController.camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return;
    }
    _mapNotifier.updateVisibleBounds(_mapController.camera.visibleBounds);
  }

  void _acceptCameraIntent(
    PendingCameraRequest request, {
    bool consumePendingRequest = false,
  }) {
    ref.read(mapProvider.notifier).acceptCameraIntent(request);
    if (consumePendingRequest) {
      ref.read(mapProvider.notifier).consumeCameraRequest(request.serial);
    }
    if (request.persist) {
      unawaited(_mapNotifier.persistCameraPosition());
    }
  }

  void _syncVisibleBounds() {
    if (_mapController.camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return;
    }

    ref
        .read(mapProvider.notifier)
        .updateVisibleBounds(_mapController.camera.visibleBounds);
  }

  void _updateContinuousCamera({
    required LatLng center,
    required double zoom,
    bool debounce = true,
  }) {
    final liveCamera = _LiveCameraState(
      center: center,
      zoom: zoom,
      mgrs: _convertToMgrs(center),
      token: ++_cameraIntentToken,
    );
    _liveCamera = liveCamera;
    _bumpViewportUiRevision();
    _applyContinuousMotionSideEffects(zoom: zoom);
    if (debounce) {
      _scheduleCameraPositionSave();
    } else {
      _markPendingCameraSave();
    }
  }

  void _applyContinuousMotionSideEffects({required double zoom}) {
    final mapState = ref.read(mapProvider);
    final notifier = ref.read(mapProvider.notifier);
    if (_routeDraftDeletePopupMarkerId != null) {
      _dismissRouteDraftMarkerDeletePopup();
    }
    if (_trackRouteChooserItems != null) {
      _dismissTrackRouteChooser(suppressReopen: true);
    }
    if (!_isPointerDown && mapState.cursorMgrs != null) {
      notifier.clearCursorMgrs();
    }
    if (mapState.hoveredPeakId != null) {
      notifier.clearHoveredPeak();
    }
    if (mapState.hoveredTrackId != null) {
      notifier.clearHoveredTrack();
    }
    if (mapState.showInfoPopup) {
      notifier.toggleInfoPopup();
    }
    if (zoom < MapConstants.clearPeakInfo && mapState.peakInfo != null) {
      notifier.closePeakInfoPopup();
    }
  }

  void _scheduleRouteGraphPrefetch(LatLngBounds bounds) {
    if (!_shouldPrefetchRouteGraph()) {
      _routeGraphPrefetchTimer?.cancel();
      return;
    }

    _routeGraphPrefetchTimer?.cancel();
    _routeGraphPrefetchTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) {
        return;
      }

      unawaited(_mapNotifier.prefetchRouteGraphVisibleBounds(bounds));
    });
  }

  bool _shouldPrefetchRouteGraph([MapState? mapState]) {
    final MapState currentState = mapState ?? ref.read(mapProvider);
    return currentState.showTrails ||
        (currentState.isRouteDrafting &&
            currentState.routeDraftMode != RouteMode.straightLine);
  }

  bool _commitLiveCameraToCanonicalState() {
    final liveCamera = _liveCamera;
    if (liveCamera == null || liveCamera.token != _cameraIntentToken) {
      return false;
    }

    final mapState = ref.read(mapProvider);
    if (_isSameCameraForValues(
      leftCenter: mapState.center,
      leftZoom: mapState.zoom,
      rightCenter: liveCamera.center,
      rightZoom: liveCamera.zoom,
    )) {
      _syncVisibleBounds();
      if (_liveCamera?.token == liveCamera.token) {
        _liveCamera = null;
        _bumpViewportUiRevision();
      }
      return false;
    }

    ref
        .read(mapProvider.notifier)
        .updatePosition(liveCamera.center, liveCamera.zoom);
    _syncVisibleBounds();
    if (_liveCamera?.token == liveCamera.token) {
      _liveCamera = null;
      _bumpViewportUiRevision();
    }
    return true;
  }

  void _supersedePendingContinuousCamera() {
    _cameraIntentToken += 1;
    _pendingCameraSaveTimer?.cancel();
    _pendingCameraSaveTimer = null;
    _hasPendingCameraSave = false;
    if (_liveCamera != null) {
      _liveCamera = null;
      _bumpViewportUiRevision();
    }
  }

  void _bumpViewportUiRevision() {
    _viewportUiRevision.value += 1;
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
    } catch (_) {
      return 'Invalid';
    }
  }

  double _selectedMapGotoZoom(Tasmap50k map) {
    if (_mapController.camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return MapConstants.defaultMapZoom;
    }

    final bounds = ref.read(tasmapRepositoryProvider).getMapBounds(map);
    if (bounds == null) {
      return MapConstants.defaultMapZoom;
    }

    try {
      final fit = CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      );
      return fit.fit(_mapController.camera).zoom;
    } catch (_) {
      return MapConstants.defaultMapZoom;
    }
  }

  @override
  void dispose() {
    _mapChartHoverNotifier.clear();
    _removeRouteDraftOverlays();
    _pendingCameraSaveTimer?.cancel();
    _pendingCameraSaveTimer = null;
    _hasPendingCameraSave = false;
    _liveCamera = null;
    WidgetsBinding.instance.removeObserver(this);
    _scrollTimer?.cancel();
    _routeGraphPrefetchTimer?.cancel();
    _gotoFocusNode.dispose();
    _searchFocusNode.dispose();
    _mapFocusNode.dispose();
    _viewportUiRevision.dispose();
    super.dispose();
  }

  void _scheduleRouteDraftOverlaySync(bool isRouteDrafting) {
    if (_routeDraftOverlaySyncScheduled) {
      return;
    }

    final overlaysReady = _routeGraphOverlayEntry != null;
    if (isRouteDrafting == _routeDraftOverlayVisible &&
        (isRouteDrafting ? overlaysReady : !_routeDraftOverlayVisible)) {
      return;
    }

    _routeDraftOverlaySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeDraftOverlaySyncScheduled = false;
      if (!mounted) {
        return;
      }
      _syncRouteDraftOverlays(
        isRouteDrafting: ref.read(mapProvider).isRouteDrafting,
      );
    });
  }

  void _syncRouteDraftOverlays({required bool isRouteDrafting}) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    if (!isRouteDrafting) {
      _removeRouteDraftOverlays();
      return;
    }

    _routeDraftOverlayVisible = true;
    if (_routeGraphOverlayEntry == null) {
      _routeGraphOverlayEntry = OverlayEntry(
        builder: (context) => const Positioned(
          key: Key('route-graph-overlay-root'),
          left: UiConstants.sideMenuColumnWidth + 32,
          bottom: 16,
          child: RouteDraftGraphOverlay(),
        ),
      );
      overlay.insert(_routeGraphOverlayEntry!);
    }
  }

  void _removeRouteDraftOverlays() {
    _routeGraphOverlayEntry?.remove();
    _routeGraphOverlayEntry = null;
    _routeDraftOverlayVisible = false;
  }

  @override
  Widget build(BuildContext context) {
    MapRebuildDebugCounters.recordRouteRootBuild();
    final routeChrome = ref.watch(
      mapProvider.select(
        (state) => (
          endDrawerMode: state.endDrawerMode,
          showPeakSearch: state.showPeakSearch,
          searchResults: state.searchPopupResults,
          searchQuery: state.searchPopupQuery,
          searchIsLoadingMore: state.searchPopupIsLoadingMore,
          searchIsExhausted: state.searchPopupIsExhausted,
          searchEntityFilter: state.searchPopupEntityFilter,
          searchRegionKey: state.searchPopupRegionKey,
          searchSort: state.searchPopupSort,
          searchGroup: state.searchPopupGroup,
          showPeakMetadataFilters: state.showPeakMetadataFilters,
          peakRatingFilter: state.peakRatingFilter,
          peakDifficultyFilter: state.peakDifficultyFilter,
          peakDurationFilter: state.peakDurationFilter,
          showGotoInput: state.showGotoInput,
          mapSuggestions: state.mapSuggestions,
          showInfoPopup: state.showInfoPopup,
          infoMapName: state.infoMapName,
          infoMgrs: state.infoMgrs,
          infoPeakName: state.infoPeakName,
          infoPeakElevation: state.infoPeakElevation,
          hasTrackRecoveryIssue: state.hasTrackRecoveryIssue,
          trackCount: state.tracks.length,
          isRouteDrafting: state.isRouteDrafting,
          routeDraftDisplayMarkers: state.routeDraftDisplayMarkers,
          routeDraftCommittedPoints: state.routeDraftCommittedPoints,
          routeDraftProvisionalPoints: state.routeDraftProvisionalPoints,
          routeDraftMode: state.routeDraftMode,
          routeDraftColour: state.routeDraftColour,
          routeDraftNameFieldFocused: state.routeDraftNameFieldFocused,
          hoveredRouteDraftMarkerId: state.hoveredRouteDraftMarkerId,
          hoveredRouteDraftSegmentIndex: state.hoveredRouteDraftSegmentIndex,
          hoveredRouteDraftSegmentPoint: state.hoveredRouteDraftSegmentPoint,
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (routeChrome.showPeakSearch && !_searchFocusNode.hasFocus) {
        _searchFocusNode.requestFocus();
      }
      if (routeChrome.showGotoInput && !_gotoFocusNode.hasFocus) {
        _gotoFocusNode.requestFocus();
      }
      if (!routeChrome.showPeakSearch &&
          !routeChrome.showGotoInput &&
          !_mapFocusNode.hasFocus &&
          !routeChrome.routeDraftNameFieldFocused &&
          mounted) {
        _mapFocusNode.requestFocus();
      }
    });

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissSurfaceIntent(),
        SingleActivator(LogicalKeyboardKey.keyC, control: true):
            DismissSurfaceIntent(),
      },
      child: Actions(
        actions: {
          DismissSurfaceIntent: CallbackAction<DismissSurfaceIntent>(
            onInvoke: (intent) => _dismissHighestPrioritySurface(),
          ),
        },
        child: Focus(
          focusNode: _mapFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (_searchFocusNode.hasFocus ||
                _gotoFocusNode.hasFocus ||
                (_isEditableTextFocused() &&
                    event.logicalKey != LogicalKeyboardKey.escape)) {
              return KeyEventResult.ignored;
            }
            if (routeChrome.routeDraftNameFieldFocused &&
                event.logicalKey != LogicalKeyboardKey.escape) {
              return KeyEventResult.ignored;
            }
            final mapState = ref.read(mapProvider);
            final key = event.logicalKey;
            final notifier = ref.read(mapProvider.notifier);
            final isCtrlC =
                key == LogicalKeyboardKey.keyC &&
                HardwareKeyboard.instance.isControlPressed &&
                !HardwareKeyboard.instance.isMetaPressed;

            if (event is KeyDownEvent && mapState.peakInfoPeak != null) {
              notifier.closePeakInfoPopup();
            }

            if (event is KeyDownEvent &&
                isCtrlC &&
                _dismissHighestPrioritySurface()) {
              return KeyEventResult.handled;
            }

            if (mapState.showInfoPopup &&
                event is KeyDownEvent &&
                key == LogicalKeyboardKey.keyG) {
              notifier.closeInfoPopup();
              return KeyEventResult.handled;
            }

            if (mapState.isRouteDrafting &&
                event is KeyDownEvent &&
                (HardwareKeyboard.instance.isMetaPressed ||
                    HardwareKeyboard.instance.isControlPressed) &&
                key == LogicalKeyboardKey.keyZ &&
                mapState.routeDraftStage != RouteDraftStage.routingSegment &&
                !mapState.isSavingRoute) {
              if (HardwareKeyboard.instance.isShiftPressed) {
                if (mapState.routeDraftCanRedo) {
                  notifier.redoRouteDraftEdit();
                }
              } else if (mapState.routeDraftCanUndo) {
                notifier.undoRouteDraftEdit();
              }
              return KeyEventResult.handled;
            }

            if (event is KeyDownEvent &&
                HardwareKeyboard.instance.isMetaPressed &&
                key == LogicalKeyboardKey.keyF) {
              notifier.openSearchPopup();
              return KeyEventResult.handled;
            }

            if (key == LogicalKeyboardKey.equal ||
                key == LogicalKeyboardKey.comma ||
                key == LogicalKeyboardKey.period ||
                key == LogicalKeyboardKey.less ||
                key == LogicalKeyboardKey.add ||
                key == LogicalKeyboardKey.minus ||
                key == LogicalKeyboardKey.greater) {
              if (event is KeyDownEvent) {
                final currentZoom = _mapController.camera.zoom;
                final newZoom =
                    (key == LogicalKeyboardKey.equal ||
                        key == LogicalKeyboardKey.period ||
                        key == LogicalKeyboardKey.greater ||
                        key == LogicalKeyboardKey.add)
                    ? currentZoom + 1
                    : currentZoom - 1;
                _applyAcceptedCameraMove(
                  PendingCameraRequest(
                    center: _mapController.camera.center,
                    zoom: newZoom,
                    serial: 0,
                  ),
                );
              }
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyK ||
                key == LogicalKeyboardKey.arrowUp) {
              if (event is KeyDownEvent) {
                _startScrolling(0, -1);
              } else if (event is KeyUpEvent) {
                _stopScrolling();
              }
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyJ ||
                key == LogicalKeyboardKey.arrowDown) {
              if (event is KeyDownEvent) {
                _startScrolling(0, 1);
              } else if (event is KeyUpEvent) {
                _stopScrolling();
              }
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyH ||
                key == LogicalKeyboardKey.arrowLeft) {
              if (event is KeyDownEvent) {
                _startScrolling(-1, 0);
              } else if (event is KeyUpEvent) {
                _stopScrolling();
              }
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyL ||
                key == LogicalKeyboardKey.arrowRight) {
              if (event is KeyDownEvent) {
                _startScrolling(1, 0);
              } else if (event is KeyUpEvent) {
                _stopScrolling();
              }
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyS) {
              _goToCurrentLocation();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyG) {
              notifier.toggleGotoInput();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyI) {
              if (event is KeyDownEvent) {
                final selectedLocation = mapState.selectedLocation;
                if (selectedLocation != null) {
                  // Center on the marker so popup appears to the right of marker
                  _applyAcceptedCameraMove(
                    PendingCameraRequest(
                      center: selectedLocation,
                      zoom: mapState.zoom,
                      serial: 0,
                    ),
                  );
                }
                notifier.toggleInfoPopup();
              }
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyB) {
              _openBasemapsDrawer();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyC) {
              _centerOnSelectedLocationDirect();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyM) {
              notifier.toggleMapOverlay();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyT) {
              if (event is KeyDownEvent) {
                notifier.setEndDrawerMode(EndDrawerMode.tracksRoutes);
                _scaffoldKey.currentState?.openEndDrawer();
              }
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
            key: _scaffoldKey,
            endDrawer: switch (routeChrome.endDrawerMode) {
              EndDrawerMode.basemaps => MapBasemapsDrawer(
                basemapKeys: _basemapDrawerBasemapKeys ?? const [],
              ),
              EndDrawerMode.peakLists => const MapPeakListsDrawer(),
              EndDrawerMode.tracksRoutes => const MapTracksRoutesDrawer(),
            },
            onEndDrawerChanged: (isOpen) {
              if (!isOpen && mounted) {
                setState(() => _basemapDrawerBasemapKeys = null);
                _mapFocusNode.requestFocus();
              }
            },
            body: Stack(
              children: [
                Builder(
                  builder: (context) {
                    final mapScene = ref.watch(
                      mapProvider.select(
                        (state) => (
                          center: state.center,
                          zoom: state.zoom,
                          basemap: state.basemap,
                          selectedLocation: state.selectedLocation,
                          showInfoPopup: state.showInfoPopup,
                          peakInfoPeak: state.peakInfoPeak,
                          selectedPeaks: state.selectedPeaks,
                          selectedMap: state.selectedMap,
                          visibleBounds: state.visibleBounds,
                          showSelectedMapLayer: state.showSelectedMapLayer,
                          showMapOverlay: state.showMapOverlay,
                          showDistanceGrid: state.showDistanceGrid,
                          showRoutes: state.showRoutes,
                          showTracks: state.showTracks,
                          showTrails: state.showTrails,
                          showPeaks: state.showPeaks,
                          hasTrackRecoveryIssue: state.hasTrackRecoveryIssue,
                          peaks: state.peaks,
                          tracks: state.tracks,
                          selectedTrackId: state.selectedTrackId,
                          selectedRouteId: state.selectedRouteId,
                          selectedMapFocusSerial: state.selectedMapFocusSerial,
                          selectedTrackFocusSerial:
                              state.selectedTrackFocusSerial,
                          selectedRouteFocusSerial:
                              state.selectedRouteFocusSerial,
                          pendingCameraRequest: state.pendingCameraRequest,
                        ),
                      ),
                    );
                    final routeGraphAvailable = ref.watch(
                      routeGraphReadinessProvider.select(
                        (state) =>
                            state.status != RouteGraphReadinessStatus.failed,
                      ),
                    );
                    final trailService = ref.watch(
                      routeGraphTrailServiceProvider,
                    );
                    final showPeakInfo = ref.watch(
                      peakMarkerInfoSettingsProvider,
                    );
                    final showPeakOwnershipRings = ref.watch(
                      peakOwnershipRingSettingsProvider,
                    );
                    final showPolygons = ref.watch(
                      showPolygonsSettingsProvider,
                    );
                    final polygonAssets = showPolygons
                        ? ref.watch(polygonAssetsProvider)
                        : null;
                    final peakViewportSelectionInputs = ref.watch(
                      mapProvider.select(
                        (state) => (
                          peakListSelectionMode: state.peakListSelectionMode,
                          selectedPeakListIds: state.selectedPeakListIds,
                          pinnedPeakListIdsByRegion:
                              state.pinnedPeakListIdsByRegion,
                          peakClusteringEnabled: state.peakClusteringEnabled,
                        ),
                      ),
                    );
                    final peakLists = ref.watch(peakListsProvider);
                    final peakListRepository = ref.read(
                      peakListRepositoryProvider,
                    );
                    final shouldBuildPeakViewport =
                        mapScene.showPeaks &&
                        mapScene.zoom >= MapConstants.peakMinZoom;
                    final peakViewportSelectionData = shouldBuildPeakViewport
                        ? buildPeakViewportSelectionData(
                            peakListSelectionMode: peakViewportSelectionInputs
                                .peakListSelectionMode,
                            selectedPeakListIds:
                                peakViewportSelectionInputs.selectedPeakListIds,
                            pinnedPeakListIdsByRegion:
                                peakViewportSelectionInputs
                                    .pinnedPeakListIdsByRegion,
                            visibleBounds: mapScene.visibleBounds,
                            peaks: mapScene.peaks,
                            peakLists: peakLists,
                            ratingFilter: routeChrome.peakRatingFilter,
                            difficultyFilter: routeChrome.peakDifficultyFilter,
                            durationFilter: routeChrome.peakDurationFilter,
                            showPeakOwnershipRings: showPeakOwnershipRings,
                            repo: peakListRepository,
                          )
                        : null;
                    final filteredPeaks =
                        peakViewportSelectionData?.filteredPeaks ??
                        const <Peak>[];
                    final peakMarkerColours =
                        peakViewportSelectionData?.peakMarkerColours ??
                        const <int, int>{};
                    final activeOwnershipSegments =
                        peakViewportSelectionData?.activeOwnershipSegments ??
                        const <int, List<PeakOwnershipRingSegment>>{};
                    final ownershipRingSegments =
                        peakViewportSelectionData?.ownershipRingSegments ??
                        const <int, List<PeakOwnershipRingSegment>>{};
                    final clusteringEnabled = shouldBuildPeakViewport
                        ? peakViewportSelectionInputs.peakClusteringEnabled
                        : false;
                    final routes = ref.watch(routeListProvider);
                    final routeDraftSourceRouteId = ref.watch(
                      mapProvider.select((state) => state.sourceRouteId),
                    );
                    final polygonLayer = _polygonAssetLayerFor(
                      showPolygons: showPolygons,
                      polygonAssets: polygonAssets,
                    );
                    final routeDraftVisibility = ref.watch(
                      mapProvider.select(
                        (state) => (
                          isRouteDrafting: state.isRouteDrafting,
                          isSavingRoute: state.isSavingRoute,
                        ),
                      ),
                    );
                    final routeSnackbarMessage = ref
                        .read(mapProvider.notifier)
                        .consumeRouteSnackbarMessage();
                    if (routeSnackbarMessage != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(routeSnackbarMessage)),
                        );
                      });
                    }
                    if (_wasRouteDrafting &&
                        !routeDraftVisibility.isRouteDrafting) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _mapFocusNode.requestFocus();
                      });
                    }
                    _scheduleRouteDraftOverlaySync(
                      routeDraftVisibility.isRouteDrafting,
                    );
                    _wasRouteDrafting = routeDraftVisibility.isRouteDrafting;
                    ref.watch(
                      tasmapStateProvider.select(
                        (state) => state.tasmapRevision,
                      ),
                    );
                    final mapState = ref.read(mapProvider);
                    final favouriteWaypoints = ref
                        .read(mapProvider.notifier)
                        .favouriteWaypoints();
                    final peakViewportInputs = shouldBuildPeakViewport
                        ? _PeakViewportInputs(
                            peaks: filteredPeaks,
                            correlatedPeakIds: ref
                                .read(mapProvider.notifier)
                                .correlatedPeakIds,
                            untickedPeakColours: peakMarkerColours,
                            activeOwnershipSegments: activeOwnershipSegments,
                            ownershipRingSegments: ownershipRingSegments,
                            clusteringEnabled: clusteringEnabled,
                          )
                        : null;
                    _queueSelectedMapZoom(mapState);
                    _queueSelectedTrackZoom(mapState);
                    _queueSelectedRouteZoom(mapState, routes);
                    _queueCameraRequest(mapState);

                    return LayoutBuilder(
                      builder: (context, _) {
                        return ValueListenableBuilder<int>(
                          valueListenable: _viewportUiRevision,
                          builder: (context, _, child) {
                            final displayZoom =
                                _liveCamera?.zoom ?? mapScene.zoom;
                            final trailPolylines =
                                mapScene.showTrails &&
                                    routeGraphAvailable &&
                                    _mapReady &&
                                    trailService != null &&
                                    _mapController.camera.nonRotatedSize !=
                                        MapCamera.kImpossibleSize
                                ? trailService.buildVisibleTrails(
                                    minLat: _mapController
                                        .camera
                                        .visibleBounds
                                        .south,
                                    minLon: _mapController
                                        .camera
                                        .visibleBounds
                                        .west,
                                    maxLat: _mapController
                                        .camera
                                        .visibleBounds
                                        .north,
                                    maxLon: _mapController
                                        .camera
                                        .visibleBounds
                                        .east,
                                    zoom: displayZoom,
                                  )
                                : const <Polyline>[];
                            GpxTrack? selectedTrack;
                            for (final track in mapScene.tracks) {
                              if (track.gpxTrackId ==
                                  mapScene.selectedTrackId) {
                                selectedTrack = track;
                                break;
                              }
                            }
                            app_route.Route? selectedRoute;
                            for (final route in routes) {
                              if (route.id == mapScene.selectedRouteId) {
                                selectedRoute = route;
                                break;
                              }
                            }
                            final mgrsGridGeometry =
                                _mapReady &&
                                    mapScene.showDistanceGrid &&
                                    _mapController.camera.nonRotatedSize !=
                                        MapCamera.kImpossibleSize
                                ? buildVisibleMgrsGridGeometry(
                                    visibleBounds:
                                        mapScene.visibleBounds ??
                                        _mapController.camera.visibleBounds,
                                    zoom: mapScene.zoom,
                                    latitude: mapScene.center.latitude,
                                  )
                                : null;
                            final showMapReadouts =
                                selectedTrack == null && selectedRoute == null;
                            final routeDraftDisplayMarkers =
                                _draggingRouteDraftMarkerId == null ||
                                    _draggingRouteDraftMarkerScreenOffset ==
                                        null
                                ? routeChrome.routeDraftDisplayMarkers
                                : routeChrome.routeDraftDisplayMarkers
                                      .map(
                                        (marker) =>
                                            marker.id ==
                                                _draggingRouteDraftMarkerId
                                            ? marker.copyWith(
                                                point: _mapController.camera
                                                    .screenOffsetToLatLng(
                                                      _draggingRouteDraftMarkerScreenOffset!,
                                                    ),
                                              )
                                            : marker,
                                      )
                                      .toList(growable: false);
                            final routeDraftMarkerInteractionActive =
                                _pendingRouteDraftDragMarkerId != null ||
                                _draggingRouteDraftMarkerId != null;
                            var interactionFlags =
                                InteractiveFlag.all &
                                ~InteractiveFlag.rotate &
                                ~InteractiveFlag.pinchMove &
                                ~InteractiveFlag.pinchZoom;
                            if (routeDraftMarkerInteractionActive) {
                              interactionFlags &= ~InteractiveFlag.drag;
                            }

                            return Stack(
                              children: [
                                Consumer(
                                  builder: (context, ref, child) {
                                    final cursorState = ref.watch(
                                      mapProvider.select(
                                        (state) => (
                                          hoveredRouteDraftMarkerId:
                                              state.hoveredRouteDraftMarkerId,
                                          hoveredRouteDraftSegmentIndex: state
                                              .hoveredRouteDraftSegmentIndex,
                                          hoveredTrackId: state.hoveredTrackId,
                                          hoveredRouteId: state.hoveredRouteId,
                                          hoveredPeakId: state.hoveredPeakId,
                                        ),
                                      ),
                                    );
                                    return MouseRegion(
                                      key: const Key('map-interaction-region'),
                                      cursor: _mouseCursor(
                                        hoveredRouteDraftMarkerId: cursorState
                                            .hoveredRouteDraftMarkerId,
                                        hoveredRouteDraftSegmentIndex:
                                            cursorState
                                                .hoveredRouteDraftSegmentIndex,
                                        hoveredTrackId:
                                            cursorState.hoveredTrackId,
                                        hoveredRouteId:
                                            cursorState.hoveredRouteId,
                                        hoveredPeakId:
                                            cursorState.hoveredPeakId,
                                      ),
                                      onExit: (event) {
                                        final mapState = ref.read(mapProvider);
                                        final notifier = ref.read(
                                          mapProvider.notifier,
                                        );
                                        if (mapState.isPeakInfoHovered &&
                                            mapState.peakInfoPeak != null &&
                                            !_peakInfoPopupBounds(
                                              context,
                                              mapState.peakInfoPeak!,
                                            ).contains(event.localPosition)) {
                                          notifier.closeHoveredPeakInfoPopup();
                                        }
                                        notifier.clearCursorMgrs();
                                        notifier.clearHoveredPeak();
                                        notifier.clearHoveredTrack();
                                        notifier.clearHoveredRoute();
                                        notifier.clearHoveredRouteDraftMarker();
                                        notifier
                                            .clearHoveredRouteDraftSegmentPreview();
                                      },
                                      child: child!,
                                    );
                                  },
                                  child: Listener(
                                    behavior: HitTestBehavior.translucent,
                                    onPointerPanZoomStart:
                                        _handleTrackpadPanZoomStart,
                                    onPointerPanZoomUpdate:
                                        _handleTrackpadPanZoomUpdate,
                                    onPointerPanZoomEnd:
                                        _handleTrackpadPanZoomEnd,
                                    child: FlutterMap(
                                      mapController: _mapController,
                                      options: MapOptions(
                                        initialCenter: mapScene.center,
                                        initialZoom: mapScene.zoom,
                                        interactionOptions: InteractionOptions(
                                          flags: interactionFlags,
                                        ),
                                        onMapReady: _handleMapReady,
                                        onSecondaryTap: (tapPosition, point) {
                                          if (!routeChrome.isRouteDrafting) {
                                            _centerOnSelectedLocationDirect();
                                          }
                                        },
                                        onPointerDown: (event, point) {
                                          _mapFocusNode.requestFocus();
                                          _dismissRouteDraftMarkerDeletePopup();
                                          _isPointerDown = true;
                                          _pointerDownPosition =
                                              event.localPosition;
                                          _driveEtaClickConsumed = false;
                                          if (event.kind ==
                                              PointerDeviceKind.mouse) {
                                            final mgrsState = ref.read(
                                              mapProvider.select(
                                                (state) => (
                                                  cursorMgrs: state.cursorMgrs,
                                                  cursorPoint:
                                                      state.cursorPoint,
                                                  gotoMgrs: state.gotoMgrs,
                                                  currentMgrs:
                                                      state.currentMgrs,
                                                  center: state.center,
                                                ),
                                              ),
                                            );
                                            final frozenMgrs =
                                                mgrsState.cursorMgrs ??
                                                mgrsState.gotoMgrs ??
                                                _liveCamera?.mgrs ??
                                                mgrsState.currentMgrs;
                                            _dragFrozenReadoutMgrs = frozenMgrs;
                                            _dragFrozenReadoutMapName =
                                                _readoutMapName(
                                                  cursorPoint:
                                                      mgrsState.cursorPoint,
                                                  gotoMgrs: mgrsState.gotoMgrs,
                                                  currentCenter:
                                                      mgrsState.center,
                                                );
                                          }
                                          if (event.kind ==
                                              PointerDeviceKind.mouse) {
                                            ref
                                                .read(mapProvider.notifier)
                                                .setCursorMgrs(point);
                                          }
                                          ref
                                              .read(mapProvider.notifier)
                                              .clearHoveredRouteDraftMarker();
                                          _primaryClickPending =
                                              event.kind ==
                                                  PointerDeviceKind.mouse &&
                                              event.buttons ==
                                                  kPrimaryMouseButton;
                                          _bumpViewportUiRevision();
                                        },
                                        onPointerUp: (event, point) async {
                                          final primaryClickPending =
                                              _primaryClickPending;
                                          final moved =
                                              _pointerDownPosition != null &&
                                              (event.localPosition -
                                                          _pointerDownPosition!)
                                                      .distance >
                                                  5;
                                          _isPointerDown = false;
                                          _pointerDownPosition = null;
                                          _primaryClickPending = false;
                                          _bumpViewportUiRevision();
                                          _dragFrozenReadoutMgrs = null;
                                          _dragFrozenReadoutMapName = null;
                                          if (event.kind ==
                                              PointerDeviceKind.mouse) {
                                            ref
                                                .read(mapProvider.notifier)
                                                .setCursorMgrs(point);
                                          }
                                          if (moved) {
                                            _flushPendingCameraPosition();
                                            return;
                                          }
                                          final notifier = ref.read(
                                            mapProvider.notifier,
                                          );
                                          final tappedLocation = _mapController
                                              .camera
                                              .screenOffsetToLatLng(
                                                event.localPosition,
                                              );
                                          if (_mapTapActionPopupAnchor !=
                                                  null ||
                                              _mapTapActionPopupLocation !=
                                                  null) {
                                            _dismissMapTapActionPopup();
                                          }
                                          if (_showFavouritesPopup) {
                                            setState(() {
                                              _showFavouritesPopup = false;
                                            });
                                          }
                                          if (routeChrome.isRouteDrafting) {
                                            if (_routeDraftMarkerTapConsumed) {
                                              _routeDraftMarkerTapConsumed =
                                                  false;
                                              return;
                                            }
                                            final draftState = ref.read(
                                              mapProvider,
                                            );
                                            if (draftState
                                                    .hoveredRouteDraftSegmentIndex !=
                                                null) {
                                              notifier
                                                  .commitHoveredRouteDraftSegmentPreview();
                                              return;
                                            }
                                            notifier.addRouteDraftMarker(
                                              tappedLocation,
                                              straightLine:
                                                  routeChrome.routeDraftMode ==
                                                  RouteMode.straightLine,
                                            );
                                            return;
                                          }
                                          final mapState = ref.read(
                                            mapProvider,
                                          );
                                          final tappablePeaks =
                                              mapState.showPeaks &&
                                                  mapState.zoom >=
                                                      MapConstants.peakMinZoom
                                              ? ref.read(filteredPeaksProvider)
                                              : const <Peak>[];
                                          final tappedCluster =
                                              _hitTestPeakCluster(
                                                event.localPosition,
                                                mapState,
                                                tappablePeaks,
                                              );
                                          if (tappedCluster != null) {
                                            _expandPeakCluster(tappedCluster);
                                            return;
                                          }
                                          final tappedPeak = _hitTestPeak(
                                            event.localPosition,
                                            mapState,
                                            tappablePeaks,
                                          );
                                          if (tappedPeak != null) {
                                            notifier.openPeakInfoPopup(
                                              tappedPeak,
                                            );
                                            return;
                                          }
                                          notifier.clearHoveredPeak();
                                          if (ref
                                              .read(mapProvider)
                                              .showInfoPopup) {
                                            notifier.toggleInfoPopup();
                                          }
                                          if (event.kind !=
                                              PointerDeviceKind.mouse) {
                                            _handleTrackHover(
                                              event.localPosition,
                                              tappedLocation,
                                              ref.read(mapProvider),
                                            );
                                          }
                                          final clickTrackId = _hitTestTrackId(
                                            event.localPosition,
                                            ref.read(mapProvider),
                                          );
                                          final clickRouteId = _hitTestRouteId(
                                            event.localPosition,
                                            ref.read(mapProvider),
                                            routes,
                                          );
                                          if (_trackRouteChooserItems != null) {
                                            _dismissTrackRouteChooser(
                                              suppressReopen: true,
                                            );
                                          }
                                          final driveEtaHit =
                                              clickTrackId == null &&
                                                  clickRouteId == null
                                              ? _driveEtaHitForTap(
                                                  localPosition:
                                                      event.localPosition,
                                                  tappedLocation:
                                                      tappedLocation,
                                                  hoveredTrackId: clickTrackId,
                                                  hoveredRouteId: clickRouteId,
                                                )
                                              : null;
                                          final chooserItems =
                                              _buildTrackRouteChooserItems(
                                                localPosition:
                                                    event.localPosition,
                                                routes: routes,
                                                mapState: ref.read(mapProvider),
                                              );
                                          if (chooserItems.length > 1) {
                                            notifier.clearHoveredTrack();
                                            notifier.clearHoveredRoute();
                                            _openTrackRouteChooser(
                                              anchor: event.localPosition,
                                              items: chooserItems,
                                            );
                                            return;
                                          }
                                          if (clickTrackId == null) {
                                            notifier.clearHoveredTrack();
                                          }
                                          if (clickRouteId == null) {
                                            notifier.clearHoveredRoute();
                                          }
                                          if (ref
                                                  .read(mapProvider)
                                                  .peakInfoPeak !=
                                              null) {
                                            notifier.closePeakInfoPopup();
                                          }
                                          if (ref
                                                  .read(mapProvider)
                                                  .driveEtaPopup !=
                                              null) {
                                            notifier.closeDriveEtaPopup();
                                          }
                                          final shouldOpenMapTapActionPopup =
                                              !_driveEtaClickConsumed &&
                                              ref
                                                      .read(mapProvider)
                                                      .driveEtaPopup ==
                                                  null &&
                                              clickTrackId == null &&
                                              clickRouteId == null &&
                                              (primaryClickPending ||
                                                  event.kind !=
                                                      PointerDeviceKind.mouse);
                                          if (shouldOpenMapTapActionPopup) {
                                            _openMapTapActionPopup(
                                              anchor: event.localPosition,
                                              location: tappedLocation,
                                              driveEtaHit: driveEtaHit,
                                            );
                                            return;
                                          }
                                          if (!_driveEtaClickConsumed &&
                                              ref
                                                      .read(mapProvider)
                                                      .driveEtaPopup ==
                                                  null) {
                                            if (primaryClickPending &&
                                                clickTrackId != null) {
                                              notifier.setSelectedLocation(
                                                tappedLocation,
                                              );
                                              notifier.selectTrack(
                                                clickTrackId,
                                              );
                                            } else if (primaryClickPending &&
                                                clickRouteId != null) {
                                              notifier.setSelectedLocation(
                                                tappedLocation,
                                              );
                                              notifier.selectRoute(
                                                clickRouteId,
                                              );
                                            } else if (primaryClickPending) {
                                              notifier.setSelectedLocation(
                                                tappedLocation,
                                              );
                                              notifier.clearSelectedRoute();
                                              notifier.clearSelectedTrack();
                                            } else if (event.kind !=
                                                PointerDeviceKind.mouse) {
                                              notifier.setSelectedLocation(
                                                tappedLocation,
                                              );
                                            }
                                          }
                                        },
                                        onPointerCancel: (event, point) {
                                          _isPointerDown = false;
                                          _pointerDownPosition = null;
                                          _bumpViewportUiRevision();
                                          _dragFrozenReadoutMgrs = null;
                                          _dragFrozenReadoutMapName = null;
                                          _flushPendingCameraPosition();
                                          ref
                                              .read(mapProvider.notifier)
                                              .clearHoveredTrack();
                                          ref
                                              .read(mapProvider.notifier)
                                              .clearHoveredPeak();
                                          ref
                                              .read(mapProvider.notifier)
                                              .clearHoveredRoute();
                                          ref
                                              .read(mapProvider.notifier)
                                              .clearHoveredRouteDraftMarker();
                                          ref
                                              .read(mapProvider.notifier)
                                              .clearHoveredRouteDraftSegmentPreview();
                                        },
                                        onPointerHover: (event, point) {
                                          _handleMapHover(
                                            event.localPosition,
                                            point,
                                            ref.read(mapProvider),
                                            filteredPeaks,
                                            routes,
                                          );
                                        },
                                        onPositionChanged:
                                            (position, hasGesture) {
                                              if (hasGesture) {
                                                _updateContinuousCamera(
                                                  center: position.center,
                                                  zoom: position.zoom,
                                                );
                                                _scheduleRouteGraphPrefetch(
                                                  _mapController
                                                      .camera
                                                      .visibleBounds,
                                                );
                                              }
                                            },
                                      ),
                                      children: [
                                        buildBasemapTileLayer(
                                          mapScene.basemap,
                                          userAgentPackageName:
                                              'com.peak_bagger.app',
                                          tileProvider:
                                              _buildTileProviderForBasemap(
                                                mapScene.basemap,
                                              ),
                                        ),
                                        if (trailPolylines.isNotEmpty)
                                          buildTrailPolylines(trailPolylines),
                                        if (routeChrome.isRouteDrafting)
                                          buildDraftRoutePolylines(
                                            committedPoints: routeChrome
                                                .routeDraftCommittedPoints,
                                            provisionalPoints: routeChrome
                                                .routeDraftProvisionalPoints,
                                            colour:
                                                routeChrome.routeDraftColour,
                                          ),
                                        if (routeChrome.isRouteDrafting &&
                                            routeChrome
                                                .routeDraftDisplayMarkers
                                                .isNotEmpty)
                                          MarkerLayer(
                                            key: const Key(
                                              'route-draft-marker-layer',
                                            ),
                                            markers: buildRouteDraftMarkers(
                                              markers: routeDraftDisplayMarkers,
                                              colour:
                                                  routeChrome.routeDraftColour,
                                              hoveredMarkerId: routeChrome
                                                  .hoveredRouteDraftMarkerId,
                                              hoveredSegmentIndex: routeChrome
                                                  .hoveredRouteDraftSegmentIndex,
                                              hoveredSegmentPoint: routeChrome
                                                  .hoveredRouteDraftSegmentPoint,
                                              onHoverEnter: ref
                                                  .read(mapProvider.notifier)
                                                  .setHoveredRouteDraftMarkerId,
                                              onHoverExit: ref
                                                  .read(mapProvider.notifier)
                                                  .clearHoveredRouteDraftMarker,
                                              onPointerDown:
                                                  _consumeRouteDraftMarkerTap,
                                              onPointerMove:
                                                  _trackRouteDraftMarkerDrag,
                                              onPointerUp:
                                                  _finishRouteDraftMarkerInteraction,
                                              onTap:
                                                  _openRouteDraftMarkerDeletePopup,
                                              onHoveredSegmentTap: () {
                                                ref
                                                    .read(mapProvider.notifier)
                                                    .commitHoveredRouteDraftSegmentPreview();
                                              },
                                              onHoveredSegmentPanStart:
                                                  _beginHoveredRouteDraftSegmentInteraction,
                                              onHoveredSegmentPanUpdate:
                                                  _trackHoveredRouteDraftSegmentDrag,
                                              onHoveredSegmentPanEnd:
                                                  _endHoveredRouteDraftSegmentInteraction,
                                            ),
                                          ),
                                        if (mapScene.selectedPeaks.isNotEmpty)
                                          CircleLayer(
                                            circles: mapScene.selectedPeaks.map(
                                              (peak) {
                                                return CircleMarker(
                                                  point: LatLng(
                                                    peak.latitude,
                                                    peak.longitude,
                                                  ),
                                                  radius: 15,
                                                  color: Colors.blue.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  borderColor: Colors.blue,
                                                  borderStrokeWidth: 2,
                                                );
                                              },
                                            ).toList(),
                                          ),
                                        if (mapScene.showSelectedMapLayer)
                                          buildMapRectangle(
                                            ref.read(tasmapRepositoryProvider),
                                            mapScene.selectedMap!,
                                          ),
                                        if (mapScene.showMapOverlay)
                                          PolygonLayer(
                                            key: const Key('tasmap-layer'),
                                            polygons: buildAllMapRectangles(
                                              ref.read(
                                                tasmapRepositoryProvider,
                                              ),
                                            ),
                                          ),
                                        if (mgrsGridGeometry != null &&
                                            mgrsGridGeometry.lines.isNotEmpty)
                                          buildMgrsGridLayer(mgrsGridGeometry),
                                        ?polygonLayer,
                                        if (mapScene.showRoutes)
                                          buildRoutePolylines(
                                            routes,
                                            mapScene.zoom,
                                            selectedRouteId:
                                                mapScene.selectedRouteId,
                                            excludedRouteId:
                                                routeDraftSourceRouteId,
                                          ),
                                        if (mapScene.showTracks)
                                          buildTrackPolylines(
                                            mapScene.tracks,
                                            mapScene.zoom,
                                            selectedTrackId:
                                                mapScene.selectedTrackId,
                                          ),
                                        if (_homeLocation() != null)
                                          MarkerLayer(
                                            key: const Key('home-marker-layer'),
                                            markers: [
                                              Marker(
                                                key: const Key('home-marker'),
                                                point: _homeLocation()!,
                                                width: HomeMapMarkerTheme
                                                    .value
                                                    .markerSize,
                                                height: HomeMapMarkerTheme
                                                    .value
                                                    .markerSize,
                                                child: const HomeMarker(),
                                              ),
                                            ],
                                          ),
                                        if (mapScene.selectedLocation != null)
                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                point:
                                                    mapScene.selectedLocation!,
                                                width: 40,
                                                height: 40,
                                                child: const Icon(
                                                  Icons.my_location,
                                                  color: Colors.amber,
                                                  size: 32,
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (favouriteWaypoints.isNotEmpty)
                                          MarkerLayer(
                                            key: const Key(
                                              'favourite-marker-layer',
                                            ),
                                            markers: favouriteWaypoints
                                                .map((favourite) {
                                                  final labelWidth =
                                                      peakMarkerLabelMaxWidth(
                                                        context,
                                                      );
                                                  return Marker(
                                                    key: Key(
                                                      'favourite-marker-${favourite.id}',
                                                    ),
                                                    point: LatLng(
                                                      favourite.latitude,
                                                      favourite.longitude,
                                                    ),
                                                    width: labelWidth,
                                                    height:
                                                        FavouriteMapMarkerTheme
                                                            .value
                                                            .markerSize,
                                                    child: FavouriteMarker(
                                                      key: Key(
                                                        'favourite-marker-widget-${favourite.id}',
                                                      ),
                                                      id: favourite.id,
                                                      name: favourite.name,
                                                    ),
                                                  );
                                                })
                                                .toList(growable: false),
                                          ),
                                        if (peakViewportInputs != null &&
                                            filteredPeaks.isNotEmpty)
                                          Consumer(
                                            builder: (context, ref, child) {
                                              final peakUiState = ref.watch(
                                                mapProvider.select(
                                                  (state) => (
                                                    hoveredPeakId:
                                                        state.hoveredPeakId,
                                                    popupPeakId: state
                                                        .peakInfoPeak
                                                        ?.osmId,
                                                  ),
                                                ),
                                              );
                                              return MapScreenPeakLayer(
                                                zoom: mapScene.zoom,
                                                showPeakInfo: showPeakInfo,
                                                hoveredPeakId:
                                                    peakUiState.hoveredPeakId,
                                                popupPeakId:
                                                    peakUiState.popupPeakId,
                                                viewportData:
                                                    _buildPeakViewportData(
                                                      peaks: peakViewportInputs
                                                          .peaks,
                                                      camera:
                                                          _mapController.camera,
                                                      inputs:
                                                          peakViewportInputs,
                                                      allowContinuousMotionLag:
                                                          true,
                                                    ),
                                              );
                                            },
                                          ),
                                        if (mapScene.showSelectedMapLayer)
                                          TasmapPolygonLabelLayer(
                                            key: const Key(
                                              'tasmap-label-layer',
                                            ),
                                            insetX:
                                                tasmapPolygonLabelDefaultInsetX,
                                            insetY:
                                                tasmapPolygonLabelDefaultInsetY,
                                            entries:
                                                buildSelectedMapLabelEntries(
                                                  ref.read(
                                                    tasmapRepositoryProvider,
                                                  ),
                                                  mapScene.selectedMap!,
                                                  mapScene.zoom,
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                ),
                                          ),
                                        if (mapScene.showMapOverlay)
                                          TasmapPolygonLabelLayer(
                                            key: const Key(
                                              'tasmap-label-layer',
                                            ),
                                            insetX:
                                                tasmapPolygonLabelDefaultInsetX,
                                            insetY:
                                                tasmapPolygonLabelDefaultInsetY,
                                            entries: buildOverlayLabelEntries(
                                              ref.read(
                                                tasmapRepositoryProvider,
                                              ),
                                              mapScene.zoom,
                                              Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                          ),
                                        if (mgrsGridGeometry != null &&
                                            mgrsGridGeometry.labels.isNotEmpty)
                                          MapMgrsGridLabelLayer(
                                            labels: mgrsGridGeometry.labels,
                                          ),
                                        Consumer(
                                          builder: (context, ref, child) {
                                            final chartHoverPoint = ref.watch(
                                              mapChartHoverProvider,
                                            );
                                            if (chartHoverPoint == null) {
                                              return const SizedBox.shrink();
                                            }

                                            return buildChartHoverMarkerLayer(
                                              chartHoverPoint,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (showMapReadouts)
                                  Positioned(
                                    left: 16,
                                    top: 16,
                                    child: IgnorePointer(
                                      child: Consumer(
                                        builder: (context, ref, child) {
                                          final mgrsState = ref.watch(
                                            mapProvider.select(
                                              (state) => (
                                                cursorMgrs: state.cursorMgrs,
                                                cursorPoint: state.cursorPoint,
                                                gotoMgrs: state.gotoMgrs,
                                                currentMgrs: state.currentMgrs,
                                                center: state.center,
                                              ),
                                            ),
                                          );
                                          final displayMgrs =
                                              _isPointerDown &&
                                                  _dragFrozenReadoutMgrs != null
                                              ? _dragFrozenReadoutMgrs!
                                              : mgrsState.cursorMgrs ??
                                                    mgrsState.gotoMgrs ??
                                                    _liveCamera?.mgrs ??
                                                    mgrsState.currentMgrs;
                                          final mapName =
                                              _isPointerDown &&
                                                  _dragFrozenReadoutMapName !=
                                                      null
                                              ? _dragFrozenReadoutMapName!
                                              : _readoutMapName(
                                                  cursorPoint:
                                                      mgrsState.cursorPoint,
                                                  gotoMgrs: mgrsState.gotoMgrs,
                                                  currentCenter:
                                                      mgrsState.center,
                                                );
                                          return MapMgrsReadout(
                                            mapName: mapName,
                                            mgrs: displayMgrs,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                if (showMapReadouts)
                                  Positioned(
                                    left: 16,
                                    bottom: routeChrome.isRouteDrafting
                                        ? 16 + RouteConstants.sheetHeight + 16
                                        : 16,
                                    child: IgnorePointer(
                                      child: MapZoomReadout(
                                        zoom: displayZoom,
                                        latitude: mapScene.center.latitude,
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: 16,
                                  top: 16,
                                  bottom: 16,
                                  child: AnimatedSlide(
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOut,
                                    offset: showMapReadouts
                                        ? const Offset(-1.1, 0)
                                        : Offset.zero,
                                    child: IgnorePointer(
                                      ignoring: showMapReadouts,
                                      child: showMapReadouts
                                          ? const SizedBox(
                                              width: UiConstants
                                                  .preferredLeftWidth,
                                            )
                                          : MapTrackInfoPanel(
                                              track: selectedRoute == null
                                                  ? selectedTrack
                                                  : null,
                                              route: selectedRoute,
                                              onEdit: selectedRoute == null
                                                  ? null
                                                  : () {
                                                      final route =
                                                          selectedRoute;
                                                      if (route == null) {
                                                        return;
                                                      }
                                                      ref
                                                          .read(
                                                            mapProvider
                                                                .notifier,
                                                          )
                                                          .beginRouteEdit(
                                                            route,
                                                          );
                                                    },
                                              onElevationProfileHoverChanged:
                                                  (hoverSample) {
                                                    final hoverNotifier = ref
                                                        .read(
                                                          mapChartHoverProvider
                                                              .notifier,
                                                        );
                                                    if (hoverSample == null) {
                                                      hoverNotifier.clear();
                                                      return;
                                                    }

                                                    final currentState = ref
                                                        .read(mapProvider);
                                                    if (selectedRoute != null) {
                                                      if (currentState
                                                              .selectedRouteId !=
                                                          selectedRoute.id) {
                                                        hoverNotifier.clear();
                                                        return;
                                                      }

                                                      final point =
                                                          _chartHoverResolver
                                                              .resolveRouteHover(
                                                                route:
                                                                    selectedRoute,
                                                                hoverSample:
                                                                    hoverSample,
                                                              );
                                                      if (point == null) {
                                                        hoverNotifier.clear();
                                                      } else {
                                                        hoverNotifier.show(
                                                          point,
                                                        );
                                                      }
                                                      return;
                                                    }

                                                    final track = selectedTrack;
                                                    if (track != null) {
                                                      if (currentState
                                                              .selectedTrackId !=
                                                          track.gpxTrackId) {
                                                        hoverNotifier.clear();
                                                        return;
                                                      }

                                                      final point =
                                                          _chartHoverResolver
                                                              .resolveTrackHover(
                                                                track: track,
                                                                hoverSample:
                                                                    hoverSample,
                                                              );
                                                      if (point == null) {
                                                        hoverNotifier.clear();
                                                      } else {
                                                        hoverNotifier.show(
                                                          point,
                                                        );
                                                      }
                                                      return;
                                                    }

                                                    hoverNotifier.clear();
                                                  },
                                              onVisibilityChanged: (visible) {
                                                final notifier = ref.read(
                                                  mapProvider.notifier,
                                                );
                                                if (selectedRoute != null) {
                                                  notifier.setRouteVisibility(
                                                    selectedRoute.id,
                                                    visible,
                                                  );
                                                  return;
                                                }
                                                final trackId =
                                                    selectedTrack?.gpxTrackId;
                                                if (trackId != null) {
                                                  notifier.setTrackVisibility(
                                                    trackId,
                                                    visible,
                                                  );
                                                }
                                              },
                                              onRouteWalkingSpeedChanged:
                                                  selectedRoute == null
                                                  ? null
                                                  : (value) {
                                                      final route =
                                                          selectedRoute;
                                                      if (route == null) {
                                                        return;
                                                      }
                                                      ref
                                                          .read(
                                                            mapProvider
                                                                .notifier,
                                                          )
                                                          .updateRouteWalkingSpeed(
                                                            route.id,
                                                            value,
                                                          );
                                                    },
                                              onRouteTimingRecalculate:
                                                  selectedRoute == null
                                                  ? null
                                                  : (algorithm) {
                                                      final route =
                                                          selectedRoute;
                                                      if (route == null) {
                                                        return;
                                                      }
                                                      ref
                                                          .read(
                                                            mapProvider
                                                                .notifier,
                                                          )
                                                          .recalculateRouteTiming(
                                                            route.id,
                                                            algorithm,
                                                          );
                                                    },
                                              onExport: () {
                                                unawaited(
                                                  _exportInfoSelection(
                                                    track: selectedRoute == null
                                                        ? selectedTrack
                                                        : null,
                                                    route: selectedRoute,
                                                  ),
                                                );
                                              },
                                              onClose: () {
                                                final notifier = ref.read(
                                                  mapProvider.notifier,
                                                );
                                                notifier.clearSelectedTrack();
                                                notifier.clearSelectedRoute();
                                                ref
                                                    .read(
                                                      mapChartHoverProvider
                                                          .notifier,
                                                    )
                                                    .clear();
                                                _mapFocusNode.requestFocus();
                                              },
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                MapActionRail(
                  onCreateRoute: _beginRouteDraft,
                  onShowBasemaps: _openBasemapsDrawer,
                  onDropMarker: _showDropMarkerPopupForCurrentLocation,
                  onShowFavourites: _toggleFavouritesPopup,
                ),
                if (routeChrome.isRouteDrafting)
                  const Positioned(
                    key: Key('route-controls-overlay-root'),
                    right: UiConstants.actionsColumnWidth,
                    bottom: 16,
                    child: RouteDraftControlsOverlay(),
                  ),
                if (routeChrome.showPeakSearch)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: MapSearchPopup(
                        focusNode: _searchFocusNode,
                        searchResults: routeChrome.searchResults,
                        isLoadingMore: routeChrome.searchIsLoadingMore,
                        isExhausted: routeChrome.searchIsExhausted,
                        searchQuery: routeChrome.searchQuery,
                        entityFilter: routeChrome.searchEntityFilter,
                        selectedRegionKey: routeChrome.searchRegionKey,
                        sort: routeChrome.searchSort,
                        group: routeChrome.searchGroup,
                        availableRegions: buildMapSearchRegionOptions(),
                        onChanged: (value) {
                          ref
                              .read(mapProvider.notifier)
                              .updateSearchPopupQuery(value);
                        },
                        onSelectEntityFilter: (value) {
                          ref
                              .read(mapProvider.notifier)
                              .setSearchPopupEntityFilter(value);
                        },
                        onSelectRegionKey: (value) {
                          ref
                              .read(mapProvider.notifier)
                              .setSearchPopupRegionKey(value);
                        },
                        onSelectSort: (value) {
                          ref
                              .read(mapProvider.notifier)
                              .setSearchPopupSort(value);
                        },
                        onSelectGroup: (value) {
                          ref
                              .read(mapProvider.notifier)
                              .setSearchPopupGroup(value);
                        },
                        onLoadMore: () {
                          ref
                              .read(mapProvider.notifier)
                              .loadMoreSearchPopupResults();
                        },
                        onClose: () {
                          _searchFocusNode.unfocus();
                          ref.read(mapProvider.notifier).closeSearchPopup();
                        },
                        onSelectResult: (result) {
                          switch (result.type) {
                            case MapSearchResultType.peak:
                              _focusPeakDirect(result.peak!);
                            case MapSearchResultType.track:
                              ref
                                  .read(mapProvider.notifier)
                                  .showTrack(
                                    result.track!.gpxTrackId,
                                    selectedLocation: result.anchor,
                                  );
                            case MapSearchResultType.route:
                              ref
                                  .read(mapProvider.notifier)
                                  .showRoute(
                                    result.route!.id,
                                    selectedLocation: result.anchor,
                                  );
                            case MapSearchResultType.map:
                              ref
                                  .read(mapProvider.notifier)
                                  .selectMapFromSearch(
                                    result.map!,
                                    selectedLocation: result.anchor,
                                  );
                          }
                          ref.read(mapProvider.notifier).closeSearchPopup();
                        },
                      ),
                    ),
                  ),
                if (routeChrome.showPeakMetadataFilters)
                  Positioned.fill(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const Key('map-metadata-filter-backdrop'),
                              onTap: () {
                                ref
                                    .read(mapProvider.notifier)
                                    .closePeakMetadataFilters();
                              },
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16, top: 16),
                            child: SizedBox(
                              width: 360,
                              child: MapMetadataFilterPopup(
                                ratingFilter: routeChrome.peakRatingFilter,
                                difficultyFilter:
                                    routeChrome.peakDifficultyFilter,
                                durationFilter: routeChrome.peakDurationFilter,
                                difficultyOptions: ref.watch(
                                  mapDifficultyFilterOptionsProvider,
                                ),
                                onSelectRatingFilter: (value) {
                                  ref
                                      .read(mapProvider.notifier)
                                      .setPeakRatingFilter(value);
                                },
                                onSelectDifficultyFilter: (value) {
                                  ref
                                      .read(mapProvider.notifier)
                                      .setPeakDifficultyFilter(value);
                                },
                                onSelectDurationFilter: (value) {
                                  ref
                                      .read(mapProvider.notifier)
                                      .setPeakDurationFilter(value);
                                },
                                onClearFilters: () {
                                  ref
                                      .read(mapProvider.notifier)
                                      .clearPeakMetadataFilters();
                                },
                                onClose: () {
                                  ref
                                      .read(mapProvider.notifier)
                                      .closePeakMetadataFilters();
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (routeChrome.showGotoInput)
                  Positioned(
                    right: 72,
                    top: 16,
                    child: MapGotoPanel(
                      focusNode: _gotoFocusNode,
                      controller: _gotoController,
                      errorText: _gotoError,
                      mapSuggestions: routeChrome.mapSuggestions,
                      onChanged: (value) {
                        if (_gotoError != null) {
                          setState(() => _gotoError = null);
                        }
                        ref
                            .read(mapProvider.notifier)
                            .parseGridReference(value);
                      },
                      onSubmitted: (_) =>
                          _handleGotoSubmit(ref.read(mapProvider)),
                      onClose: () {
                        ref.read(mapProvider.notifier).clearGotoMgrs();
                        ref
                            .read(mapProvider.notifier)
                            .setGotoInputVisible(false);
                        _gotoController.clear();
                      },
                      onNavigate: _navigateToGridReference,
                      onTabShortcut: _handleGotoTab,
                      onSelectSuggestion: (map) {
                        _gotoController.text = map.name;
                        ref.read(mapProvider.notifier).selectMap(map);
                        _zoomToMapExtent(map);
                        ref
                            .read(mapProvider.notifier)
                            .setGotoInputVisible(false);
                      },
                    ),
                  ),
                if (routeChrome.showInfoPopup)
                  Positioned(
                    left: MediaQuery.of(context).size.width / 2 + 16,
                    top: MediaQuery.of(context).size.height / 2 - 50,
                    child: MapInfoPopupCard(
                      infoMapName: routeChrome.infoMapName,
                      infoMgrs: routeChrome.infoMgrs,
                      infoPeakName: routeChrome.infoPeakName,
                      infoPeakElevation: routeChrome.infoPeakElevation,
                      hasTrackRecoveryIssue: routeChrome.hasTrackRecoveryIssue,
                      trackCount: routeChrome.trackCount,
                      onClose: () {
                        ref.read(mapProvider.notifier).toggleInfoPopup();
                      },
                    ),
                  ),
                Consumer(
                  builder: (context, ref, child) {
                    final driveEtaPopup = ref.watch(
                      mapProvider.select((state) => state.driveEtaPopup),
                    );
                    if (driveEtaPopup == null) {
                      return const SizedBox.shrink();
                    }
                    return _buildDriveEtaPopup(context, driveEtaPopup);
                  },
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final peakInfo = ref.watch(
                      mapProvider.select((state) => state.peakInfo),
                    );
                    if (peakInfo == null) {
                      return const SizedBox.shrink();
                    }
                    return _buildPeakInfoPopup(context, peakInfo);
                  },
                ),
                if (_routeDraftDeletePopupMarkerId != null)
                  _buildRouteDraftDeletePopup(
                    context,
                    routeChrome.routeDraftDisplayMarkers,
                  ),
                if (_trackRouteChooserItems != null)
                  _buildTrackRouteChooserPopup(context),
                if (_mapTapActionPopupAnchor != null &&
                    _mapTapActionPopupLocation != null)
                  _buildMapTapActionPopup(context),
                if (_showFavouritesPopup) _buildFavouritesPopup(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TileProvider _buildTileProviderForBasemap(Basemap basemap) {
    final cachedProvider = _cachedTileProvider;
    if (_cachedTileProviderBasemap == basemap && cachedProvider != null) {
      return cachedProvider;
    }

    final previousProvider = cachedProvider;
    final nextProvider = TileCacheService.getStoreForBasemap(basemap) == null
        ? NetworkTileProvider(headers: mapTileHeaders(basemap))
        : FMTCTileProvider(
            stores: {basemap.name: BrowseStoreStrategy.readUpdateCreate},
            loadingStrategy: BrowseLoadingStrategy.cacheFirst,
            recordHitsAndMisses: false,
            headers: mapTileHeaders(basemap),
            urlTransformer: (url) =>
                TileCacheService.transformBrowseUrl(basemap, url),
          );

    _cachedTileProviderBasemap = basemap;
    _cachedTileProvider = nextProvider;
    if (previousProvider != null) {
      previousProvider.dispose();
    }
    return nextProvider;
  }

  Widget _buildPeakInfoPopup(BuildContext context, PeakInfoContent content) {
    final isPinned = ref.read(mapProvider).isPeakInfoPinned;
    final placement = resolvePeakInfoPopupPlacement(
      anchorScreenOffset: _screenOffsetForPeak(content.peak),
      viewportSize: MediaQuery.of(context).size,
      popupSize: UiConstants.peakInfoPopupSize,
    );
    if (!placement.isAnchorable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(mapProvider.notifier).closePeakInfoPopup();
        }
      });
      return const SizedBox.shrink();
    }

    return Positioned(
      left:
          placement.topLeft.dx -
          (placement.bridgeOnLeft ? PeakInfoPopupSurface.bridgeWidth : 0),
      top: placement.topLeft.dy,
      child: SizedBox(
        width:
            UiConstants.peakInfoPopupSize.width +
            PeakInfoPopupSurface.bridgeWidth,
        child: PeakInfoPopupSurface(
          content: content,
          bridgeOnLeft: placement.bridgeOnLeft,
          onEdit: () async {
            ref.read(mapProvider.notifier).pinPeakInfoPopup();
          },
          onSaveEdit: _savePeakInfoPopupEdit,
          currentMarker: ref.read(mapProvider.notifier).getCurrentMarker(),
          onEditInAdmin: !isPinned
              ? null
              : () {
                  setObjectBoxAdminPendingPeakSelection(
                    peakId: content.peak.id,
                    searchQuery: content.peak.name,
                  );
                  context.goNamed('objectboxAdmin');
                },
          onDropMarker: () async {
            final notifier = ref.read(mapProvider.notifier);
            final saved = await notifier.setCurrentMarker(
              LatLng(content.peak.latitude, content.peak.longitude),
              name: content.peak.name,
            );
            if (saved) {
              notifier.closePeakInfoPopup();
            }
          },
          onClose: () {
            ref.read(mapProvider.notifier).closePeakInfoPopup();
          },
        ),
      ),
    );
  }

  bool _isEditableTextFocused() {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null) {
      return false;
    }

    return focusedContext.widget is EditableText ||
        focusedContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  Future<String?> _savePeakInfoPopupEdit(Peak peak) async {
    final repository = ref.read(peakRepositoryProvider);
    try {
      await repository.saveDetailed(peak);
      ref.read(peakRevisionProvider.notifier).increment();
      await ref.read(mapProvider.notifier).reloadPeakMarkers();
      return null;
    } catch (error, stackTrace) {
      developer.log(
        'Peak popup save failed for ${peak.name}',
        error: error,
        stackTrace: stackTrace,
        name: 'map_screen',
      );
      return 'Failed to save peak: $error';
    }
  }

  Widget _buildMapTapActionPopup(BuildContext context) {
    final anchor = _mapTapActionPopupAnchor!;
    const popupWidth = 260.0;
    const popupHeight = 176.0;
    final size = MediaQuery.of(context).size;
    final left = (anchor.dx + 12).clamp(8.0, size.width - popupWidth - 8);
    final top = (anchor.dy + 12).clamp(8.0, size.height - popupHeight - 8);
    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: popupWidth,
        child: MapTapActionPopupCard(
          onDropMarker: _handleDropMarkerFromPopup,
          onDropFavourite: _handleDropFavouriteFromPopup,
          onClose: _dismissMapTapActionPopup,
          onDriveEtaHome: _mapTapActionPopupDriveEtaHit == null
              ? null
              : _handleDriveEtaFromHome,
          onDriveEtaMarker:
              _mapTapActionPopupDriveEtaHit != null &&
                  ref.read(mapProvider).selectedLocation != null
              ? _handleDriveEtaFromMarker
              : null,
        ),
      ),
    );
  }

  Widget _buildFavouritesPopup(BuildContext context) {
    final favourites = ref.read(mapProvider.notifier).favouriteWaypoints();
    return Positioned(
      right: RouterConstants.themeActionRightInset + 56,
      top: (MediaQuery.of(context).size.height / 2 - 120).clamp(8.0, 320.0),
      child: SizedBox(
        width: 280,
        child: FavouritesPopupCard(
          favourites: favourites,
          onClose: () {
            if (mounted) {
              setState(() {
                _showFavouritesPopup = false;
              });
            }
          },
          onSelect: (favourite) {
            ref
                .read(mapProvider.notifier)
                .requestCameraMove(
                  center: LatLng(favourite.latitude, favourite.longitude),
                  zoom: MapConstants.defaultZoom,
                  clearGotoMgrs: true,
                  clearHoveredPeakId: true,
                  clearHoveredTrackId: true,
                );
            if (mounted) {
              setState(() {
                _showFavouritesPopup = false;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildDriveEtaPopup(BuildContext context, DriveEtaPopupState popup) {
    final placement = resolvePeakInfoPopupPlacement(
      anchorScreenOffset: _screenOffsetForLatLng(popup.anchor),
      viewportSize: MediaQuery.of(context).size,
      popupSize: UiConstants.peakInfoPopupSize,
    );
    if (!placement.isAnchorable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(mapProvider.notifier).closeDriveEtaPopup();
        }
      });
      return const SizedBox.shrink();
    }

    return Positioned(
      left:
          placement.topLeft.dx -
          (placement.bridgeOnLeft ? PeakInfoPopupSurface.bridgeWidth : 0),
      top: placement.topLeft.dy,
      child: SizedBox(
        width:
            UiConstants.peakInfoPopupSize.width +
            PeakInfoPopupSurface.bridgeWidth,
        child: DriveEtaPopupSurface(
          state: popup,
          bridgeOnLeft: placement.bridgeOnLeft,
          onClose: () {
            ref.read(mapProvider.notifier).closeDriveEtaPopup();
          },
        ),
      ),
    );
  }

  Widget _buildRouteDraftDeletePopup(
    BuildContext context,
    List<RouteDraftDisplayMarker> markers,
  ) {
    const popupSize = Size(220, 116);
    final markerId = _routeDraftDeletePopupMarkerId;
    final viewportRevision = _routeDraftDeletePopupViewportRevision;
    if (markerId == null || viewportRevision != _viewportUiRevision.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _dismissRouteDraftMarkerDeletePopup();
        }
      });
      return const SizedBox.shrink();
    }

    RouteDraftDisplayMarker? marker;
    for (final candidate in markers) {
      if (candidate.id == markerId) {
        marker = candidate;
        break;
      }
    }
    if (marker == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _dismissRouteDraftMarkerDeletePopup();
        }
      });
      return const SizedBox.shrink();
    }

    final placement = resolvePeakInfoPopupPlacement(
      anchorScreenOffset: _screenOffsetForRouteDraftMarker(marker.point),
      viewportSize: MediaQuery.of(context).size,
      popupSize: popupSize,
      markerSize: switch (marker.kind) {
        RouteMarkerKind.numbered => RouteUI.markerNumberedSize,
        RouteMarkerKind.circle || RouteMarkerKind.target => RouteUI.markerSize,
      },
    );
    if (!placement.isAnchorable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _dismissRouteDraftMarkerDeletePopup();
        }
      });
      return const SizedBox.shrink();
    }

    return Positioned(
      left: placement.topLeft.dx,
      top: placement.topLeft.dy,
      child: SizedBox(
        width: popupSize.width,
        child: RouteDraftMarkerDeletePopupCard(
          key: const Key('route-draft-delete-popup'),
          onDelete: () {
            unawaited(_deleteRouteDraftMarker(markerId));
          },
          onClose: _dismissRouteDraftMarkerDeletePopup,
        ),
      ),
    );
  }

  Widget _buildTrackRouteChooserPopup(BuildContext context) {
    final items = _trackRouteChooserItems;
    final anchor = _trackRouteChooserAnchor;
    final viewportRevision = _trackRouteChooserViewportRevision;
    if (items == null ||
        anchor == null ||
        viewportRevision != _viewportUiRevision.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _dismissTrackRouteChooser(suppressReopen: true);
        }
      });
      return const SizedBox.shrink();
    }

    final placement = resolvePeakInfoPopupPlacement(
      anchorScreenOffset: anchor,
      viewportSize: MediaQuery.of(context).size,
      popupSize: const Size(
        TrackRouteChooserPopup.width,
        TrackRouteChooserPopup.maxHeight,
      ),
    );
    if (!placement.isAnchorable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _dismissTrackRouteChooser(suppressReopen: true);
        }
      });
      return const SizedBox.shrink();
    }

    return Positioned(
      left: placement.topLeft.dx,
      top: placement.topLeft.dy,
      child: MouseRegion(
        onExit: (_) => _dismissTrackRouteChooser(suppressReopen: true),
        child: TrackRouteChooserPopup(
          items: items,
          onSelected: _selectTrackRouteChooserItem,
          onClose: _dismissTrackRouteChooser,
        ),
      ),
    );
  }

  void _navigateToGridReference() {
    final input = _gotoController.text.trim();
    if (input.isEmpty) return;

    final (location, error) = ref
        .read(mapProvider.notifier)
        .parseGridReference(input);

    if (error != null) {
      setState(() => _gotoError = error);
    } else if (location != null) {
      final selectedMap = ref.read(mapProvider).selectedMap;
      final zoom = selectedMap == null
          ? MapConstants.defaultZoom
          : _selectedMapGotoZoom(selectedMap);
      _moveVisibleMapToLocation(location, zoom, updateSelectedLocation: true);
      ref.read(mapProvider.notifier).setGotoInputVisible(false);
    }
  }

  void _zoomToMapExtent(Tasmap50k map, {int attempt = 0, int? focusSerial}) {
    if (focusSerial != null && _pendingSelectedMapSerial != focusSerial) {
      return;
    }
    if (_mapController.camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      if (attempt < 6) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _zoomToMapExtent(
              map,
              attempt: attempt + 1,
              focusSerial: focusSerial,
            );
          }
        });
      }
      return;
    }

    final repo = ref.read(tasmapRepositoryProvider);
    final bounds = repo.getMapBounds(map);
    if (bounds == null) {
      final center = repo.getMapCenter(map);
      if (center != null) {
        _applyAcceptedCameraMove(
          PendingCameraRequest(
            center: center,
            zoom: MapConstants.defaultMapZoom,
            serial: focusSerial ?? 0,
          ),
        );
      }
      _markSelectedMapZoomApplied(focusSerial);
      return;
    }

    final targetCenter = repo.getMapCenter(map);

    try {
      final cameraFit = CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      );
      _applyAcceptedCameraFit(
        PendingCameraRequest(
          center: targetCenter ?? _mapController.camera.center,
          zoom: _mapController.camera.zoom,
          serial: focusSerial ?? 0,
        ),
        () => _mapController.fitCamera(cameraFit),
      );
      _markSelectedMapZoomApplied(focusSerial);
    } catch (e) {
      final center = repo.getMapCenter(map);
      if (center != null) {
        _applyAcceptedCameraMove(
          PendingCameraRequest(
            center: center,
            zoom: MapConstants.defaultMapZoom,
            serial: focusSerial ?? 0,
          ),
        );
      }
      _markSelectedMapZoomApplied(focusSerial);
    }
  }

  void _markSelectedMapZoomApplied(int? focusSerial) {
    if (focusSerial == null) {
      return;
    }
    _appliedSelectedMapSerial = focusSerial;
    if (_pendingSelectedMapSerial == focusSerial) {
      _pendingSelectedMap = null;
      _pendingSelectedMapSerial = null;
    }
  }

  void _moveMap(double dx, double dy) {
    final center = _mapController.camera.center;
    final newCenter = LatLng(center.latitude + dy, center.longitude + dx);
    _mapController.move(newCenter, _mapController.camera.zoom);
    _updateContinuousCamera(
      center: newCenter,
      zoom: _mapController.camera.zoom,
      debounce: false,
    );
  }

  PolygonLayer? _polygonAssetLayerFor({
    required bool showPolygons,
    required AsyncValue<List<MapPolygonAsset>>? polygonAssets,
  }) {
    if (!showPolygons) {
      _cachedPolygonAssetLayer = null;
      _cachedPolygonAssetLayerAssets = null;
      return null;
    }

    final assets = polygonAssets?.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    if (assets == null) {
      return _cachedPolygonAssetLayer;
    }
    if (assets.isEmpty) {
      _cachedPolygonAssetLayer = null;
      _cachedPolygonAssetLayerAssets = null;
      return null;
    }
    if (identical(_cachedPolygonAssetLayerAssets, assets)) {
      return _cachedPolygonAssetLayer;
    }

    _cachedPolygonAssetLayerAssets = assets;
    _cachedPolygonAssetLayer = buildPolygonAssetLayer(assets);
    return _cachedPolygonAssetLayer;
  }

  void _goToCurrentLocation() {
    // TODO: Implement GPS location
  }

  void _dismissTransientUi({
    bool closeInfoPopup = false,
    bool closePeakSearch = false,
    bool closeGotoInput = false,
  }) {
    final mapState = ref.read(mapProvider);
    final notifier = ref.read(mapProvider.notifier);

    if (closeInfoPopup && mapState.showInfoPopup) {
      notifier.toggleInfoPopup();
    }
    if (closeInfoPopup && mapState.peakInfoPeak != null) {
      notifier.closePeakInfoPopup();
    }
    if (closePeakSearch && mapState.showPeakSearch) {
      notifier.closeSearchPopup();
    }
    if (closeGotoInput && mapState.showGotoInput) {
      notifier.setGotoInputVisible(false);
    }
  }

  void _openBasemapsDrawer() {
    _dismissTransientUi(
      closeInfoPopup: true,
      closePeakSearch: true,
      closeGotoInput: true,
    );

    final mapState = ref.read(mapProvider);
    final point = mapState.cursorPoint ?? mapState.center;
    final availableBasemaps = regionManifestCatalog.basemapsForPoint(point);
    final availableBasemapKeys = {
      for (final basemap in availableBasemaps) basemap.key,
    };

    if (!availableBasemapKeys.contains(mapState.basemap.name)) {
      ref.read(mapProvider.notifier).setBasemap(Basemap.tracestrack);
    }

    setState(() {
      _basemapDrawerBasemapKeys = availableBasemaps
          .map((basemap) => basemap.key)
          .toList(growable: false);
    });
    ref.read(mapProvider.notifier).setEndDrawerMode(EndDrawerMode.basemaps);
    _scaffoldKey.currentState?.openEndDrawer();
  }

  String _readoutMapName({
    required LatLng? cursorPoint,
    required String? gotoMgrs,
    required LatLng currentCenter,
  }) {
    if (cursorPoint != null) {
      return _mapNotifier.mapNameForPoint(cursorPoint);
    }
    if (gotoMgrs != null) {
      return _mapNotifier.mapNameForMgrs(gotoMgrs);
    }
    final liveCamera = _liveCamera;
    if (liveCamera != null) {
      return _mapNotifier.mapNameForPoint(liveCamera.center);
    }
    return _mapNotifier.mapNameForPoint(currentCenter);
  }

  Offset _screenOffsetForPeak(Peak peak) {
    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return const Offset(0, 0);
    }
    return camera.latLngToScreenOffset(LatLng(peak.latitude, peak.longitude));
  }

  Offset _screenOffsetForLatLng(LatLng point) {
    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return const Offset(0, 0);
    }
    return camera.latLngToScreenOffset(point);
  }

  Rect _peakInfoPopupBounds(BuildContext context, Peak peak) {
    final placement = resolvePeakInfoPopupPlacement(
      anchorScreenOffset: _screenOffsetForPeak(peak),
      viewportSize: MediaQuery.of(context).size,
      popupSize: UiConstants.peakInfoPopupSize,
    );
    final left =
        placement.topLeft.dx -
        (placement.bridgeOnLeft ? PeakInfoPopupSurface.bridgeWidth : 0);
    return Rect.fromLTWH(
      left,
      placement.topLeft.dy,
      UiConstants.peakInfoPopupSize.width + PeakInfoPopupSurface.bridgeWidth,
      UiConstants.peakInfoPopupSize.height,
    );
  }

  Offset _screenOffsetForRouteDraftMarker(LatLng point) {
    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return const Offset(0, 0);
    }
    return camera.latLngToScreenOffset(point);
  }

  void _handleMapReady() {
    _mapReady = true;
    _tryApplyPendingCameraRequest();
    _tryZoomPendingSelectedMap();
    _tryZoomPendingSelectedTrack();
    _syncVisibleBounds();
    if (ref.read(mapProvider).showTrails) {
      unawaited(
        _mapNotifier.prefetchRouteGraphVisibleBounds(
          _mapController.camera.visibleBounds,
        ),
      );
    }
  }

  void _queueCameraRequest(MapState mapState) {
    final request = mapState.pendingCameraRequest;
    if (request == null) {
      _pendingCameraRequestSerial = null;
      return;
    }

    final nextSerial = request.serial;
    if (_appliedCameraRequestSerial == nextSerial) {
      return;
    }

    _pendingCameraRequestSerial = nextSerial;
    _tryApplyPendingCameraRequest();
  }

  void _tryApplyPendingCameraRequest() {
    final serial = _pendingCameraRequestSerial;
    if (!_mapReady || serial == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _applyPendingCameraRequest(serial);
    });
  }

  void _applyPendingCameraRequest(int serial) {
    final mapState = ref.read(mapProvider);
    final request = mapState.pendingCameraRequest;
    if (mapState.cameraRequestSerial != serial || request?.serial != serial) {
      return;
    }

    final acceptedRequest = request!;
    final bounds = acceptedRequest.bounds;
    if (bounds == null) {
      _applyAcceptedCameraMove(acceptedRequest, consumePendingRequest: true);
    } else {
      _applyPendingCameraBoundsRequest(acceptedRequest, bounds);
    }
    _markCameraRequestApplied(serial);
  }

  void _applyPendingCameraBoundsRequest(
    PendingCameraRequest request,
    LatLngBounds bounds,
  ) {
    if (_boundsCollapseToSinglePoint(bounds)) {
      _applyAcceptedCameraMove(
        request.copyWith(
          center: bounds.southWest,
          zoom: MapConstants.defaultMapZoom,
        ),
        consumePendingRequest: true,
      );
      return;
    }

    try {
      _applyAcceptedCameraFit(
        request,
        () => _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: _selectedPathFitPadding()),
        ),
        consumePendingRequest: true,
      );
    } catch (_) {
      _applyAcceptedCameraMove(
        request.copyWith(
          center: bounds.southWest,
          zoom: MapConstants.defaultMapZoom,
        ),
        consumePendingRequest: true,
      );
    }
  }

  bool _boundsCollapseToSinglePoint(LatLngBounds bounds) {
    return (bounds.northEast.latitude - bounds.southWest.latitude).abs() <=
            MapConstants.cameraEpsilon &&
        (bounds.northEast.longitude - bounds.southWest.longitude).abs() <=
            MapConstants.cameraEpsilon;
  }

  bool _isSameCamera(LatLng center, double zoom) {
    final camera = _mapController.camera;
    return (camera.center.latitude - center.latitude).abs() <=
            MapConstants.cameraEpsilon &&
        (camera.center.longitude - center.longitude).abs() <=
            MapConstants.cameraEpsilon &&
        (camera.zoom - zoom).abs() <= MapConstants.cameraEpsilon;
  }

  bool _isSameCameraForValues({
    required LatLng leftCenter,
    required double leftZoom,
    required LatLng rightCenter,
    required double rightZoom,
  }) {
    return (leftCenter.latitude - rightCenter.latitude).abs() <=
            MapConstants.cameraEpsilon &&
        (leftCenter.longitude - rightCenter.longitude).abs() <=
            MapConstants.cameraEpsilon &&
        (leftZoom - rightZoom).abs() <= MapConstants.cameraEpsilon;
  }

  void _markCameraRequestApplied(int serial) {
    _appliedCameraRequestSerial = serial;
    if (_pendingCameraRequestSerial == serial) {
      _pendingCameraRequestSerial = null;
    }
  }

  void _queueSelectedMapZoom(MapState mapState) {
    final selectedMap = mapState.selectedMap;
    if (selectedMap == null ||
        mapState.tasmapDisplayMode != TasmapDisplayMode.selectedMap) {
      _pendingSelectedMap = null;
      _pendingSelectedMapSerial = null;
      return;
    }

    final nextSerial = mapState.selectedMapFocusSerial;
    if (_appliedSelectedMapSerial == nextSerial) {
      return;
    }
    _pendingSelectedMap = selectedMap;
    _pendingSelectedMapSerial = nextSerial;
    _tryZoomPendingSelectedMap();
  }

  void _queueSelectedTrackZoom(MapState mapState) {
    final selectedTrackId = mapState.selectedTrackId;
    if (selectedTrackId == null || !mapState.showTracks) {
      _pendingSelectedTrack = null;
      _pendingSelectedTrackSerial = null;
      return;
    }

    GpxTrack? selectedTrack;
    for (final track in mapState.tracks) {
      if (track.gpxTrackId == selectedTrackId && track.visible) {
        selectedTrack = track;
        break;
      }
    }
    if (selectedTrack == null) {
      _pendingSelectedTrack = null;
      _pendingSelectedTrackSerial = null;
      return;
    }

    final nextSerial = mapState.selectedTrackFocusSerial;
    if (_appliedSelectedTrackSerial == nextSerial) {
      return;
    }

    _pendingSelectedTrack = selectedTrack;
    _pendingSelectedTrackSerial = nextSerial;
    _tryZoomPendingSelectedTrack();
  }

  void _queueSelectedRouteZoom(
    MapState mapState,
    List<app_route.Route> routes,
  ) {
    final selectedRouteId = mapState.selectedRouteId;
    if (selectedRouteId == null || !mapState.showRoutes) {
      _pendingSelectedRoute = null;
      _pendingSelectedRouteSerial = null;
      return;
    }

    app_route.Route? selectedRoute;
    for (final route in routes) {
      if (route.id == selectedRouteId && route.visible) {
        selectedRoute = route;
        break;
      }
    }
    if (selectedRoute == null) {
      _pendingSelectedRoute = null;
      _pendingSelectedRouteSerial = null;
      return;
    }

    final nextSerial = mapState.selectedRouteFocusSerial;
    if (_appliedSelectedRouteSerial == nextSerial) {
      return;
    }

    _pendingSelectedRoute = selectedRoute;
    _pendingSelectedRouteSerial = nextSerial;
    _tryZoomPendingSelectedRoute();
  }

  void _tryZoomPendingSelectedMap() {
    final selectedMap = _pendingSelectedMap;
    final selectedMapSerial = _pendingSelectedMapSerial;
    if (!_mapReady || selectedMap == null || selectedMapSerial == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _zoomToMapExtent(selectedMap, focusSerial: selectedMapSerial);
    });
  }

  void _tryZoomPendingSelectedTrack() {
    final selectedTrack = _pendingSelectedTrack;
    final selectedTrackSerial = _pendingSelectedTrackSerial;
    if (!_mapReady || selectedTrack == null || selectedTrackSerial == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _zoomToTrackExtent(selectedTrack, focusSerial: selectedTrackSerial);
    });
  }

  void _tryZoomPendingSelectedRoute() {
    final selectedRoute = _pendingSelectedRoute;
    final selectedRouteSerial = _pendingSelectedRouteSerial;
    if (!_mapReady || selectedRoute == null || selectedRouteSerial == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _zoomToRouteExtent(selectedRoute, focusSerial: selectedRouteSerial);
    });
  }

  EdgeInsets _selectedPathFitPadding() {
    const overlayGap = 24.0;
    const outerInset = 16.0;
    const minVisibleWidth = 160.0;
    const minVisibleHeight = 120.0;
    final viewPadding =
        MediaQuery.maybeOf(context)?.viewPadding ?? EdgeInsets.zero;
    final viewportSize = _mapController.camera.nonRotatedSize;

    var left = outerInset + UiConstants.preferredLeftWidth + overlayGap;
    var right =
        RouterConstants.themeActionRightInset +
        UiConstants.actionsColumnWidth +
        overlayGap +
        viewPadding.right;
    var top = outerInset + overlayGap + viewPadding.top;
    var bottom = outerInset + overlayGap + viewPadding.bottom;

    final horizontalPadding = left + right;
    final maxHorizontalPadding = viewportSize.width - minVisibleWidth;
    if (maxHorizontalPadding > 0 && horizontalPadding > maxHorizontalPadding) {
      final scale = maxHorizontalPadding / horizontalPadding;
      left *= scale;
      right *= scale;
    }

    final verticalPadding = top + bottom;
    final maxVerticalPadding = viewportSize.height - minVisibleHeight;
    if (maxVerticalPadding > 0 && verticalPadding > maxVerticalPadding) {
      final scale = maxVerticalPadding / verticalPadding;
      top *= scale;
      bottom *= scale;
    }

    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  void _zoomToTrackExtent(GpxTrack track, {int attempt = 0, int? focusSerial}) {
    if (focusSerial != null && _pendingSelectedTrackSerial != focusSerial) {
      return;
    }
    if (_mapController.camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      if (attempt < 6) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _zoomToTrackExtent(
              track,
              attempt: attempt + 1,
              focusSerial: focusSerial,
            );
          }
        });
      }
      return;
    }

    final points = track.getSegments().expand((segment) => segment).toList();
    if (points.isEmpty) {
      _markSelectedTrackZoomApplied(focusSerial);
      return;
    }

    if (points.length == 1) {
      _applyAcceptedCameraMove(
        PendingCameraRequest(
          center: points.single,
          zoom: MapConstants.defaultMapZoom,
          serial: focusSerial ?? 0,
        ),
      );
      _markSelectedTrackZoomApplied(focusSerial);
      return;
    }

    try {
      final bounds = LatLngBounds.fromPoints(points);
      final cameraFit = CameraFit.bounds(
        bounds: bounds,
        padding: _selectedPathFitPadding(),
      );
      _applyAcceptedCameraFit(
        PendingCameraRequest(
          center: _mapController.camera.center,
          zoom: _mapController.camera.zoom,
          serial: focusSerial ?? 0,
        ),
        () => _mapController.fitCamera(cameraFit),
      );
      _markSelectedTrackZoomApplied(focusSerial);
    } catch (_) {
      _applyAcceptedCameraMove(
        PendingCameraRequest(
          center: points.first,
          zoom: MapConstants.defaultMapZoom,
          serial: focusSerial ?? 0,
        ),
      );
      _markSelectedTrackZoomApplied(focusSerial);
    }
  }

  void _zoomToRouteExtent(
    app_route.Route route, {
    int attempt = 0,
    int? focusSerial,
  }) {
    if (focusSerial != null && _pendingSelectedRouteSerial != focusSerial) {
      return;
    }
    if (_mapController.camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      if (attempt < 6) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _zoomToRouteExtent(
              route,
              attempt: attempt + 1,
              focusSerial: focusSerial,
            );
          }
        });
      }
      return;
    }

    final points = route.gpxRoute;
    if (points.isEmpty) {
      _applyAcceptedCameraMove(
        PendingCameraRequest(
          center: _mapController.camera.center,
          zoom: _mapController.camera.zoom,
          serial: focusSerial ?? 0,
        ),
      );
      _markSelectedRouteZoomApplied(focusSerial);
      return;
    }

    if (points.length == 1) {
      _applyAcceptedCameraMove(
        PendingCameraRequest(
          center: points.single,
          zoom: MapConstants.defaultMapZoom,
          serial: focusSerial ?? 0,
        ),
      );
      _markSelectedRouteZoomApplied(focusSerial);
      return;
    }

    try {
      final bounds = LatLngBounds.fromPoints(points);
      final cameraFit = CameraFit.bounds(
        bounds: bounds,
        padding: _selectedPathFitPadding(),
      );
      _applyAcceptedCameraFit(
        PendingCameraRequest(
          center: _mapController.camera.center,
          zoom: _mapController.camera.zoom,
          serial: focusSerial ?? 0,
        ),
        () => _mapController.fitCamera(cameraFit),
      );
      _markSelectedRouteZoomApplied(focusSerial);
    } catch (_) {
      _applyAcceptedCameraMove(
        PendingCameraRequest(
          center: points.first,
          zoom: MapConstants.defaultMapZoom,
          serial: focusSerial ?? 0,
        ),
      );
      _markSelectedRouteZoomApplied(focusSerial);
    }
  }

  void _markSelectedTrackZoomApplied(int? focusSerial) {
    if (focusSerial == null) {
      return;
    }
    _appliedSelectedTrackSerial = focusSerial;
    if (_pendingSelectedTrackSerial == focusSerial) {
      _pendingSelectedTrack = null;
      _pendingSelectedTrackSerial = null;
    }
  }

  void _markSelectedRouteZoomApplied(int? focusSerial) {
    if (focusSerial == null) {
      return;
    }
    _appliedSelectedRouteSerial = focusSerial;
    if (_pendingSelectedRouteSerial == focusSerial) {
      _pendingSelectedRoute = null;
      _pendingSelectedRouteSerial = null;
    }
  }
}

class _PeakViewportInputs {
  const _PeakViewportInputs({
    required this.peaks,
    required this.correlatedPeakIds,
    required this.untickedPeakColours,
    required this.activeOwnershipSegments,
    required this.ownershipRingSegments,
    required this.clusteringEnabled,
  });

  final List<Peak> peaks;
  final Set<int> correlatedPeakIds;
  final Map<int, int> untickedPeakColours;
  final Map<int, List<PeakOwnershipRingSegment>> activeOwnershipSegments;
  final Map<int, List<PeakOwnershipRingSegment>> ownershipRingSegments;
  final bool clusteringEnabled;
}

class _SettledPeakViewportFrame {
  const _SettledPeakViewportFrame({required this.viewportData});

  final PeakClusterViewportData viewportData;
}

class _LiveCameraState {
  const _LiveCameraState({
    required this.center,
    required this.zoom,
    required this.mgrs,
    required this.token,
  });

  final LatLng center;
  final double zoom;
  final String mgrs;
  final int token;
}
