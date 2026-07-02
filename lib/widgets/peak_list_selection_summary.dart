import 'package:flutter/material.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';

class PeakListSelectionSummaryStrip extends StatelessWidget {
  const PeakListSelectionSummaryStrip({
    super.key,
    required this.summary,
  });

  final PeakListSelectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final chip in summary.chips)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _PeakListSelectionChip(chip: chip),
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

class _PeakListSelectionChip extends StatelessWidget {
  const _PeakListSelectionChip({required this.chip});

  final PeakListSelectionChip chip;

  @override
  Widget build(BuildContext context) {
    final key = switch ((chip.isAllPeaks, chip.isNone, chip.peakListId)) {
      (true, _, _) => const Key('peak-list-selection-chip-all-peaks'),
      (_, true, _) => const Key('peak-list-selection-chip-none'),
      (_, _, final int peakListId) => Key('peak-list-selection-chip-$peakListId'),
      _ => null,
    };

    return Chip(
      key: key,
      label: Text(
        chip.label,
        overflow: TextOverflow.ellipsis,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}
