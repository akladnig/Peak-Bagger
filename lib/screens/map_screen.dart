import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'dart:async';
import 'package:peak_bagger/providers/map_provider.dart';

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
    final displayMgrs =
        mapState.cursorMgrs ?? mapState.gotoMgrs ?? mapState.currentMgrs;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mapState.syncEnabled &&
          _mapController.camera.center != mapState.center) {
        _mapController.move(mapState.center, mapState.zoom);
      }
      if (mapState.showPeakSearch && !_searchFocusNode.hasFocus) {
        _searchFocusNode.requestFocus();
      }
      if (mapState.showGotoInput && !_gotoFocusNode.hasFocus) {
        _gotoFocusNode.requestFocus();
      }
    });

    return Scaffold(
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
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            MouseRegion(
              cursor: _isPointerDown
                  ? SystemMouseCursors.grabbing
                  : SystemMouseCursors.grab,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapState.center,
                  initialZoom: mapState.zoom,
                  onSecondaryTap: (tapPosition, point) {
                    ref.read(mapProvider.notifier).centerOnSelectedLocation();
                  },
                  onPointerDown: (event, point) {
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
                      ref.read(mapProvider.notifier).setSelectedLocation(point);
                    }
                  },
                  onPointerHover: (event, point) {
                    ref.read(mapProvider.notifier).setCursorMgrs(point);
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
                    PolygonLayer(polygons: _buildAllMapRectangles()),
                ],
              ),
            ),
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
                              child: TextField(
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
                                  final mapState = ref.read(mapProvider);
                                  if (mapState.selectedMap != null &&
                                      mapState.mapSuggestions.isEmpty) {
                                    _zoomToMapExtent(mapState.selectedMap!);
                                    ref
                                        .read(mapProvider.notifier)
                                        .setGotoInputVisible(false);
                                  }
                                },
                                onSubmitted: (_) {
                                  if (_gotoError == null) {
                                    _navigateToGridReference();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
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

  PolygonLayer _buildMapRectangle(Tasmap50k map) {
    if (map.tl.isEmpty || map.tr.isEmpty || map.bl.isEmpty || map.br.isEmpty) {
      return const PolygonLayer(polygons: []);
    }

    try {
      final tl = _cornerToLatLng(map.tl);
      final tr = _cornerToLatLng(map.tr);
      final bl = _cornerToLatLng(map.bl);
      final br = _cornerToLatLng(map.br);

      if (tl == null || tr == null || bl == null || br == null) {
        return const PolygonLayer(polygons: []);
      }

      final minLat = [
        tl,
        tr,
        bl,
        br,
      ].map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
      final maxLat = [
        tl,
        tr,
        bl,
        br,
      ].map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
      final minLng = [
        tl,
        tr,
        bl,
        br,
      ].map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
      final maxLng = [
        tl,
        tr,
        bl,
        br,
      ].map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

      final points = <LatLng>[
        LatLng(minLat, minLng),
        LatLng(minLat, maxLng),
        LatLng(maxLat, maxLng),
        LatLng(maxLat, minLng),
      ];

      return PolygonLayer(
        polygons: [
          Polygon(
            points: points,
            color: Colors.blue.withValues(alpha: 0.1),
            borderColor: Colors.blue,
            borderStrokeWidth: 2,
          ),
        ],
      );
    } catch (e) {
      return const PolygonLayer(polygons: []);
    }
  }

  LatLng? _cornerToLatLng(String corner) {
    if (corner.length != 12) return null;
    final fullMgrs = '55G$corner';
    try {
      final coords = mgrs.Mgrs.toPoint(fullMgrs);
      return LatLng(coords[1], coords[0]);
    } catch (e) {
      return null;
    }
  }

  List<Polygon> _buildAllMapRectangles() {
    final repo = ref.read(tasmapRepositoryProvider);
    final maps = repo.getAllMaps();
    final polygons = <Polygon>[];

    for (final map in maps) {
      if (map.tl.isEmpty ||
          map.tr.isEmpty ||
          map.bl.isEmpty ||
          map.br.isEmpty) {
        continue;
      }

      try {
        final tl = _cornerToLatLng(map.tl);
        final tr = _cornerToLatLng(map.tr);
        final bl = _cornerToLatLng(map.bl);
        final br = _cornerToLatLng(map.br);

        if (tl == null || tr == null || bl == null || br == null) continue;

        final minLat = [
          tl,
          tr,
          bl,
          br,
        ].map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
        final maxLat = [
          tl,
          tr,
          bl,
          br,
        ].map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
        final minLng = [
          tl,
          tr,
          bl,
          br,
        ].map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
        final maxLng = [
          tl,
          tr,
          bl,
          br,
        ].map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

        polygons.add(
          Polygon(
            points: [
              LatLng(minLat, minLng),
              LatLng(minLat, maxLng),
              LatLng(maxLat, maxLng),
              LatLng(maxLat, minLng),
            ],
            color: Colors.blue.withValues(alpha: 0.1),
            borderColor: Colors.blue,
            borderStrokeWidth: 2,
          ),
        );
      } catch (e) {
        continue;
      }
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
      } else {
        _mapController.move(location, 15);
        ref.read(mapProvider.notifier).centerOnLocation(location);
      }
      ref.read(mapProvider.notifier).setGotoInputVisible(false);
    }
  }

  void _zoomToMapExtent(Tasmap50k map) {
    final mgrsCodes = map.mgrs100kIdList;
    if (mgrsCodes.isEmpty) {
      _mapController.move(_mapController.camera.center, 15);
      return;
    }

    try {
      final allPoints = <LatLng>[];
      final isWrapAround = map.northingMax < map.northingMin;

      for (int i = 0; i < mgrsCodes.length; i++) {
        final mgrsCode = mgrsCodes[i];
        int nMin, nMax;

        if (isWrapAround && mgrsCodes.length == 2) {
          if (i == 0) {
            nMin = map.northingMin;
            nMax = 99999;
          } else {
            nMin = 0;
            nMax = map.northingMax;
          }
        } else {
          nMin = map.northingMin;
          nMax = map.northingMax;
        }

        final eMinPad = map.eastingMin.toString().padLeft(5, '0');
        final nMinPad = nMin.toString().padLeft(5, '0');
        final eMaxPad = map.eastingMax.toString().padLeft(5, '0');
        final nMaxPad = nMax.toString().padLeft(5, '0');

        final mgrsSw = '55G${mgrsCode.substring(0, 2)} $eMinPad $nMinPad';
        final mgrsNe = '55G${mgrsCode.substring(0, 2)} $eMaxPad $nMaxPad';

        final pSw = mgrs.Mgrs.toPoint(mgrsSw);
        final pNe = mgrs.Mgrs.toPoint(mgrsNe);

        final sw = LatLng(pSw[1], pSw[0]);
        final ne = LatLng(pNe[1], pNe[0]);

        allPoints.addAll([sw, ne]);
      }

      if (allPoints.isEmpty) {
        _mapController.move(_mapController.camera.center, 15);
        return;
      }

      final minLat = allPoints
          .map((p) => p.latitude)
          .reduce((a, b) => a < b ? a : b);
      final maxLat = allPoints
          .map((p) => p.latitude)
          .reduce((a, b) => a > b ? a : b);
      final minLng = allPoints
          .map((p) => p.longitude)
          .reduce((a, b) => a < b ? a : b);
      final maxLng = allPoints
          .map((p) => p.longitude)
          .reduce((a, b) => a > b ? a : b);

      final sw = LatLng(minLat, minLng);
      final ne = LatLng(maxLat, maxLng);

      final bounds = LatLngBounds(sw, ne);
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
      _mapController.move(_mapController.camera.center, 15);
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
}
