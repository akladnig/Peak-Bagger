import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/elevation_summary_service.dart';

enum ElevationDisplayMode { columns, line }

class ElevationChart extends StatefulWidget {
  const ElevationChart({
    super.key,
    required this.controller,
    required this.buckets,
    required this.mode,
    required this.bucketExtent,
    required this.visibleTotalMetres,
    required this.visibleAverageMetres,
  });

  final ScrollController controller;
  final List<ElevationBucket> buckets;
  final ElevationDisplayMode mode;
  final double bucketExtent;
  final int visibleTotalMetres;
  final int visibleAverageMetres;

  @override
  State<ElevationChart> createState() => _ElevationChartState();
}

class _ElevationChartState extends State<ElevationChart> {
  int? _selectedBucketIndex;
  bool _selectedIsPinned = false;

  void _selectBucket(int index, {required bool pinned}) {
    setState(() {
      _selectedBucketIndex = index;
      _selectedIsPinned = pinned;
    });
  }

  void _clearHoverSelection(int index) {
    if (_selectedIsPinned) {
      return;
    }
    if (_selectedBucketIndex == index) {
      setState(() {
        _selectedBucketIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = widget.buckets;
    final contentWidth = math.max(widget.bucketExtent * buckets.length, 1).toDouble();
    final maxAscent = buckets.fold<double>(0, (maxValue, bucket) => math.max(maxValue, bucket.ascentMetres));
    final chartMaxY = math.max(1.0, maxAscent * 1.1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Visible: ${widget.visibleTotalMetres} m average ${widget.visibleAverageMetres} m',
            style: theme.textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: widget.controller,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 28),
                      child: widget.mode == ElevationDisplayMode.columns
                          ? _ElevationBarChart(
                              buckets: buckets,
                              chartMaxY: chartMaxY,
                              selectedBucketIndex: _selectedBucketIndex,
                            )
                          : _ElevationLineChart(
                              buckets: buckets,
                              chartMaxY: chartMaxY,
                              selectedBucketIndex: _selectedBucketIndex,
                          ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: _BottomAxisLabels(
                        buckets: buckets,
                        bucketExtent: widget.bucketExtent,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < buckets.length; index++)
                          SizedBox(
                            width: widget.bucketExtent,
                            child: MouseRegion(
                              key: Key('elevation-bucket-$index'),
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => _selectBucket(index, pinned: false),
                              onExit: (_) => _clearHoverSelection(index),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _selectBucket(index, pinned: true),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  decoration: BoxDecoration(
                                    color: _selectedBucketIndex == index
                                        ? theme.colorScheme.primary.withValues(alpha: 0.10)
                                        : Colors.transparent,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: _selectedBucketIndex == index
                                            ? theme.colorScheme.primary
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_selectedBucketIndex != null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: _ElevationTooltipCard(
                            key: const Key('elevation-tooltip'),
                            bucket: buckets[_selectedBucketIndex!],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ElevationBarChart extends StatelessWidget {
  const _ElevationBarChart({
    required this.buckets,
    required this.chartMaxY,
    required this.selectedBucketIndex,
  });

  final List<ElevationBucket> buckets;
  final double chartMaxY;
  final int? selectedBucketIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: chartMaxY,
        alignment: BarChartAlignment.spaceAround,
        barGroups: [
          for (var index = 0; index < buckets.length; index++)
            BarChartGroupData(
              x: index,
              barsSpace: 20,
              barRods: [
                BarChartRodData(
                  toY: buckets[index].ascentMetres,
                  width: 24,
                  borderRadius: BorderRadius.circular(6),
                  color: index == selectedBucketIndex
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.primary,
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: const BarTouchData(enabled: false),
      ),
    );
  }
}

class _ElevationLineChart extends StatelessWidget {
  const _ElevationLineChart({
    required this.buckets,
    required this.chartMaxY,
    required this.selectedBucketIndex,
  });

  final List<ElevationBucket> buckets;
  final double chartMaxY;
  final int? selectedBucketIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(0, buckets.length - 1).toDouble(),
        minY: 0,
        maxY: chartMaxY,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < buckets.length; index++)
                FlSpot(index.toDouble(), buckets[index].ascentMetres),
            ],
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isSelected = index == selectedBucketIndex;
                return FlDotCirclePainter(
                  radius: isSelected ? 5 : 3,
                  color: isSelected ? theme.colorScheme.tertiary : theme.colorScheme.primary,
                  strokeWidth: 0,
                );
              },
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}

class _BottomAxisLabels extends StatelessWidget {
  const _BottomAxisLabels({required this.buckets, required this.bucketExtent});

  final List<ElevationBucket> buckets;
  final double bucketExtent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final bucket in buckets)
            SizedBox(
              width: bucketExtent,
              child: Center(
                child: Text(
                  bucket.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ElevationTooltipCard extends StatelessWidget {
  const _ElevationTooltipCard({super.key, required this.bucket});

  final ElevationBucket bucket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 6,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              bucket.label,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('${bucket.roundedAscentMetres} m', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
