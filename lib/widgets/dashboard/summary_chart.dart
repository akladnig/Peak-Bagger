import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/date_formatters.dart';
import '../../services/summary_card_service.dart';
import '../../theme.dart';
import '../dashboard_chart_chrome.dart';

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
    this.tooltipValueTextColors,
    required this.tooltipTitleText,
    required this.yAxisLabelText,
    this.secondarySeriesOnTop = false,
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
  final List<Color> Function(
    BuildContext context,
    SummaryBucket bucket,
    SummaryBucket? secondaryBucket,
  )?
  tooltipValueTextColors;
  final String Function(SummaryBucket bucket, SummaryPeriodPreset period)
  tooltipTitleText;
  final String Function(double value) yAxisLabelText;
  final bool secondarySeriesOnTop;

  @override
  State<SummaryChart> createState() => _SummaryChartState();
}

class _SummaryChartState extends State<SummaryChart> {
  int? _selectedBucketIndex;
  bool _selectedIsPinned = false;
  static const double _tooltipMaxWidth = 220;

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
    final chartSeriesTheme =
        theme.extension<ChartSeriesTheme>() ??
        ChartSeriesTheme.fromColorScheme(theme.colorScheme);
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
    final chartMaxY = widget.chartMaxYFor(
      math.max(maxValue, secondaryMaxValue),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartViewportWidth = math.max<double>(
          constraints.maxWidth - yAxisLabelWidth,
          1,
        );
        final scrollOffset = widget.controller.hasClients
            ? widget.controller.offset
            : 0.0;

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
                      child: DashboardChartYAxisLabels(
                        entries: [
                          for (var index = 0; index <= 4; index++)
                            DashboardChartYAxisLabelEntry(
                              key: Key(
                                '${widget.keyPrefix}-y-axis-label-$index',
                              ),
                              text: widget.yAxisLabelText(
                                chartMaxY - ((chartMaxY / 4) * index),
                              ),
                              fractionFromTop: index / 4,
                            ),
                        ],
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
                        color: dashboardChartAxisColor(),
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
                                        secondarySeriesOnTop:
                                            widget.secondarySeriesOnTop,
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
                                                  ? chartSeriesTheme
                                                        .primarySeriesColor
                                                        .withValues(alpha: 0.10)
                                                  : Colors.transparent,
                                              border: Border(
                                                bottom: BorderSide(
                                                  color:
                                                      _selectedBucketIndex ==
                                                          index
                                                      ? chartSeriesTheme
                                                            .primarySeriesColor
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
                              Builder(
                                builder: (context) {
                                  final selectedBucket =
                                      buckets[_selectedBucketIndex!];
                                  final tooltipTitleText = widget
                                      .tooltipTitleText(
                                        selectedBucket,
                                        widget.period,
                                      );
                                  final tooltipValueTexts = widget
                                      .tooltipValueTexts(
                                        selectedBucket,
                                        secondaryBuckets?[_selectedBucketIndex!],
                                      );
                                  final tooltipValueTextColors = widget
                                      .tooltipValueTextColors
                                      ?.call(
                                        context,
                                        selectedBucket,
                                        secondaryBuckets?[_selectedBucketIndex!],
                                      );
                                  final tooltipWidth = _tooltipWidth(
                                    context: context,
                                    titleText: tooltipTitleText,
                                    valueTexts: tooltipValueTexts,
                                  );

                                  return Positioned(
                                    top: 0,
                                    left: _tooltipLeft(
                                      index: _selectedBucketIndex!,
                                      bucketExtent: widget.bucketExtent,
                                      viewportWidth: chartViewportWidth,
                                      scrollOffset: scrollOffset,
                                      tooltipWidth: tooltipWidth,
                                    ),
                                    child: SizedBox(
                                      width: tooltipWidth,
                                      child: IgnorePointer(
                                        child: _SummaryTooltipCard(
                                          key: Key(
                                            '${widget.keyPrefix}-tooltip',
                                          ),
                                          titleText: tooltipTitleText,
                                          valueTexts: tooltipValueTexts,
                                          valueTextColors:
                                              tooltipValueTextColors,
                                        ),
                                      ),
                                    ),
                                  );
                                },
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

double _tooltipLeft({
  required int index,
  required double bucketExtent,
  required double viewportWidth,
  required double scrollOffset,
  required double tooltipWidth,
}) {
  final bucketCenter = (index * bucketExtent) + (bucketExtent / 2);
  final leftBound = scrollOffset;
  final rightBound = math.max(
    leftBound,
    scrollOffset + viewportWidth - tooltipWidth,
  );
  return (bucketCenter - (tooltipWidth / 2))
      .clamp(leftBound, rightBound)
      .toDouble();
}

double _tooltipWidth({
  required BuildContext context,
  required String titleText,
  required List<String> valueTexts,
}) {
  final theme = Theme.of(context);
  final titleStyle = theme.textTheme.bodyMedium?.copyWith(
    fontWeight: FontWeight.w600,
  );
  final valueStyle = theme.textTheme.bodySmall;
  final titleWidth = _measureTextWidth(context, titleText, titleStyle);
  final valueWidth = valueTexts.fold<double>(
    0,
    (maxWidth, text) =>
        math.max(maxWidth, _measureTextWidth(context, text, valueStyle)),
  );

  const horizontalPadding = 12 * 2;
  const cardMargin = 4 * 2;
  return math
      .min(
        _SummaryChartState._tooltipMaxWidth,
        math.max(titleWidth, valueWidth) + horizontalPadding + cardMargin,
      )
      .ceilToDouble();
}

double _measureTextWidth(BuildContext context, String text, TextStyle? style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width;
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
    final chartSeriesTheme =
        theme.extension<ChartSeriesTheme>() ??
        ChartSeriesTheme.fromColorScheme(theme.colorScheme);

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
                        ? chartSeriesTheme.selectedPrimarySeriesColor
                        : chartSeriesTheme.primarySeriesColor,
                  ),
                  if (secondaryBuckets != null)
                    _seriesRod(
                      value: secondaryBuckets![index].value,
                      width: DashboardUI.rodWidthFor(bucketExtent) / 2,
                      color: index == selectedBucketIndex
                          ? chartSeriesTheme.selectedSecondarySeriesColor
                          : chartSeriesTheme.secondarySeriesColor,
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
                      BarChartRodStackItem(
                        0,
                        buckets[index].value,
                        index == selectedBucketIndex
                            ? chartSeriesTheme.selectedPrimarySeriesColor
                            : chartSeriesTheme.primarySeriesColor,
                      ),
                      if (secondaryBuckets != null &&
                          secondaryBuckets![index].value > 0)
                        BarChartRodStackItem(
                          buckets[index].value,
                          secondaryBuckets![index].value,
                          index == selectedBucketIndex
                              ? chartSeriesTheme.selectedSecondarySeriesColor
                              : chartSeriesTheme.secondarySeriesColor,
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
  return dashboardChartGridData(
    minY: 0,
    maxY: chartMaxY,
    horizontalInterval: chartMaxY / 4,
  );
}

ExtraLinesData _summaryExtraLinesData(double chartMaxY) {
  return dashboardChartExtraLinesData(minY: 0, maxY: chartMaxY);
}

class _SummaryLineChart extends StatelessWidget {
  const _SummaryLineChart({
    required this.buckets,
    required this.secondaryBuckets,
    required this.chartMaxY,
    required this.selectedBucketIndex,
    required this.yAxisLabelText,
    required this.secondarySeriesOnTop,
  });

  final List<SummaryBucket> buckets;
  final List<SummaryBucket>? secondaryBuckets;
  final double chartMaxY;
  final int? selectedBucketIndex;
  final String Function(double value) yAxisLabelText;
  final bool secondarySeriesOnTop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chartSeriesTheme =
        theme.extension<ChartSeriesTheme>() ??
        ChartSeriesTheme.fromColorScheme(theme.colorScheme);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: buckets.length.toDouble(),
        minY: 0,
        maxY: chartMaxY,
        lineBarsData: [
          if (secondarySeriesOnTop && secondaryBuckets != null)
            LineChartBarData(
              spots: [
                for (var index = 0; index < buckets.length; index++)
                  FlSpot(_summaryLineSpotX(index), buckets[index].value),
              ],
              isCurved: true,
              color: chartSeriesTheme.primarySeriesColor,
              barWidth: ChartUI.barWidth,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isSelected = index == selectedBucketIndex;
                  return FlDotCirclePainter(
                    radius: isSelected
                        ? ChartUI.radiusSelected
                        : ChartUI.radius,
                    color: dashboardChartSurfaceColor(theme),
                    strokeColor: isSelected
                        ? chartSeriesTheme.selectedPrimarySeriesColor
                        : chartSeriesTheme.primarySeriesColor,
                    strokeWidth: ChartUI.strokeWidth,
                  );
                },
              ),
            ),
          if (secondaryBuckets != null)
            LineChartBarData(
              spots: [
                for (var index = 0; index < secondaryBuckets!.length; index++)
                  FlSpot(
                    _summaryLineSpotX(index),
                    secondaryBuckets![index].value,
                  ),
              ],
              isCurved: true,
              color: chartSeriesTheme.secondarySeriesColor,
              barWidth: ChartUI.barWidth,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isSelected = index == selectedBucketIndex;
                  return FlDotCirclePainter(
                    radius: isSelected
                        ? ChartUI.radiusSelected
                        : ChartUI.radius,
                    color: dashboardChartSurfaceColor(theme),
                    strokeColor: isSelected
                        ? chartSeriesTheme.selectedSecondarySeriesColor
                        : chartSeriesTheme.secondarySeriesColor,
                    strokeWidth: ChartUI.strokeWidth,
                  );
                },
              ),
            ),
          if (!secondarySeriesOnTop)
            LineChartBarData(
              spots: [
                for (var index = 0; index < buckets.length; index++)
                  FlSpot(_summaryLineSpotX(index), buckets[index].value),
              ],
              isCurved: true,
              color: chartSeriesTheme.primarySeriesColor,
              barWidth: ChartUI.barWidth,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final isSelected = index == selectedBucketIndex;
                  return FlDotCirclePainter(
                    radius: isSelected
                        ? ChartUI.radiusSelected
                        : ChartUI.radius,
                    color: dashboardChartSurfaceColor(theme),
                    strokeColor: isSelected
                        ? chartSeriesTheme.selectedPrimarySeriesColor
                        : chartSeriesTheme.primarySeriesColor,
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

double _summaryLineSpotX(int index) => index.toDouble() + 0.5;

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
                        color: dashboardChartGuideColor(),
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
                          color: dashboardChartGuideColor(),
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
    this.valueTextColors,
  });

  final String titleText;
  final List<String> valueTexts;
  final List<Color>? valueTextColors;

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
              Text(
                valueTexts[index],
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      valueTextColors != null && index < valueTextColors!.length
                      ? valueTextColors![index]
                      : null,
                ),
              ),
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
    SummaryPeriodPreset.yearToDate ||
    SummaryPeriodPreset.allTime => bucket.label,
  };
}
