import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/date_formatters.dart';
import '../../services/summary_card_service.dart';
import '../../theme.dart';

enum SummaryBarSeriesStyle { stacked, grouped }

enum SummaryDisplayMode { columns, line }

class SummaryChart extends StatefulWidget {
  const SummaryChart({
    super.key,
    required this.keyPrefix,
    required this.controller,
    required this.buckets,
    this.secondaryBuckets,
    required this.mode,
    required this.barSeriesStyle,
    required this.bucketExtent,
    required this.period,
    required this.referenceDate,
    required this.chartMaxYFor,
    required this.tooltipValueTexts,
    required this.tooltipTitleText,
    required this.yAxisLabelText,
  });

  final String keyPrefix;
  final ScrollController controller;
  final List<SummaryBucket> buckets;
  final List<SummaryBucket>? secondaryBuckets;
  final SummaryDisplayMode mode;
  final SummaryBarSeriesStyle barSeriesStyle;
  final double bucketExtent;
  final SummaryPeriodPreset period;
  final DateTime referenceDate;
  final double Function(double maxValue) chartMaxYFor;
  final List<String> Function(
    SummaryBucket bucket,
    SummaryBucket? secondaryBucket,
  )
  tooltipValueTexts;
  final String Function(SummaryBucket bucket, SummaryPeriodPreset period)
  tooltipTitleText;
  final String Function(double value) yAxisLabelText;

  @override
  State<SummaryChart> createState() => _SummaryChartState();
}

class _SummaryChartState extends State<SummaryChart> {
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
      setState(() => _selectedBucketIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buckets = widget.buckets;
    final secondaryBuckets = widget.secondaryBuckets;
    final bucketContentWidth = math.max<double>(
      (widget.bucketExtent * buckets.length).ceilToDouble() + 0.01,
      1,
    );
    final maxValue = buckets.fold<double>(
      0,
      (maxValue, bucket) => math.max(maxValue, bucket.value),
    );
    final secondaryMaxValue =
        secondaryBuckets?.fold<double>(
          0,
          (maxValue, bucket) => math.max(maxValue, bucket.value),
        ) ??
        0;
    const yAxisLabelWidth = DashboardUI.yAxisLabelWidth;
    final chartMaxY = widget.chartMaxYFor(math.max(maxValue, secondaryMaxValue));
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartViewportWidth = math.max<double>(
          constraints.maxWidth - yAxisLabelWidth,
          1,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 20,
                    bottom: 28,
                    width: yAxisLabelWidth,
                    child: IgnorePointer(
                      child: _YAxisLabels(
                        keyPrefix: widget.keyPrefix,
                        chartMaxY: chartMaxY,
                        yAxisLabelText: widget.yAxisLabelText,
                      ),
                    ),
                  ),
                  // Draw the y-axis
                  Positioned(
                    left: yAxisLabelWidth,
                    top: 20,
                    bottom: 28,
                    child: IgnorePointer(
                      child: ColoredBox(
                        key: Key('${widget.keyPrefix}-y-axis-separator'),
                        color: _axisColor(),
                        child: const SizedBox(width: 1),
                      ),
                    ),
                  ),
                  Positioned(
                    left: yAxisLabelWidth,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: SingleChildScrollView(
                      controller: widget.controller,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: math.max(bucketContentWidth, chartViewportWidth),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 20,
                                  bottom: 28,
                                ),
                                child: widget.mode == SummaryDisplayMode.columns
                                    ? _SummaryBarChart(
                                        buckets: buckets,
                                        secondaryBuckets: secondaryBuckets,
                                        chartMaxY: chartMaxY,
                                        selectedBucketIndex:
                                            _selectedBucketIndex,
                                        bucketExtent: widget.bucketExtent,
                                        style: widget.barSeriesStyle,
                                        yAxisLabelText: widget.yAxisLabelText,
                                      )
                                    : _SummaryLineChart(
                                        buckets: buckets,
                                        secondaryBuckets: secondaryBuckets,
                                        chartMaxY: chartMaxY,
                                        selectedBucketIndex:
                                            _selectedBucketIndex,
                                        yAxisLabelText: widget.yAxisLabelText,
                                      ),
                              ),
                            ),
                            if (DashboardUI.fullHeightLabelGuides)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: _VerticalLabelGuides(
                                    buckets: buckets,
                                    bucketExtent: widget.bucketExtent,
                                    period: widget.period,
                                    referenceDate: widget.referenceDate,
                                  ),
                                ),
                              ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                child: _BottomAxisLabels(
                                  keyPrefix: widget.keyPrefix,
                                  buckets: buckets,
                                  bucketExtent: widget.bucketExtent,
                                  period: widget.period,
                                  referenceDate: widget.referenceDate,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (
                                    var index = 0;
                                    index < buckets.length;
                                    index++
                                  )
                                    SizedBox(
                                      width: widget.bucketExtent,
                                      child: MouseRegion(
                                        key: Key(
                                          '${widget.keyPrefix}-bucket-$index',
                                        ),
                                        cursor: SystemMouseCursors.click,
                                        onEnter: (_) =>
                                            _selectBucket(index, pinned: false),
                                        onExit: (_) =>
                                            _clearHoverSelection(index),
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => _selectBucket(
                                            index,
                                            pinned: true,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 120,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  _selectedBucketIndex == index
                                                  ? theme.colorScheme.primary
                                                        .withValues(alpha: 0.10)
                                                  : Colors.transparent,
                                              border: Border(
                                                bottom: BorderSide(
                                                  color:
                                                      _selectedBucketIndex ==
                                                          index
                                                      ? theme
                                                            .colorScheme
                                                            .primary
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
                                left:
                                    (_selectedBucketIndex! *
                                        widget.bucketExtent) +
                                    (widget.bucketExtent / 2),
                                child: FractionalTranslation(
                                  translation: const Offset(-0.5, 0),
                                  child: IgnorePointer(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 220,
                                      ),
                                      child: _SummaryTooltipCard(
                                        key: Key('${widget.keyPrefix}-tooltip'),
                                        titleText: widget.tooltipTitleText(
                                          buckets[_selectedBucketIndex!],
                                          widget.period,
                                        ),
                                        valueTexts: widget.tooltipValueTexts(
                                          buckets[_selectedBucketIndex!],
                                          secondaryBuckets?[_selectedBucketIndex!],
                                        ),
                                      ),
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
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryBarChart extends StatelessWidget {
  const _SummaryBarChart({
    required this.buckets,
    required this.secondaryBuckets,
    required this.chartMaxY,
    required this.selectedBucketIndex,
    required this.bucketExtent,
    required this.style,
    required this.yAxisLabelText,
  });

  final List<SummaryBucket> buckets;
  final List<SummaryBucket>? secondaryBuckets;
  final double chartMaxY;
  final int? selectedBucketIndex;
  final double bucketExtent;
  final SummaryBarSeriesStyle style;
  final String Function(double value) yAxisLabelText;

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
            switch (style) {
              SummaryBarSeriesStyle.grouped => BarChartGroupData(
                x: index,
                barsSpace: 6,
                barRods: [
                  _seriesRod(
                    value: buckets[index].value,
                    width: DashboardUI.rodWidthFor(bucketExtent) / 2,
                    color: index == selectedBucketIndex
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.primary,
                  ),
                  if (secondaryBuckets != null)
                    _seriesRod(
                      value: secondaryBuckets![index].value,
                      width: DashboardUI.rodWidthFor(bucketExtent) / 2,
                      color: _secondarySeriesColor,
                    ),
                ],
              ),
              SummaryBarSeriesStyle.stacked => BarChartGroupData(
                x: index,
                barsSpace: 0,
                barRods: [
                  BarChartRodData(
                    toY: secondaryBuckets == null
                        ? buckets[index].value
                        : math.max(
                            buckets[index].value,
                            secondaryBuckets![index].value,
                          ),
                    width: DashboardUI.rodWidthFor(bucketExtent),
                    borderRadius: BorderRadius.circular(DashboardUI.rodRadius),
                    color: Colors.transparent,
                    rodStackItems: [
                      if (secondaryBuckets != null &&
                          secondaryBuckets![index].value < buckets[index].value)
                        BarChartRodStackItem(
                          0,
                          secondaryBuckets![index].value,
                          _secondarySeriesColor,
                        ),
                      BarChartRodStackItem(
                        secondaryBuckets != null &&
                                secondaryBuckets![index].value <
                                    buckets[index].value
                            ? secondaryBuckets![index].value
                            : 0,
                        buckets[index].value,
                        index == selectedBucketIndex
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.primary,
                      ),
                      if (secondaryBuckets != null &&
                          secondaryBuckets![index].value > buckets[index].value)
                        BarChartRodStackItem(
                          buckets[index].value,
                          secondaryBuckets![index].value,
                          _secondarySeriesColor,
                        ),
                    ],
                  ),
                ],
              ),
            },
        ],
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: _summaryGridData(chartMaxY),
        extraLinesData: _summaryExtraLinesData(chartMaxY),
        borderData: FlBorderData(show: false),
        barTouchData: const BarTouchData(enabled: false),
      ),
    );
  }
}

BarChartRodData _seriesRod({
  required double value,
  required double width,
  required Color color,
}) {
  return BarChartRodData(
    toY: value,
    width: width,
    borderRadius: BorderRadius.circular(DashboardUI.rodRadius),
    color: color,
  );
}

FlGridData _summaryGridData(double chartMaxY) {
  final interval = chartMaxY / 4;

  return FlGridData(
    show: true,
    drawVerticalLine: false,
    horizontalInterval: interval,
    checkToShowHorizontalLine: (value) => value > 0 && value < chartMaxY,
    getDrawingHorizontalLine: (value) =>
        FlLine(color: _guideColor(), strokeWidth: 1, dashArray: [8, 4]),
  );
}

ExtraLinesData _summaryExtraLinesData(double chartMaxY) {
  return ExtraLinesData(
    extraLinesOnTop: true,
    horizontalLines: [
      HorizontalLine(y: 0, color: _axisColor(), strokeWidth: 1.5),
      HorizontalLine(
        y: chartMaxY,
        color: _guideColor(),
        strokeWidth: 1,
        dashArray: [8, 4],
      ),
    ],
  );
}

Color _guideColor() {
  final baseColor = thinDivider.color ?? const Color(0xff7b7b7b);
  return baseColor.withValues(alpha: baseColor.a * 0.2);
}

Color _axisColor() {
  final baseColor = thinDivider.color ?? const Color(0xff7b7b7b);
  return baseColor.withValues(alpha: baseColor.a * 0.9);
}

class _SummaryLineChart extends StatelessWidget {
  const _SummaryLineChart({
    required this.buckets,
    required this.secondaryBuckets,
    required this.chartMaxY,
    required this.selectedBucketIndex,
    required this.yAxisLabelText,
  });

  final List<SummaryBucket> buckets;
  final List<SummaryBucket>? secondaryBuckets;
  final double chartMaxY;
  final int? selectedBucketIndex;
  final String Function(double value) yAxisLabelText;

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
          if (secondaryBuckets != null)
            LineChartBarData(
              spots: [
                for (var index = 0; index < secondaryBuckets!.length; index++)
                  FlSpot(index.toDouble(), secondaryBuckets![index].value),
              ],
              isCurved: true,
              color: _secondarySeriesColor,
              barWidth: ChartUI.barWidth,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isSelected = index == selectedBucketIndex;
                  return FlDotCirclePainter(
                    radius: isSelected
                        ? ChartUI.radiusSelected
                        : ChartUI.radius,
                    color: theme.colorScheme.surfaceContainer,
                    strokeColor: isSelected
                        ? ChartUI.colourSelected
                        : ChartUI.colour,
                    strokeWidth: ChartUI.strokeWidth,
                  );
                },
              ),
            ),
          LineChartBarData(
            spots: [
              for (var index = 0; index < buckets.length; index++)
                FlSpot(index.toDouble(), buckets[index].value),
            ],
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: ChartUI.barWidth,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isSelected = index == selectedBucketIndex;
                return FlDotCirclePainter(
                  radius: isSelected ? ChartUI.radiusSelected : ChartUI.radius,
                  color: theme.colorScheme.surfaceContainer,
                  strokeColor: isSelected
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.primary,
                  strokeWidth: ChartUI.strokeWidth,
                );
              },
            ),
          ),
        ],
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: _summaryGridData(chartMaxY),
        extraLinesData: _summaryExtraLinesData(chartMaxY),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }
}

class _YAxisLabels extends StatelessWidget {
  const _YAxisLabels({
    required this.keyPrefix,
    required this.chartMaxY,
    required this.yAxisLabelText,
  });

  final String keyPrefix;
  final double chartMaxY;
  final String Function(double value) yAxisLabelText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelValues = _yAxisLabelValues(chartMaxY);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textDirection = Directionality.of(context);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index <= 4; index++)
              Positioned(
                left: 0,
                right: 4,
                top: _yAxisLabelTop(
                  index: index,
                  chartHeight: constraints.maxHeight,
                  labelStyle: theme.textTheme.labelSmall,
                  labelText: yAxisLabelText(labelValues[index]),
                  textDirection: textDirection,
                ),
                child: Text(
                  yAxisLabelText(labelValues[index]),
                  key: Key('$keyPrefix-y-axis-label-$index'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.right,
                ),
              ),
          ],
        );
      },
    );
  }
}

List<double> _yAxisLabelValues(double chartMaxY) {
  final interval = chartMaxY / 4;
  return [for (var index = 0; index <= 4; index++) chartMaxY - (interval * index)];
}

double _yAxisLabelTop({
  required int index,
  required double chartHeight,
  required TextStyle? labelStyle,
  required String labelText,
  required TextDirection textDirection,
}) {
  final painter = TextPainter(
    text: TextSpan(text: labelText, style: labelStyle),
    maxLines: 1,
    textDirection: textDirection,
  )..layout();

  final interval = chartHeight / 4;
  return (interval * index) - (painter.height / 2);
}

class _BottomAxisLabels extends StatelessWidget {
  const _BottomAxisLabels({
    required this.keyPrefix,
    required this.buckets,
    required this.bucketExtent,
    required this.period,
    required this.referenceDate,
  });

  final String keyPrefix;
  final List<SummaryBucket> buckets;
  final double bucketExtent;
  final SummaryPeriodPreset period;
  final DateTime referenceDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < buckets.length; index++)
            SizedBox(
              width: bucketExtent,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (!DashboardUI.fullHeightLabelGuides &&
                      _axisLabelFor(
                        index: index,
                        buckets: buckets,
                        period: period,
                        referenceDate: referenceDate,
                      ).isNotEmpty)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: ColoredBox(
                        color: _guideColor(),
                        child: const SizedBox(width: 1),
                      ),
                    ),
                  _labelWidget(index, theme),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _labelWidget(int index, ThemeData theme) {
    final label = _axisLabelFor(
      index: index,
      buckets: buckets,
      period: period,
      referenceDate: referenceDate,
    );
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }

    if (period == SummaryPeriodPreset.month ||
        period == SummaryPeriodPreset.last3Months ||
        period == SummaryPeriodPreset.last6Months) {
      return Positioned.fill(
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _labelSpanWidth(index),
            child: Padding(
              padding: EdgeInsets.only(
                left: period == SummaryPeriodPreset.month ? 2 : 4,
              ),
              child: Text(
                key: Key('$keyPrefix-bottom-axis-label-$index'),
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Text(
        key: Key('$keyPrefix-bottom-axis-label-$index'),
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall,
      ),
    );
  }

  double _labelSpanWidth(int index) {
    var span = 1;
    for (var nextIndex = index + 1; nextIndex < buckets.length; nextIndex++) {
      final nextLabel = _axisLabelFor(
        index: nextIndex,
        buckets: buckets,
        period: period,
        referenceDate: referenceDate,
      );
      if (nextLabel.isNotEmpty) {
        break;
      }
      span += 1;
    }
    return span * bucketExtent;
  }
}

class _VerticalLabelGuides extends StatelessWidget {
  const _VerticalLabelGuides({
    required this.buckets,
    required this.bucketExtent,
    required this.period,
    required this.referenceDate,
  });

  final List<SummaryBucket> buckets;
  final double bucketExtent;
  final SummaryPeriodPreset period;
  final DateTime referenceDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < buckets.length; index++)
          SizedBox(
            width: bucketExtent,
            child: Align(
              alignment: Alignment.centerLeft,
              child:
                  _axisLabelFor(
                    index: index,
                    buckets: buckets,
                    period: period,
                    referenceDate: referenceDate,
                  ).isNotEmpty
                  ? SizedBox(
                      width: 1,
                      height: double.infinity,
                      child: CustomPaint(
                        painter: _DashedVerticalLinePainter(
                          color: _guideColor(),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}

class _DashedVerticalLinePainter extends CustomPainter {
  const _DashedVerticalLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashLength = 8.0;
    const gapLength = 4.0;
    final x = size.width / 2;

    var startY = 0.0;
    while (startY < size.height) {
      final endY = math.min(startY + dashLength, size.height);
      canvas.drawLine(Offset(x, startY), Offset(x, endY), paint);
      startY += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedVerticalLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

String _axisLabelFor({
  required int index,
  required List<SummaryBucket> buckets,
  required SummaryPeriodPreset period,
  required DateTime referenceDate,
}) {
  final bucket = buckets[index];

  if (period == SummaryPeriodPreset.month) {
    final dayDelta = _dateOnlyDifferenceInDays(bucket.start, referenceDate);
    return dayDelta % 7 == 0 ? bucket.label : '';
  }

  if (period == SummaryPeriodPreset.last3Months ||
      period == SummaryPeriodPreset.last6Months) {
    if (index == 0) {
      return bucket.label;
    }

    final previousBucket = buckets[index - 1];
    final startsNewMonth =
        previousBucket.start.month != bucket.start.month ||
        previousBucket.start.year != bucket.start.year;
    return startsNewMonth ? bucket.label : '';
  }

  return bucket.label;
}

int _dateOnlyDifferenceInDays(DateTime a, DateTime b) {
  final aUtc = DateTime.utc(a.year, a.month, a.day);
  final bUtc = DateTime.utc(b.year, b.month, b.day);
  return aUtc.difference(bUtc).inDays;
}

class _SummaryTooltipCard extends StatelessWidget {
  const _SummaryTooltipCard({
    super.key,
    required this.titleText,
    required this.valueTexts,
  });

  final String titleText;
  final List<String> valueTexts;

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
              titleText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            for (var index = 0; index < valueTexts.length; index++) ...[
              SizedBox(height: index == 0 ? 4 : 2),
              Text(valueTexts[index], style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

String defaultTooltipTitleText(
  SummaryBucket bucket,
  SummaryPeriodPreset period,
) {
  return switch (period) {
    SummaryPeriodPreset.week ||
    SummaryPeriodPreset.month ||
    SummaryPeriodPreset.last3Months ||
    SummaryPeriodPreset.last6Months => formatSummaryDayMonth(bucket.start),
    SummaryPeriodPreset.last12Months ||
    SummaryPeriodPreset.allTime => bucket.label,
  };
}

const _secondarySeriesColor = Color(0xFF2E7D32);
