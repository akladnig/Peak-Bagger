import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';

class MapPeakListsDrawer extends ConsumerWidget {
  const MapPeakListsDrawer({super.key});

  static const _noneLabel = 'None';
  static const _allPeaksLabel = 'All Peaks';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:peakListSelectionMode, :selectedPeakListId, :peaks) = ref.watch(
      mapProvider.select(
        (state) => (
          peakListSelectionMode: state.peakListSelectionMode,
          selectedPeakListId: state.selectedPeakListId,
          peaks: state.peaks,
        ),
      ),
    );
    final peakLists = ref.watch(peakListsProvider);
    final renderablePeakIds = peaks
        .map((peak) => peak.osmId)
        .toSet();
    final visiblePeakLists = <({PeakList peakList, int renderableCount})>[];

    for (final peakList in peakLists) {
      try {
        final items = decodePeakListItems(peakList.peakList);
        final renderableCount = items
            .map((item) => item.peakOsmId)
            .where(renderablePeakIds.contains)
            .toSet()
            .length;
        visiblePeakLists.add((
          peakList: peakList,
          renderableCount: renderableCount,
        ));
      } catch (error, stackTrace) {
        developer.log(
          'Skipping invalid peak list ${peakList.peakListId} in drawer.',
          error: error,
          stackTrace: stackTrace,
          name: 'map_peak_lists_drawer',
        );
      }
    }
    visiblePeakLists.sort(
      (left, right) => left.peakList.name.toLowerCase().compareTo(
        right.peakList.name.toLowerCase(),
      ),
    );

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
            trailing: peakListSelectionMode == PeakListSelectionMode.none
                ? const Icon(Icons.check)
                : null,
            onTap: () {
              ref.read(mapProvider.notifier).selectPeakList(
                PeakListSelectionMode.none,
              );
              Navigator.pop(context);
            },
          ),
          for (final entry in visiblePeakLists)
            ListTile(
              key: Key('peak-list-item-${entry.peakList.name}'),
              title: Text(entry.peakList.name),
              subtitle: Text(_renderablePeakLabel(entry.renderableCount)),
              trailing: peakListSelectionMode ==
                          PeakListSelectionMode.specificList &&
                      selectedPeakListId == entry.peakList.peakListId
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                ref.read(mapProvider.notifier).selectPeakList(
                  PeakListSelectionMode.specificList,
                  peakListId: entry.peakList.peakListId,
                );
                Navigator.pop(context);
              },
            ),
          ListTile(
            key: const Key('peak-list-item-All Peaks'),
            title: const Text(_allPeaksLabel),
            trailing:
                peakListSelectionMode == PeakListSelectionMode.allPeaks
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

  String _renderablePeakLabel(int count) {
    return count == 1
        ? '1 renderable peak'
        : '$count renderable peaks';
  }
}
