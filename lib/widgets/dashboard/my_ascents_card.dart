import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/map_provider.dart';
import '../../providers/dashboard_browsing_provider.dart';
import '../../router.dart';
import '../../services/my_ascents_summary_service.dart';
import '../../theme.dart';
import 'dashboard_card_keyboard.dart';

class MyAscentsCard extends ConsumerStatefulWidget {
  const MyAscentsCard({super.key});

  @override
  ConsumerState<MyAscentsCard> createState() => _MyAscentsCardState();
}

class _MyAscentsCardState extends ConsumerState<MyAscentsCard> {
  final _reveal = DashboardRowRevealController();
  static final _selection = dashboardRowSelectionProvider('my-ascents');

  void _openSelected() {
    final id = ref.read(_selection).selectedId;
    final row = ref
        .read(sortedMyAscentsProvider)
        .sections
        .expand((s) => s.rows)
        .where((r) => r.baggedId == id)
        .firstOrNull;
    if (row != null) _openTrack(row.gpxId);
  }

  void _toggleSort() {
    ref.read(myAscentsAscendingProvider.notifier).toggle();
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _openTrack(int trackId) {
    if (trackId <= 0) {
      return;
    }

    ref.read(mapProvider.notifier).showTrack(trackId);
    router.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(sortedMyAscentsProvider);
    final ascending = ref.watch(myAscentsAscendingProvider);
    final selection = ref.watch(_selection);
    ref.listen(_selection, (_, next) => _reveal.reveal(next.selectedId));
    _reveal.retainIds(selection.ids);
    final controller = ref.read(_selection.notifier);
    final keyboard = DashboardCardKeyboard.maybeOf(context);

    return DashboardCardActions(
      onEntry: controller.enter,
      actions: {
        LogicalKeyboardKey.arrowDown: () => controller.move(true),
        LogicalKeyboardKey.keyJ: () => controller.move(true),
        LogicalKeyboardKey.arrowUp: () => controller.move(false),
        LogicalKeyboardKey.keyK: () => controller.move(false),
        LogicalKeyboardKey.keyS: _toggleSort,
        LogicalKeyboardKey.enter: _openSelected,
      },
      child: KeyedSubtree(
        key: const Key('my-ascents-card'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MyAscentsTableHeader(
                ascending: ascending,
                onToggleSort: _toggleSort,
                key: const Key('my-ascents-table-header'),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: summary.isEmpty
                    ? const _MyAscentsEmptyState()
                    : KeyedSubtree(
                        key: const Key('my-ascents-table'),
                        child: SingleChildScrollView(
                          controller: _reveal.scroll,
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final section in summary.sections) ...[
                                _MyAscentsYearHeader(section: section),
                                for (final row in section.rows)
                                  _MyAscentsTableRow(
                                    row: row,
                                    revealKey: _reveal.keyFor(row.baggedId),
                                    selected:
                                        selection.selectedId == row.baggedId,
                                    cardFocus: keyboard?.focusNode,
                                    onTap: () => _openTrack(row.gpxId),
                                  ),
                                const SizedBox(height: 4),
                              ],
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

class _MyAscentsEmptyState extends StatelessWidget {
  const _MyAscentsEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('my-ascents-empty-state'),
      child: Text('No ascents yet'),
    );
  }
}

class _MyAscentsTableHeader extends StatelessWidget {
  const _MyAscentsTableHeader({
    super.key,
    required this.ascending,
    required this.onToggleSort,
  });

  final bool ascending;
  final VoidCallback onToggleSort;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _MyAscentsTableCell(
          label: 'Peak Name',
          flex: 5,
          textAlign: TextAlign.start,
          style: style,
        ),
        _MyAscentsTableCell(
          label: 'Elevation',
          flex: 2,
          textAlign: TextAlign.end,
          style: style,
        ),
        _MyAscentsTableCell(
          label: 'Date Climbed',
          flex: 4,
          textAlign: TextAlign.end,
          style: style,
        ),
        IconButton(
          key: const Key('my-ascents-sort-toggle'),
          tooltip: ascending ? 'Sort newest first' : 'Sort oldest first',
          onPressed: onToggleSort,
          mouseCursor: SystemMouseCursors.click,
          icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
        ),
      ],
    );
  }
}

class _MyAscentsYearHeader extends StatelessWidget {
  const _MyAscentsYearHeader({required this.section});

  final MyAscentsYearSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyedSubtree(
      key: Key('my-ascents-year-${section.year}'),
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Text(
          '${section.year} - ${section.rows.length} peaks climbed',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MyAscentsTableRow extends StatefulWidget {
  const _MyAscentsTableRow({
    required this.row,
    required this.onTap,
    required this.revealKey,
    required this.selected,
    required this.cardFocus,
  });

  final MyAscentsRow row;
  final VoidCallback onTap;
  final Key revealKey;
  final bool selected;
  final FocusNode? cardFocus;

  @override
  State<_MyAscentsTableRow> createState() => _MyAscentsTableRowState();
}

class _MyAscentsTableRowState extends State<_MyAscentsTableRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rowTheme =
        theme.extension<RowHoverTheme>() ??
        (theme.brightness == Brightness.dark
            ? RowHoverTheme.dark
            : RowHoverTheme.light);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: widget.selected
          ? theme.colorScheme.onPrimaryContainer
          : _isHovered
          ? rowTheme.hoveredTextColor
          : null,
    );

    return KeyedSubtree(
      key: Key('my-ascents-row-${widget.row.baggedId}'),
      child: Semantics(
        selected: widget.selected,
        child: InkWell(
          key: widget.revealKey,
          canRequestFocus: false,
          onTap: widget.onTap,
          onHover: (value) {
            if (_isHovered == value) {
              return;
            }
            setState(() {
              _isHovered = value;
            });
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
                color: widget.selected
                    ? theme.colorScheme.primaryContainer
                    : _isHovered
                    ? rowTheme.hoverColor
                    : Colors.transparent,
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
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  _MyAscentsTableCell(
                    label: widget.row.peakName,
                    flex: 5,
                    textAlign: TextAlign.start,
                    style: textStyle,
                  ),
                  _MyAscentsTableCell(
                    label: widget.row.elevationText,
                    flex: 2,
                    textAlign: TextAlign.end,
                    style: textStyle,
                  ),
                  _MyAscentsTableCell(
                    label: widget.row.dateText,
                    flex: 4,
                    textAlign: TextAlign.end,
                    style: textStyle,
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

class _MyAscentsTableCell extends StatelessWidget {
  const _MyAscentsTableCell({
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
