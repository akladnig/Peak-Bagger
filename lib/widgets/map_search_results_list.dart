import 'package:flutter/material.dart';

import '../models/map_search_result.dart';
import '../theme.dart';

class MapSearchResultsList extends StatelessWidget {
  const MapSearchResultsList({
    required this.searchResults,
    required this.searchQuery,
    required this.onSelectResult,
    super.key,
  });

  final List<MapSearchResult> searchResults;
  final String searchQuery;
  final ValueChanged<MapSearchResult> onSelectResult;

  @override
  Widget build(BuildContext context) {
    if (searchResults.isNotEmpty) {
      return ListView.separated(
        shrinkWrap: true,
        itemCount: searchResults.length,
        separatorBuilder: (context, index) => thinDivider,
        itemBuilder: (context, index) {
          final result = searchResults[index];
          return ListTile(
            key: Key('map-search-result-${result.type.name}-${result.id}'),
            dense: true,
            leading: Icon(_iconFor(result.type)),
            title: Row(
              children: [
                Expanded(
                  child: Text(result.title, overflow: TextOverflow.ellipsis),
                ),
                if (result.trailingText case final trailingText?) ...[
                  const SizedBox(width: 8),
                  Text(trailingText),
                ],
              ],
            ),
            subtitle: Text(result.subtitle),
            onTap: () => onSelectResult(result),
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

  IconData _iconFor(MapSearchResultType type) {
    return switch (type) {
      MapSearchResultType.peak => Icons.landscape,
      MapSearchResultType.track => Icons.hiking,
      MapSearchResultType.route => Icons.route,
      MapSearchResultType.map => Icons.map,
    };
  }
}
