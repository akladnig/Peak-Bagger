import 'dart:async';
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
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/peak_hover_detector.dart';
import 'package:peak_bagger/services/track_hover_detector.dart';
import 'package:peak_bagger/services/map_trackpad_gesture_classifier.dart';
import '../core/constants.dart';
import 'package:peak_bagger/widgets/map_action_rail.dart';
import 'package:peak_bagger/widgets/map_basemaps_drawer.dart';
import 'package:peak_bagger/widgets/map_peak_lists_drawer.dart';
import 'package:peak_bagger/widgets/map_rebuild_debug_counters.dart';
import 'package:peak_bagger/widgets/tasmap_polygon_label.dart';

import 'map_screen_layers.dart';
import 'map_screen_panels.dart';

class DismissSurfaceIntent extends Intent {
  const DismissSurfaceIntent();
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final MapController _mapController;
  late final MapNotifier _mapNotifier;
  final _gotoController = TextEditingController();
  final _gotoFocusNode = FocusNode();
  final _searchFocusNode = FocusNode();
  final _mapFocusNode = FocusNode();
  String? _gotoError;
  bool _mapReady = false;
  Tasmap50k? _pendingSelectedMap;
  int? _pendingSelectedMapSerial;
  int? _appliedSelectedMapSerial;
  GpxTrack? _pendingSelectedTrack;
  int? _pendingSelectedTrackSerial;
  int? _appliedSelectedTrackSerial;
  int? _pendingCameraRequestSerial;
  int? _appliedCameraRequestSerial;
  bool _isPointerDown = false;
  Offset? _pointerDownPosition;
  bool _primaryClickPending = false;
  LatLng? _trackpadGestureCenter;
  double? _trackpadGestureZoom;
  Timer? _scrollTimer;
  double _scrollDx = 0;
  double _scrollDy = 0;
  _LiveCameraState? _liveCamera;
  int _cameraIntentToken = 0;
  final _viewportUiRevision = ValueNotifier<int>(0);
  Timer? _pendingCameraSaveTimer;
  bool _hasPendingCameraSave = false;
  static final _tickedPeakMarker = SvgPicture.asset(
    'assets/peak_marker_ticked.svg',
  );
  static final _untickedPeakMarker = SvgPicture.asset(
    'assets/peak_marker.svg',
    colorFilter: const ColorFilter.mode(Color(0xFFD66A6D), BlendMode.srcIn),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapController = MapController();
    _mapNotifier = ref.read(mapProvider.notifier);
    _searchFocusNode.addListener(_onSearchFocusChange);
    _gotoFocusNode.addListener(_onGotoFocusChange);
    Future.microtask(() {
      if (mounted) {
        _mapNotifier.reconcileSelectedTrackState();
      }
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
    final scaffoldWidth = _scaffoldKey.currentContext?.size?.width;
    final viewportWidth =
        scaffoldWidth ?? MediaQuery.sizeOf(_scaffoldKey.currentContext ?? context).width;
    final panelVisible =
        viewportWidth >= RouterConstants.shellBreakpoint &&
        mapState.showTracks &&
        mapState.tracks.any(
          (track) => track.gpxTrackId == mapState.selectedTrackId,
        );
    final scaffoldState = _scaffoldKey.currentState;
    final scaffoldContext = _scaffoldKey.currentContext;
    if ((scaffoldState?.isEndDrawerOpen ?? false) && scaffoldContext != null) {
      Navigator.of(scaffoldContext).pop();
      _mapFocusNode.requestFocus();
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
    if (panelVisible) {
      notifier.clearSelectedTrack();
      _mapFocusNode.requestFocus();
      return true;
    }
    return false;
  }

  MouseCursor _mouseCursor(MapState mapState) {
    if (_isPointerDown) {
      return SystemMouseCursors.grabbing;
    }
    if (mapState.hoveredTrackId != null) {
      return SystemMouseCursors.click;
    }
    if (mapState.hoveredPeakId != null) {
      return SystemMouseCursors.click;
    }
    return SystemMouseCursors.grab;
  }

  bool _handlePeakHover(
    Offset localPosition,
    MapState mapState,
    List<Peak> peaks,
  ) {
    final notifier = ref.read(mapProvider.notifier);

    if (_isPointerDown || !mapState.showPeaks || mapState.zoom < MapConstants.peakMinZoom) {
      notifier.clearHoveredPeak();
      return false;
    }

    final peak = _hitTestPeak(localPosition, mapState, peaks);
    notifier.setHoveredPeakId(peak?.osmId);
    return peak != null;
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

    final candidates = _buildPeakHoverCandidates(peaks, camera);
    if (candidates.isEmpty) {
      return null;
    }

    final result = PeakHoverDetector.findHoveredPeak(
      pointerPosition: localPosition,
      candidates: candidates,
    );
    final peakId = result.hoveredPeakId;
    if (peakId == null) {
      return null;
    }
    for (final peak in peaks) {
      if (peak.osmId == peakId) {
        return peak;
      }
    }
    return null;
  }

  List<PeakHoverCandidate> _buildPeakHoverCandidates(
    List<Peak> peaks,
    MapCamera camera,
  ) {
    final correlatedPeakIds = ref.read(mapProvider.notifier).correlatedPeakIds;
    final untickedCandidates = <PeakHoverCandidate>[];
    final tickedCandidates = <PeakHoverCandidate>[];

    for (final peak in peaks) {
      final candidate = PeakHoverCandidate(
        peakId: peak.osmId,
        screenPosition: camera.latLngToScreenOffset(
          LatLng(peak.latitude, peak.longitude),
        ),
      );
      if (correlatedPeakIds.contains(peak.osmId)) {
        tickedCandidates.add(candidate);
      } else {
        untickedCandidates.add(candidate);
      }
    }

    return [...untickedCandidates, ...tickedCandidates];
  }

  void _handleMapHover(
    Offset localPosition,
    LatLng location,
    MapState mapState,
    List<Peak> peaks,
  ) {
    final notifier = ref.read(mapProvider.notifier);
    notifier.setCursorMgrs(location);
    if (_handlePeakHover(localPosition, mapState, peaks)) {
      notifier.clearHoveredTrack();
      return;
    }
    _handleTrackHover(localPosition, location, mapState);
  }

  void _handleTrackHover(
    Offset localPosition,
    LatLng location,
    MapState mapState,
  ) {
    final notifier = ref.read(mapProvider.notifier);
    notifier.setCursorMgrs(location);

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

  List<TrackHoverCandidate> _buildTrackHoverCandidates(
    MapState mapState,
    MapCamera camera,
  ) {
    final displayZoom = mapState.zoom.round().clamp(
      MapConstants.peakMinZoom,
      MapConstants.peakMaxZoom,
    );
    final candidates = <TrackHoverCandidate>[];

    for (final track in mapState.tracks) {
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
      MapConstants.peakMinZoom.toDouble(),
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
    _acceptCameraIntent(
      request,
      consumePendingRequest: consumePendingRequest,
    );
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
      _acceptCameraIntent(
        request.copyWith(
          center: _mapController.camera.center,
          zoom: _mapController.camera.zoom,
        ),
        consumePendingRequest: consumePendingRequest,
      );
    });
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
    if (mapState.cursorMgrs != null) {
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
      if (_liveCamera?.token == liveCamera.token) {
        _liveCamera = null;
        _bumpViewportUiRevision();
      }
      return false;
    }

    ref.read(mapProvider.notifier).updatePosition(liveCamera.center, liveCamera.zoom);
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
    _flushPendingCameraPosition();
    WidgetsBinding.instance.removeObserver(this);
    _scrollTimer?.cancel();
    _gotoFocusNode.dispose();
    _searchFocusNode.dispose();
    _mapFocusNode.dispose();
    _viewportUiRevision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MapRebuildDebugCounters.recordRouteRootBuild();
    final routeChrome = ref.watch(
      mapProvider.select(
        (state) => (
          endDrawerMode: state.endDrawerMode,
          showPeakSearch: state.showPeakSearch,
          searchResults: state.searchResults,
          searchQuery: state.searchQuery,
          showGotoInput: state.showGotoInput,
          mapSuggestions: state.mapSuggestions,
          showInfoPopup: state.showInfoPopup,
          infoMapName: state.infoMapName,
          infoMgrs: state.infoMgrs,
          infoPeakName: state.infoPeakName,
          infoPeakElevation: state.infoPeakElevation,
          hasTrackRecoveryIssue: state.hasTrackRecoveryIssue,
          trackCount: state.tracks.length,
          peakInfo: state.peakInfo,
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
          mounted) {
        _mapFocusNode.requestFocus();
      }
    });

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissSurfaceIntent(),
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
        if (_searchFocusNode.hasFocus || _gotoFocusNode.hasFocus) {
          return KeyEventResult.ignored;
        }
        final mapState = ref.read(mapProvider);
        final key = event.logicalKey;
        final notifier = ref.read(mapProvider.notifier);

        if (event is KeyDownEvent && mapState.peakInfoPeak != null) {
          notifier.closePeakInfoPopup();
        }

        // Close popup on any key press (except I which toggles it)
        if (mapState.showInfoPopup && key != LogicalKeyboardKey.keyI) {
          if (event is KeyDownEvent) {
            notifier.toggleInfoPopup();
          }
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
            notifier.setEndDrawerMode(EndDrawerMode.basemaps);
            _scaffoldKey.currentState?.openEndDrawer();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyC) {
            _centerOnSelectedLocationDirect();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyM) {
            notifier.toggleMapOverlay();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyT) {
            if (event is KeyDownEvent) {
              notifier.toggleTracks();
            }
            return KeyEventResult.handled;
          }
            return KeyEventResult.ignored;
          },
          child: Scaffold(
        key: _scaffoldKey,
        endDrawer: switch (routeChrome.endDrawerMode) {
          EndDrawerMode.basemaps => const MapBasemapsDrawer(),
          EndDrawerMode.peakLists => const MapPeakListsDrawer(),
        },
        onEndDrawerChanged: (isOpen) {
          if (!isOpen && mounted) {
            _mapFocusNode.requestFocus();
          }
        },
        body: Stack(
          children: [
            Consumer(
              builder: (context, ref, _) {
                final mapState = ref.watch(mapProvider);
                final filteredPeaks = ref.watch(filteredPeaksProvider);
                ref.watch(
                  tasmapStateProvider.select((state) => state.tasmapRevision),
                );
                _queueSelectedMapZoom(mapState);
                _queueSelectedTrackZoom(mapState);
                _queueCameraRequest(mapState);

                return ValueListenableBuilder<int>(
                  valueListenable: _viewportUiRevision,
                  builder: (context, revision, child) {
                    final displayMgrs =
                        mapState.cursorMgrs ??
                        mapState.gotoMgrs ??
                        _liveCamera?.mgrs ??
                        mapState.currentMgrs;
                    final displayZoom = _liveCamera?.zoom ?? mapState.zoom;

                    return Stack(
                      children: [
                        MouseRegion(
                          key: const Key('map-interaction-region'),
                          cursor: _mouseCursor(mapState),
                          onExit: (_) {
                            final notifier = ref.read(mapProvider.notifier);
                            notifier.clearCursorMgrs();
                            notifier.clearHoveredPeak();
                            notifier.clearHoveredTrack();
                          },
                          child: Listener(
                            behavior: HitTestBehavior.translucent,
                            onPointerPanZoomStart: _handleTrackpadPanZoomStart,
                            onPointerPanZoomUpdate: _handleTrackpadPanZoomUpdate,
                            onPointerPanZoomEnd: _handleTrackpadPanZoomEnd,
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: mapState.center,
                                initialZoom: mapState.zoom,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all &
                                      ~InteractiveFlag.rotate &
                                      ~InteractiveFlag.pinchMove &
                                      ~InteractiveFlag.pinchZoom,
                                ),
                                onMapReady: _handleMapReady,
                                onSecondaryTap: (tapPosition, point) {
                                  _centerOnSelectedLocationDirect();
                                },
                                onPointerDown: (event, point) {
                                  _mapFocusNode.requestFocus();
                                  _isPointerDown = true;
                                  _pointerDownPosition = event.localPosition;
                                  _primaryClickPending =
                                      event.kind == PointerDeviceKind.mouse &&
                                      event.buttons == kPrimaryMouseButton;
                                  _bumpViewportUiRevision();
                                },
                                onPointerUp: (event, point) {
                                  final primaryClickPending =
                                      _primaryClickPending;
                                  final moved =
                                      _pointerDownPosition != null &&
                                      (event.localPosition - _pointerDownPosition!)
                                              .distance >
                                          5;
                                  _isPointerDown = false;
                                  _pointerDownPosition = null;
                                  _primaryClickPending = false;
                                  _bumpViewportUiRevision();
                                  if (moved) {
                                    _flushPendingCameraPosition();
                                    return;
                                  }
                                  final notifier = ref.read(mapProvider.notifier);
                                  final tappedPeak = _hitTestPeak(
                                    event.localPosition,
                                    ref.read(mapProvider),
                                    ref.read(filteredPeaksProvider),
                                  );
                                  if (tappedPeak != null) {
                                    notifier.openPeakInfoPopup(tappedPeak);
                                    return;
                                  }
                                  if (ref.read(mapProvider).peakInfoPeak != null) {
                                    notifier.closePeakInfoPopup();
                                  }
                                  if (ref.read(mapProvider).showInfoPopup) {
                                    notifier.toggleInfoPopup();
                                  }
                                  final tappedLocation = _mapController.camera
                                      .screenOffsetToLatLng(event.localPosition);
                                  _handleTrackHover(
                                    event.localPosition,
                                    tappedLocation,
                                    mapState,
                                  );
                                  if (primaryClickPending ||
                                      event.kind != PointerDeviceKind.mouse) {
                                    notifier.setSelectedLocation(tappedLocation);
                                  }
                                  final hoveredTrackId = ref
                                      .read(mapProvider)
                                      .hoveredTrackId;
                                  if (primaryClickPending &&
                                      hoveredTrackId != null) {
                                    notifier.selectTrack(hoveredTrackId);
                                  } else if (primaryClickPending) {
                                    notifier.clearSelectedTrack();
                                  }
                                },
                                onPointerCancel: (event, point) {
                                  _isPointerDown = false;
                                  _pointerDownPosition = null;
                                  _bumpViewportUiRevision();
                                  _flushPendingCameraPosition();
                                  ref.read(mapProvider.notifier).clearHoveredTrack();
                                  ref.read(mapProvider.notifier).clearHoveredPeak();
                                },
                                onPointerHover: (event, point) {
                                  _handleMapHover(
                                    event.localPosition,
                                    point,
                                    mapState,
                                    filteredPeaks,
                                  );
                                },
                                onPositionChanged: (position, hasGesture) {
                                  if (hasGesture) {
                                    _updateContinuousCamera(
                                      center: position.center,
                                      zoom: position.zoom,
                                    );
                                  }
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate: mapTileUrl(mapState.basemap),
                                  userAgentPackageName: 'com.peak_bagger.app',
                                  tileProvider: FMTCTileProvider(
                                    urlTransformer: (url) => url,
                                    stores: {
                                      'openstreetmap':
                                          BrowseStoreStrategy.readUpdateCreate,
                                      'tracestrack':
                                          BrowseStoreStrategy.readUpdateCreate,
                                      'tasmapTopo':
                                          BrowseStoreStrategy.readUpdateCreate,
                                      'tasmap50k':
                                          BrowseStoreStrategy.readUpdateCreate,
                                      'tasmap25k':
                                          BrowseStoreStrategy.readUpdateCreate,
                                    },
                                    loadingStrategy:
                                        BrowseLoadingStrategy.cacheFirst,
                                  ),
                                ),
                                if (mapState.selectedLocation != null)
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: mapState.selectedLocation!,
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
                                if (mapState.selectedPeaks.isNotEmpty)
                                  CircleLayer(
                                    circles: mapState.selectedPeaks.map((peak) {
                                      return CircleMarker(
                                        point: LatLng(
                                          peak.latitude,
                                          peak.longitude,
                                        ),
                                        radius: 15,
                                        color: Colors.blue.withValues(alpha: 0.3),
                                        borderColor: Colors.blue,
                                        borderStrokeWidth: 2,
                                      );
                                    }).toList(),
                                  ),
                                if (mapState.showSelectedMapLayer)
                                  buildMapRectangle(
                                    ref.read(tasmapRepositoryProvider),
                                    mapState.selectedMap!,
                                  ),
                                if (mapState.showMapOverlay)
                                  PolygonLayer(
                                    key: const Key('tasmap-layer'),
                                    polygons: buildAllMapRectangles(
                                      ref.read(tasmapRepositoryProvider),
                                    ),
                                  ),
                                if (mapState.showTracks)
                                  buildTrackPolylines(
                                    mapState.tracks,
                                    mapState.zoom,
                                    selectedTrackId: mapState.selectedTrackId,
                                  ),
                                if (mapState.showPeaks &&
                                    filteredPeaks.isNotEmpty &&
                                    mapState.zoom >= MapConstants.peakMinZoom)
                                  MarkerLayer(
                                    key: const Key('peak-marker-layer'),
                                    markers: buildPeakMarkers(
                                      peaks: filteredPeaks,
                                      zoom: mapState.zoom,
                                      correlatedPeakIds: ref
                                          .read(mapProvider.notifier)
                                          .correlatedPeakIds,
                                      tickedPeakMarker: _tickedPeakMarker,
                                      untickedPeakMarker: _untickedPeakMarker,
                                      hoveredPeakId: mapState.hoveredPeakId,
                                    ),
                                  ),
                                if (mapState.showSelectedMapLayer)
                                  TasmapPolygonLabelLayer(
                                    key: const Key('tasmap-label-layer'),
                                    insetX: tasmapPolygonLabelDefaultInsetX,
                                    insetY: tasmapPolygonLabelDefaultInsetY,
                                    entries: buildSelectedMapLabelEntries(
                                      ref.read(tasmapRepositoryProvider),
                                      mapState.selectedMap!,
                                      mapState.zoom,
                                      Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                if (mapState.showMapOverlay)
                                  TasmapPolygonLabelLayer(
                                    key: const Key('tasmap-label-layer'),
                                    insetX: tasmapPolygonLabelDefaultInsetX,
                                    insetY: tasmapPolygonLabelDefaultInsetY,
                                    entries: buildOverlayLabelEntries(
                                      ref.read(tasmapRepositoryProvider),
                                      mapState.zoom,
                                      Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          top: 16,
                          child: MapMgrsReadout(mgrs: displayMgrs),
                        ),
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: MapZoomReadout(zoom: displayZoom),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const MapActionRail(),
            if (routeChrome.showPeakSearch)
              Positioned(
                right: 72,
                top: 16,
                child: MapPeakSearchPanel(
                  focusNode: _searchFocusNode,
                  searchResults: routeChrome.searchResults,
                  searchQuery: routeChrome.searchQuery,
                  onChanged: (value) {
                    ref.read(mapProvider.notifier).searchPeaks(value);
                  },
                  onSubmitted: (_) {
                    ref.read(mapProvider.notifier).selectAllSearchResults();
                    _searchFocusNode.unfocus();
                  },
                  onClose: () {
                    _searchFocusNode.unfocus();
                    ref.read(mapProvider.notifier).setPeakSearchVisible(false);
                  },
                  onSelectPeak: (peak) {
                    _focusPeakDirect(peak);
                    ref.read(mapProvider.notifier).setPeakSearchVisible(false);
                    ref.read(mapProvider.notifier).clearSearch();
                  },
                  mapNameForPeak: _mapNameForPeak,
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
                    ref.read(mapProvider.notifier).parseGridReference(value);
                  },
                  onSubmitted: (_) => _handleGotoSubmit(ref.read(mapProvider)),
                  onClose: () {
                    ref.read(mapProvider.notifier).clearGotoMgrs();
                    ref.read(mapProvider.notifier).setGotoInputVisible(false);
                    _gotoController.clear();
                  },
                  onNavigate: _navigateToGridReference,
                  onTabShortcut: _handleGotoTab,
                  onSelectSuggestion: (map) {
                    _gotoController.text = map.name;
                    ref.read(mapProvider.notifier).selectMap(map);
                    _zoomToMapExtent(map);
                    ref.read(mapProvider.notifier).setGotoInputVisible(false);
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
            if (routeChrome.peakInfo != null)
              _buildPeakInfoPopup(context, routeChrome.peakInfo!),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeakInfoPopup(BuildContext context, PeakInfoContent content) {
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
      left: placement.topLeft.dx,
      top: placement.topLeft.dy,
      child: SizedBox(
        width: UiConstants.peakInfoPopupSize.width,
        child: PeakInfoPopupCard(
          key: const Key('peak-info-popup'),
          content: content,
          onClose: () {
            ref.read(mapProvider.notifier).closePeakInfoPopup();
          },
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

  void _goToCurrentLocation() {
    // TODO: Implement GPS location
  }

  String _mapNameForPeak(Peak peak) {
    try {
      return ref
              .read(tasmapRepositoryProvider)
              .findByMgrsCodeAndCoordinates(
                '${peak.gridZoneDesignator}${peak.mgrs100kId}${peak.easting}${peak.northing}',
              )
              ?.name ??
          'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  Offset _screenOffsetForPeak(Peak peak) {
    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return const Offset(0, 0);
    }
    return camera.latLngToScreenOffset(LatLng(peak.latitude, peak.longitude));
  }

  void _handleMapReady() {
    _mapReady = true;
    _tryApplyPendingCameraRequest();
    _tryZoomPendingSelectedMap();
    _tryZoomPendingSelectedTrack();
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

    _applyAcceptedCameraMove(request!, consumePendingRequest: true);
    _markCameraRequestApplied(serial);
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
      if (track.gpxTrackId == selectedTrackId) {
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
        padding: const EdgeInsets.all(50),
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
