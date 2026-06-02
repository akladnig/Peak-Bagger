import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/constants.dart';
import '../core/number_formatters.dart';
import '../theme.dart';
import '../services/elevation_profile_series_builder.dart';

enum ElevationProfileAxisMode { distance, time }

class ElevationProfileChart extends StatefulWidget {
  const ElevationProfileChart({
    super.key,
    required this.series,
    this.isLoading = false,
    this.errorText,
  });

  final ElevationProfileSeries series;
  final bool isLoading;
  final String? errorText;

  @override
  State<ElevationProfileChart> createState() => _ElevationProfileChartState();
}

class _ElevationProfileChartState extends State<ElevationProfileChart> {
  var _axisMode = ElevationProfileAxisMode.distance;

  @override
  void didUpdateWidget(covariant ElevationProfileChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_supportsTimeAxis && _axisMode == ElevationProfileAxisMode.time) {
      _axisMode = ElevationProfileAxisMode.distance;
    }
  }

  bool get _supportsTimeAxis => widget.series.supportsTimeAxis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final series = widget.series;
    final hasUsablePoints = series.hasUsableElevation;

    return Card(
      key: const Key('elevation-profile-chart'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: DashboardUI.cardBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Elevation profile', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (hasUsablePoints) _buildAxisChips(context),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _buildStateBody(context, hasUsablePoints),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAxisChips(BuildContext context) {
    final supportsTimeAxis = _supportsTimeAxis;
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          key: const Key('elevation-profile-distance-toggle'),
          label: const Text('Distance'),
          selected: _axisMode == ElevationProfileAxisMode.distance,
          onSelected: (selected) {
            if (selected) {
              setState(() => _axisMode = ElevationProfileAxisMode.distance);
            }
          },
        ),
        ChoiceChip(
          key: const Key('elevation-profile-time-toggle'),
          label: const Text('Time'),
          selected: _axisMode == ElevationProfileAxisMode.time,
          onSelected: supportsTimeAxis
              ? (selected) {
                  if (selected) {
                    setState(() => _axisMode = ElevationProfileAxisMode.time);
                  }
                }
              : null,
          selectedColor: theme.colorScheme.primaryContainer,
          disabledColor: theme.colorScheme.surfaceContainer,
        ),
      ],
    );
  }

  Widget _buildStateBody(BuildContext context, bool hasUsablePoints) {
    if (widget.isLoading && !hasUsablePoints) {
      return _ElevationProfileStateMessage(
        key: const Key('elevation-profile-loading-state'),
        icon: Icons.hourglass_top,
        message: 'Sampling elevation...',
      );
    }

    if (widget.errorText != null && !hasUsablePoints) {
      return _ElevationProfileStateMessage(
        key: const Key('elevation-profile-error-state'),
        icon: Icons.error_outline,
        message: widget.errorText!,
      );
    }

    if (!hasUsablePoints) {
      return const _ElevationProfileStateMessage(
        key: Key('elevation-profile-empty-state'),
        icon: Icons.show_chart,
        message: 'No elevation data yet',
      );
    }

    return SizedBox(height: 220, child: LineChart(_buildChartData(context)));
  }

  LineChartData _buildChartData(BuildContext context) {
    final theme = Theme.of(context);
    final series = widget.series;
    final axisMode =
        _supportsTimeAxis && _axisMode == ElevationProfileAxisMode.time
        ? ElevationProfileAxisMode.time
        : ElevationProfileAxisMode.distance;

    final segments = _segmentsForAxis(axisMode, series.samples);
    final minX = _minX(axisMode, series.samples);
    final maxX = _maxX(axisMode, series.samples, minX);
    final maxY = _maxY(series.samples);
    final xInterval = _axisInterval(minX, maxX);
    final yInterval = maxY / 4;

    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: 0,
      maxY: maxY,
      lineBarsData: [
        for (final segment in segments)
          LineChartBarData(
            spots: segment,
            isCurved: false,
            color: theme.colorScheme.primary,
            barWidth: ChartUI.barWidth,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: ChartUI.radius,
                  color: theme.colorScheme.surfaceContainer,
                  strokeColor: theme.colorScheme.primary,
                  strokeWidth: ChartUI.strokeWidth,
                );
              },
            ),
          ),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 56,
            interval: yInterval,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  formatElevation(value.round()),
                  style: theme.textTheme.labelSmall,
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: xInterval,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                meta: meta,
                child: Text(
                  _formatXAxisLabel(value, axisMode),
                  style: theme.textTheme.labelSmall,
                ),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: yInterval,
        checkToShowHorizontalLine: (value) => value > 0 && value < maxY,
        getDrawingHorizontalLine: (value) => FlLine(
          color: _guideColor(),
          strokeWidth: 1,
          dashArray: const [8, 4],
        ),
      ),
      extraLinesData: ExtraLinesData(
        extraLinesOnTop: true,
        horizontalLines: [
          HorizontalLine(y: 0, color: _axisColor(), strokeWidth: 1.5),
          HorizontalLine(
            y: maxY,
            color: _guideColor(),
            strokeWidth: 1,
            dashArray: const [8, 4],
          ),
        ],
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) {
            return spots
                .map((spot) {
                  return LineTooltipItem(
                    '${_formatXAxisLabel(spot.x, axisMode)}\n${formatElevation(spot.y.round())}',
                    (theme.textTheme.labelSmall ?? const TextStyle()).copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  );
                })
                .toList(growable: false);
          },
        ),
      ),
    );
  }

  List<List<FlSpot>> _segmentsForAxis(
    ElevationProfileAxisMode axisMode,
    List<ElevationProfileSample> samples,
  ) {
    final segments = <List<FlSpot>>[];
    var current = <FlSpot>[];

    void flush() {
      if (current.isNotEmpty) {
        segments.add(List<FlSpot>.unmodifiable(current));
        current = <FlSpot>[];
      }
    }

    for (final sample in samples) {
      final x = switch (axisMode) {
        ElevationProfileAxisMode.distance => sample.distanceMeters,
        ElevationProfileAxisMode.time =>
          sample.timeLocal?.millisecondsSinceEpoch.toDouble(),
      };
      final y = sample.elevationMeters;
      if (x == null || y == null) {
        flush();
        continue;
      }
      current.add(FlSpot(x, y));
    }

    flush();
    return segments;
  }

  double _minX(
    ElevationProfileAxisMode axisMode,
    List<ElevationProfileSample> samples,
  ) {
    final values = _xValues(axisMode, samples);
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce(math.min);
  }

  double _maxX(
    ElevationProfileAxisMode axisMode,
    List<ElevationProfileSample> samples,
    double minX,
  ) {
    final values = _xValues(axisMode, samples);
    if (values.isEmpty) {
      return 1;
    }
    final maxX = values.reduce(math.max);
    if (maxX == minX) {
      return maxX + 1;
    }
    return maxX;
  }

  List<double> _xValues(
    ElevationProfileAxisMode axisMode,
    List<ElevationProfileSample> samples,
  ) {
    final values = <double>[];
    for (final sample in samples) {
      final value = switch (axisMode) {
        ElevationProfileAxisMode.distance => sample.distanceMeters,
        ElevationProfileAxisMode.time =>
          sample.timeLocal?.millisecondsSinceEpoch.toDouble(),
      };
      if (value != null) {
        values.add(value);
      }
    }
    return values;
  }

  double _maxY(List<ElevationProfileSample> samples) {
    final values = [
      for (final sample in samples)
        if (sample.elevationMeters != null) sample.elevationMeters!,
    ];
    if (values.isEmpty) {
      return 1;
    }
    final maxY = values.reduce(math.max);
    return maxY <= 0 ? 1 : maxY;
  }

  double _axisInterval(double minX, double maxX) {
    final span = maxX - minX;
    if (span <= 0) {
      return 1;
    }
    return span / 4;
  }

  String _formatXAxisLabel(double value, ElevationProfileAxisMode axisMode) {
    return switch (axisMode) {
      ElevationProfileAxisMode.distance => formatDistance(value),
      ElevationProfileAxisMode.time => DateFormat(
        'HH:mm',
      ).format(DateTime.fromMillisecondsSinceEpoch(value.round())),
    };
  }
}

class _ElevationProfileStateMessage extends StatelessWidget {
  const _ElevationProfileStateMessage({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(message, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

Color _guideColor() {
  final baseColor = thinDivider.color ?? const Color(0xff7b7b7b);
  return baseColor.withValues(alpha: baseColor.a * 0.2);
}

Color _axisColor() {
  final baseColor = thinDivider.color ?? const Color(0xff7b7b7b);
  return baseColor.withValues(alpha: baseColor.a * 0.9);
}
