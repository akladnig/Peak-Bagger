import 'package:flutter/material.dart';

import '../../models/gpx_track.dart';
import '../../services/elevation_summary_service.dart';
import 'elevation_chart.dart';
import 'summary_card.dart';

typedef ElevationVisibleSummary = SummaryVisibleSummary;

class ElevationCard extends StatelessWidget {
  const ElevationCard({
    super.key,
    required this.tracks,
    required this.isLoading,
    this.now,
    this.onVisibleSummaryChanged,
  });

  final List<GpxTrack> tracks;
  final bool isLoading;
  final DateTime? now;
  final ValueChanged<ElevationVisibleSummary?>? onVisibleSummaryChanged;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('elevation-card'),
      child: SummaryCard(
        tracks: tracks,
        isLoading: isLoading,
        now: now,
        onVisibleSummaryChanged: onVisibleSummaryChanged,
        adapter: const SummaryCardMetricAdapter(
          keyPrefix: 'elevation',
          emptyStateText: 'No elevation data yet',
          metric: ElevationSummaryService.metric,
          tooltipValueText: formatElevationTooltipValue,
          tooltipTitleText: formatElevationTooltipTitle,
        ),
      ),
    );
  }
}
