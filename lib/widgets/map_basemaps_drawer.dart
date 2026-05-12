import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/map_provider.dart';

class MapBasemapsDrawer extends ConsumerWidget {
  const MapBasemapsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final basemap = ref.watch(mapProvider.select((state) => state.basemap));

    return Drawer(
      key: const Key('basemaps-drawer'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Basemaps',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Tracestrack Topo'),
            trailing: basemap == Basemap.tracestrack
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              ref.read(mapProvider.notifier).setBasemap(Basemap.tracestrack);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('OpenStreetMap'),
            trailing: basemap == Basemap.openstreetmap
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              ref.read(mapProvider.notifier).setBasemap(Basemap.openstreetmap);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('TasMap Topographic'),
            trailing: basemap == Basemap.tasmapTopo
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              ref.read(mapProvider.notifier).setBasemap(Basemap.tasmapTopo);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('TasMap 50k'),
            trailing: basemap == Basemap.tasmap50k
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              ref.read(mapProvider.notifier).setBasemap(Basemap.tasmap50k);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('TasMap 25k'),
            trailing: basemap == Basemap.tasmap25k
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              ref.read(mapProvider.notifier).setBasemap(Basemap.tasmap25k);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
