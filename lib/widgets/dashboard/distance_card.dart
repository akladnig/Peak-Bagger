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
  static const adapter = SummaryCardMetricAdapter(
    keyPrefix: 'distance',
    emptyStateText: 'No distance data yet',
    metric: metric,
    tooltipValueText: _distanceTooltipValue,
    headerValueText: formatDistance,
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

String _distanceTooltipValue(SummaryBucket bucket) =>
    formatDistance(bucket.value);

double? _trackDistance(GpxTrack track) => track.distance2d;
