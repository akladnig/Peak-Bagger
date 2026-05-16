import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/date_formatters.dart';
import '../../models/gpx_track.dart';
import '../../services/summary_card_service.dart';
import 'summary_chart.dart';

class SummaryVisibleSummary {
  const SummaryVisibleSummary({
    required this.period,
    required this.totalValue,
    required this.averageValue,
  });

  final SummaryPeriodPreset period;
  final double totalValue;
  final double averageValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SummaryVisibleSummary &&
          runtimeType == other.runtimeType &&
          period == other.period &&
          totalValue == other.totalValue &&
          averageValue == other.averageValue;

  @override
  int get hashCode => Object.hash(period, totalValue, averageValue);
}

class SummaryCardMetricAdapter {
  const SummaryCardMetricAdapter({
    required this.keyPrefix,
    required this.emptyStateText,
    required this.metric,
    required this.tooltipValueText,
    required this.headerValueText,
    this.tooltipTitleText = defaultTooltipTitleText,
    this.averageLabelText = defaultAverageLabelText,
  });

  final String keyPrefix;
  final String emptyStateText;
  final SummaryMetricDefinition metric;
  final String Function(SummaryBucket bucket) tooltipValueText;
  final String Function(double value) headerValueText;
  final String Function(SummaryBucket bucket, SummaryPeriodPreset period)
  tooltipTitleText;
  final String Function(SummaryPeriodPreset period) averageLabelText;
}

class SummaryCard extends StatefulWidget {
  const SummaryCard({
    super.key,
    required this.tracks,
    required this.isLoading,
    required this.adapter,
    this.now,
    this.onVisibleSummaryChanged,
  });

  final List<GpxTrack> tracks;
  final bool isLoading;
  final SummaryCardMetricAdapter adapter;
  final DateTime? now;
  final ValueChanged<SummaryVisibleSummary?>? onVisibleSummaryChanged;

  @override
  State<SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<SummaryCard> {
  final SummaryCardService _service = const SummaryCardService();
  final ScrollController _scrollController = ScrollController();

  SummaryPeriodPreset _period = SummaryPeriodPreset.last12Months;
  SummaryDisplayMode _mode = SummaryDisplayMode.columns;
  bool _anchoredToLatest = false;
  double _viewportWidth = 0;
  double _maxScrollExtent = 0;
  SummaryVisibleSummary? _lastVisibleSummary;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant SummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracks != widget.tracks ||
        oldWidget.isLoading != widget.isLoading) {
      _anchoredToLatest = false;
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (mounted) {
      setState(() {});
    }
  }

  void _selectPeriod(SummaryPeriodPreset? next) {
    if (next == null || next == _period) {
      return;
    }

    setState(() {
      _period = next;
      _anchoredToLatest = false;
    });
  }

  void _toggleMode() {
    setState(() {
      _mode = switch (_mode) {
        SummaryDisplayMode.columns => SummaryDisplayMode.line,
        SummaryDisplayMode.line => SummaryDisplayMode.columns,
      };
    });
  }

  void _shiftWindow(bool forward) {
    if (!_scrollController.hasClients || _maxScrollExtent <= 0) {
      return;
    }

    final target = _service.shiftScrollOffset(
      currentOffset: _scrollController.offset,
      viewportWidth: _viewportWidth,
      maxScrollExtent: _maxScrollExtent,
      forward: forward,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
    );
  }

  void _reportVisibleSummary(SummaryVisibleSummary? summary) {
    if (widget.onVisibleSummaryChanged == null ||
        _lastVisibleSummary == summary) {
      return;
    }

    _lastVisibleSummary = summary;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onVisibleSummaryChanged?.call(summary);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.isLoading ? _buildLoadingState() : _buildContent();
  }

  Widget _buildLoadingState() {
    _reportVisibleSummary(null);
    return Center(
      key: Key('${widget.adapter.keyPrefix}-loading-state'),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildContent() {
    final now = (widget.now ?? DateTime.now()).toLocal();
    final referenceDate = DateTime(now.year, now.month, now.day);
    final timeline = _service.buildTimeline(
      tracks: widget.tracks,
      period: _period,
      metric: widget.adapter.metric,
      now: widget.now,
    );

    if (timeline.isEmpty) {
      _reportVisibleSummary(null);
      return Center(
        key: Key('${widget.adapter.keyPrefix}-empty-state'),
        child: Text(
          widget.adapter.emptyStateText,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewportWidth = constraints.maxWidth;
                final visibleColumnCount = visibleColumnCountForPeriod(_period);
                final bucketExtent = DashboardUI.columnWidthFor(
                  availableWidth: constraints.maxWidth,
                  visibleColumnCount: visibleColumnCount,
                );
                final contentWidth = math.max<double>(
                  (timeline.buckets.length * bucketExtent).ceilToDouble() +
                      0.01,
                  1,
                );
                _maxScrollExtent = math.max(
                  0,
                  contentWidth - constraints.maxWidth,
                );
                _syncScrollPosition(timeline.buckets.length);

                final visibleBuckets = _visibleBuckets(
                  timeline.buckets,
                  constraints.maxWidth,
                );
                final visibleTotal = _service.visibleTotalValue(visibleBuckets);
                final visibleAverage = _service.visibleAverageValueForPeriod(
                  period: _period,
                  buckets: visibleBuckets,
                );
                final visibleRangeText = formatSummaryDateRange(
                  visibleBuckets.first.start,
                  visibleBuckets.last.start,
                );
                _reportVisibleSummary(
                  SummaryVisibleSummary(
                    period: _period,
                    totalValue: visibleTotal,
                    averageValue: visibleAverage,
                  ),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SummaryHeader(
                      keyPrefix: widget.adapter.keyPrefix,
                      period: _period,
                      mode: _mode,
                      visibleRangeText: visibleRangeText,
                      onPeriodChanged: _selectPeriod,
                      onToggleMode: _toggleMode,
                      onPrevious: () => _shiftWindow(false),
                      onNext: () => _shiftWindow(true),
                      canMovePrevious: _canMovePrevious(
                        timeline.buckets.length,
                      ),
                      canMoveNext: _canMoveNext(timeline.buckets.length),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SummaryChart(
                        key: Key('${widget.adapter.keyPrefix}-scroll-view'),
                        keyPrefix: widget.adapter.keyPrefix,
                        controller: _scrollController,
                        buckets: timeline.buckets,
                        mode: _mode,
                        bucketExtent: bucketExtent,
                        period: _period,
                        referenceDate: referenceDate,
                        tooltipValueText: widget.adapter.tooltipValueText,
                        tooltipTitleText: widget.adapter.tooltipTitleText,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _canMovePrevious(int bucketCount) {
    if (bucketCount <= 0 || !_scrollController.hasClients) {
      return false;
    }
    return _scrollController.offset > 0;
  }

  bool _canMoveNext(int bucketCount) {
    if (bucketCount <= 0 || !_scrollController.hasClients) {
      return false;
    }
    return _scrollController.offset < _maxScrollExtent;
  }

  void _syncScrollPosition(int bucketCount) {
    if (bucketCount == 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      if (!_scrollController.hasClients) {
        _syncScrollPosition(bucketCount);
        return;
      }

      final target = _anchoredToLatest
          ? _scrollController.offset.clamp(0.0, _maxScrollExtent).toDouble()
          : _maxScrollExtent;
      if (!_anchoredToLatest) {
        _anchoredToLatest = true;
      }

      if ((_scrollController.offset - target).abs() > 0.5) {
        _scrollController.jumpTo(target);
      }
    });
  }

  List<SummaryBucket> _visibleBuckets(
    List<SummaryBucket> buckets,
    double viewportWidth,
  ) {
    if (buckets.isEmpty) {
      return const [];
    }

    final visibleCount = math.min(
      buckets.length,
      visibleColumnCountForPeriod(_period),
    );
    final maxStartIndex = math.max(0, buckets.length - visibleCount);
    if (!_scrollController.hasClients) {
      return buckets.sublist(maxStartIndex, buckets.length);
    }

    final bucketExtent = DashboardUI.columnWidthFor(
      availableWidth: viewportWidth,
      visibleColumnCount: visibleColumnCountForPeriod(_period),
    );
    final currentOffset = _scrollController.offset
        .clamp(0.0, _maxScrollExtent)
        .toDouble();
    final startIndex = _anchoredToLatest
        ? math.min(
            maxStartIndex,
            math.max(0, (currentOffset / bucketExtent).floor()),
          )
        : maxStartIndex;
    final endIndex = math.min(buckets.length, startIndex + visibleCount);
    return buckets.sublist(startIndex, endIndex);
  }
}

class _SummaryHeader extends StatelessWidget {
  static const double _periodDropdownWidth = 160;

  const _SummaryHeader({
    required this.keyPrefix,
    required this.period,
    required this.mode,
    required this.visibleRangeText,
    required this.onPeriodChanged,
    required this.onToggleMode,
    required this.onPrevious,
    required this.onNext,
    required this.canMovePrevious,
    required this.canMoveNext,
  });

  final String keyPrefix;
  final SummaryPeriodPreset period;
  final SummaryDisplayMode mode;
  final String visibleRangeText;
  final ValueChanged<SummaryPeriodPreset?> onPeriodChanged;
  final VoidCallback onToggleMode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canMovePrevious;
  final bool canMoveNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _periodDropdownWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Theme(
                  data: theme.copyWith(
                    hoverColor: theme.colorScheme.primary.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  child: PopupMenuButton<SummaryPeriodPreset>(
                    key: const Key('summary-period-dropdown'),
                    initialValue: period,
                    position: PopupMenuPosition.under,
                    padding: EdgeInsets.zero,
                    menuPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: onPeriodChanged,
                    itemBuilder: (context) {
                      return SummaryPeriodPreset.values
                          .map(
                            (value) => PopupMenuItem<SummaryPeriodPreset>(
                              value: value,
                              height: 36,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(value.label),
                            ),
                          )
                          .toList(growable: false);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              period.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Spacer(),
            IconButton(
              key: const Key('summary-prev-window'),
              tooltip: 'Previous window',
              onPressed: canMovePrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              key: const Key('summary-next-window'),
              tooltip: 'Next window',
              onPressed: canMoveNext ? onNext : null,
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              key: const Key('summary-mode-fab'),
              onPressed: onToggleMode,
              tooltip: mode == SummaryDisplayMode.columns
                  ? 'Switch to line view'
                  : 'Switch to column view',
              child: Icon(
                mode == SummaryDisplayMode.columns
                    ? Icons.show_chart
                    : Icons.bar_chart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          visibleRangeText,
          key: Key('$keyPrefix-period-range'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

int visibleColumnCountForPeriod(SummaryPeriodPreset period) {
  return switch (period) {
    SummaryPeriodPreset.week => 7,
    SummaryPeriodPreset.month => 31,
    SummaryPeriodPreset.last3Months => 13,
    SummaryPeriodPreset.last6Months => 26,
    SummaryPeriodPreset.last12Months || SummaryPeriodPreset.allTime => 12,
  };
}

String defaultAverageLabelText(SummaryPeriodPreset period) =>
    period.averageLabel;
