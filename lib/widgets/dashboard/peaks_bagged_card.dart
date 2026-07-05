import 'package:flutter/material.dart';

import '../../core/number_formatters.dart';
import '../../models/gpx_track.dart';
import '../../services/peaks_bagged_summary_service.dart';
import '../../services/summary_card_service.dart';
import '../../theme.dart';
import 'summary_card.dart';
import 'summary_chart.dart';

typedef PeaksBaggedVisibleSummary = SummaryVisibleSummary;

class PeaksBaggedCard extends StatefulWidget {
  const PeaksBaggedCard({
    super.key,
    required this.tracks,
    required this.isLoading,
    this.now,
    this.onVisibleSummaryChanged,
  });

  final List<GpxTrack> tracks;
  final bool isLoading;
  final DateTime? now;
  final ValueChanged<PeaksBaggedVisibleSummary?>? onVisibleSummaryChanged;

  @override
  State<PeaksBaggedCard> createState() => _PeaksBaggedCardState();
}

class _PeaksBaggedCardState extends State<PeaksBaggedCard> {
  static const _service = PeaksBaggedSummaryService();

  List<GpxTrack>? _cachedTracks;
  PeaksBaggedSeries? _cachedSeries;
  PeaksBaggedSeries? _cachedAdapterSeries;
  SummaryCardMetricAdapter? _cachedAdapter;

  @override
  void didUpdateWidget(covariant PeaksBaggedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracks != widget.tracks) {
      _cachedTracks = null;
      _cachedSeries = null;
      _cachedAdapterSeries = null;
      _cachedAdapter = null;
    }
  }

  PeaksBaggedSeries _seriesFor(List<GpxTrack> tracks) {
    if (_cachedTracks == tracks && _cachedSeries != null) {
      return _cachedSeries!;
    }

    _cachedTracks = tracks;
    _cachedSeries = _service.buildSeries(tracks);
    return _cachedSeries!;
  }

  SummaryCardMetricAdapter _adapterFor(PeaksBaggedSeries series) {
    if (_cachedAdapter != null && identical(_cachedAdapterSeries, series)) {
      return _cachedAdapter!;
    }

    _cachedAdapterSeries = series;
    _cachedAdapter = SummaryCardMetricAdapter(
      keyPrefix: 'peaks-bagged',
      emptyStateText: 'No peaks bagged yet',
      metric: SummaryMetricDefinition(valueOf: series.totalValueOf),
      secondaryMetric: SummaryMetricDefinition(valueOf: series.newValueOf),
      tooltipValueTexts: _tooltipValueTexts,
      tooltipValueTextColors: _tooltipValueColors,
      headerValueText: _formatHeaderValue,
      secondarySeriesOnTop: true,
      barSeriesStyle: SummaryBarSeriesStyle.stacked,
      yAxisLabelText: (value) => formatCount(value.round()),
    );
    return _cachedAdapter!;
  }

  @override
  Widget build(BuildContext context) {
    final series = _seriesFor(widget.tracks);
    final adapter = _adapterFor(series);

    return KeyedSubtree(
      key: const Key('peaks-bagged-card'),
      child: SummaryCard(
        tracks: widget.tracks,
        isLoading: widget.isLoading,
        initialMode: SummaryDisplayMode.line,
        now: widget.now,
        onVisibleSummaryChanged: widget.onVisibleSummaryChanged,
        adapter: adapter,
      ),
    );
  }
}

String _formatHeaderValue(double value) => formatCount(value.round());

List<String> _tooltipValueTexts(
  SummaryBucket bucket,
  SummaryBucket? secondaryBucket,
) {
  return [
    'Total Peaks: ${formatCount(bucket.value.round())}',
    if (secondaryBucket != null)
      'New peaks: ${formatCount(secondaryBucket.value.round())}',
  ];
}

List<Color> _tooltipValueColors(
  BuildContext context,
  SummaryBucket bucket,
  SummaryBucket? secondaryBucket,
) {
  final theme = Theme.of(context);
  final chartSeriesTheme =
      theme.extension<ChartSeriesTheme>() ??
      ChartSeriesTheme.fromColorScheme(theme.colorScheme);
  return [
    lighten(chartSeriesTheme.primarySeriesColor),
    if (secondaryBucket != null) lighten(chartSeriesTheme.secondarySeriesColor),
  ];
}
