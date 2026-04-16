import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/track_hover_detector.dart';
import 'package:peak_bagger/widgets/map_action_rail.dart';
import 'package:peak_bagger/widgets/map_basemaps_drawer.dart';
import 'package:peak_bagger/widgets/tasmap_outline_layer.dart';

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
  bool _isPointerDown = false;
  Offset? _pointerDownPosition;
  Timer? _scrollTimer;
  double _scrollDx = 0;
  double _scrollDy = 0;
  static const _scrollSpeed = 0.001;
  static const _scrollInterval = Duration(milliseconds: 16);

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
    return SystemMouseCursors.grab;
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

  Widget _buildMgrsDisplay(String mgrs) {
    final lines = mgrs.split('\n');
    if (lines.length < 2) {
      return Text(
        mgrs,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }

    final firstLine = lines[0];
    final secondLine = lines[1];
    final parts = secondLine.split(' ');
    if (parts.length < 2) {
      return Text(
        mgrs,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }

    final easting = parts[0];
    final northing = parts[1];

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: [
          TextSpan(text: '$firstLine\n'),
          TextSpan(
            text: easting.substring(0, 3),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: '${easting.substring(3)} '),
          TextSpan(
            text: northing.substring(0, 3),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: northing.substring(3)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);
    ref.watch(tasmapStateProvider.select((state) => state.tasmapRevision));
    final displayMgrs =
        mapState.cursorMgrs ?? mapState.gotoMgrs ?? mapState.currentMgrs;

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
                      key == LogicalKeyboardKey.less ||
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
                notifier.clearHoveredTrack();
              },
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapState.center,
                  initialZoom: mapState.zoom,
                  onSecondaryTap: (tapPosition, point) {
                    ref.read(mapProvider.notifier).centerOnSelectedLocation();
                  },
                  onPointerDown: (event, point) {
                    _mapFocusNode.requestFocus();
                    ref.read(mapProvider.notifier).clearHoveredTrack();
                    setState(() {
                      _isPointerDown = true;
                      _pointerDownPosition = event.localPosition;
                    });
                  },
                  onPointerUp: (event, point) {
                    final moved =
                        _pointerDownPosition != null &&
                        (event.localPosition - _pointerDownPosition!).distance >
                            5;
                    setState(() {
                      _isPointerDown = false;
                      _pointerDownPosition = null;
                    });
                    if (ref.read(mapProvider).showInfoPopup) {
                      ref.read(mapProvider.notifier).toggleInfoPopup();
                    } else if (!moved) {
                      _handleTrackHover(
                        event.localPosition,
                        _mapController.camera.screenOffsetToLatLng(
                          event.localPosition,
                        ),
                        mapState,
                      );
                      ref.read(mapProvider.notifier).setSelectedLocation(point);
                    }
                  },
                  onPointerCancel: (event, point) {
                    setState(() {
                      _isPointerDown = false;
                      _pointerDownPosition = null;
                    });
                    ref.read(mapProvider.notifier).clearHoveredTrack();
                  },
                  onPointerHover: (event, point) {
                    ref.read(mapProvider.notifier).setCursorMgrs(point);
                    _handleTrackHover(event.localPosition, point, mapState);
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
                    urlTemplate: _getTileUrl(mapState.basemap),
                    userAgentPackageName: 'com.peak_bagger.app',
                    tileProvider: NetworkTileProvider(),
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
                  if (mapState.peaks.isNotEmpty && mapState.zoom >= 12)
                    MarkerLayer(
                      markers: mapState.peaks.map((peak) {
                        return Marker(
                          point: LatLng(peak.latitude, peak.longitude),
                          width: 20,
                          height: 20,
                          child: Icon(
                            Icons.change_history,
                            color: const Color(0xFFB22222),
                            size: 16,
                          ),
                        );
                      }).toList(),
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
                  if (mapState.selectedMap != null)
                    _buildMapRectangle(mapState.selectedMap!),
                  if (mapState.showMapOverlay)
                    PolygonLayer(
                      key: const Key('tasmap-overlay-layer'),
                      polygons: _buildAllMapRectangles(),
                    ),
                  if (mapState.showTracks)
                    _buildTrackPolylines(mapState.tracks, mapState.zoom),
                ],
              ),
            ),
            const MapActionRail(),
            Positioned(
              left: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: _buildMgrsDisplay(displayMgrs),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'zoom: ${mapState.zoom.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            if (mapState.showPeakSearch)
              Positioned(
                right: 72,
                top: 16,
                child: Card(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 30 * 8.0,
                              child: TextField(
                                focusNode: _searchFocusNode,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Search peaks',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.search, size: 20),
                                ),
                                onChanged: (value) {
                                  ref
                                      .read(mapProvider.notifier)
                                      .searchPeaks(value);
                                },
                                onSubmitted: (_) {
                                  ref
                                      .read(mapProvider.notifier)
                                      .selectAllSearchResults();
                                  _searchFocusNode.unfocus();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchFocusNode.unfocus();
                                ref
                                    .read(mapProvider.notifier)
                                    .setPeakSearchVisible(false);
                              },
                            ),
                          ],
                        ),
                      ),
                      if (mapState.searchResults.isNotEmpty)
                        SizedBox(
                          width: 30 * 8.0,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: mapState.searchResults.length,
                            itemBuilder: (context, index) {
                              final peak = mapState.searchResults[index];
                              return ListTile(
                                dense: true,
                                title: Text(peak.name),
                                subtitle: Text(
                                  peak.elevation != null
                                      ? '${peak.elevation!.toStringAsFixed(0)}m'
                                      : 'Unknown',
                                ),
                                onTap: () {
                                  ref
                                      .read(mapProvider.notifier)
                                      .centerOnPeak(peak);
                                  ref
                                      .read(mapProvider.notifier)
                                      .setPeakSearchVisible(false);
                                  ref.read(mapProvider.notifier).clearSearch();
                                },
                              );
                            },
                          ),
                        ),
                      if (mapState.searchQuery.isNotEmpty &&
                          mapState.searchResults.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('No peaks found'),
                        ),
                    ],
                  ),
                ),
              ),
            if (mapState.showGotoInput)
              Positioned(
                right: 72,
                top: 16,
                child: Card(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 30 * 8.0,
                              child: CallbackShortcuts(
                                bindings: {
                                  const SingleActivator(LogicalKeyboardKey.tab):
                                      _handleGotoTab,
                                },
                                child: TextField(
                                  key: const Key('goto-map-input'),
                                  focusNode: _gotoFocusNode,
                                  controller: _gotoController,
                                  decoration: InputDecoration(
                                    hintText: 'Go to location',
                                    isDense: true,
                                    border: const OutlineInputBorder(),
                                    errorText: _gotoError,
                                  ),
                                  onChanged: (value) {
                                    if (_gotoError != null) {
                                      setState(() => _gotoError = null);
                                    }
                                    ref
                                        .read(mapProvider.notifier)
                                        .parseGridReference(value);
                                  },
                                  onSubmitted: (_) {
                                    _handleGotoSubmit(ref.read(mapProvider));
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              key: const Key('goto-map-close'),
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                ref.read(mapProvider.notifier).clearGotoMgrs();
                                ref
                                    .read(mapProvider.notifier)
                                    .setGotoInputVisible(false);
                                _gotoController.clear();
                              },
                            ),
                            IconButton(
                              key: const Key('goto-map-submit'),
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: _navigateToGridReference,
                            ),
                          ],
                        ),
                      ),
                      if (mapState.mapSuggestions.isNotEmpty)
                        SizedBox(
                          width: 30 * 8.0,
                          height: 150,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: mapState.mapSuggestions.length,
                            itemBuilder: (context, index) {
                              final map = mapState.mapSuggestions[index];
                              return ListTile(
                                dense: true,
                                title: Text(map.name),
                                subtitle: Text(map.series),
                                onTap: () {
                                  _gotoController.text = map.name;
                                  ref.read(mapProvider.notifier).selectMap(map);
                                  _zoomToMapExtent(map);
                                  ref
                                      .read(mapProvider.notifier)
                                      .setGotoInputVisible(false);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (mapState.showInfoPopup)
              Positioned(
                left: MediaQuery.of(context).size.width / 2 + 16,
                top: MediaQuery.of(context).size.height / 2 - 50,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.map, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              mapState.infoMapName ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                ref
                                    .read(mapProvider.notifier)
                                    .toggleInfoPopup();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        if (mapState.infoMgrs != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            mapState.infoMgrs!,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                        if (mapState.infoPeakName != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.terrain, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                mapState.infoPeakName!,
                                style: const TextStyle(fontSize: 13),
                              ),
                              if (mapState.infoPeakElevation != null) ...[
                                const Text(' '),
                                Text(
                                  '${mapState.infoPeakElevation!.toStringAsFixed(0)}m',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        ],
                        if (mapState.hasTrackRecoveryIssue) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'Some tracks need to be rebuilt.',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ] else if (mapState.tracks.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.route, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                '${mapState.tracks.length} tracks available',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getTileUrl(Basemap basemap) {
    switch (basemap) {
      case Basemap.tracestrack:
        return 'https://tile.tracestrack.com/topo__/{z}/{x}/{y}.webp?key=8bd67b17be9041b60f241c2aa45ecf0d';
      case Basemap.openstreetmap:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  Widget _buildMapRectangle(Tasmap50k map) {
    final repo = ref.read(tasmapRepositoryProvider);
    final points = repo.getMapPolygonPoints(map);
    if (points.length < 4) {
      return const SizedBox.shrink();
    }

    return TasmapOutlineLayer(
      key: const Key('tasmap-outline-layer'),
      points: points,
    );
  }

  List<Polygon> _buildAllMapRectangles() {
    final repo = ref.read(tasmapRepositoryProvider);
    final maps = repo.getAllMaps();
    final polygons = <Polygon>[];

    for (final map in maps) {
      final points = repo.getMapPolygonPoints(map);
      if (points.length < 4) {
        continue;
      }

      polygons.add(
        Polygon(
          points: points,
          color: Colors.transparent,
          borderColor: Colors.blue,
          borderStrokeWidth: 2,
        ),
      );
    }

    return polygons;
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

  void _zoomToMapExtent(Tasmap50k map) {
    final repo = ref.read(tasmapRepositoryProvider);
    final bounds = repo.getMapBounds(map);
    if (bounds == null) {
      final center = repo.getMapCenter(map);
      if (center != null) {
        _mapController.move(center, 12);
      }
      return;
    }

    try {
      final cameraFit = CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      );
      _mapController.fitCamera(cameraFit);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final newCenter = _mapController.camera.center;
        final newZoom = _mapController.camera.zoom;
        ref.read(mapProvider.notifier).updatePosition(newCenter, newZoom);
      });
    } catch (e) {
      final center = repo.getMapCenter(map);
      if (center != null) {
        _mapController.move(center, 12);
      }
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

  PolylineLayer _buildTrackPolylines(List<GpxTrack> tracks, double zoom) {
    final polylines = <Polyline>[];
    final displayZoom = zoom.round().clamp(6, 18);

    for (final track in tracks) {
      try {
        for (final segment in track.getSegmentsForZoom(displayZoom)) {
          if (segment.isEmpty) continue;
          polylines.add(
            Polyline(
              points: segment,
              color: Color(track.trackColour),
              strokeWidth: 3.0,
            ),
          );
        }
      } catch (e) {
        // Skip malformed track
      }
    }

    return PolylineLayer(polylines: polylines);
  }
}
