import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/gpx_track.dart';
import '../../services/elevation_summary_service.dart';

enum ElevationDisplayMode { columns, line }

class ElevationCard extends StatefulWidget {
  const ElevationCard({
    super.key,
    required this.tracks,
    required this.isLoading,
    this.now,
  });

  final List<GpxTrack> tracks;
  final bool isLoading;
  final DateTime? now;

  @override
  State<ElevationCard> createState() => _ElevationCardState();
}

class _ElevationCardState extends State<ElevationCard> {
  static const double _bucketExtent = 72;

  final ElevationSummaryService _service = const ElevationSummaryService();
  final ScrollController _scrollController = ScrollController();

  ElevationPeriodPreset _period = ElevationPeriodPreset.last12Months;
  ElevationDisplayMode _mode = ElevationDisplayMode.columns;
  bool _anchoredToLatest = false;
  double _viewportWidth = 0;
  double _maxScrollExtent = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant ElevationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracks != widget.tracks || oldWidget.isLoading != widget.isLoading) {
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

    setState(() => _period = next);
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

  @override
  Widget build(BuildContext context) {
    final child = widget.isLoading
        ? const _ElevationLoadingState()
        : _buildContent();

    return KeyedSubtree(
      key: const Key('elevation-card'),
      child: child,
    );
  }

  Widget _buildContent() {
    final timeline = _service.buildTimeline(
      tracks: widget.tracks,
      period: _period,
      now: widget.now,
    );

    if (timeline.isEmpty) {
      return const _ElevationEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ElevationHeader(
              period: _period,
              totalMetres: timeline.totalMetres,
              averageMetres: timeline.averageMetres,
              onPeriodChanged: _selectPeriod,
              onPrevious: () => _shiftWindow(false),
              onNext: () => _shiftWindow(true),
              canMovePrevious: _canMovePrevious(timeline.buckets.length),
              canMoveNext: _canMoveNext(timeline.buckets.length),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _viewportWidth = constraints.maxWidth;
                  _maxScrollExtent = math.max(
                    0,
                    (timeline.buckets.length * _bucketExtent) - constraints.maxWidth,
                  );
                  _syncScrollPosition(timeline.buckets.length);

                  final visibleBuckets = _visibleBuckets(timeline.buckets, constraints.maxWidth);
                  final visibleTotal = _service.visibleTotalMetres(visibleBuckets);
                  final visibleAverage = _service.visibleAverageMetres(visibleBuckets);

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: _ElevationTimelineStrip(
                          key: const Key('elevation-scroll-view'),
                          controller: _scrollController,
                          buckets: timeline.buckets,
                          mode: _mode,
                          bucketExtent: _bucketExtent,
                          visibleTotal: visibleTotal,
                          visibleAverage: visibleAverage,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: FloatingActionButton.small(
                          key: const Key('elevation-mode-fab'),
                          onPressed: _toggleMode,
                          tooltip: _mode == ElevationDisplayMode.columns
                              ? 'Switch to line view'
                              : 'Switch to column view',
                          child: Icon(
                            _mode == ElevationDisplayMode.columns
                                ? Icons.show_chart
                                : Icons.bar_chart,
                          ),
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
    if (!_scrollController.hasClients || bucketCount == 0) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final target = _anchoredToLatest ? _scrollController.offset.clamp(0.0, _maxScrollExtent) : _maxScrollExtent;
      if (!_anchoredToLatest) {
        _anchoredToLatest = true;
      }

      if ((_scrollController.offset - target).abs() > 0.5) {
        _scrollController.jumpTo(target);
      }
    });
  }

  List<ElevationBucket> _visibleBuckets(List<ElevationBucket> buckets, double viewportWidth) {
    if (buckets.isEmpty) {
      return const [];
    }

    final visibleCount = math.max(1, (viewportWidth / _bucketExtent).floor());
    final maxStartIndex = math.max(0, buckets.length - visibleCount);
    final startIndex = _anchoredToLatest
        ? math.min(
            maxStartIndex,
            (_scrollController.offset / _bucketExtent).floor(),
          )
        : maxStartIndex;
    final endIndex = math.min(buckets.length, startIndex + visibleCount);
    return buckets.sublist(startIndex, endIndex);
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
      child: Text(
        'No elevation data yet',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

class _ElevationHeader extends StatelessWidget {
  const _ElevationHeader({
    required this.period,
    required this.totalMetres,
    required this.averageMetres,
    required this.onPeriodChanged,
    required this.onPrevious,
    required this.onNext,
    required this.canMovePrevious,
    required this.canMoveNext,
  });

  final ElevationPeriodPreset period;
  final int totalMetres;
  final int averageMetres;
  final ValueChanged<ElevationPeriodPreset?> onPeriodChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canMovePrevious;
  final bool canMoveNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<ElevationPeriodPreset>(
                key: const Key('elevation-period-dropdown'),
                value: period,
                onChanged: onPeriodChanged,
                items: ElevationPeriodPreset.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                    )
                    .toList(growable: false),
              ),
              _MetricPill(label: 'Total', value: '$totalMetres m'),
              _MetricPill(label: 'Average', value: '$averageMetres m'),
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
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text('$label $value'),
      ),
    );
  }
}

class _ElevationTimelineStrip extends StatelessWidget {
  const _ElevationTimelineStrip({
    super.key,
    required this.controller,
    required this.buckets,
    required this.mode,
    required this.bucketExtent,
    required this.visibleTotal,
    required this.visibleAverage,
  });

  final ScrollController controller;
  final List<ElevationBucket> buckets;
  final ElevationDisplayMode mode;
  final double bucketExtent;
  final int visibleTotal;
  final int visibleAverage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxAscent = buckets.fold<double>(0, (maxValue, bucket) => math.max(maxValue, bucket.ascentMetres));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Visible: $visibleTotal m average $visibleAverage m'),
        ),
        Expanded(
          child: ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            itemExtent: bucketExtent,
            itemCount: buckets.length,
            itemBuilder: (context, index) {
              final bucket = buckets[index];
              final heightFactor = maxAscent <= 0 ? 0.0 : bucket.ascentMetres / maxAscent;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _ElevationBucketTile(
                  key: Key('elevation-bucket-$index'),
                  bucket: bucket,
                  mode: mode,
                  heightFactor: heightFactor,
                  color: theme.colorScheme.primary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ElevationBucketTile extends StatelessWidget {
  const _ElevationBucketTile({
    super.key,
    required this.bucket,
    required this.mode,
    required this.heightFactor,
    required this.color,
  });

  final ElevationBucket bucket;
  final ElevationDisplayMode mode;
  final double heightFactor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barHeight = 24 + (heightFactor * 84);

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              bucket.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: mode == ElevationDisplayMode.columns ? 18 : 12,
              height: math.max(24, barHeight),
              decoration: BoxDecoration(
                color: mode == ElevationDisplayMode.columns
                    ? color.withValues(alpha: 0.8)
                    : color.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(mode == ElevationDisplayMode.columns ? 8 : 999),
              ),
              child: Center(
                child: Icon(
                  mode == ElevationDisplayMode.columns ? Icons.square : Icons.circle,
                  size: mode == ElevationDisplayMode.columns ? 10 : 8,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${bucket.roundedAscentMetres} m',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
