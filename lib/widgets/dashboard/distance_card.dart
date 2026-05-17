import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/number_formatters.dart';
import '../../models/gpx_track.dart';
import '../../services/summary_card_service.dart';
import 'summary_card.dart';

class DistanceCard extends StatelessWidget {
  const DistanceCard({
    super.key,
    required this.tracks,
    required this.isLoading,
    this.now,
    this.onVisibleSummaryChanged,
  });

  static const metric = SummaryMetricDefinition(valueOf: _trackDistance);
  static const secondaryMetric = SummaryMetricDefinition(
    valueOf: _trackDistance3d,
  );
  static const adapter = SummaryCardMetricAdapter(
    keyPrefix: 'distance',
    emptyStateText: 'No distance data yet',
    metric: metric,
    secondaryMetric: secondaryMetric,
    tooltipValueTexts: _distanceTooltipValues,
    headerValueText: formatDistance,
    yAxisLabelText: formatDistance,
    chartMaxYFor: _distanceChartMaxY,
  );

  final List<GpxTrack> tracks;
  final bool isLoading;
  final DateTime? now;
  final ValueChanged<SummaryVisibleSummary?>? onVisibleSummaryChanged;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('distance-card'),
      child: SummaryCard(
        tracks: tracks,
        isLoading: isLoading,
        now: now,
        onVisibleSummaryChanged: onVisibleSummaryChanged,
        adapter: adapter,
      ),
    );
  }
}

List<String> _distanceTooltipValues(
  SummaryBucket bucket,
  SummaryBucket? secondaryBucket,
) {
  return [
    '2D: ${formatDistance(bucket.value)}',
    if (secondaryBucket != null) '3D: ${formatDistance(secondaryBucket.value)}',
  ];
}

double? _trackDistance(GpxTrack track) => track.distance2d;

double? _trackDistance3d(GpxTrack track) => track.distance3d;

double _distanceChartMaxY(double maxValue) {
  return math.max(4000.0, (((maxValue.floor()) + 1 + 3999) ~/ 4000) * 4000.0);
}
