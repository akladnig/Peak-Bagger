import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/date_formatters.dart';
import '../../models/gpx_track.dart';
import '../../services/elevation_summary_service.dart';
import 'elevation_chart.dart';

class ElevationVisibleSummary {
  const ElevationVisibleSummary({
    required this.period,
    required this.totalMetres,
    required this.averageMetres,
  });

  final ElevationPeriodPreset period;
  final int totalMetres;
  final int averageMetres;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElevationVisibleSummary &&
          runtimeType == other.runtimeType &&
          period == other.period &&
          totalMetres == other.totalMetres &&
          averageMetres == other.averageMetres;

  @override
  int get hashCode => Object.hash(period, totalMetres, averageMetres);
}

class ElevationCard extends StatefulWidget {
  const ElevationCard({
    super.key,
    required this.tracks,
    required this.isLoading,
    this.now,
    this.onVisibleSummaryChanged,
  });

  final List<GpxTrack> tracks;
  final bool isLoading;
  final DateTime? now;
  final ValueChanged<ElevationVisibleSummary?>? onVisibleSummaryChanged;

  @override
  State<ElevationCard> createState() => _ElevationCardState();
}

class _ElevationCardState extends State<ElevationCard> {
  final ElevationSummaryService _service = const ElevationSummaryService();
  final ScrollController _scrollController = ScrollController();

  ElevationPeriodPreset _period = ElevationPeriodPreset.last12Months;
  ElevationDisplayMode _mode = ElevationDisplayMode.columns;
  bool _anchoredToLatest = false;
  double _viewportWidth = 0;
  double _maxScrollExtent = 0;
  ElevationVisibleSummary? _lastVisibleSummary;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant ElevationCard oldWidget) {
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

  void _selectPeriod(ElevationPeriodPreset? next) {
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
        ElevationDisplayMode.columns => ElevationDisplayMode.line,
        ElevationDisplayMode.line => ElevationDisplayMode.columns,
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

  void _reportVisibleSummary(ElevationVisibleSummary? summary) {
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
    final child = widget.isLoading ? _buildLoadingState() : _buildContent();

    return KeyedSubtree(key: const Key('elevation-card'), child: child);
  }

  Widget _buildLoadingState() {
    _reportVisibleSummary(null);
    return const _ElevationLoadingState();
  }

  Widget _buildContent() {
    final now = (widget.now ?? DateTime.now()).toLocal();
    final referenceDate = DateTime(now.year, now.month, now.day);
    final timeline = _service.buildTimeline(
      tracks: widget.tracks,
      period: _period,
      now: widget.now,
    );

    if (timeline.isEmpty) {
      _reportVisibleSummary(null);
      return const _ElevationEmptyState();
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
                final visibleColumnCount = _visibleColumnCountForPeriod(
                  _period,
                );
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
                final visibleTotal = _service.visibleTotalMetres(
                  visibleBuckets,
                );
                final visibleAverage = _service.visibleAverageMetresForPeriod(
                  period: _period,
                  buckets: visibleBuckets,
                );
                final visibleRangeText = formatElevationDateRange(
                  visibleBuckets.first.start,
                  visibleBuckets.last.start,
                );
                _reportVisibleSummary(
                  ElevationVisibleSummary(
                    period: _period,
                    totalMetres: visibleTotal,
                    averageMetres: visibleAverage,
                  ),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ElevationHeader(
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
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ElevationChart(
                              key: const Key('elevation-scroll-view'),
                              controller: _scrollController,
                              buckets: timeline.buckets,
                              mode: _mode,
                              bucketExtent: bucketExtent,
                              period: _period,
                              referenceDate: referenceDate,
                            ),
                          ),
                        ],
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

  List<ElevationBucket> _visibleBuckets(
    List<ElevationBucket> buckets,
    double viewportWidth,
  ) {
    if (buckets.isEmpty) {
      return const [];
    }

    final visibleCount = math.min(
      buckets.length,
      _visibleColumnCountForPeriod(_period),
    );
    final maxStartIndex = math.max(0, buckets.length - visibleCount);
    if (!_scrollController.hasClients) {
      return buckets.sublist(maxStartIndex, buckets.length);
    }

    final bucketExtent = DashboardUI.columnWidthFor(
      availableWidth: viewportWidth,
      visibleColumnCount: _visibleColumnCountForPeriod(_period),
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

  int _visibleColumnCountForPeriod(ElevationPeriodPreset period) {
    return switch (period) {
      ElevationPeriodPreset.week => 7,
      ElevationPeriodPreset.month => 31,
      ElevationPeriodPreset.last3Months => 13,
      ElevationPeriodPreset.last6Months => 26,
      ElevationPeriodPreset.last12Months || ElevationPeriodPreset.allTime => 12,
    };
  }
}

class _ElevationLoadingState extends StatelessWidget {
  const _ElevationLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('elevation-loading-state'),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ElevationEmptyState extends StatelessWidget {
  const _ElevationEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      key: const Key('elevation-empty-state'),
      child: Text('No elevation data yet', style: theme.textTheme.bodyMedium),
    );
  }
}

class _ElevationHeader extends StatelessWidget {
  static const double _periodDropdownWidth = 160;

  const _ElevationHeader({
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

  final ElevationPeriodPreset period;
  final ElevationDisplayMode mode;
  final String visibleRangeText;
  final ValueChanged<ElevationPeriodPreset?> onPeriodChanged;
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
                  child: PopupMenuButton<ElevationPeriodPreset>(
                    key: const Key('elevation-period-dropdown'),
                    initialValue: period,
                    position: PopupMenuPosition.under,
                    padding: EdgeInsets.zero,
                    menuPadding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: onPeriodChanged,
                    itemBuilder: (context) {
                      return ElevationPeriodPreset.values
                          .map(
                            (value) => PopupMenuItem<ElevationPeriodPreset>(
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
              key: const Key('elevation-prev-window'),
              tooltip: 'Previous window',
              onPressed: canMovePrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              key: const Key('elevation-next-window'),
              tooltip: 'Next window',
              onPressed: canMoveNext ? onNext : null,
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              key: const Key('elevation-mode-fab'),
              onPressed: onToggleMode,
              tooltip: mode == ElevationDisplayMode.columns
                  ? 'Switch to line view'
                  : 'Switch to column view',
              child: Icon(
                mode == ElevationDisplayMode.columns
                    ? Icons.show_chart
                    : Icons.bar_chart,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          visibleRangeText,
          key: const Key('elevation-period-range'),
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
