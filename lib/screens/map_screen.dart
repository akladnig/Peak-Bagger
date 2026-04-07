import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/providers/map_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final MapController _mapController;
  bool _showGotoInput = false;
  final _gotoController = TextEditingController();
  String? _gotoError;
  String _cursorMgrs = '';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _gotoController.dispose();
    super.dispose();
  }

  String _convertToMgrs(LatLng location) {
    try {
      final mgrsString = mgrs.Mgrs.forward([
        location.longitude,
        location.latitude,
      ], 5);
      if (mgrsString.length >= 5) {
        return '${mgrsString.substring(0, 5)}\n${mgrsString.substring(5)}';
      }
      return mgrsString;
    } catch (e) {
      return 'Invalid';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);
    final displayMgrs = mapState.gotoMgrs ?? mapState.currentMgrs;

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
                  key == LogicalKeyboardKey.comma ||
                  key == LogicalKeyboardKey.less ||
                  key == LogicalKeyboardKey.add) {
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                );
              } else {
                _mapController.move(
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
              setState(() => _showGotoInput = !_showGotoInput);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: mapState.center,
                initialZoom: mapState.zoom,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    ref
                        .read(mapProvider.notifier)
                        .updatePosition(position.center, position.zoom);
                    setState(() {
                      _cursorMgrs = _convertToMgrs(position.center);
                    });
                  }
                },
                onTap: (tapPosition, point) {
                  ref.read(mapProvider.notifier).centerOnLocation(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _getTileUrl(mapState.basemap),
                  userAgentPackageName: 'com.peak_bagger.app',
                ),
              ],
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
                child: Text(
                  displayMgrs,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
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
            if (_cursorMgrs.isNotEmpty && _cursorMgrs != mapState.currentMgrs)
              Positioned(
                left: 16,
                bottom: 50,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _cursorMgrs,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            if (_showGotoInput)
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
                            _gotoController.clear();
                            setState(() {
                              _showGotoInput = false;
                              _gotoError = null;
                            });
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
      setState(() => _showGotoInput = false);
    }
  }

  void _moveMap(double dx, double dy) {
    final center = _mapController.camera.center;
    _mapController.move(
      LatLng(center.latitude + dy, center.longitude + dx),
      _mapController.camera.zoom,
    );
  }

  void _goToCurrentLocation() {
    // TODO: Implement GPS location
  }
}
