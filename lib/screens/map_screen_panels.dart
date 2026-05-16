import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/date_formatters.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/peak_search_results_list.dart';

class PeakInfoPopupPlacement {
  const PeakInfoPopupPlacement({
    required this.topLeft,
    required this.isAnchorable,
  });

  final Offset topLeft;
  final bool isAnchorable;
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

  return PeakInfoPopupPlacement(
    topLeft: Offset(left.toDouble(), top.toDouble()),
    isAnchorable: isAnchorable,
  );
}

class MapMgrsReadout extends StatelessWidget {
  const MapMgrsReadout({required this.mgrs, super.key});

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
      child: _MapMgrsText(mgrs: mgrs),
    );
  }
}

class MapZoomReadout extends StatelessWidget {
  const MapZoomReadout({required this.zoom, super.key});

  final double zoom;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('map-zoom-readout'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'zoom: ${zoom.toStringAsFixed(0)}',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class MapTrackInfoPanel extends StatelessWidget {
  const MapTrackInfoPanel({
    required this.track,
    required this.onClose,
    super.key,
  });

  final GpxTrack track;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final displayName = track.trackName.trim().isEmpty
        ? 'Unnamed Track'
        : track.trackName.trim();
    final normalizedPeaks = normalizeTrackPeakNames(track.peaks);

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
                            tooltip: 'Close track info',
                            onPressed: onClose,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatTrackDate(track.trackDate)),
                          Text(
                            formatTrackTimeRange(
                              track.startDateTime,
                              track.endDateTime,
                            ),
                          ),
                        ],
                      ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SummaryMetric(
                                label: 'Distance',
                                value: formatDistance(track.distance2d),
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
                          for (final peakName in normalizedPeaks)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(peakName),
                            ),
                          const SizedBox(height: 2),
                        ] else ...[
                          const Text('None'),
                          const SizedBox(height: 6),
                        ],
                        thinDivider,
                        if (track.peakCorrelationProcessed &&
                            normalizedPeaks.isNotEmpty) ...[
                          _LabeledValueRow(
                            label: 'Distance to highest peak',
                            value: formatDistance(track.distanceToPeak),
                          ),
                          thinDivider,
                          _LabeledValueRow(
                            label: 'Distance from highest peak',
                            value: formatDistance(track.distanceFromPeak),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 20),
                        const _SectionTitle(title: 'Elevation'),
                        thinDivider,
                        _LabeledValueRow(
                          label: 'Total Ascent',
                          value: formatAscent(track.ascent),
                        ),
                        thinDivider,
                        _LabeledValueRow(
                          label: 'Start Elevation',
                          value: formatElevation(track.startElevation),
                        ),
                        thinDivider,
                        _LabeledValueRow(
                          label: 'End Elevation',
                          value: formatElevation(track.endElevation),
                        ),
                        thinDivider,
                        _LabeledValueRow(
                          label: 'Max Elevation',
                          value: formatElevation(track.highestElevation),
                        ),
                        thinDivider,
                        _LabeledValueRow(
                          label: 'Min Elevation',
                          value: formatElevation(track.lowestElevation),
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

List<String> normalizeTrackPeakNames(Iterable<Peak> peaks) {
  final seenPeakIds = <int>{};
  final displayNames = <String>[];
  for (final peak in peaks) {
    if (!seenPeakIds.add(peak.osmId)) {
      continue;
    }
    final trimmed = peak.name.trim();
    displayNames.add(trimmed.isEmpty ? 'Unknown Peak' : trimmed);
  }
  displayNames.sort(
    (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
  );
  return displayNames;
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
                      '${infoPeakElevation!.toStringAsFixed(0)}m',
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
    super.key,
  });

  final PeakInfoContent content;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final peak = content.peak;
    final elevationText = peak.elevation == null
        ? '—'
        : '${peak.elevation!.toStringAsFixed(0)}m';
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

    return Card(
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
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('peak-info-popup-close'),
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (altName.isNotEmpty) ...[
              Text('Alt Name: $altName', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
            ],
            Text(
              'Height: $elevationText',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'Map: ${content.mapName}',
              style: const TextStyle(fontSize: 13),
            ),
            if (mgrsText != null) ...[
              const SizedBox(height: 4),
              Text(
                'MGRS: $mgrsText',
                style: TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
            if (listNames.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '$listLabel: ${listNames.join(', ')}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapMgrsText extends StatelessWidget {
  const _MapMgrsText({required this.mgrs});

  final String mgrs;

  @override
  Widget build(BuildContext context) {
    final lines = mgrs.split('\n');
    if (lines.length < 2) {
      return Text(mgrs, style: _textStyle(context));
    }

    final firstLine = lines[0];
    final secondLine = lines[1];
    final parts = secondLine.split(' ');
    if (parts.length < 2) {
      return Text(mgrs, style: _textStyle(context));
    }

    final easting = parts[0];
    final northing = parts[1];

    return RichText(
      text: TextSpan(
        style: _textStyle(context),
        children: [
          TextSpan(text: '$firstLine\n'),
          TextSpan(
            text: easting.substring(0, 3),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: '${easting.substring(3)} '),
          TextSpan(
            text: northing.substring(0, 3),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: northing.substring(3)),
        ],
      ),
    );
  }

  TextStyle _textStyle(BuildContext context) {
    return TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurface,
    );
  }
}
