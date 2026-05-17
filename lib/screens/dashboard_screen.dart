import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/core/constants.dart';

import '../core/number_formatters.dart';
import '../providers/dashboard_layout_provider.dart';
import '../providers/map_provider.dart';
import '../services/summary_card_service.dart';
import '../widgets/dashboard/distance_card.dart';
import '../widgets/dashboard/elevation_card.dart';
import '../widgets/dashboard/latest_walk_card.dart';
import '../widgets/dashboard/my_ascents_card.dart';
import '../widgets/dashboard/my_lists_card.dart';
import '../widgets/dashboard/peaks_bagged_card.dart';
import '../widgets/dashboard/year_to_date_card.dart';
import '../widgets/dashboard/summary_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, this.now});

  final DateTime? now;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  SummaryVisibleSummary? _elevationSummary;
  SummaryVisibleSummary? _distanceSummary;
  SummaryVisibleSummary? _peaksBaggedSummary;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(dashboardLayoutProvider.notifier).load());
  }

  void _handleElevationSummaryChanged(SummaryVisibleSummary? summary) {
    if (_elevationSummary == summary) {
      return;
    }

    setState(() {
      _elevationSummary = summary;
    });
  }

  void _handleDistanceSummaryChanged(SummaryVisibleSummary? summary) {
    if (_distanceSummary == summary) {
      return;
    }

    setState(() {
      _distanceSummary = summary;
    });
  }

  void _handlePeaksBaggedSummaryChanged(SummaryVisibleSummary? summary) {
    if (_peaksBaggedSummary == summary) {
      return;
    }

    setState(() {
      _peaksBaggedSummary = summary;
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
                findChildIndexCallback: (key) {
                  final valueKey = key is ValueKey<String> ? key.value : null;
                  if (valueKey == null ||
                      !valueKey.startsWith('dashboard-card-')) {
                    return null;
                  }

                  final cardId = valueKey.substring('dashboard-card-'.length);
                  return order.indexOf(cardId);
                },
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
                    'distance' => DistanceCard(
                      tracks: tracks,
                      isLoading: isLoadingTracks,
                      now: widget.now,
                      onVisibleSummaryChanged: _handleDistanceSummaryChanged,
                    ),
                    'latest-walk' => LatestWalkCard(tracks: tracks),
                    'elevation' => ElevationCard(
                      tracks: tracks,
                      isLoading: isLoadingTracks,
                      now: widget.now,
                      onVisibleSummaryChanged: _handleElevationSummaryChanged,
                    ),
                    'my-ascents' => const MyAscentsCard(),
                    'my-lists' => const MyListsCard(),
                    'peaks-bagged' => PeaksBaggedCard(
                      tracks: tracks,
                      isLoading: isLoadingTracks,
                      now: widget.now,
                      onVisibleSummaryChanged: _handlePeaksBaggedSummaryChanged,
                    ),
                    'year-to-date' => YearToDateCard(
                      tracks: tracks,
                      isLoading: isLoadingTracks,
                      now: widget.now,
                    ),
                    _ => const _DashboardCardBody(),
                  };
                  return _DashboardCard(
                    key: ValueKey('dashboard-card-${definition.id}'),
                    definition: definition,
                    headerTrailing: switch (definition.id) {
                      'elevation' when _elevationSummary != null =>
                        _DashboardCardHeaderMetrics(
                          summary: _elevationSummary!,
                          valueFormatter: ElevationCard.adapter.headerValueText,
                          averageLabelText:
                              ElevationCard.adapter.averageLabelText,
                        ),
                      'distance' when _distanceSummary != null =>
                        _DashboardCardHeaderMetrics(
                          summary: _distanceSummary!,
                          valueFormatter: DistanceCard.adapter.headerValueText,
                          averageLabelText:
                              DistanceCard.adapter.averageLabelText,
                        ),
                      'peaks-bagged' when _peaksBaggedSummary != null =>
                        _DashboardCardHeaderMetrics(
                          summary: _peaksBaggedSummary!,
                          valueFormatter: _formatCountValue,
                          averageLabelText: defaultAverageLabelText,
                        ),
                      _ => null,
                    },
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
    super.key,
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
              borderRadius: DashboardUI.cardBorderRadius,
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
            borderRadius: DashboardUI.cardBorderRadius,
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
    if (headerTrailing == null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.drag_indicator, size: 18),
        ],
      );
    }

    final textDirection = Directionality.of(context);
    final titleWidth = _measureSingleLineTextWidth(
      text: title,
      style: titleStyle,
      textDirection: textDirection,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final trailingMaxWidth =
            (constraints.maxWidth -
                    titleWidth.clamp(0.0, constraints.maxWidth).toDouble() -
                    42)
                .clamp(0.0, constraints.maxWidth)
                .toDouble();

        return Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: trailingMaxWidth),
              child: Align(
                alignment: Alignment.centerRight,
                child: headerTrailing!,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.drag_indicator, size: 18),
          ],
        );
      },
    );
  }
}

double _measureSingleLineTextWidth({
  required String text,
  required TextStyle? style,
  required TextDirection textDirection,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: textDirection,
  )..layout();
  return painter.width;
}

class _DashboardCardHeaderMetrics extends StatelessWidget {
  const _DashboardCardHeaderMetrics({
    required this.summary,
    required this.valueFormatter,
    required this.averageLabelText,
  });

  final SummaryVisibleSummary summary;
  final String Function(double value) valueFormatter;
  final String Function(SummaryPeriodPreset period) averageLabelText;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _DashboardCardHeaderMetricPill(
            label: 'Total:',
            value: valueFormatter(summary.totalValue),
            valueKey: const Key('dashboard-card-summary-total-value'),
          ),
          const SizedBox(width: 20),
          _DashboardCardHeaderMetricPill(
            label: averageLabelText(summary.period),
            value: valueFormatter(summary.averageValue),
            valueKey: const Key('dashboard-card-summary-average-value'),
          ),
        ],
      ),
    );
  }
}

class _DashboardCardHeaderMetricPill extends StatelessWidget {
  const _DashboardCardHeaderMetricPill({
    required this.label,
    required this.value,
    this.valueKey,
  });

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        SizedBox(
          width: 70,
          child: Text(
            value,
            key: valueKey,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
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

String _formatCountValue(double value) => formatElevationMetres(value.round());
