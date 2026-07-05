import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';

import '../core/constants.dart';
import '../theme.dart';
import 'peak_list_control_visual_style.dart';

class PeakListSelectionSummaryStrip extends StatelessWidget {
  const PeakListSelectionSummaryStrip({super.key, required this.summary});

  final PeakListSelectionSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.chips.isEmpty) {
      return const SizedBox.shrink();
    }

    final chips = [
      for (final chip in summary.chips)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: chip.peakListId == null
              ? _PassivePeakListSelectionChip(chip: chip)
              : _InteractivePeakListSelectionChip(chip: chip),
        ),
    ];

    return KeyedSubtree(
      key: const Key('peak-list-selection-summary'),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(children: chips),
      ),
    );
  }
}

class _PassivePeakListSelectionChip extends StatelessWidget {
  const _PassivePeakListSelectionChip({required this.chip});

  final PeakListSelectionChip chip;

  @override
  Widget build(BuildContext context) {
    final searchButtonTheme = Theme.of(
      context,
    ).extension<SearchButtonThemeData>();
    final key = switch ((chip.isAllPeaks, chip.isNone, chip.peakListId)) {
      (true, _, _) => const Key('peak-list-selection-chip-all-peaks'),
      (_, true, _) => const Key('peak-list-selection-chip-none'),
      (_, _, final int peakListId) => Key(
        'peak-list-selection-chip-$peakListId',
      ),
      _ => null,
    };

    return Semantics(
      button: true,
      selected: true,
      child: IgnorePointer(
        child: OutlinedButton(
          key: key,
          style: searchButtonTheme?.selectedStyle,
          onPressed: () {},
          child: Text(
            chip.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: UiConstants.drawerControlFontSize),
          ),
        ),
      ),
    );
  }
}

class _InteractivePeakListSelectionChip extends ConsumerWidget {
  const _InteractivePeakListSelectionChip({required this.chip});

  final PeakListSelectionChip chip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peakListId = chip.peakListId!;
    final controlStyle = peakListControlVisualStyle(
      context,
      isSelected: chip.isSelected,
      colourValue: chip.colourValue,
      useNeutralStyle: chip.usesNeutralStyle,
    );

    return KeyedSubtree(
      key: Key('peak-list-app-bar-item-$peakListId'),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          KeyedSubtree(
            key: Key('peak-list-app-bar-toggle-$peakListId'),
            child: OutlinedButton(
              key: Key('peak-list-selection-chip-$peakListId'),
              style: controlStyle.buttonStyle,
              onPressed: () {
                ref
                    .read(mapProvider.notifier)
                    .togglePeakListSelection(peakListId);
              },
              child: Padding(
                padding: const EdgeInsets.only(
                  right: searchControlIconSize + 16,
                ),
                child: Text(
                  chip.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: UiConstants.drawerControlFontSize,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 6,
            child: IconButton(
              key: Key(
                chip.isPinned
                    ? 'peak-list-app-bar-unpin-$peakListId'
                    : 'peak-list-app-bar-pin-$peakListId',
              ),
              iconSize: searchControlIconSize,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              onPressed: chip.regionKey == null
                  ? null
                  : () {
                      final notifier = ref.read(mapProvider.notifier);
                      if (chip.isPinned) {
                        notifier.unpinPeakListForRegion(
                          regionKey: chip.regionKey!,
                          peakListId: peakListId,
                        );
                      } else {
                        notifier.pinPeakListForRegion(
                          regionKey: chip.regionKey!,
                          peakListId: peakListId,
                        );
                      }
                    },
              icon: SvgPicture.asset(
                chip.isPinned ? 'assets/svg/unpin.svg' : 'assets/svg/pin.svg',
                width: searchControlIconSize,
                height: searchControlIconSize,
                colorFilter: ColorFilter.mode(
                  controlStyle.iconColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
