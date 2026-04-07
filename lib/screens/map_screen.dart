import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:peak_bagger/providers/map_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);

    return Scaffold(
      body: Stack(
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
                }
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
                '55G FN 00000 00000',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
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
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'layers',
                  onPressed: () => _showBasemapPanel(context),
                  child: const Icon(Icons.layers),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'mylocation',
                  onPressed: () {},
                  child: const Icon(Icons.near_me),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'goto',
                  onPressed: () {},
                  child: const Icon(Icons.directions),
                ),
              ],
            ),
          ),
        ],
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

  void _showBasemapPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final mapState = ref.watch(mapProvider);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Tracestrack Topo'),
                trailing: mapState.basemap == Basemap.tracestrack
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  ref
                      .read(mapProvider.notifier)
                      .setBasemap(Basemap.tracestrack);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('OpenStreetMap'),
                trailing: mapState.basemap == Basemap.openstreetmap
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  ref
                      .read(mapProvider.notifier)
                      .setBasemap(Basemap.openstreetmap);
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
