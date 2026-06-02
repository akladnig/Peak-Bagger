import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/date_formatters.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/elevation_profile_series_builder.dart';
import 'package:peak_bagger/services/map_ruler_scale.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/peak_search_results_list.dart';
import 'package:peak_bagger/widgets/elevation_profile_chart.dart';

class PeakInfoPopupPlacement {
  const PeakInfoPopupPlacement({
    required this.topLeft,
    required this.isAnchorable,
    required this.bridgeOnLeft,
  });

  final Offset topLeft;
  final bool isAnchorable;
  final bool bridgeOnLeft;
}

PeakInfoPopupPlacement resolvePeakInfoPopupPlacement({
  required Offset anchorScreenOffset,
  required Size viewportSize,
  required Size popupSize,
  double markerSize = 20,
  double margin = 8,
  double preferredGap = 16,
}) {
  final isAnchorable =
      anchorScreenOffset.dx >= 0 &&
      anchorScreenOffset.dy >= 0 &&
      anchorScreenOffset.dx <= viewportSize.width &&
      anchorScreenOffset.dy <= viewportSize.height;

  final halfMarker = markerSize / 2;
  var left = anchorScreenOffset.dx + halfMarker + preferredGap;
  if (left + popupSize.width + margin > viewportSize.width) {
    left = anchorScreenOffset.dx - halfMarker - preferredGap - popupSize.width;
  }
  left = left.clamp(margin, viewportSize.width - popupSize.width - margin);

  final unclampedTop = anchorScreenOffset.dy - popupSize.height / 2;
  final top = unclampedTop.clamp(
    margin,
    viewportSize.height - popupSize.height - margin,
  );

  final bridgeOnLeft = left >= anchorScreenOffset.dx;

  return PeakInfoPopupPlacement(
    topLeft: Offset(left.toDouble(), top.toDouble()),
    isAnchorable: isAnchorable,
    bridgeOnLeft: bridgeOnLeft,
  );
}

class MapMgrsReadout extends StatelessWidget {
  const MapMgrsReadout({required this.mapName, required this.mgrs, super.key});

  final String mapName;
  final String mgrs;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('map-mgrs-readout'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              text: mapName,
              style:
                  (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
                      .copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            _formatMgrs(mgrs),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

class MapZoomReadout extends StatelessWidget {
  const MapZoomReadout({required this.zoom, required this.latitude, super.key});

  final double zoom;
  final double latitude;

  @override
  Widget build(BuildContext context) {
    final selection = selectMapRulerScale(zoom: zoom, latitude: latitude);
    final distanceLabel = formatDistance(selection.distanceMeters.toDouble());
    final boxTopInset =
        MapConstants.mapRulerHorizontalPadding >
            MapConstants.mapRulerVerticalPadding
        ? MapConstants.mapRulerHorizontalPadding -
              MapConstants.mapRulerVerticalPadding
        : 0.0;
    return Container(
      key: const Key('map-zoom-readout'),
      padding: const EdgeInsets.symmetric(
        horizontal: MapConstants.mapRulerHorizontalPadding,
        vertical: MapConstants.mapRulerVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(MapConstants.mapRulerBorderRadius),
      ),
      child: SizedBox(
        width: selection.barWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(top: boxTopInset),
              child: SizedBox(
                width: selection.barWidth,
                height: MapConstants.mapRulerEndCapHeight,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Container(
                        key: const Key('map-ruler-left-cap'),
                        width: MapConstants.mapRulerBarHeight,
                        height: MapConstants.mapRulerEndCapHeight,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        key: const Key('map-ruler-right-cap'),
                        width: MapConstants.mapRulerBarHeight,
                        height: MapConstants.mapRulerEndCapHeight,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        key: const Key('map-ruler-bar'),
                        height: MapConstants.mapRulerBarHeight,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Text(
                        distanceLabel,
                        key: const Key('map-ruler-distance-text'),
                        textAlign: TextAlign.center,
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                        style: mapRulerTextStyle(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'zoom: ${formatCount(zoom.round())}',
              key: const Key('map-ruler-zoom-text'),
              textAlign: TextAlign.center,
              textHeightBehavior: const TextHeightBehavior(
                applyHeightToFirstAscent: false,
                applyHeightToLastDescent: false,
              ),
              style: mapRulerTextStyle(context),
            ),
          ],
        ),
      ),
    );
  }
}

class MapTrackInfoPanel extends StatelessWidget {
  const MapTrackInfoPanel({
    this.track,
    this.route,
    required this.onClose,
    this.onExport,
    super.key,
  }) : assert(track != null || route != null),
       assert(track == null || route == null);

  final GpxTrack? track;
  final app_route.Route? route;
  final VoidCallback onClose;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final isRoute = route != null;
    final displayName = isRoute ? _routeName(route!) : _trackName(track!);

    return SizedBox(
      width: UiConstants.preferredLeftWidth,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Card(
          key: const Key('track-info-panel'),
          color: Theme.of(context).colorScheme.secondary,
          margin: EdgeInsets.zero,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            key: const Key('track-info-panel-close'),
                            tooltip: isRoute
                                ? 'Close route info'
                                : 'Close track info',
                            onPressed: onClose,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      if (!isRoute) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(formatTrackDate(track!.trackDate)),
                            Text(
                              formatTrackTimeRange(
                                track!.startDateTime,
                                track!.endDateTime,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: isRoute
                        ? _buildRouteBody(context, route!)
                        : _buildTrackBody(context, track!),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('track-info-panel-export-button'),
                      onPressed: onExport,
                      icon: const Icon(Icons.download),
                      label: const Text('Export'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _trackName(GpxTrack track) {
    return track.trackName.trim().isEmpty
        ? 'Unnamed Track'
        : track.trackName.trim();
  }

  String _routeName(app_route.Route route) {
    return route.name.trim().isEmpty ? 'Unnamed Route' : route.name.trim();
  }

  Widget _buildRouteBody(BuildContext context, app_route.Route route) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryMetric(
                label: 'Distance',
                value: formatDistance(route.distance2d, decimalPlaces: 1),
              ),
            ),
            Expanded(
              child: _SummaryMetric(
                label: 'Ascent',
                value: formatAscent(route.ascent),
              ),
            ),
            Expanded(
              child: _SummaryMetric(
                label: 'Descent',
                value: formatElevation(route.descent.round()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Elevation'),
        thinDivider,
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevationProfileChart(
            series: ElevationProfileSeriesBuilder.fromRoutePoints(
              points: route.gpxRoute,
              elevations: route.gpxRouteElevations,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _LabeledValueRow(
          label: 'Total Ascent',
          value: formatAscent(route.ascent),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'Start Elevation',
          value: formatElevation(route.startElevation.round()),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'End Elevation',
          value: formatElevation(route.endElevation.round()),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'Max Elevation',
          value: formatElevation(route.highestElevation.round()),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'Min Elevation',
          value: formatElevation(route.lowestElevation.round()),
        ),
      ],
    );
  }

  Widget _buildTrackBody(BuildContext context, GpxTrack track) {
    final normalizedPeaks = normalizeTrackPeaks(track.peaks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryMetric(
                label: 'Distance',
                value: formatDistance(track.distance2d, decimalPlaces: 1),
              ),
            ),
            Expanded(
              child: _SummaryMetric(
                label: 'Ascent',
                value: formatAscent(track.ascent),
              ),
            ),
            Expanded(
              child: _SummaryMetric(
                label: 'Total Time',
                value: formatDuration(track.totalTimeMillis),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Peaks Climbed'),
        thinDivider,
        const SizedBox(height: 6),
        if (normalizedPeaks.isNotEmpty) ...[
          for (final peak in normalizedPeaks)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _displayPeakName(peak),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    peak.elevation != null
                        ? formatElevation(peak.elevation!.round())
                        : '—',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 2),
        ] else ...[
          const Text('None'),
          const SizedBox(height: 6),
        ],
        thinDivider,
        if (track.peakCorrelationProcessed && normalizedPeaks.isNotEmpty) ...[
          _LabeledValueRow(
            label: 'Distance to highest peak',
            value: formatDistance(track.distanceToPeak, decimalPlaces: 1),
          ),
          thinDivider,
          _LabeledValueRow(
            label: 'Distance from highest peak',
            value: formatDistance(track.distanceFromPeak, decimalPlaces: 1),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Elevation'),
        thinDivider,
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevationProfileChart(
            series: ElevationProfileSeriesBuilder.fromTrackProfileJson(
              track.elevationProfile,
            ),
            minElevation: track.lowestElevation,
            maxElevation: track.highestElevation,
          ),
        ),
        const SizedBox(height: 16),
        _LabeledValueRow(
          label: 'Total Ascent',
          value: formatAscent(track.ascent),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'Start Elevation',
          value: formatElevation(track.startElevation.round()),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'End Elevation',
          value: formatElevation(track.endElevation.round()),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'Max Elevation',
          value: formatElevation(track.highestElevation.round()),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'Min Elevation',
          value: formatElevation(track.lowestElevation.round()),
        ),
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Time'),
        thinDivider,
        _LabeledValueRow(
          label: 'Total Time',
          value: formatDuration(track.totalTimeMillis),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'Moving Time',
          value: formatDuration(track.movingTime),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'Resting Time',
          value: formatDuration(track.restingTime),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'Paused Time',
          value: formatDuration(track.pausedTime),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _LabeledValueRow extends StatelessWidget {
  const _LabeledValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

String formatTrackTimeRange(DateTime? start, DateTime? end) {
  return 'from ${formatTimeOnly(start)} to ${formatTimeOnly(end)}';
}

String formatTimeOnly(DateTime? value) {
  if (value == null) {
    return 'Unknown';
  }
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatDuration(int? millis) {
  if (millis == null) {
    return 'Unknown';
  }
  final totalMinutes = millis ~/ Duration.millisecondsPerMinute;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${totalMinutes}m';
}

List<Peak> normalizeTrackPeaks(Iterable<Peak> peaks) {
  final seenPeakIds = <int>{};
  final displayPeaks = <Peak>[];
  for (final peak in peaks) {
    if (!seenPeakIds.add(peak.osmId)) {
      continue;
    }
    displayPeaks.add(peak);
  }
  displayPeaks.sort((left, right) {
    final nameComparison = _displayPeakName(
      left,
    ).toLowerCase().compareTo(_displayPeakName(right).toLowerCase());
    if (nameComparison != 0) {
      return nameComparison;
    }
    return left.osmId.compareTo(right.osmId);
  });
  return displayPeaks;
}

String _displayPeakName(Peak peak) {
  final trimmed = peak.name.trim();
  return trimmed.isEmpty ? 'Unknown Peak' : trimmed;
}

List<String> normalizeTrackPeakNames(Iterable<Peak> peaks) {
  return normalizeTrackPeaks(peaks).map(_displayPeakName).toList();
}

class MapPeakSearchPanel extends StatelessWidget {
  const MapPeakSearchPanel({
    required this.focusNode,
    required this.searchResults,
    required this.searchQuery,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClose,
    required this.onSelectPeak,
    required this.mapNameForPeak,
    super.key,
  });

  final FocusNode focusNode;
  final List<Peak> searchResults;
  final String searchQuery;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClose;
  final ValueChanged<Peak> onSelectPeak;
  final String Function(Peak peak) mapNameForPeak;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(
                  width: 30 * 8.0,
                  child: TextField(
                    key: const Key('peak-search-input'),
                    focusNode: focusNode,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search peaks',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('peak-search-close'),
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          if (searchResults.isNotEmpty)
            SizedBox(
              width: 30 * 8.0,
              child: PeakSearchResultsList(
                searchResults: searchResults,
                searchQuery: searchQuery,
                mapNameForPeak: mapNameForPeak,
                onSelectPeak: onSelectPeak,
              ),
            ),
          if (searchResults.isEmpty)
            PeakSearchResultsList(
              searchResults: searchResults,
              searchQuery: searchQuery,
              mapNameForPeak: mapNameForPeak,
              onSelectPeak: onSelectPeak,
            ),
        ],
      ),
    );
  }
}

class MapGotoPanel extends StatelessWidget {
  const MapGotoPanel({
    required this.focusNode,
    required this.controller,
    required this.errorText,
    required this.mapSuggestions,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClose,
    required this.onNavigate,
    required this.onTabShortcut,
    required this.onSelectSuggestion,
    super.key,
  });

  final FocusNode focusNode;
  final TextEditingController controller;
  final String? errorText;
  final List<Tasmap50k> mapSuggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClose;
  final VoidCallback onNavigate;
  final VoidCallback onTabShortcut;
  final ValueChanged<Tasmap50k> onSelectSuggestion;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(
                  width: 30 * 8.0,
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.tab):
                          onTabShortcut,
                    },
                    child: TextField(
                      key: const Key('goto-map-input'),
                      focusNode: focusNode,
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Go to location',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                      ),
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('goto-map-close'),
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                ),
                IconButton(
                  key: const Key('goto-map-submit'),
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: onNavigate,
                ),
              ],
            ),
          ),
          if (mapSuggestions.isNotEmpty)
            SizedBox(
              width: 30 * 8.0,
              height: 150,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: mapSuggestions.length,
                itemBuilder: (context, index) {
                  final map = mapSuggestions[index];
                  return ListTile(
                    dense: true,
                    title: Text(map.name),
                    subtitle: Text(map.series),
                    onTap: () => onSelectSuggestion(map),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class MapInfoPopupCard extends StatelessWidget {
  const MapInfoPopupCard({
    required this.infoMapName,
    required this.infoMgrs,
    required this.infoPeakName,
    required this.infoPeakElevation,
    required this.hasTrackRecoveryIssue,
    required this.trackCount,
    required this.onClose,
    super.key,
  });

  final String? infoMapName;
  final String? infoMgrs;
  final String? infoPeakName;
  final double? infoPeakElevation;
  final bool hasTrackRecoveryIssue;
  final int trackCount;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map, size: 18),
                const SizedBox(width: 8),
                Text(
                  infoMapName ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            if (infoMgrs != null) ...[
              const SizedBox(height: 4),
              Text(
                infoMgrs!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
            if (infoPeakName != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.terrain, size: 16),
                  const SizedBox(width: 4),
                  Text(infoPeakName!, style: const TextStyle(fontSize: 13)),
                  if (infoPeakElevation != null) ...[
                    const Text(' '),
                    Text(
                      formatCompactElevation(infoPeakElevation!),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ],
              ),
            ],
            if (hasTrackRecoveryIssue) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.warning_amber_rounded, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Some tracks need to be rebuilt.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ] else if (trackCount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.route, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$trackCount tracks available',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PeakInfoPopupCard extends StatelessWidget {
  const PeakInfoPopupCard({
    required this.content,
    required this.onClose,
    this.onDropMarker,
    super.key,
  });

  final PeakInfoContent content;
  final VoidCallback onClose;
  final VoidCallback? onDropMarker;

  @override
  Widget build(BuildContext context) {
    final peak = content.peak;
    final altName = peak.altName.trim();
    final listNames = content.listNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final listLabel = switch (listNames.length) {
      1 => 'List',
      _ => 'Lists',
    };
    final mgrsParts = [
      peak.gridZoneDesignator.trim(),
      peak.mgrs100kId.trim(),
      peak.easting.trim(),
      peak.northing.trim(),
    ];
    final mgrsText = mgrsParts.every((part) => part.isNotEmpty)
        ? mgrsParts.join(' ')
        : null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: UiConstants.peakInfoPopupSize.height,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.terrain, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      peak.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (onDropMarker != null) ...[
                    IconButton(
                      key: const Key('peak-info-popup-drop-marker'),
                      tooltip: 'Drop a Marker on the Peak',
                      icon: const Icon(
                        Icons.my_location,
                        color: Colors.amber,
                        size: 16,
                      ),
                      onPressed: onDropMarker,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    key: const Key('peak-info-popup-close'),
                    tooltip: 'Close Peak Info',
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (altName.isNotEmpty) ...[
                        _PeakInfoLabeledValueRow(
                          label: 'Alt Name:',
                          value: altName,
                        ),
                        const SizedBox(height: 4),
                      ],
                      _PeakInfoLabeledValueRow(
                        label: 'Height:',
                        value: peak.elevation == null
                            ? '—'
                            : formatElevation(peak.elevation!.round()),
                      ),
                      if (content.ascentRows.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'My Ascents:',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        for (final ascent in content.ascentRows)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, bottom: 4),
                            child: Text(
                              '${ascent.trackLabel} (${ascent.dateText})',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                      ],
                      if (content.ascentRows.isNotEmpty)
                        const SizedBox(height: 4),
                      _PeakInfoLabeledValueRow(
                        label: 'Map:',
                        value: content.mapName,
                      ),
                      if (mgrsText != null) ...[
                        const SizedBox(height: 4),
                        _PeakInfoLabeledValueRow(
                          label: 'MGRS:',
                          value: mgrsText,
                          monospaceValue: true,
                        ),
                      ],
                      if (listNames.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _PeakInfoLabeledValueRow(
                          label: '$listLabel:',
                          value: listNames.join(', '),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PeakInfoPopupSurface extends StatelessWidget {
  const PeakInfoPopupSurface({
    required this.content,
    required this.onClose,
    this.onDropMarker,
    required this.bridgeOnLeft,
    super.key,
  });

  static const bridgeWidth = 12.0;

  final PeakInfoContent content;
  final VoidCallback onClose;
  final VoidCallback? onDropMarker;
  final bool bridgeOnLeft;

  @override
  Widget build(BuildContext context) {
    final popupWidth = UiConstants.peakInfoPopupSize.width;
    final totalWidth = popupWidth + bridgeWidth;

    return MouseRegion(
      child: SizedBox(
        width: totalWidth,
        child: Align(
          alignment: bridgeOnLeft ? Alignment.centerRight : Alignment.centerLeft,
          child: SizedBox(
            width: popupWidth,
            child: PeakInfoPopupCard(
              key: const Key('peak-info-popup'),
              content: content,
              onClose: onClose,
              onDropMarker: onDropMarker,
            ),
          ),
        ),
      ),
    );
  }
}

class RouteDraftMarkerDeletePopupCard extends StatelessWidget {
  const RouteDraftMarkerDeletePopupCard({
    required this.onDelete,
    required this.onClose,
    super.key,
  });

  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Edit Point', style: theme.textTheme.titleSmall),
                ),
                IconButton(
                  key: const Key('route-draft-delete-popup-close'),
                  tooltip: 'Close point actions',
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('route-draft-delete-action'),
              onPressed: onDelete,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Delete Point'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeakInfoLabeledValueRow extends StatelessWidget {
  const _PeakInfoLabeledValueRow({
    required this.label,
    required this.value,
    this.monospaceValue = false,
  });

  final String label;
  final String value;
  final bool monospaceValue;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodySmall;
    final valueStyle = baseStyle?.copyWith(
      fontWeight: FontWeight.bold,
      fontFamily: monospaceValue ? 'monospace' : null,
    );
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: label),
          TextSpan(text: ' '),
          TextSpan(text: value, style: valueStyle),
        ],
      ),
    );
  }
}

String _formatMgrs(String mgrs) {
  final lines = mgrs.split('\n');
  if (lines.length < 2 || lines[0].length < 5) {
    return mgrs.replaceFirst('\n', ' ');
  }

  return '${lines[0].substring(0, 3)} ${lines[0].substring(3)} ${lines[1]}';
}
