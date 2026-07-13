import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class DashboardChartYAxisLabelEntry {
  const DashboardChartYAxisLabelEntry({
    required this.text,
    required this.fractionFromTop,
    this.key,
  });

  final String text;
  final double fractionFromTop;
  final Key? key;
}

class DashboardChartYAxisLabels extends StatelessWidget {
  const DashboardChartYAxisLabels({
    super.key,
    required this.entries,
    this.textAlign = TextAlign.right,
    this.padding = const EdgeInsets.only(right: 4),
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final List<DashboardChartYAxisLabelEntry> entries;
  final TextAlign textAlign;
  final EdgeInsets padding;
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textDirection = Directionality.of(context);
        return Padding(
          padding: padding,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final entry in entries)
                Positioned(
                  left: 0,
                  right: 0,
                  top: _dashboardChartAxisLabelTop(
                    fractionFromTop: entry.fractionFromTop,
                    chartHeight: constraints.maxHeight,
                    topInset: topInset,
                    bottomInset: bottomInset,
                    labelStyle: theme.textTheme.labelSmall,
                    labelText: entry.text,
                    textDirection: textDirection,
                  ),
                  child: Text(
                    entry.text,
                    key: entry.key,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: textAlign,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Color dashboardChartSurfaceColor(ThemeData theme) {
  return theme.colorScheme.surfaceContainer;
}

Color dashboardChartGuideColor() {
  final baseColor = thinDivider.color ?? const Color(0xff7b7b7b);
  return baseColor.withValues(alpha: baseColor.a * 0.2);
}

Color dashboardChartAxisColor() {
  final baseColor = thinDivider.color ?? const Color(0xff7b7b7b);
  return baseColor.withValues(alpha: baseColor.a * 0.9);
}

FlGridData dashboardChartGridData({
  required double minY,
  required double maxY,
  required double horizontalInterval,
}) {
  return FlGridData(
    show: true,
    drawVerticalLine: false,
    horizontalInterval: horizontalInterval,
    checkToShowHorizontalLine: (value) => value > minY && value < maxY,
    getDrawingHorizontalLine: (value) => FlLine(
      color: dashboardChartGuideColor(),
      strokeWidth: 1,
      dashArray: const [8, 4],
    ),
  );
}

ExtraLinesData dashboardChartExtraLinesData({
  required double minY,
  required double maxY,
  List<VerticalLine> verticalLines = const [],
}) {
  return ExtraLinesData(
    extraLinesOnTop: true,
    verticalLines: verticalLines,
    horizontalLines: [
      HorizontalLine(
        y: minY,
        color: dashboardChartAxisColor(),
        strokeWidth: 1.5,
      ),
      HorizontalLine(
        y: maxY,
        color: dashboardChartGuideColor(),
        strokeWidth: 1,
        dashArray: const [8, 4],
      ),
    ],
  );
}

double _dashboardChartAxisLabelTop({
  required double fractionFromTop,
  required double chartHeight,
  required double topInset,
  required double bottomInset,
  required TextStyle? labelStyle,
  required String labelText,
  required TextDirection textDirection,
}) {
  final painter = TextPainter(
    text: TextSpan(text: labelText, style: labelStyle),
    maxLines: 1,
    textDirection: textDirection,
  )..layout();

  final plotHeight = math.max(0.0, chartHeight - topInset - bottomInset);
  return topInset + (plotHeight * fractionFromTop) - (painter.height / 2);
}
