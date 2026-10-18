import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_formatters.dart';
import '../../models/gpx_track.dart';
import '../../providers/time_chart_type_provider.dart';
import '../../services/summary_card_service.dart';
import '../../services/time_summary_metrics.dart';
import '../../theme.dart';
import 'summary_card.dart';
import 'summary_chart.dart';
import 'time_chart_type_menu.dart';

class TimeCard extends ConsumerWidget {
  const TimeCard({
    super.key,
    required this.tracks,
    required this.isLoading,
    this.now,
    this.onVisibleSummaryChanged,
  });

  static const adapter = SummaryCardMetricAdapter(
    keyPrefix: 'time',
    emptyStateText: 'No time data yet',
    metric: TimeSummaryMetrics.total,
    secondaryMetric: TimeSummaryMetrics.moving,
    isEligible: TimeSummaryMetrics.isEligible,
    chartValueScale: 1 / Duration.millisecondsPerDay,
    barSeriesStyle: SummaryBarSeriesStyle.subsetStacked,
    secondarySeriesOnTop: true,
    tooltipValueTexts: _tooltipValues,
    tooltipValueTextColors: _tooltipColors,
    headerValueText: formatDurationMillis,
    yAxisLabelText: formatDurationDaysAxis,
    chartMaxYFor: _chartMaxDays,
  );

  final List<GpxTrack> tracks;
  final bool isLoading;
  final DateTime? now;
  final ValueChanged<SummaryVisibleSummary?>? onVisibleSummaryChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(timeChartTypeProvider);
    return KeyedSubtree(
      key: const Key('time-card'),
      child: SummaryCard(
        tracks: tracks,
        isLoading: isLoading,
        now: now,
        onVisibleSummaryChanged: onVisibleSummaryChanged,
        adapter: adapter,
        displayMode: type == TimeChartType.line
            ? SummaryDisplayMode.line
            : SummaryDisplayMode.columns,
        barSeriesStyle: type == TimeChartType.clusteredColumn
            ? SummaryBarSeriesStyle.grouped
            : SummaryBarSeriesStyle.subsetStacked,
        chartTypeControlBuilder: (onOpen, onChanged) =>
            TimeChartTypeMenu(onOpen: onOpen, onChanged: onChanged),
      ),
    );
  }
}

List<String> _tooltipValues(SummaryBucket total, SummaryBucket? moving) => [
  'Total Time: ${formatDurationMillis(total.value)}',
  'Moving Time: ${formatDurationMillis(moving?.value ?? 0)}',
];

List<Color> _tooltipColors(
  BuildContext context,
  SummaryBucket total,
  SummaryBucket? moving,
) {
  final theme = Theme.of(context);
  final series =
      theme.extension<ChartSeriesTheme>() ??
      ChartSeriesTheme.fromColorScheme(theme.colorScheme);
  return [
    lighten(series.primarySeriesColor),
    lighten(series.secondarySeriesColor),
  ];
}

double _chartMaxDays(double maxDays) {
  if (maxDays <= 0 || !maxDays.isFinite) return 1;
  final step = math
      .pow(10, (math.log(maxDays / 4) / math.ln10).floor())
      .toDouble();
  return (maxDays / 4 / step).ceil() * step * 4;
}
