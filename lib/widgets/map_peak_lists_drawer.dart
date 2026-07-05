import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/peak_list_colour_resolver.dart';
import 'package:peak_bagger/services/peak_list_visibility.dart';

import '../core/constants.dart';
import '../core/number_formatters.dart';
import '../theme.dart';
import 'drawer_outline_button.dart';
import 'peak_list_control_visual_style.dart';

class MapPeakListsDrawer extends ConsumerWidget {
  const MapPeakListsDrawer({super.key});

  static const _allPeaksLabel = 'All Peaks';
  static const _drawerTrailingButtonWidth = 32.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (
      :peakListSelectionMode,
      :selectedPeakListIds,
      :pinnedPeakListIdsByRegion,
    ) = ref.watch(
      mapProvider.select(
        (state) => (
          peakListSelectionMode: state.peakListSelectionMode,
          selectedPeakListIds: state.selectedPeakListIds,
          pinnedPeakListIdsByRegion: state.pinnedPeakListIdsByRegion,
        ),
      ),
    );
    final visibleRegionKeys = ref.watch(
      mapProvider.select(
        (state) => visibleRegionKeysForBounds(state.visibleBounds),
      ),
    );
    final peakListsLoadState = ref.watch(peakListsLoadProvider);
    final peakLists = ref.watch(peakListsProvider);
    final visiblePeakLists = <({PeakList peakList, int renderableCount})>[];

    for (final peakList in peakLists) {
      if (!peakListAppliesToVisibleRegions(peakList, visibleRegionKeys)) {
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
      ], trailingWidth: _drawerTrailingButtonWidth),
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
                  child: Builder(
                    builder: (context) {
                      final regionKey = canonicalRegionKey(
                        normalizePeakListRegionKey(entry.peakList.region),
                      );
                      final isPinned =
                          regionKey != null &&
                          (pinnedPeakListIdsByRegion[regionKey]?.contains(
                                entry.peakList.peakListId,
                              ) ??
                              false);
                      final controlStyle = peakListControlVisualStyle(
                        context,
                        isSelected:
                            peakListSelectionMode ==
                                PeakListSelectionMode.specificList &&
                            selectedPeakListIds.contains(
                              entry.peakList.peakListId,
                            ),
                        colourValue: resolvePeakListColour(entry.peakList),
                      );

                      return DrawerOutlineButton(
                        buttonKey: Key('peak-list-item-${entry.peakList.name}'),
                        icon: Icons.landscape,
                        label: entry.peakList.name,
                        isSelected:
                            peakListSelectionMode ==
                                PeakListSelectionMode.specificList &&
                            selectedPeakListIds.contains(
                              entry.peakList.peakListId,
                            ),
                        style: controlStyle.buttonStyle,
                        onPressed: () {
                          ref
                              .read(mapProvider.notifier)
                              .togglePeakListSelection(
                                entry.peakList.peakListId,
                              );
                        },
                        trailing: IconButton(
                          key: Key(
                            'peak-list-pin-${entry.peakList.peakListId}',
                          ),
                          iconSize: searchControlIconSize,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: _drawerTrailingButtonWidth,
                            height: 32,
                          ),
                          onPressed: () {
                            final notifier = ref.read(mapProvider.notifier);
                            if (isPinned) {
                              notifier.unpinPeakListForRegion(
                                regionKey: entry.peakList.region,
                                peakListId: entry.peakList.peakListId,
                              );
                            } else {
                              notifier.pinPeakListForRegion(
                                regionKey: entry.peakList.region,
                                peakListId: entry.peakList.peakListId,
                              );
                            }
                          },
                          icon: SvgPicture.asset(
                            isPinned
                                ? 'assets/svg/unpin.svg'
                                : 'assets/svg/pin.svg',
                            width: searchControlIconSize,
                            height: searchControlIconSize,
                            key: Key(
                              isPinned
                                  ? 'peak-list-unpin-icon-${entry.peakList.peakListId}'
                                  : 'peak-list-pin-icon-${entry.peakList.peakListId}',
                            ),
                            colorFilter: ColorFilter.mode(
                              controlStyle.iconColor,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      );
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
    final formattedCount = formatCount(count);
    return count == 1 ? '$formattedCount peak' : '$formattedCount peaks';
  }
}
