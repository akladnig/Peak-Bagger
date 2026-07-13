import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_formatters.dart';
import '../../providers/map_provider.dart';
import '../../providers/my_lists_summary_provider.dart';
import '../../services/peak_list_summary_service.dart';
import '../../router.dart';
import '../../theme.dart';

class MyListsCard extends ConsumerWidget {
  const MyListsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(myListsSummaryProvider);
    if (rows.isEmpty) {
      return const _MyListsEmptyState();
    }

    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final rowStyle = theme.textTheme.bodySmall;

    return KeyedSubtree(
      key: const Key('my-lists-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _MyListsTableHeader(),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: const Key('my-lists-table'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final row in rows)
                    _MyListsTableRow(
                      key: Key('my-lists-row-${row.peakList.peakListId}'),
                      row: row,
                      headerStyle: headerStyle,
                      rowStyle: rowStyle,
                      onTap: () async {
                        final result = await ref
                            .read(mapProvider.notifier)
                            .preparePeakListMapNavigation(
                              row.peakList.peakListId,
                            );
                        if (!context.mounted) {
                          return;
                        }
                        if (!result.shouldNavigate) {
                          final message = result.message;
                          if (message != null) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          }
                          return;
                        }

                        router.go('/map');
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyListsEmptyState extends StatelessWidget {
  const _MyListsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('my-lists-empty-state'),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No peak lists yet',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _MyListsTableHeader extends StatelessWidget {
  const _MyListsTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;

    return KeyedSubtree(
      key: const Key('my-lists-table-header'),
      child: Row(
        children: [
          _MyListsTableCell(
            label: 'List',
            flex: 5,
            textAlign: TextAlign.start,
            style: style,
          ),
          _MyListsTableCell(
            label: 'Total Peaks',
            flex: 2,
            textAlign: TextAlign.end,
            style: style,
          ),
          _MyListsTableCell(
            label: 'Climbed',
            flex: 2,
            textAlign: TextAlign.end,
            style: style,
          ),
          _MyListsTableCell(
            label: '% Climbed',
            flex: 2,
            textAlign: TextAlign.end,
            style: style,
          ),
          _MyListsTableCell(
            label: 'Unclimbed',
            flex: 2,
            textAlign: TextAlign.end,
            style: style,
          ),
        ],
      ),
    );
  }
}

class _MyListsTableRow extends StatefulWidget {
  const _MyListsTableRow({
    super.key,
    required this.row,
    required this.headerStyle,
    required this.rowStyle,
    required this.onTap,
  });

  final PeakListSummaryRow row;
  final TextStyle? headerStyle;
  final TextStyle? rowStyle;
  final VoidCallback onTap;

  @override
  State<_MyListsTableRow> createState() => _MyListsTableRowState();
}

class _MyListsTableRowState extends State<_MyListsTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowTheme =
        theme.extension<RowHoverTheme>() ??
        (theme.brightness == Brightness.dark
            ? RowHoverTheme.dark
            : RowHoverTheme.light);
    final textColor = _isHovered ? rowTheme.hoveredTextColor : null;
    final backgroundColor = _isHovered
        ? rowTheme.hoverColor
        : Colors.transparent;

    return InkWell(
      onTap: widget.onTap,
      onHover: (value) {
        if (_isHovered == value) {
          return;
        }

        setState(() => _isHovered = value);
      },
      mouseCursor: SystemMouseCursors.click,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _MyListsTableCell(
                label: widget.row.peakList.name,
                flex: 5,
                textAlign: TextAlign.start,
                style: widget.headerStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              _MyListsTableCell(
                label: formatCount(widget.row.totalPeaks),
                flex: 2,
                textAlign: TextAlign.end,
                style: widget.rowStyle?.copyWith(color: textColor),
              ),
              _MyListsTableCell(
                label: formatCount(widget.row.climbed),
                flex: 2,
                textAlign: TextAlign.end,
                style: widget.rowStyle?.copyWith(color: textColor),
              ),
              _MyListsTableCell(
                label: widget.row.percentageLabel,
                flex: 2,
                textAlign: TextAlign.end,
                style: widget.rowStyle?.copyWith(color: textColor),
              ),
              _MyListsTableCell(
                label: formatCount(widget.row.unclimbed),
                flex: 2,
                textAlign: TextAlign.end,
                style: widget.rowStyle?.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyListsTableCell extends StatelessWidget {
  const _MyListsTableCell({
    required this.label,
    required this.flex,
    required this.textAlign,
    required this.style,
  });

  final String label;
  final int flex;
  final TextAlign textAlign;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
