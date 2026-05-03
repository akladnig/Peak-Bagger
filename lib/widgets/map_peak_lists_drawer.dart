import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/map_provider.dart';

class MapPeakListsDrawer extends ConsumerWidget {
  const MapPeakListsDrawer({super.key});

  static const _noneLabel = 'None';
  static const _allPeaksLabel = 'All Peaks';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapProvider);

    return Drawer(
      key: const Key('peak-lists-drawer'),
      child: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Peak Lists',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            key: const Key('peak-list-item-None'),
            title: const Text(_noneLabel),
            trailing: mapState.peakListSelectionMode == PeakListSelectionMode.none
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              ref.read(mapProvider.notifier).selectPeakList(
                PeakListSelectionMode.none,
              );
              Navigator.pop(context);
            },
          ),
          ListTile(
            key: const Key('peak-list-item-All Peaks'),
            title: const Text(_allPeaksLabel),
            trailing:
                mapState.peakListSelectionMode == PeakListSelectionMode.allPeaks
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              ref.read(mapProvider.notifier).selectPeakList(
                PeakListSelectionMode.allPeaks,
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
