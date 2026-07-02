import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/peak_list_visibility.dart';

import '../core/constants.dart';
import '../services/region_manifest_catalog.dart';
import 'drawer_outline_button.dart';

class MapPeakListsDrawer extends ConsumerWidget {
  const MapPeakListsDrawer({super.key});

  static const _allPeaksLabel = 'All Peaks';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:peakListSelectionMode, :selectedPeakListIds) = ref.watch(
      mapProvider.select(
        (state) => (
          peakListSelectionMode: state.peakListSelectionMode,
          selectedPeakListIds: state.selectedPeakListIds,
        ),
      ),
    );
    final currentRegionKey = ref.watch(
      mapProvider.select(
        (state) => regionManifestCatalog.regionKeyForPoint(state.center),
      ),
    );
    final peakListsLoadState = ref.watch(peakListsLoadProvider);
    final peakLists = ref.watch(peakListsProvider);
    final visiblePeakLists = <({PeakList peakList, int renderableCount})>[];

    for (final peakList in peakLists) {
      if (!peakListAppliesToRegion(peakList, currentRegionKey)) {
        continue;
      }

      try {
        final itemCount = decodePeakListItems(peakList.peakList).length;
        visiblePeakLists.add((peakList: peakList, renderableCount: itemCount));
      } catch (_) {
        continue;
      }
    }
    visiblePeakLists.sort(
      (left, right) => left.peakList.name.toLowerCase().compareTo(
        right.peakList.name.toLowerCase(),
      ),
    );

    return Drawer(
      key: const Key('peak-lists-drawer'),
      width: drawerWidthForLabels(context, [
        _allPeaksLabel,
        ...visiblePeakLists.map((entry) => entry.peakList.name),
      ]),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(UiConstants.drawerHorizontalPadding),
          children: [
            const Text(
              'Peak Lists',
              style: TextStyle(
                fontSize: UiConstants.drawerTitleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: const Key('peak-list-selection-all-peaks-row'),
              child: DrawerOutlineButton(
                buttonKey: const Key('peak-list-item-All Peaks'),
                icon: Icons.landscape,
                label: _allPeaksLabel,
                isSelected:
                    peakListSelectionMode == PeakListSelectionMode.allPeaks,
                onPressed: () {
                  ref
                      .read(mapProvider.notifier)
                      .setAllPeaksSelected(
                        peakListSelectionMode != PeakListSelectionMode.allPeaks,
                      );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (peakListsLoadState.failed)
              const ListTile(
                key: Key('peak-list-selection-unavailable-message'),
                title: Text(
                  'Peak lists unavailable',
                  style: TextStyle(fontSize: UiConstants.drawerControlFontSize),
                ),
                subtitle: Text(
                  'Using current selection until lists reload.',
                  style: TextStyle(
                    fontSize: UiConstants.drawerSupportingFontSize,
                  ),
                ),
              )
            else
              for (final entry in visiblePeakLists) ...[
                KeyedSubtree(
                  key: Key(
                    'peak-list-selection-row-${entry.peakList.peakListId}',
                  ),
                  child: DrawerOutlineButton(
                    buttonKey: Key('peak-list-item-${entry.peakList.name}'),
                    icon: Icons.landscape,
                    label: entry.peakList.name,
                    isSelected:
                        peakListSelectionMode ==
                            PeakListSelectionMode.specificList &&
                        selectedPeakListIds.contains(entry.peakList.peakListId),
                    onPressed: () {
                      ref
                          .read(mapProvider.notifier)
                          .togglePeakListSelection(entry.peakList.peakListId);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: Text(
                    _renderablePeakLabel(entry.renderableCount),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: UiConstants.drawerSupportingFontSize,
                    ),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  String _renderablePeakLabel(int count) {
    return count == 1 ? '1 peak' : '$count peaks';
  }
}
