import 'package:flutter/material.dart';

import '../core/number_formatters.dart';
import '../models/peak.dart';
import '../theme.dart';

class MapSearchResultsList extends StatelessWidget {
  const MapSearchResultsList({
    required this.searchResults,
    required this.searchQuery,
    required this.onSelectPeak,
    required this.mapNameForPeak,
    super.key,
  });

  final List<Peak> searchResults;
  final String searchQuery;
  final ValueChanged<Peak> onSelectPeak;
  final String Function(Peak peak) mapNameForPeak;

  @override
  Widget build(BuildContext context) {
    if (searchResults.isNotEmpty) {
      return ListView.separated(
        shrinkWrap: true,
        itemCount: searchResults.length,
        separatorBuilder: (context, index) => thinDivider,
        itemBuilder: (context, index) {
          final peak = searchResults[index];
          return ListTile(
            key: Key('map-search-result-peak-${peak.osmId}'),
            dense: true,
            leading: const Icon(Icons.landscape),
            title: Row(
              children: [
                Expanded(
                  child: Text(peak.name, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text(_heightFor(peak)),
              ],
            ),
            subtitle: Text(mapNameForPeak(peak)),
            onTap: () => onSelectPeak(peak),
          );
        },
      );
    }

    if (searchQuery.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('No results found'),
      );
    }

    return const SizedBox.shrink();
  }

  String _heightFor(Peak peak) {
    return peak.elevation != null
        ? formatElevation(peak.elevation!.round())
        : '—';
  }
}
