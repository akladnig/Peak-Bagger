import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:peak_bagger/theme.dart';

import '../core/constants.dart';
import '../core/number_formatters.dart';
import '../widgets/dashboard_chart_chrome.dart';
import '../services/elevation_profile_series_builder.dart';

enum ElevationProfileAxisMode { distance, time }

enum _DistanceAxisUnit { meters, kilometers }

class ElevationProfileChartHoverSample {
  const ElevationProfileChartHoverSample({
    required this.sampleIndex,
    required this.sample,
    required this.xValue,
    required this.axisMode,
  });

  final int sampleIndex;
  final ElevationProfileSample sample;
  final double xValue;
  final ElevationProfileAxisMode axisMode;
}

class ElevationProfileChart extends StatefulWidget {
  const ElevationProfileChart({
    super.key,
    required this.series,
    this.isLoading = false,
    this.errorText,
    this.minElevation,
    this.maxElevation,
    this.onHoverChanged,
  });

  final ElevationProfileSeries series;
  final bool isLoading;
  final String? errorText;
  final double? minElevation;
  final double? maxElevation;
  final ValueChanged<ElevationProfileChartHoverSample?>? onHoverChanged;

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
    final series = widget.series;
    final hasUsablePoints = series.hasUsableElevation;

    return Column(
      key: const Key('elevation-profile-chart'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: _buildStateBody(context, hasUsablePoints),
        ),
        if (hasUsablePoints) ...[
          const SizedBox(height: 12),
          Center(child: _buildAxisChips(context)),
        ],
      ],
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
          selectedColor: theme.seedColour,
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

    final axisRange = _axisRange(
      widget.series.samples,
      minElevation: widget.minElevation,
      maxElevation: widget.maxElevation,
    );
    final yAxisEntries = [
      DashboardChartYAxisLabelEntry(
        text: formatElevation(axisRange.maxY.round(), showUnits: false),
        fractionFromTop: 0,
      ),
      DashboardChartYAxisLabelEntry(
        text: formatElevation(
          (axisRange.minY + (axisRange.step * 3)).round(),
          showUnits: false,
        ),
        fractionFromTop: 0.25,
      ),
      DashboardChartYAxisLabelEntry(
        text: formatElevation(
          (axisRange.minY + (axisRange.step * 2)).round(),
          showUnits: false,
        ),
        fractionFromTop: 0.5,
      ),
      DashboardChartYAxisLabelEntry(
        text: formatElevation(
          (axisRange.minY + axisRange.step).round(),
          showUnits: false,
        ),
        fractionFromTop: 0.75,
      ),
      const DashboardChartYAxisLabelEntry(text: 'm', fractionFromTop: 1),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dashboardChartSurfaceColor(Theme.of(context)),
        borderRadius: DashboardUI.cardBorderRadius,
      ),
      child: SizedBox(
        height: 220,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final series = widget.series;
            final axisMode =
                _supportsTimeAxis && _axisMode == ElevationProfileAxisMode.time
                ? ElevationProfileAxisMode.time
                : ElevationProfileAxisMode.distance;
            final segments = _segmentsForAxis(axisMode, series.samples);
            final hoverSamples = _hoverSamplesForAxis(axisMode, series.samples);
            final minX = _minX(axisMode, series.samples);
            final maxX = _maxX(axisMode, series.samples, minX);
            final distanceAxisUnit = _distanceAxisUnit(maxX);
            final xGuideValues = _xGuideValues(minX, maxX);
            final chart = LineChart(
              _buildChartData(
                context,
                axisRange,
                axisMode: axisMode,
                distanceAxisUnit: distanceAxisUnit,
                xGuideValues: xGuideValues,
                segments: segments,
                hoverSamples: hoverSamples,
                minX: minX,
                maxX: maxX,
                onHoverChanged: widget.onHoverChanged,
              ),
            );

            if (constraints.maxWidth < 120) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: chart),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 24,
                      child: _buildXAxisLabels(
                        context,
                        axisMode: axisMode,
                        distanceAxisUnit: distanceAxisUnit,
                        xGuideValues: xGuideValues,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _yAxisRailWidth(
                    context: context,
                    entries: yAxisEntries,
                  ),
                  child: DashboardChartYAxisLabels(
                    entries: yAxisEntries,
                    textAlign: TextAlign.right,
                    padding: EdgeInsets.zero,
                    bottomInset: 28,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: chart),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 24,
                          child: _buildXAxisLabels(
                            context,
                            axisMode: axisMode,
                            distanceAxisUnit: distanceAxisUnit,
                            xGuideValues: xGuideValues,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  LineChartData _buildChartData(
    BuildContext context,
    _ElevationAxisRange axisRange, {
    required ElevationProfileAxisMode axisMode,
    required _DistanceAxisUnit distanceAxisUnit,
    required List<double> xGuideValues,
    required List<_ChartSegment> segments,
    required List<_ChartSample> hoverSamples,
    required double minX,
    required double maxX,
    required ValueChanged<ElevationProfileChartHoverSample?>? onHoverChanged,
  }) {
    final theme = Theme.of(context);
    final minY = axisRange.minY;
    final maxY = axisRange.maxY;
    final yGuideValues = _horizontalGuideValues(minY, maxY);

    return LineChartData(
      backgroundColor: dashboardChartSurfaceColor(theme),
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        for (final segment in segments)
          LineChartBarData(
            spots: segment.spots,
            isCurved: false,
            color: theme.seedColour,
            barWidth: ChartUI.barWidth,
            dotData: const FlDotData(show: false),
          ),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: false,
            reservedSize: 0,
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
          sideTitles: SideTitles(showTitles: false, reservedSize: 0),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      gridData: const FlGridData(show: false),
      extraLinesData: ExtraLinesData(
        extraLinesOnTop: true,
        verticalLines: [
          for (var index = 0; index < xGuideValues.length; index++)
            VerticalLine(
              x: xGuideValues[index],
              color: index == 0
                  ? dashboardChartAxisColor()
                  : dashboardChartGuideColor(),
              strokeWidth: index == 0 ? 1.5 : 1,
              dashArray: index == 0 ? null : const [8, 4],
            ),
        ],
        horizontalLines: [
          HorizontalLine(
            y: yGuideValues.first,
            color: dashboardChartAxisColor(),
            strokeWidth: 1.5,
          ),
          for (final y in yGuideValues.skip(1).take(3))
            HorizontalLine(
              y: y,
              color: dashboardChartGuideColor(),
              strokeWidth: 1,
              dashArray: const [8, 4],
            ),
          HorizontalLine(
            y: yGuideValues.last,
            color: dashboardChartGuideColor(),
            strokeWidth: 1,
            dashArray: const [8, 4],
          ),
        ],
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchCallback: onHoverChanged == null
            ? null
            : (event, response) {
                if (event is FlPointerExitEvent) {
                  onHoverChanged(null);
                  return;
                }

                final xValue = response?.touchChartCoordinate.dx;
                if (xValue == null || !event.isInterestedForInteractions) {
                  onHoverChanged(null);
                  return;
                }

                onHoverChanged(
                  _hoverSampleForXValue(
                    axisMode: axisMode,
                    xValue: xValue,
                    samples: hoverSamples,
                    minX: minX,
                    maxX: maxX,
                  ),
                );
              },
        getTouchedSpotIndicator: (barData, spotIndexes) {
          return spotIndexes
              .map(
                (spotIndex) => TouchedSpotIndicatorData(
                  FlLine(
                    color: theme.seedColour,
                    strokeWidth: ChartUI.hoverLineStrokeWidth,
                  ),
                  FlDotData(
                    getDotPainter: (spot, percent, bar, index) {
                      return FlDotCirclePainter(
                        radius: ChartUI.radiusTouched,
                        color: theme.seedColour,
                        strokeColor: theme.seedColour,
                        strokeWidth: 0,
                      );
                    },
                  ),
                ),
              )
              .toList(growable: false);
        },
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) {
            return spots
                .map((spot) {
                  return LineTooltipItem(
                    '${_formatXAxisLabel(spot.x, axisMode, distanceAxisUnit: distanceAxisUnit)}\n${formatElevation(spot.y.round())}',
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

  List<_ChartSegment> _segmentsForAxis(
    ElevationProfileAxisMode axisMode,
    List<ElevationProfileSample> samples,
  ) {
    final segments = <_ChartSegment>[];
    var currentSpots = <FlSpot>[];
    var currentSampleIndices = <int>[];

    void flush() {
      if (currentSpots.isNotEmpty) {
        segments.add(
          _ChartSegment(
            spots: List<FlSpot>.unmodifiable(currentSpots),
            sampleIndices: List<int>.unmodifiable(currentSampleIndices),
          ),
        );
        currentSpots = <FlSpot>[];
        currentSampleIndices = <int>[];
      }
    }

    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
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
      currentSpots.add(FlSpot(x, y));
      currentSampleIndices.add(index);
    }

    flush();
    return segments;
  }

  List<_ChartSample> _hoverSamplesForAxis(
    ElevationProfileAxisMode axisMode,
    List<ElevationProfileSample> samples,
  ) {
    final hoverSamples = <_ChartSample>[];
    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      final x = switch (axisMode) {
        ElevationProfileAxisMode.distance => sample.distanceMeters,
        ElevationProfileAxisMode.time =>
          sample.timeLocal?.millisecondsSinceEpoch.toDouble(),
      };
      if (x == null || sample.elevationMeters == null) {
        continue;
      }
      hoverSamples.add(_ChartSample(sampleIndex: index, x: x));
    }
    return hoverSamples;
  }

  ElevationProfileChartHoverSample? _hoverSampleForXValue({
    required ElevationProfileAxisMode axisMode,
    required double xValue,
    required List<_ChartSample> samples,
    required double minX,
    required double maxX,
  }) {
    if (samples.isEmpty || maxX <= minX) {
      return null;
    }

    final clampedXValue = xValue.clamp(minX, maxX);
    _ChartSample? bestSample;
    var bestDistance = double.infinity;

    for (final sample in samples) {
      final distance = (sample.x - clampedXValue).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestSample = sample;
      }
    }

    if (bestSample == null) {
      return null;
    }

    return ElevationProfileChartHoverSample(
      sampleIndex: bestSample.sampleIndex,
      sample: widget.series.samples[bestSample.sampleIndex],
      xValue: clampedXValue,
      axisMode: axisMode,
    );
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

  List<double> _xGuideValues(double minX, double maxX) {
    final span = maxX - minX;
    return List<double>.unmodifiable([
      minX,
      minX + (span * 0.25),
      minX + (span * 0.5),
      minX + (span * 0.75),
      maxX,
    ]);
  }

  List<double> _horizontalGuideValues(double minY, double maxY) {
    final span = maxY - minY;
    return List<double>.unmodifiable([
      minY,
      minY + (span * 0.25),
      minY + (span * 0.5),
      minY + (span * 0.75),
      maxY,
    ]);
  }

  _ElevationAxisRange _axisRange(
    List<ElevationProfileSample> samples, {
    double? minElevation,
    double? maxElevation,
  }) {
    final values = [
      for (final sample in samples)
        if (sample.elevationMeters != null) sample.elevationMeters!,
    ];
    if (values.isEmpty) {
      return const _ElevationAxisRange(minY: 0, maxY: 1, step: 1);
    }

    final rawMin = minElevation ?? values.reduce(math.min);
    final rawMax = maxElevation ?? values.reduce(math.max);
    final place = _elevationPlace(rawMax.abs());
    var minY = (rawMin / place).roundToDouble() * place;
    var maxY = (rawMax / place).ceilToDouble() * place;
    if (maxY <= minY) {
      maxY = minY + (place * 4);
    }

    return _ElevationAxisRange(minY: minY, maxY: maxY, step: (maxY - minY) / 4);
  }

  double _elevationPlace(double n) {
    if (n < 100) {
      return 10;
    }

    final exponent = (math.log(n) / math.ln10).floor() - 1;
    return math.pow(10.0, exponent).toDouble();
  }

  double _yAxisRailWidth({
    required BuildContext context,
    required List<DashboardChartYAxisLabelEntry> entries,
  }) {
    final textDirection = Directionality.of(context);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    var maxWidth = 0.0;
    for (final entry in entries) {
      final painter = TextPainter(
        text: TextSpan(text: entry.text, style: style),
        maxLines: 1,
        textDirection: textDirection,
      )..layout();
      if (painter.width > maxWidth) {
        maxWidth = painter.width;
      }
    }

    return maxWidth + 1;
  }

  Widget _buildXAxisLabels(
    BuildContext context, {
    required ElevationProfileAxisMode axisMode,
    required _DistanceAxisUnit distanceAxisUnit,
    required List<double> xGuideValues,
  }) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textDirection = Directionality.of(context);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < xGuideValues.length; index++)
              Positioned(
                left: _xAxisLabelLeft(
                  totalWidth: constraints.maxWidth,
                  fractionFromLeft: index / (xGuideValues.length - 1),
                  labelText: _formatXAxisLabel(
                    xGuideValues[index],
                    axisMode,
                    distanceAxisUnit: distanceAxisUnit,
                    showUnits: index == 0,
                  ),
                  labelStyle: style,
                  textDirection: textDirection,
                ),
                top: 0,
                child: Text(
                  _formatXAxisLabel(
                    xGuideValues[index],
                    axisMode,
                    distanceAxisUnit: distanceAxisUnit,
                    showUnits: index == 0,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: style,
                ),
              ),
          ],
        );
      },
    );
  }

  double _xAxisLabelLeft({
    required double totalWidth,
    required double fractionFromLeft,
    required String labelText,
    required TextStyle? labelStyle,
    required ui.TextDirection textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: labelText, style: labelStyle),
      maxLines: 1,
      textDirection: textDirection,
    )..layout();

    final width = painter.width;
    final rawLeft = (totalWidth * fractionFromLeft) - (width / 2);
    return rawLeft.clamp(0.0, math.max(0.0, totalWidth - width)).toDouble();
  }

  String _formatXAxisLabel(
    double value,
    ElevationProfileAxisMode axisMode, {
    required _DistanceAxisUnit distanceAxisUnit,
    bool showUnits = false,
  }) {
    return switch (axisMode) {
      ElevationProfileAxisMode.distance => _formatDistanceAxisLabel(
        value,
        distanceAxisUnit: distanceAxisUnit,
        showUnits: showUnits,
      ),
      ElevationProfileAxisMode.time => DateFormat(
        'HH:mm',
      ).format(DateTime.fromMillisecondsSinceEpoch(value.round())),
    };
  }

  _DistanceAxisUnit _distanceAxisUnit(double maxX) {
    return maxX >= 1000
        ? _DistanceAxisUnit.kilometers
        : _DistanceAxisUnit.meters;
  }

  String _formatDistanceAxisLabel(
    double value, {
    required _DistanceAxisUnit distanceAxisUnit,
    required bool showUnits,
  }) {
    final label = switch (distanceAxisUnit) {
      _DistanceAxisUnit.meters => value.round().toString(),
      _DistanceAxisUnit.kilometers => (value / 1000).toStringAsFixed(1),
    };

    if (!showUnits) {
      return label;
    }

    return switch (distanceAxisUnit) {
      _DistanceAxisUnit.meters => 'm',
      _DistanceAxisUnit.kilometers => 'km',
    };
  }
}

class _ChartSegment {
  const _ChartSegment({required this.spots, required this.sampleIndices});

  final List<FlSpot> spots;
  final List<int> sampleIndices;
}

class _ChartSample {
  const _ChartSample({required this.sampleIndex, required this.x});

  final int sampleIndex;
  final double x;
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

class _ElevationAxisRange {
  const _ElevationAxisRange({
    required this.minY,
    required this.maxY,
    required this.step,
  });

  final double minY;
  final double maxY;
  final double step;
}
