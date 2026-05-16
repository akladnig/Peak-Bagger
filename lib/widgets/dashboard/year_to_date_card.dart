import 'package:flutter/material.dart';

import '../../core/number_formatters.dart';
import '../../models/gpx_track.dart';
import '../../services/year_to_date_summary_service.dart';

class YearToDateCard extends StatefulWidget {
  const YearToDateCard({
    super.key,
    required this.tracks,
    required this.isLoading,
    this.now,
  });

  final List<GpxTrack> tracks;
  final bool isLoading;
  final DateTime? now;

  @override
  State<YearToDateCard> createState() => _YearToDateCardState();
}

class _YearToDateCardState extends State<YearToDateCard> {
  static const _service = YearToDateSummaryService();

  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = _service.initialYear(now: widget.now);
  }

  void _previousYear() {
    setState(() {
      _selectedYear = _service.shiftYear(year: _selectedYear, forward: false);
    });
  }

  void _nextYear() {
    setState(() {
      _selectedYear = _service.shiftYear(year: _selectedYear, forward: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = _service.initialYear(now: widget.now);
    return KeyedSubtree(
      key: const Key('year-to-date-card'),
      child: widget.isLoading
          ? const _YearToDateLoadingState()
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _YearToDateHeader(
                    year: _selectedYear,
                    onPrevious: _previousYear,
                    onNext: _nextYear,
                    canMoveNext: _selectedYear < currentYear,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _YearToDateMetrics(
                      summary: _service.buildSummary(
                        tracks: widget.tracks,
                        year: _selectedYear,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _YearToDateLoadingState extends StatelessWidget {
  const _YearToDateLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('year-to-date-loading-state'),
      child: CircularProgressIndicator(),
    );
  }
}

class _YearToDateHeader extends StatelessWidget {
  const _YearToDateHeader({
    required this.year,
    required this.onPrevious,
    required this.onNext,
    required this.canMoveNext,
  });

  final int year;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool canMoveNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            'My Walks in $year',
            key: const Key('year-to-date-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const Key('year-to-date-prev-year'),
          tooltip: 'Previous year',
          onPressed: onPrevious,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          iconSize: 18,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          key: const Key('year-to-date-next-year'),
          tooltip: 'Next year',
          onPressed: canMoveNext ? onNext : null,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          iconSize: 18,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _YearToDateMetrics extends StatelessWidget {
  const _YearToDateMetrics({required this.summary});

  final YearToDateSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final valueStyle = theme.textTheme.bodySmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _YearToDateMetricRow(
          label: 'Kilometers walked',
          value: formatDistance(summary.distance2d),
          valueKey: const Key('year-to-date-distance-value'),
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
        _YearToDateMetricRow(
          label: 'Metres climbed',
          value: formatElevationMetres(summary.ascentMetres.round()),
          valueKey: const Key('year-to-date-ascent-value'),
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
        _YearToDateMetricRow(
          label: 'Total Walks',
          value: formatElevationMetres(summary.walkCount),
          valueKey: const Key('year-to-date-total-walks-value'),
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
        _YearToDateMetricRow(
          label: 'Peaks Climbed',
          value: formatElevationMetres(summary.peaksClimbed),
          valueKey: const Key('year-to-date-peaks-climbed-value'),
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
        _YearToDateMetricRow(
          label: 'New Peaks Climbed',
          value: formatElevationMetres(summary.newPeaksClimbed),
          valueKey: const Key('year-to-date-new-peaks-climbed-value'),
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      ],
    );
  }
}

class _YearToDateMetricRow extends StatelessWidget {
  const _YearToDateMetricRow({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.labelStyle,
    required this.valueStyle,
  });

  final String label;
  final String value;
  final Key valueKey;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          key: valueKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: valueStyle,
        ),
      ],
    );
  }
}
