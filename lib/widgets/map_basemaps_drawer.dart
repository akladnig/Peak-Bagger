import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/map_provider.dart';

class MapBasemapsDrawer extends ConsumerWidget {
  const MapBasemapsDrawer({super.key, required this.basemapKeys});

  final List<String> basemapKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final basemap = ref.watch(mapProvider.select((state) => state.basemap));
    final regionBasemaps = basemapKeys
        .map(regionManifestCatalog.basemapByKey)
        .whereType<RegionManifestBasemapData>()
        .toList(growable: false);

    return Drawer(
      key: const Key('basemaps-drawer'),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Basemaps',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (regionBasemaps.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Basemaps unavailable for this region.',
                key: Key('basemaps-drawer-empty-state'),
              ),
            )
          else
            for (final basemapData in regionBasemaps)
              ListTile(
                key: Key('basemap-option-${basemapData.key}'),
                leading: const Icon(Icons.map_outlined),
                title: Text(basemapData.name),
                trailing:
                    basemap ==
                        regionManifestCatalog.basemapEnumByKey(basemapData.key)
                    ? const Icon(Icons.check)
                    : null,
                onTap: () {
                  final selected = regionManifestCatalog.basemapEnumByKey(
                    basemapData.key,
                  );
                  if (selected != null) {
                    ref.read(mapProvider.notifier).setBasemap(selected);
                  }
                  Navigator.pop(context);
                },
              ),
        ],
      ),
    );
  }
}
