import 'package:flutter/material.dart';

import '../models/map_search_result.dart';
import '../theme.dart';

class MapSearchResultsList extends StatelessWidget {
  const MapSearchResultsList({
    required this.searchResults,
    required this.searchQuery,
    required this.sort,
    required this.group,
    required this.onSelectResult,
    super.key,
  });

  final List<MapSearchResult> searchResults;
  final String searchQuery;
  final MapSearchSort sort;
  final MapSearchGroup group;
  final ValueChanged<MapSearchResult> onSelectResult;

  @override
  Widget build(BuildContext context) {
    if (searchResults.isNotEmpty) {
      final rows = _rowsForResults();
      return ListView.separated(
        shrinkWrap: true,
        itemCount: rows.length,
        separatorBuilder: (context, index) => thinDivider,
        itemBuilder: (context, index) {
          final row = rows[index];
          return switch (row) {
            _MapSearchGroupHeaderRow(:final label) => Padding(
              key: Key('map-search-group-header-${_headerKeyFor(label)}'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
            _MapSearchResultRow(:final result) => ListTile(
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
            ),
          };
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

  List<_MapSearchRow> _rowsForResults() {
    if (group == MapSearchGroup.none) {
      return searchResults
          .map<_MapSearchRow>((result) => _MapSearchResultRow(result))
          .toList(growable: false);
    }

    final grouped = <String, List<MapSearchResult>>{};
    for (final result in searchResults) {
      final label = _groupLabelFor(result);
      grouped.putIfAbsent(label, () => []).add(result);
    }

    final groupLabels = grouped.keys.toList(growable: false)
      ..sort(_compareLabels);
    final rows = <_MapSearchRow>[];
    for (final label in groupLabels) {
      rows.add(_MapSearchGroupHeaderRow(label));
      final results = List<MapSearchResult>.from(grouped[label]!)
        ..sort((left, right) {
          final comparison = left.normalizedTitle.compareTo(
            right.normalizedTitle,
          );
          if (comparison != 0) {
            return sort == MapSearchSort.nameAscending
                ? comparison
                : -comparison;
          }
          return left.id.compareTo(right.id);
        });
      rows.addAll(results.map<_MapSearchRow>(_MapSearchResultRow.new));
    }
    return rows;
  }

  String _groupLabelFor(MapSearchResult result) {
    return switch (group) {
      MapSearchGroup.none => '',
      MapSearchGroup.region => result.regionName ?? 'Unknown Region',
      MapSearchGroup.type => switch (result.type) {
        MapSearchResultType.peak => 'Peaks',
        MapSearchResultType.track ||
        MapSearchResultType.route => 'Tracks/Routes',
        MapSearchResultType.map => 'Maps',
      },
    };
  }

  int _compareLabels(String left, String right) {
    final comparison = left.toLowerCase().compareTo(right.toLowerCase());
    if (comparison == 0) {
      return 0;
    }
    return sort == MapSearchSort.nameAscending ? comparison : -comparison;
  }

  String _headerKeyFor(String label) {
    return label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }
}

sealed class _MapSearchRow {
  const _MapSearchRow();
}

class _MapSearchGroupHeaderRow extends _MapSearchRow {
  const _MapSearchGroupHeaderRow(this.label);

  final String label;
}

class _MapSearchResultRow extends _MapSearchRow {
  const _MapSearchResultRow(this.result);

  final MapSearchResult result;
}
