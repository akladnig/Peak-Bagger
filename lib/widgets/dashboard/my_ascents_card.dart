import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/map_provider.dart';
import '../../providers/my_ascents_summary_provider.dart';
import '../../router.dart';
import '../../services/my_ascents_summary_service.dart';

class MyAscentsCard extends ConsumerStatefulWidget {
  const MyAscentsCard({super.key});

  @override
  ConsumerState<MyAscentsCard> createState() => _MyAscentsCardState();
}

class _MyAscentsCardState extends ConsumerState<MyAscentsCard> {
  static const _service = MyAscentsSummaryService();

  bool _ascending = false;

  void _toggleSort() {
    setState(() => _ascending = !_ascending);
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
    final source = ref.watch(myAscentsSummaryProvider);
    final summary = _service.build(source, ascending: _ascending);

    return KeyedSubtree(
      key: const Key('my-ascents-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MyAscentsTableHeader(
              ascending: _ascending,
              onToggleSort: _toggleSort,
              key: const Key('my-ascents-table-header'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: summary.isEmpty
                  ? const _MyAscentsEmptyState()
                  : KeyedSubtree(
                      key: const Key('my-ascents-table'),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          for (final section in summary.sections) ...[
                            _MyAscentsYearHeader(
                              year: section.year,
                            ),
                            for (final row in section.rows)
                              _MyAscentsTableRow(
                                row: row,
                                onTap: () => _openTrack(row.gpxId),
                              ),
                            const SizedBox(height: 4),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
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
          icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
        ),
      ],
    );
  }
}

class _MyAscentsYearHeader extends StatelessWidget {
  const _MyAscentsYearHeader({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyedSubtree(
      key: Key('my-ascents-year-$year'),
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Text(
          '$year',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MyAscentsTableRow extends StatelessWidget {
  const _MyAscentsTableRow({required this.row, required this.onTap});

  final MyAscentsRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyedSubtree(
      key: Key('my-ascents-row-${row.baggedId}'),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _MyAscentsTableCell(
                label: row.peakName,
                flex: 5,
                textAlign: TextAlign.start,
                style: theme.textTheme.bodyMedium,
              ),
              _MyAscentsTableCell(
                label: row.elevationText,
                flex: 2,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium,
              ),
              _MyAscentsTableCell(
                label: row.dateText,
                flex: 4,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium,
              ),
            ],
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
