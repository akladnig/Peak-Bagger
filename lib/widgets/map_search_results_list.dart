import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';

import '../models/map_search_result.dart';
import '../theme.dart';

class MapSearchResultsList extends StatefulWidget {
  const MapSearchResultsList({
    required this.searchResults,
    required this.isLoadingMore,
    required this.isExhausted,
    required this.searchQuery,
    required this.isTrackDateRangeActive,
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
  final bool isTrackDateRangeActive;
  final MapSearchSort sort;
  final MapSearchGroup group;
  final VoidCallback onLoadMore;
  final ValueChanged<MapSearchResult> onSelectResult;

  @override
  State<MapSearchResultsList> createState() => _MapSearchResultsListState();
}

class _MapSearchResultsListState extends State<MapSearchResultsList> {
  static const _loadMoreThreshold = 120.0;
  static final _resultDateFormat = DateFormat('d MMM yyyy', 'en_US');

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
        (!widget.isTrackDateRangeActive &&
            widget.searchQuery.trim().length <
                MapConstants.searchPopupMinimumQueryLength)) {
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
        child: ListView.builder(
          key: const Key('map-search-results-list'),
          controller: _scrollController,
          shrinkWrap: true,
          itemCount: rows.length + (widget.isLoadingMore ? 1 : 0),
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
              _MapSearchResultRow(:final result) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapSearchResultTile(
                    key: Key(
                      'map-search-result-${result.type.name}-${result.id}',
                    ),
                    result: result,
                    icon: _iconFor(result.type),
                    dateFormat: _resultDateFormat,
                    onTap: () => widget.onSelectResult(result),
                  ),
                  if (_hasResultDividerAfter(rows, index))
                    _MapSearchResultDivider(result: result),
                ],
              ),
            };
          },
        ),
      );
    }

    if (trimmedQuery.isEmpty && !widget.isTrackDateRangeActive) {
      return const SizedBox.shrink();
    }

    if (!widget.isTrackDateRangeActive &&
        trimmedQuery.length < MapConstants.searchPopupMinimumQueryLength) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Type at least ${MapConstants.searchPopupMinimumQueryLength} characters',
        ),
      );
    }

    if (trimmedQuery.isNotEmpty || widget.isTrackDateRangeActive) {
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
      MapSearchResultType.natural => Icons.forest,
      MapSearchResultType.road => Icons.directions_car,
      MapSearchResultType.map => Icons.map,
    };
  }

  bool _hasResultDividerAfter(List<_MapSearchRow> rows, int index) {
    return index + 1 < rows.length &&
        rows[index] is _MapSearchResultRow &&
        rows[index + 1] is _MapSearchResultRow;
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
        MapSearchResultType.natural => 'Natural',
        MapSearchResultType.road => 'Roads',
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

class _MapSearchResultDivider extends StatelessWidget {
  const _MapSearchResultDivider({required this.result});

  final MapSearchResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataGridTheme =
        theme.extension<DataGridTheme>() ??
        DataGridTheme.fromColorScheme(theme.colorScheme, theme.textTheme);
    return Divider(
      key: Key('map-search-result-divider-${result.type.name}-${result.id}'),
      height: dataGridTheme.dividerThickness,
      thickness: dataGridTheme.dividerThickness,
      color: dataGridTheme.dividerColor,
    );
  }
}

class _MapSearchResultTile extends StatefulWidget {
  const _MapSearchResultTile({
    required this.result,
    required this.icon,
    required this.dateFormat,
    required this.onTap,
    super.key,
  });

  final MapSearchResult result;
  final IconData icon;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  @override
  State<_MapSearchResultTile> createState() => _MapSearchResultTileState();
}

class _MapSearchResultTileState extends State<_MapSearchResultTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataGridTheme =
        theme.extension<DataGridTheme>() ??
        DataGridTheme.fromColorScheme(theme.colorScheme, theme.textTheme);
    final title = widget.result.displayDate == null
        ? widget.result.title
        : '${widget.result.title} · ${widget.dateFormat.format(widget.result.displayDate!)}';

    return Container(
      decoration: _rowDecoration(dataGridTheme),
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            onHover: _setHovered,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            focusColor: Colors.transparent,
            onTap: widget.onTap,
            child: Padding(
              padding: dataGridTheme.rowPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(widget.icon),
                  SizedBox(width: dataGridTheme.columnGap),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: dataGridTheme.rowTextStyle,
                        ),
                        Text(
                          widget.result.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: dataGridTheme.rowTextStyle.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.result.trailingText case final trailingText?) ...[
                    SizedBox(width: dataGridTheme.columnGap),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        trailingText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dataGridTheme.rowTextStyle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration? _rowDecoration(DataGridTheme dataGridTheme) {
    if (_isPressed) {
      return BoxDecoration(color: dataGridTheme.pressedRowColor);
    }
    if (_isHovered) {
      return BoxDecoration(color: dataGridTheme.hoverColor);
    }
    return null;
  }

  void _setHovered(bool value) {
    if (_isHovered == value) {
      return;
    }
    setState(() {
      _isHovered = value;
    });
  }

  void _setPressed(bool value) {
    if (_isPressed == value) {
      return;
    }
    setState(() {
      _isPressed = value;
    });
  }
}
