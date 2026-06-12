import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/peak_list_visibility.dart';

class MapPeakListsDrawer extends ConsumerWidget {
  const MapPeakListsDrawer({super.key});

  static const _allPeaksLabel = 'All Peaks';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:peakListSelectionMode, :selectedPeakListIds, :peaks) = ref.watch(
      mapProvider.select(
        (state) => (
          peakListSelectionMode: state.peakListSelectionMode,
          selectedPeakListIds: state.selectedPeakListIds,
          peaks: state.peaks,
        ),
      ),
    );
    final peakListsLoadState = ref.watch(peakListsLoadProvider);
    final peakLists = ref.watch(peakListsProvider);
    final visiblePeakLists = <({PeakList peakList, int renderableCount})>[];

    for (final peakList in peakLists) {
      try {
        final renderableCount = renderablePeakCount(peaks: peaks, peakList: peakList);
        if (renderableCount == 0) {
          continue;
        }
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
      child: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Peak Lists',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            KeyedSubtree(
              key: const Key('peak-list-selection-all-peaks-row'),
              child: ListTile(
                key: const Key('peak-list-item-All Peaks'),
                title: const Text(_allPeaksLabel),
                onTap: () {
                  ref.read(mapProvider.notifier).setAllPeaksSelected(
                    peakListSelectionMode != PeakListSelectionMode.allPeaks,
                  );
                },
                leading: IgnorePointer(
                  child: Switch.adaptive(
                    key: const Key('peak-list-selection-all-peaks-switch'),
                    value: peakListSelectionMode == PeakListSelectionMode.allPeaks,
                    onChanged: (_) {},
                  ),
                ),
              ),
            ),
            if (peakListsLoadState.failed)
              const ListTile(
                key: Key('peak-list-selection-unavailable-message'),
                title: Text('Peak lists unavailable'),
                subtitle: Text('Using current selection until lists reload.'),
              )
            else
              for (final entry in visiblePeakLists)
                KeyedSubtree(
                  key: Key(
                    'peak-list-selection-row-${entry.peakList.peakListId}',
                  ),
                  child: ListTile(
                    key: Key('peak-list-item-${entry.peakList.name}'),
                    title: Text(entry.peakList.name),
                    subtitle: Text(_renderablePeakLabel(entry.renderableCount)),
                    onTap: () {
                      ref.read(mapProvider.notifier).togglePeakListSelection(
                        entry.peakList.peakListId,
                      );
                    },
                    leading: IgnorePointer(
                      child: Switch.adaptive(
                        key: Key(
                          'peak-list-selection-switch-${entry.peakList.peakListId}',
                        ),
                        value: peakListSelectionMode ==
                                PeakListSelectionMode.specificList &&
                            selectedPeakListIds.contains(entry.peakList.peakListId),
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  String _renderablePeakLabel(int count) {
    return count == 1
        ? '1 renderable peak'
        : '$count renderable peaks';
  }
}
