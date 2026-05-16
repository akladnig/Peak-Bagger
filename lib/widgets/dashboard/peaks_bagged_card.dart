import 'package:flutter/material.dart';

import '../../core/number_formatters.dart';
import '../../models/gpx_track.dart';
import '../../services/peaks_bagged_summary_service.dart';
import '../../services/summary_card_service.dart';
import 'summary_card.dart';
import 'summary_chart.dart';

typedef PeaksBaggedVisibleSummary = SummaryVisibleSummary;

class PeaksBaggedCard extends StatelessWidget {
  const PeaksBaggedCard({
    super.key,
    required this.tracks,
    required this.isLoading,
    this.now,
    this.onVisibleSummaryChanged,
  });

  static const _service = PeaksBaggedSummaryService();

  final List<GpxTrack> tracks;
  final bool isLoading;
  final DateTime? now;
  final ValueChanged<PeaksBaggedVisibleSummary?>? onVisibleSummaryChanged;

  @override
  Widget build(BuildContext context) {
    final series = _service.buildSeries(tracks);
    final adapter = SummaryCardMetricAdapter(
      keyPrefix: 'peaks-bagged',
      emptyStateText: 'No peaks bagged yet',
      metric: SummaryMetricDefinition(valueOf: series.totalValueOf),
      secondaryMetric: SummaryMetricDefinition(valueOf: series.newValueOf),
      tooltipValueTexts: _tooltipValueTexts,
      headerValueText: _formatHeaderValue,
      barSeriesStyle: SummaryBarSeriesStyle.stacked,
      yAxisLabelText: formatCount,
    );

    return KeyedSubtree(
      key: const Key('peaks-bagged-card'),
      child: SummaryCard(
        tracks: tracks,
        isLoading: isLoading,
        initialMode: SummaryDisplayMode.line,
        now: now,
        onVisibleSummaryChanged: onVisibleSummaryChanged,
        adapter: adapter,
      ),
    );
  }
}

String _formatHeaderValue(double value) => formatCount(value);

List<String> _tooltipValueTexts(
  SummaryBucket bucket,
  SummaryBucket? secondaryBucket,
) {
  return [
    'Total climbs: ${formatElevationMetres(bucket.value.round())}',
    if (secondaryBucket != null)
      'New peaks: ${formatElevationMetres(secondaryBucket.value.round())}',
  ];
}
