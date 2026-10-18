import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_formatters.dart';
import '../../providers/map_provider.dart';
import '../../providers/my_lists_summary_provider.dart';
import '../../services/peak_list_summary_service.dart';
import '../../router.dart';
import '../../theme.dart';
import '../../providers/dashboard_browsing_provider.dart';
import 'dashboard_card_keyboard.dart';

class MyListsCard extends ConsumerStatefulWidget {
  const MyListsCard({super.key});

  @override
  ConsumerState<MyListsCard> createState() => _MyListsCardState();
}

class _MyListsCardState extends ConsumerState<MyListsCard> {
  final _reveal = DashboardRowRevealController();
  static final _selection = dashboardRowSelectionProvider('my-lists');

  void _openSelected() {
    final id = ref.read(_selection).selectedId;
    final row = ref
        .read(myListsSummaryProvider)
        .where((r) => r.peakList.peakListId == id)
        .firstOrNull;
    if (row != null) _open(row);
  }

  Future<void> _open(PeakListSummaryRow row) async {
    final result = await ref
        .read(mapProvider.notifier)
        .preparePeakListMapNavigation(row.peakList.peakListId);
    if (!mounted) return;
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
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(myListsSummaryProvider);
    final selection = ref.watch(_selection);
    ref.listen(_selection, (_, next) => _reveal.reveal(next.selectedId));
    _reveal.retainIds(selection.ids);
    final controller = ref.read(_selection.notifier);
    final keyboard = DashboardCardKeyboard.maybeOf(context);

    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final rowStyle = theme.textTheme.bodySmall;

    return DashboardCardActions(
      onEntry: controller.enter,
      actions: {
        LogicalKeyboardKey.arrowDown: () => controller.move(true),
        LogicalKeyboardKey.keyJ: () => controller.move(true),
        LogicalKeyboardKey.arrowUp: () => controller.move(false),
        LogicalKeyboardKey.keyK: () => controller.move(false),
        LogicalKeyboardKey.enter: _openSelected,
      },
      child: rows.isEmpty
          ? const _MyListsEmptyState()
          : KeyedSubtree(
              key: const Key('my-lists-card'),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _MyListsTableHeader(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _reveal.scroll,
                        child: KeyedSubtree(
                          key: const Key('my-lists-table'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final row in rows)
                                _MyListsTableRow(
                                  key: Key(
                                    'my-lists-row-${row.peakList.peakListId}',
                                  ),
                                  row: row,
                                  headerStyle: headerStyle,
                                  rowStyle: rowStyle,
                                  revealKey: _reveal.keyFor(
                                    row.peakList.peakListId,
                                  ),
                                  selected:
                                      selection.selectedId ==
                                      row.peakList.peakListId,
                                  cardFocus: keyboard?.focusNode,
                                  onTap: () => _open(row),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
            label: 'Climbed %',
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
    required this.revealKey,
    required this.selected,
    required this.cardFocus,
  });

  final PeakListSummaryRow row;
  final TextStyle? headerStyle;
  final TextStyle? rowStyle;
  final VoidCallback onTap;
  final Key revealKey;
  final bool selected;
  final FocusNode? cardFocus;

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
    final textColor = widget.selected
        ? theme.colorScheme.onPrimaryContainer
        : _isHovered
        ? rowTheme.hoveredTextColor
        : null;
    final backgroundColor = widget.selected
        ? theme.colorScheme.primaryContainer
        : _isHovered
        ? rowTheme.hoverColor
        : Colors.transparent;

    return Semantics(
      selected: widget.selected,
      child: InkWell(
        key: widget.revealKey,
        canRequestFocus: false,
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
        child: ListenableBuilder(
          listenable: widget.cardFocus ?? const AlwaysStoppedAnimation(false),
          builder: (context, _) => AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                left: BorderSide(
                  color:
                      widget.selected &&
                          widget.cardFocus?.hasPrimaryFocus == true
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
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
