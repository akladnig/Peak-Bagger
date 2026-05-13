import 'package:flutter/material.dart';

import '../models/peak.dart';
import '../theme.dart';

class PeakSearchResultsList extends StatelessWidget {
  const PeakSearchResultsList({
    required this.searchResults,
    required this.searchQuery,
    required this.onSelectPeak,
    required this.mapNameForPeak,
    this.selectedPeakId,
    this.itemKeyBuilder,
    super.key,
  });

  final List<Peak> searchResults;
  final String searchQuery;
  final ValueChanged<Peak> onSelectPeak;
  final String Function(Peak peak) mapNameForPeak;
  final int? selectedPeakId;
  final Key? Function(Peak peak)? itemKeyBuilder;

  @override
  Widget build(BuildContext context) {
    if (searchResults.isNotEmpty) {
      return ListView.separated(
        shrinkWrap: true,
        itemCount: searchResults.length,
        separatorBuilder: (context, index) => thinDivider,
        itemBuilder: (context, index) {
          final peak = searchResults[index];
          final isSelected = selectedPeakId == peak.osmId;
          return ListTile(
            key: itemKeyBuilder?.call(peak),
            dense: true,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    peak.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(_heightFor(peak)),
              ],
            ),
            subtitle: Text(mapNameForPeak(peak)),
            selected: isSelected,
            onTap: () => onSelectPeak(peak),
          );
        },
      );
    }

    if (searchQuery.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('No peaks found'),
      );
    }

    return const SizedBox.shrink();
  }

  String _heightFor(Peak peak) {
    return peak.elevation != null
        ? '${peak.elevation!.toStringAsFixed(0)} m'
        : '—';
  }
}
