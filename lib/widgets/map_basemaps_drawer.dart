import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/map_provider.dart';

import '../core/constants.dart';
import '../services/region_manifest_catalog.dart';
import 'drawer_outline_button.dart';

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
      width: drawerWidthForLabels(
        context,
        regionBasemaps.isEmpty
            ? const ['Basemaps']
            : regionBasemaps.map((basemapData) => basemapData.name),
      ),
      child: ListView(
        padding: const EdgeInsets.all(UiConstants.drawerHorizontalPadding),
        children: [
          const Text(
            'Basemaps',
            style: TextStyle(
              fontSize: UiConstants.drawerTitleFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (regionBasemaps.isEmpty)
            const Text(
              'Basemaps unavailable for this region.',
              key: Key('basemaps-drawer-empty-state'),
              style: TextStyle(fontSize: UiConstants.drawerSupportingFontSize),
            )
          else
            for (final basemapData in regionBasemaps) ...[
              DrawerOutlineButton(
                buttonKey: Key('basemap-option-${basemapData.key}'),
                icon: Icons.map_outlined,
                label: basemapData.name,
                isSelected:
                    basemap ==
                    regionManifestCatalog.basemapEnumByKey(basemapData.key),
                onPressed: () {
                  final selected = regionManifestCatalog.basemapEnumByKey(
                    basemapData.key,
                  );
                  if (selected != null) {
                    ref.read(mapProvider.notifier).setBasemap(selected);
                  }
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}
