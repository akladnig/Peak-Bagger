import 'package:flutter/material.dart';

import '../models/peak.dart';

class PeakMultiSelectResultsList extends StatelessWidget {
  const PeakMultiSelectResultsList({
    required this.searchResults,
    required this.searchQuery,
    required this.selectedPeakIds,
    required this.onSelectionChanged,
    required this.mapNameForPeak,
    super.key,
  });

  final List<Peak> searchResults;
  final String searchQuery;
  final Set<int> selectedPeakIds;
  final ValueChanged<Set<int>> onSelectionChanged;
  final String Function(Peak peak) mapNameForPeak;

  @override
  Widget build(BuildContext context) {
    final sortedResults = List<Peak>.from(searchResults)
      ..sort((left, right) {
        final nameComparison = left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        );
        if (nameComparison != 0) {
          return nameComparison;
        }
        return left.osmId.compareTo(right.osmId);
      });
    final selectionLimitReached = selectedPeakIds.length >= 50;

    if (sortedResults.isEmpty) {
      if (searchQuery.isNotEmpty) {
        return const Padding(
          padding: EdgeInsets.all(8),
          child: Text('No peaks found'),
        );
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectionLimitReached)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Maximum 50 peaks per save',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        Expanded(
          child: ListView.separated(
            key: const Key('peak-multi-select-scrollable'),
            itemCount: sortedResults.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final peak = sortedResults[index];
              final selected = selectedPeakIds.contains(peak.osmId);
              final canSelect = selected || !selectionLimitReached;
              return _PeakSearchResultRow(
                key: Key('peak-multi-select-row-${peak.osmId}'),
                peak: peak,
                selectedPeakIds: selectedPeakIds,
                selected: selected,
                canToggleSelection: canSelect,
                mapName: mapNameForPeak(peak),
                onSelectionChanged: onSelectionChanged,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PeakSearchResultRow extends StatelessWidget {
  const _PeakSearchResultRow({
    super.key,
    required this.peak,
    required this.selectedPeakIds,
    required this.selected,
    required this.canToggleSelection,
    required this.mapName,
    required this.onSelectionChanged,
  });

  final Peak peak;
  final Set<int> selectedPeakIds;
  final bool selected;
  final bool canToggleSelection;
  final String mapName;
  final ValueChanged<Set<int>> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final checkboxKey = Key('peak-multi-select-checkbox-${peak.osmId}');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            key: checkboxKey,
            value: selected,
            activeColor: Colors.green,
            checkColor: Colors.white,
            onChanged: canToggleSelection ? _toggleSelection : null,
          ),
          Expanded(
            flex: 3,
            child: Text(
              peak.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              _heightLabel(peak.elevation),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              mapName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(bool? value) {
    final next = <int>{...selectedPeakIds};
    if (value ?? false) {
      next.add(peak.osmId);
    } else {
      next.remove(peak.osmId);
    }
    onSelectionChanged(next);
  }

  String _heightLabel(double? elevation) {
    if (elevation == null) {
      return '—';
    }
    return '${elevation.round()}m';
  }
}
