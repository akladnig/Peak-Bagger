import 'dart:async';
import 'package:flutter/gestures.dart' show kPrimaryMouseButton;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/peak_hover_detector.dart';
import 'package:peak_bagger/services/track_hover_detector.dart';
import 'package:peak_bagger/widgets/map_action_rail.dart';
import 'package:peak_bagger/widgets/map_basemaps_drawer.dart';
import 'package:peak_bagger/widgets/tasmap_polygon_label.dart';

import 'map_screen_layers.dart';
import 'map_screen_panels.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final MapController _mapController;
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
  bool _isPointerDown = false;
  Offset? _pointerDownPosition;
  bool _primaryClickPending = false;
  Timer? _scrollTimer;
  double _scrollDx = 0;
  double _scrollDy = 0;
  static const _scrollSpeed = 0.001;
  static const _scrollInterval = Duration(milliseconds: 16);
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
    _mapController = MapController();
    _searchFocusNode.addListener(_onSearchFocusChange);
    _gotoFocusNode.addListener(_onGotoFocusChange);
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

  bool _handlePeakHover(Offset localPosition, MapState mapState) {
    final notifier = ref.read(mapProvider.notifier);

    if (_isPointerDown || !mapState.showPeaks || mapState.zoom < 9) {
      notifier.clearHoveredPeak();
      return false;
    }

    final peak = _hitTestPeak(localPosition, mapState);
    notifier.setHoveredPeakId(peak?.osmId);
    return peak != null;
  }

  Peak? _hitTestPeak(Offset localPosition, MapState mapState) {
    if (!mapState.showPeaks || mapState.zoom < 9) {
      return null;
    }

    final camera = _mapController.camera;
    if (camera.nonRotatedSize == MapCamera.kImpossibleSize) {
      return null;
    }

    final candidates = _buildPeakHoverCandidates(mapState, camera);
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
    for (final peak in mapState.peaks) {
      if (peak.osmId == peakId) {
        return peak;
      }
    }
    return null;
  }

  List<PeakHoverCandidate> _buildPeakHoverCandidates(
    MapState mapState,
    MapCamera camera,
  ) {
    final correlatedPeakIds = ref.read(mapProvider.notifier).correlatedPeakIds;
    final untickedCandidates = <PeakHoverCandidate>[];
    final tickedCandidates = <PeakHoverCandidate>[];

    for (final peak in mapState.peaks) {
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
  ) {
    final notifier = ref.read(mapProvider.notifier);
    notifier.setCursorMgrs(location);
    if (_handlePeakHover(localPosition, mapState)) {
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
    final displayZoom = mapState.zoom.round().clamp(6, 18);
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
    _scrollDx = dx * _scrollSpeed;
    _scrollDy = dy * _scrollSpeed;
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(_scrollInterval, (_) {
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
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _gotoFocusNode.dispose();
    _searchFocusNode.dispose();
    _mapFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);
    ref.watch(tasmapStateProvider.select((state) => state.tasmapRevision));
    final displayMgrs =
        mapState.cursorMgrs ?? mapState.gotoMgrs ?? mapState.currentMgrs;

    _queueSelectedMapZoom(mapState);
    _queueSelectedTrackZoom(mapState);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mapState.syncEnabled) {
        _mapController.move(mapState.center, mapState.zoom);
      }
      if (mapState.showPeakSearch && !_searchFocusNode.hasFocus) {
        _searchFocusNode.requestFocus();
      }
      if (mapState.showGotoInput && !_gotoFocusNode.hasFocus) {
        _gotoFocusNode.requestFocus();
      }
      if (!mapState.showPeakSearch &&
          !mapState.showGotoInput &&
          !_mapFocusNode.hasFocus &&
          mounted) {
        _mapFocusNode.requestFocus();
      }
    });

    return Scaffold(
      endDrawer: const MapBasemapsDrawer(),
      body: Focus(
        focusNode: _mapFocusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (_searchFocusNode.hasFocus || _gotoFocusNode.hasFocus) {
            return KeyEventResult.ignored;
          }
          final mapState = ref.read(mapProvider);
          final key = event.logicalKey;

          // Close popup on any key press (except I which toggles it)
          if (mapState.showInfoPopup && key != LogicalKeyboardKey.keyI) {
            if (event is KeyDownEvent) {
              ref.read(mapProvider.notifier).toggleInfoPopup();
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
              _mapController.move(_mapController.camera.center, newZoom);
              ref
                  .read(mapProvider.notifier)
                  .updatePosition(_mapController.camera.center, newZoom);
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
            ref.read(mapProvider.notifier).toggleGotoInput();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyI) {
            if (event is KeyDownEvent) {
              final selectedLocation = mapState.selectedLocation;
              if (selectedLocation != null) {
                // Center on the marker so popup appears to the right of marker
                _mapController.move(selectedLocation, mapState.zoom);
                ref
                    .read(mapProvider.notifier)
                    .updatePosition(selectedLocation, mapState.zoom);
              }
              ref.read(mapProvider.notifier).toggleInfoPopup();
            }
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyB) {
            Scaffold.of(context).openEndDrawer();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyC) {
            ref.read(mapProvider.notifier).centerOnSelectedLocation();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyM) {
            ref.read(mapProvider.notifier).toggleMapOverlay();
            return KeyEventResult.handled;
          } else if (key == LogicalKeyboardKey.keyT) {
            if (event is KeyDownEvent) {
              ref.read(mapProvider.notifier).toggleTracks();
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
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
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapState.center,
                  initialZoom: mapState.zoom,
                  onMapReady: _handleMapReady,
                  onSecondaryTap: (tapPosition, point) {
                    ref.read(mapProvider.notifier).centerOnSelectedLocation();
                  },
                  onPointerDown: (event, point) {
                    _mapFocusNode.requestFocus();
                    setState(() {
                      _isPointerDown = true;
                      _pointerDownPosition = event.localPosition;
                      _primaryClickPending =
                          event.kind == PointerDeviceKind.mouse &&
                          event.buttons == kPrimaryMouseButton;
                    });
                  },
                  onPointerUp: (event, point) {
                    final primaryClickPending = _primaryClickPending;
                    final moved =
                        _pointerDownPosition != null &&
                        (event.localPosition - _pointerDownPosition!).distance >
                            5;
                    setState(() {
                      _isPointerDown = false;
                      _pointerDownPosition = null;
                      _primaryClickPending = false;
                    });
                    if (!moved) {
                      final notifier = ref.read(mapProvider.notifier);
                      final tappedPeak = _hitTestPeak(
                        event.localPosition,
                        ref.read(mapProvider),
                      );
                      if (tappedPeak != null) {
                        notifier.openPeakInfoPopup(tappedPeak);
                        return;
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
                      if (primaryClickPending && hoveredTrackId != null) {
                        notifier.selectTrack(hoveredTrackId);
                      } else if (primaryClickPending) {
                        notifier.clearSelectedTrack();
                      }
                    }
                  },
                  onPointerCancel: (event, point) {
                    setState(() {
                      _isPointerDown = false;
                      _pointerDownPosition = null;
                    });
                    ref.read(mapProvider.notifier).clearHoveredTrack();
                    ref.read(mapProvider.notifier).clearHoveredPeak();
                  },
                  onPointerHover: (event, point) {
                    _handleMapHover(event.localPosition, point, mapState);
                  },
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture) {
                      if (ref.read(mapProvider).showInfoPopup) {
                        ref.read(mapProvider.notifier).toggleInfoPopup();
                      }
                      ref
                          .read(mapProvider.notifier)
                          .updatePosition(position.center, position.zoom);
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
                        'openstreetmap': BrowseStoreStrategy.readUpdateCreate,
                        'tracestrack': BrowseStoreStrategy.readUpdateCreate,
                        'tasmapTopo': BrowseStoreStrategy.readUpdateCreate,
                        'tasmap50k': BrowseStoreStrategy.readUpdateCreate,
                        'tasmap25k': BrowseStoreStrategy.readUpdateCreate,
                      },
                      loadingStrategy: BrowseLoadingStrategy.cacheFirst,
                    ),
                  ),
                  if (mapState.selectedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: mapState.selectedLocation!,
                          width: 40,
                          height: 40,
                          child: Icon(
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
                          point: LatLng(peak.latitude, peak.longitude),
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
                      mapState.peaks.isNotEmpty &&
                      mapState.zoom >= 9)
                    MarkerLayer(
                      key: const Key('peak-marker-layer'),
                      markers: buildPeakMarkers(
                        peaks: mapState.peaks,
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
            const MapActionRail(),
            Positioned(
              left: 16,
              top: 16,
              child: MapMgrsReadout(mgrs: displayMgrs),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: MapZoomReadout(zoom: mapState.zoom),
            ),
            if (mapState.showPeakSearch)
              Positioned(
                right: 72,
                top: 16,
                child: MapPeakSearchPanel(
                  focusNode: _searchFocusNode,
                  searchResults: mapState.searchResults,
                  searchQuery: mapState.searchQuery,
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
                    ref.read(mapProvider.notifier).centerOnPeak(peak);
                    ref.read(mapProvider.notifier).setPeakSearchVisible(false);
                    ref.read(mapProvider.notifier).clearSearch();
                  },
                  mapNameForPeak: _mapNameForPeak,
                ),
              ),
            if (mapState.showGotoInput)
              Positioned(
                right: 72,
                top: 16,
                child: MapGotoPanel(
                  focusNode: _gotoFocusNode,
                  controller: _gotoController,
                  errorText: _gotoError,
                  mapSuggestions: mapState.mapSuggestions,
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
            if (mapState.showInfoPopup)
              Positioned(
                left: MediaQuery.of(context).size.width / 2 + 16,
                top: MediaQuery.of(context).size.height / 2 - 50,
                child: MapInfoPopupCard(
                  infoMapName: mapState.infoMapName,
                  infoMgrs: mapState.infoMgrs,
                  infoPeakName: mapState.infoPeakName,
                  infoPeakElevation: mapState.infoPeakElevation,
                  hasTrackRecoveryIssue: mapState.hasTrackRecoveryIssue,
                  trackCount: mapState.tracks.length,
                  onClose: () {
                    ref.read(mapProvider.notifier).toggleInfoPopup();
                  },
                ),
              ),
            if (mapState.peakInfoPeak != null)
              Positioned(
                left: peakInfoPopupTopLeft(
                  _screenOffsetForPeak(mapState.peakInfoPeak!),
                ).dx,
                top: peakInfoPopupTopLeft(
                  _screenOffsetForPeak(mapState.peakInfoPeak!),
                ).dy,
                child: PeakInfoPopupCard(
                  key: const Key('peak-info-popup'),
                  peak: mapState.peakInfoPeak!,
                  onClose: () {
                    ref.read(mapProvider.notifier).closePeakInfoPopup();
                  },
                ),
              ),
          ],
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
      if (selectedMap != null) {
        _zoomToMapExtent(selectedMap);
        ref.read(mapProvider.notifier).centerOnLocation(location);
      } else {
        _mapController.move(location, 15);
        ref.read(mapProvider.notifier).centerOnLocation(location);
      }
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
        _mapController.move(center, 12);
        ref.read(mapProvider.notifier).updatePosition(center, 12);
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
      _mapController.fitCamera(cameraFit);

      if (targetCenter != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ref
              .read(mapProvider.notifier)
              .updatePosition(targetCenter, _mapController.camera.zoom);
        });
      }
      _markSelectedMapZoomApplied(focusSerial);
    } catch (e) {
      final center = repo.getMapCenter(map);
      if (center != null) {
        _mapController.move(center, 12);
        ref.read(mapProvider.notifier).updatePosition(center, 12);
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
    ref
        .read(mapProvider.notifier)
        .updatePosition(newCenter, _mapController.camera.zoom);
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
    _tryZoomPendingSelectedMap();
    _tryZoomPendingSelectedTrack();
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

    final selectedTrack = ref
        .read(gpxTrackRepositoryProvider)
        .findById(selectedTrackId);
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
      _mapController.move(points.single, 12);
      ref.read(mapProvider.notifier).updatePosition(points.single, 12);
      _markSelectedTrackZoomApplied(focusSerial);
      return;
    }

    try {
      final bounds = LatLngBounds.fromPoints(points);
      final cameraFit = CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      );
      _mapController.fitCamera(cameraFit);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref
            .read(mapProvider.notifier)
            .updatePosition(
              _mapController.camera.center,
              _mapController.camera.zoom,
            );
      });
      _markSelectedTrackZoomApplied(focusSerial);
    } catch (_) {
      _mapController.move(points.first, 12);
      ref.read(mapProvider.notifier).updatePosition(points.first, 12);
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
