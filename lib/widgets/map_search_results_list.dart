import 'package:flutter/material.dart';

import '../core/constants.dart';

import '../models/map_search_result.dart';
import '../theme.dart';

class MapSearchResultsList extends StatefulWidget {
  const MapSearchResultsList({
    required this.searchResults,
    required this.isLoadingMore,
    required this.isExhausted,
    required this.searchQuery,
    required this.sort,
    required this.group,
    required this.onLoadMore,
    required this.onSelectResult,
    super.key,
  });

  final List<MapSearchResult> searchResults;
  final bool isLoadingMore;
  final bool isExhausted;
  final String searchQuery;
  final MapSearchSort sort;
  final MapSearchGroup group;
  final VoidCallback onLoadMore;
  final ValueChanged<MapSearchResult> onSelectResult;

  @override
  State<MapSearchResultsList> createState() => _MapSearchResultsListState();
}

class _MapSearchResultsListState extends State<MapSearchResultsList> {
  static const _loadMoreThreshold = 120.0;

  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    _maybeLoadMore(notification.metrics);
    return false;
  }

  void _maybeLoadMore(ScrollMetrics metrics) {
    if (widget.isLoadingMore ||
        widget.isExhausted ||
        widget.searchResults.isEmpty ||
        widget.searchQuery.trim().length <
            MapConstants.searchPopupMinimumQueryLength) {
      return;
    }
    final remaining = metrics.maxScrollExtent - metrics.pixels;
    if (remaining <= _loadMoreThreshold) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmedQuery = widget.searchQuery.trim();
    if (widget.searchResults.isNotEmpty) {
      final rows = _rowsForResults();
      return NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: ListView.separated(
          key: const Key('map-search-results-list'),
          controller: _scrollController,
          shrinkWrap: true,
          itemCount: rows.length + (widget.isLoadingMore ? 1 : 0),
          separatorBuilder: (context, index) => thinDivider,
          itemBuilder: (context, index) {
            if (index >= rows.length) {
              return const Padding(
                key: Key('map-search-loading-more'),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Loading more...'),
                  ],
                ),
              );
            }

            final row = rows[index];
            return switch (row) {
              _MapSearchGroupHeaderRow(:final label) => Padding(
                key: Key('map-search-group-header-${_headerKeyFor(label)}'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              _MapSearchResultRow(:final result) => ListTile(
                key: Key('map-search-result-${result.type.name}-${result.id}'),
                dense: true,
                leading: Icon(_iconFor(result.type)),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        result.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (result.trailingText case final trailingText?) ...[
                      const SizedBox(width: 8),
                      Text(trailingText),
                    ],
                  ],
                ),
                subtitle: Text(result.subtitle),
                onTap: () => widget.onSelectResult(result),
              ),
            };
          },
        ),
      );
    }

    if (trimmedQuery.isEmpty) {
      return const SizedBox.shrink();
    }

    if (trimmedQuery.length < MapConstants.searchPopupMinimumQueryLength) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Type at least ${MapConstants.searchPopupMinimumQueryLength} characters',
        ),
      );
    }

    if (trimmedQuery.isNotEmpty) {
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
    if (widget.group == MapSearchGroup.none) {
      return widget.searchResults
          .map<_MapSearchRow>((result) => _MapSearchResultRow(result))
          .toList(growable: false);
    }

    final grouped = <String, List<MapSearchResult>>{};
    for (final result in widget.searchResults) {
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
            return widget.sort == MapSearchSort.nameAscending
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
    return switch (widget.group) {
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
    return widget.sort == MapSearchSort.nameAscending
        ? comparison
        : -comparison;
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
