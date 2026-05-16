import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/number_formatters.dart';
import '../providers/dashboard_layout_provider.dart';
import '../providers/map_provider.dart';
import '../services/elevation_summary_service.dart';
import '../widgets/dashboard/elevation_card.dart';
import '../widgets/dashboard/latest_walk_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  ElevationVisibleSummary? _elevationSummary;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(dashboardLayoutProvider.notifier).load());
  }

  void _handleElevationSummaryChanged(ElevationVisibleSummary? summary) {
    if (_elevationSummary == summary) {
      return;
    }

    setState(() {
      _elevationSummary = summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(dashboardLayoutProvider);
    final tracks = ref.watch(mapProvider.select((state) => state.tracks));
    final isLoadingTracks = ref.watch(
      mapProvider.select((state) => state.isLoadingTracks),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = _resolveColumnCount(constraints.maxWidth);
              return GridView.builder(
                key: const Key('dashboard-board'),
                itemCount: order.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: dashboardCardAspectRatio,
                ),
                itemBuilder: (context, index) {
                  final definition = dashboardCards.firstWhere(
                    (card) => card.id == order[index],
                  );
                  final body = switch (definition.id) {
                    'latest-walk' => LatestWalkCard(tracks: tracks),
                    'elevation' => ElevationCard(
                      tracks: tracks,
                      isLoading: isLoadingTracks,
                      onVisibleSummaryChanged: _handleElevationSummaryChanged,
                    ),
                    _ => const _DashboardCardBody(),
                  };
                  return _DashboardCard(
                    definition: definition,
                    headerTrailing:
                        definition.id == 'elevation' &&
                            _elevationSummary != null
                        ? _DashboardCardHeaderMetrics(
                            summary: _elevationSummary!,
                          )
                        : null,
                    body: body,
                    onMove: (draggedId, targetId) {
                      unawaited(
                        ref
                            .read(dashboardLayoutProvider.notifier)
                            .moveCard(draggedId, targetId),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  int _resolveColumnCount(double width) {
    if (width >= dashboardDesktopWideBreakpoint) {
      return 3;
    }
    if (width >= dashboardDesktopMediumBreakpoint) {
      return 2;
    }
    return 1;
  }
}

class _DashboardCard extends StatefulWidget {
  const _DashboardCard({
    required this.definition,
    required this.headerTrailing,
    required this.body,
    required this.onMove,
  });

  final DashboardCardDefinition definition;
  final Widget? headerTrailing;
  final Widget body;
  final void Function(String draggedId, String targetId) onMove;

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  bool _isPointerHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DragTarget<String>(
      key: Key('dashboard-card-${widget.definition.id}'),
      onWillAcceptWithDetails: (details) =>
          details.data != widget.definition.id,
      onAcceptWithDetails: (details) {
        widget.onMove(details.data, widget.definition.id);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered =
            _isPointerHovered || _isDragging || candidateData.isNotEmpty;
        return MouseRegion(
          onEnter: (_) {
            if (!_isPointerHovered) {
              setState(() => _isPointerHovered = true);
            }
          },
          onExit: (_) {
            if (_isPointerHovered) {
              setState(() => _isPointerHovered = false);
            }
          },
          child: Card(
            elevation: 4,
            clipBehavior: Clip.antiAlias,
            color: theme.colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: isHovered
                    ? theme.colorScheme.outlineVariant
                    : theme.colorScheme.outline,
                width: isHovered ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DashboardCardHeader(
                  definition: widget.definition,
                  headerTrailing: widget.headerTrailing,
                  onDragStarted: () {
                    if (!_isDragging) {
                      setState(() => _isDragging = true);
                    }
                  },
                  onDragEnded: () {
                    if (_isDragging) {
                      setState(() => _isDragging = false);
                    }
                  },
                ),
                Expanded(child: widget.body),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardCardHeader extends StatelessWidget {
  const _DashboardCardHeader({
    required this.definition,
    required this.headerTrailing,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final DashboardCardDefinition definition;
  final Widget? headerTrailing;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Draggable<String>(
        data: definition.id,
        onDragStarted: onDragStarted,
        onDragEnd: (_) => onDragEnded(),
        feedback: _DashboardCardDragFeedback(
          definition: definition,
          headerTrailing: headerTrailing,
        ),
        childWhenDragging: const Opacity(
          opacity: 0.35,
          child: _DashboardCardHeaderBodyPlaceholder(),
        ),
        child: Container(
          key: Key('dashboard-card-${definition.id}-drag-handle'),
          color: theme.colorScheme.primaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _DashboardCardHeaderRow(
            title: definition.title,
            headerTrailing: headerTrailing,
            titleStyle: theme.textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}

class _DashboardCardBody extends StatelessWidget {
  const _DashboardCardBody();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Placeholder'));
  }
}

class _DashboardCardDragFeedback extends StatelessWidget {
  const _DashboardCardDragFeedback({
    required this.definition,
    required this.headerTrailing,
  });

  final DashboardCardDefinition definition;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 280,
        height: 280 / dashboardCardAspectRatio,
        child: Card(
          elevation: 8,
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: theme.colorScheme.outlineVariant, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: theme.colorScheme.primaryContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: _DashboardCardHeaderRow(
                  title: definition.title,
                  headerTrailing: headerTrailing,
                  titleStyle: theme.textTheme.titleMedium,
                ),
              ),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCardHeaderRow extends StatelessWidget {
  const _DashboardCardHeaderRow({
    required this.title,
    required this.headerTrailing,
    required this.titleStyle,
  });

  final String title;
  final Widget? headerTrailing;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: titleStyle),
        const SizedBox(width: 12),
        if (headerTrailing != null) ...[
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: headerTrailing!,
            ),
          ),
          const SizedBox(width: 12),
        ] else ...[
          const Spacer(),
        ],
        const Icon(Icons.drag_indicator),
      ],
    );
  }
}

class _DashboardCardHeaderMetrics extends StatelessWidget {
  const _DashboardCardHeaderMetrics({required this.summary});

  final ElevationVisibleSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DashboardCardHeaderMetricPill(
          label: 'Total:',
          value: '${formatElevationMetres(summary.totalMetres)} m',
        ),
        const SizedBox(width: 24),
        _DashboardCardHeaderMetricPill(
          label: _averageLabel,
          value: '${formatElevationMetres(summary.averageMetres)} m',
        ),
      ],
    );
  }

  String get _averageLabel {
    return switch (summary.period) {
      ElevationPeriodPreset.week => 'Daily Avg:',
      ElevationPeriodPreset.month => 'Weekly Avg:',
      ElevationPeriodPreset.last3Months ||
      ElevationPeriodPreset.last6Months => 'Monthly Avg:',
      ElevationPeriodPreset.last12Months => 'Monthly Avg:',
      ElevationPeriodPreset.allTime => 'Annual Avg:',
    };
  }
}

class _DashboardCardHeaderMetricPill extends StatelessWidget {
  const _DashboardCardHeaderMetricPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        Text(label),
        SizedBox(
          width: 70,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardCardHeaderBodyPlaceholder extends StatelessWidget {
  const _DashboardCardHeaderBodyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
