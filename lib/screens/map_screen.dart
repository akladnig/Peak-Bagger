import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/models/peak.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final MapController _mapController;
  final _gotoController = TextEditingController();
  String? _gotoError;
  bool _isPointerDown = false;
  Offset? _pointerDownPosition;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
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
    });

    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.equal ||
                key == LogicalKeyboardKey.comma ||
                key == LogicalKeyboardKey.period ||
                key == LogicalKeyboardKey.less ||
                key == LogicalKeyboardKey.add ||
                key == LogicalKeyboardKey.minus ||
                key == LogicalKeyboardKey.greater) {
              if (key == LogicalKeyboardKey.equal ||
                  key == LogicalKeyboardKey.period ||
                  key == LogicalKeyboardKey.less ||
                  key == LogicalKeyboardKey.add) {
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                );
                ref
                    .read(mapProvider.notifier)
                    .updatePosition(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
              } else {
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1,
                );
                ref
                    .read(mapProvider.notifier)
                    .updatePosition(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
              }
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyK ||
                key == LogicalKeyboardKey.arrowUp) {
              _moveMap(0, -0.1);
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyJ ||
                key == LogicalKeyboardKey.arrowDown) {
              _moveMap(0, 0.1);
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyH ||
                key == LogicalKeyboardKey.arrowLeft) {
              _moveMap(-0.1, 0);
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyL ||
                key == LogicalKeyboardKey.arrowRight) {
              _moveMap(0.1, 0);
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyS) {
              _goToCurrentLocation();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyG) {
              ref.read(mapProvider.notifier).toggleGotoInput();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyB) {
              Scaffold.of(context).openEndDrawer();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.keyC) {
              ref.read(mapProvider.notifier).centerOnSelectedLocation();
              return KeyEventResult.handled;
            }
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
                    if (!moved) {
                      ref.read(mapProvider.notifier).setSelectedLocation(point);
                    }
                  },
                  onPointerHover: (event, point) {
                    ref.read(mapProvider.notifier).setCursorMgrs(point);
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
                left: 16,
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
                            Expanded(
                              child: TextField(
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
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                ref
                                    .read(mapProvider.notifier)
                                    .setPeakSearchVisible(false);
                              },
                            ),
                          ],
                        ),
                      ),
                      if (mapState.searchResults.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
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
                left: 16,
                right: 72,
                top: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _gotoController,
                            decoration: InputDecoration(
                              hintText: 'Go to location',
                              isDense: true,
                              border: const OutlineInputBorder(),
                              errorText: _gotoError,
                            ),
                            onChanged: (_) {
                              if (_gotoError != null) {
                                setState(() => _gotoError = null);
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

  void _navigateToGridReference() {
    final input = _gotoController.text.trim();
    if (input.isEmpty) return;

    final (location, error) = ref
        .read(mapProvider.notifier)
        .parseGridReference(input);

    if (error != null) {
      setState(() => _gotoError = error);
    } else if (location != null) {
      _mapController.move(location, 15);
      ref.read(mapProvider.notifier).centerOnLocation(location);
      ref.read(mapProvider.notifier).setGotoInputVisible(false);
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
