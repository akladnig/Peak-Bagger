import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/date_formatters.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/core/widgets/popup_keyboard_dismiss.dart';
import 'package:peak_bagger/core/widgets/popup_shell.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/models/waypoints.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/elevation_profile_series_builder.dart';
import 'package:peak_bagger/services/map_ruler_scale.dart';
import 'package:peak_bagger/services/peak_admin_editor.dart';
import 'package:peak_bagger/services/route_timing_service.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/peak_marker_glyph.dart';
import 'package:peak_bagger/widgets/peak_search_results_list.dart';
import 'package:peak_bagger/widgets/elevation_profile_chart.dart';

typedef PeakInfoPopupEditCallback = FutureOr<void> Function();
typedef PeakInfoPopupSaveCallback = Future<String?> Function(Peak peak);

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
    this.onEdit,
    this.onVisibilityChanged,
    this.onRouteWalkingSpeedChanged,
    this.onRouteTimingRecalculate,
    this.onExport,
    this.onElevationProfileHoverChanged,
    super.key,
  }) : assert(track != null || route != null),
       assert(track == null || route == null);

  final GpxTrack? track;
  final app_route.Route? route;
  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final ValueChanged<bool>? onVisibilityChanged;
  final ValueChanged<double>? onRouteWalkingSpeedChanged;
  final ValueChanged<RouteTimingAlgorithm>? onRouteTimingRecalculate;
  final VoidCallback? onExport;
  final ValueChanged<ElevationProfileChartHoverSample?>?
  onElevationProfileHoverChanged;

  @override
  Widget build(BuildContext context) {
    final isRoute = route != null;
    final displayName = isRoute ? _routeName(route!) : _trackName(track!);
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

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
                          if (isRoute)
                            IconButton(
                              key: const Key('track-info-panel-edit-button'),
                              tooltip: 'Edit Route',
                              onPressed: onEdit,
                              icon: Icon(Icons.edit, color: onSurfaceColor),
                            ),
                          if (isRoute) const SizedBox(width: 4),
                          IconButton(
                            key: const Key('track-info-panel-close'),
                            tooltip: isRoute
                                ? 'Close route info'
                                : 'Close track info',
                            onPressed: onClose,
                            icon: Icon(Icons.close, color: onSurfaceColor),
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
                        ? _buildRouteBody(
                            context,
                            route!,
                            onVisibilityChanged: onVisibilityChanged,
                            onRouteWalkingSpeedChanged:
                                onRouteWalkingSpeedChanged,
                            onRouteTimingRecalculate: onRouteTimingRecalculate,
                          )
                        : _buildTrackBody(
                            context,
                            track!,
                            onVisibilityChanged: onVisibilityChanged,
                          ),
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
                      icon: Icon(Icons.download, color: onSurfaceColor),
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

  Widget _buildRouteBody(
    BuildContext context,
    app_route.Route route, {
    required ValueChanged<bool>? onVisibilityChanged,
    required ValueChanged<double>? onRouteWalkingSpeedChanged,
    required ValueChanged<RouteTimingAlgorithm>? onRouteTimingRecalculate,
  }) {
    final legacyTimingExplanation = routeTimingExplanation(
      estimatedTime: route.estimatedTime,
      routeTimingSource: route.routeTimingSource,
    );
    final timingDisplay = resolveRouteTimingDisplay(
      points: route.gpxRoute,
      elevations: route.gpxRouteElevations,
      estimatedTimeMillis: route.estimatedTime,
      routeTimingSource: route.routeTimingSource,
      routeTimingProfileJson: route.routeTimingProfileJson,
      routeTimingSegmentKindsJson: route.routeTimingSegmentKindsJson,
      walkingSpeedKmh: route.walkingSpeedKmh,
    );
    final naismithInfo = routeTimingNaismithInfo(
      displayState: timingDisplay,
      routeTimingSource: route.routeTimingSource,
    );
    final scarfInfo = routeTimingScarfInfo(
      displayState: timingDisplay,
      routeTimingSource: route.routeTimingSource,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SummaryMetric(
                label: 'Distance (2d/3d)',
                value: formatDistance2d3d(route.distance2d, route.distance3d),
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
            onHoverChanged: onElevationProfileHoverChanged,
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
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Estimated Time'),
        thinDivider,
        const SizedBox(height: 16),
        if (legacyTimingExplanation != null)
          SizedBox.shrink(child: Text(legacyTimingExplanation)),
        KeyedSubtree(
          key: const Key('route-estimated-time-row'),
          child: Column(
            children: [
              const SizedBox.shrink(child: Text('Estimated Time')),
              _RouteTimingLabeledValueRow(
                key: const Key('route-estimated-time-naismith-row'),
                label: 'Estimated Time (Naismith)',
                value: timingDisplay.naismithDurationMillis == null
                    ? '—'
                    : formatDuration(timingDisplay.naismithDurationMillis),
                infoButtonKey: const Key('route-estimated-time-naismith-info'),
                recalculateButtonKey: const Key(
                  'route-estimated-time-naismith-recalculate',
                ),
                onInfoPressed: (anchorContext) {
                  _showRouteTimingInfoDialog(
                    panelContext: context,
                    anchorContext: anchorContext,
                    popupKey: const Key('route-estimated-time-naismith-popup'),
                    title: 'Estimated Time (Naismith)',
                    message: naismithInfo,
                  );
                },
                onRecalculate: onRouteTimingRecalculate == null
                    ? null
                    : () => onRouteTimingRecalculate(
                        RouteTimingAlgorithm.naismith,
                      ),
              ),
            ],
          ),
        ),
        thinDivider,
        _RouteTimingLabeledValueRow(
          key: const Key('route-estimated-time-scarf-row'),
          label: 'Estimated Time (Scarf)',
          value: timingDisplay.scarfDurationMillis == null
              ? '—'
              : formatDuration(timingDisplay.scarfDurationMillis),
          infoButtonKey: const Key('route-estimated-time-scarf-info'),
          recalculateButtonKey: const Key(
            'route-estimated-time-scarf-recalculate',
          ),
          onInfoPressed: (anchorContext) {
            _showRouteTimingInfoDialog(
              panelContext: context,
              anchorContext: anchorContext,
              popupKey: const Key('route-estimated-time-scarf-popup'),
              title: 'Estimated Time (Scarf)',
              message: scarfInfo,
            );
          },
          onRecalculate: onRouteTimingRecalculate == null
              ? null
              : () => onRouteTimingRecalculate(RouteTimingAlgorithm.scarf),
        ),
        const SizedBox(height: 12),
        if (timingDisplay.limitationMessage != null)
          Padding(
            key: const Key('route-timing-limitation-message'),
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              timingDisplay.limitationMessage!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        _RouteWalkingSpeedControl(
          speedKmh: timingDisplay.effectiveWalkingSpeedKmh,
          enabled: onRouteWalkingSpeedChanged != null,
          onChanged: onRouteWalkingSpeedChanged,
        ),
        const SizedBox(height: 20),
        _VisibilityToggleRow(
          key: const Key('track-info-panel-visibility-row'),
          label: route.visible
              ? 'Hide this route on the map'
              : 'Show this route on the map',
          visible: route.visible,
          onChanged: onVisibilityChanged,
        ),
      ],
    );
  }

  Widget _buildTrackBody(
    BuildContext context,
    GpxTrack track, {
    required ValueChanged<bool>? onVisibilityChanged,
  }) {
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
                label: 'Distance (2d/3d)',
                value: formatDistance2d3d(track.distance2d, track.distance3d),
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
            onHoverChanged: onElevationProfileHoverChanged,
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
        const SizedBox(height: 20),
        const _SectionTitle(title: 'Speed'),
        thinDivider,
        _LabeledValueRow(
          label: 'Average Speed',
          value: _formatTrackSpeed(
            track.averageSpeedKmh,
            durationMillis: track.totalTimeMillis,
          ),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'Moving Speed',
          value: _formatTrackSpeed(
            track.movingSpeedKmh,
            durationMillis: track.movingTime,
          ),
        ),
        thinDivider,
        _LabeledValueRow(
          label: 'Max Speed',
          value: _formatTrackSpeed(
            track.maxSpeedKmh,
            durationMillis: track.totalTimeMillis,
          ),
        ),
        const SizedBox(height: 20),
        _VisibilityToggleRow(
          key: const Key('track-info-panel-visibility-row'),
          label: track.visible
              ? 'Hide this track on the map'
              : 'Show this track on the map',
          visible: track.visible,
          onChanged: onVisibilityChanged,
        ),
      ],
    );
  }
}

enum TrackRouteChooserItemKind { track, route }

class TrackRouteChooserItem {
  const TrackRouteChooserItem.track({
    required this.track,
    required this.segments,
  }) : kind = TrackRouteChooserItemKind.track,
       route = null;

  const TrackRouteChooserItem.route({
    required this.route,
    required this.segments,
  }) : kind = TrackRouteChooserItemKind.route,
       track = null;

  final TrackRouteChooserItemKind kind;
  final GpxTrack? track;
  final app_route.Route? route;
  final List<List<LatLng>> segments;

  int get id =>
      kind == TrackRouteChooserItemKind.track ? track!.gpxTrackId : route!.id;

  String get displayName => switch (kind) {
    TrackRouteChooserItemKind.track => _chooserTrackName(track!),
    TrackRouteChooserItemKind.route => _chooserRouteName(route!),
  };

  String get subtitle => switch (kind) {
    TrackRouteChooserItemKind.track =>
      'Track • ${formatDistance(track!.distance2d, decimalPlaces: 1)} • ${formatTrackDate(track!.trackDate)} • ${formatDuration(track!.totalTimeMillis)}',
    TrackRouteChooserItemKind.route =>
      'Route • ${formatDistance(route!.distance2d, decimalPlaces: 1)}',
  };

  Color get color => switch (kind) {
    TrackRouteChooserItemKind.track => Color(track!.trackColour),
    TrackRouteChooserItemKind.route =>
      route!.colour == 0 ? const Color(0xFF4C8BF5) : Color(route!.colour),
  };
}

class TrackRouteChooserPopup extends StatelessWidget {
  const TrackRouteChooserPopup({
    required this.items,
    required this.onSelected,
    required this.onClose,
    super.key,
  });

  static const width = 392.0;
  static const maxHeight = 320.0;

  final List<TrackRouteChooserItem> items;
  final ValueChanged<TrackRouteChooserItem> onSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: maxHeight),
        child: PopupShell(
          key: const Key('track-route-chooser-popup'),
          title: Text(
            'Select Track or Route',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          onClose: onClose,
          closeButtonKey: const Key('track-route-chooser-close'),
          closeTooltip: 'Close chooser',
          bodyFlexible: true,
          body: ListView.separated(
            primary: false,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return _TrackRouteChooserRow(
                item: item,
                onTap: () => onSelected(item),
              );
            },
          ),
        ),
      ),
    );
  }
}

String _chooserTrackName(GpxTrack track) {
  return track.trackName.trim().isEmpty
      ? 'Unnamed Track'
      : track.trackName.trim();
}

String _chooserRouteName(app_route.Route route) {
  return route.name.trim().isEmpty ? 'Unnamed Route' : route.name.trim();
}

class _TrackRouteChooserRow extends StatelessWidget {
  const _TrackRouteChooserRow({required this.item, required this.onTap});

  final TrackRouteChooserItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('track-route-chooser-row-${item.kind.name}-${item.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                key: Key(
                  'track-route-chooser-thumbnail-${item.kind.name}-${item.id}',
                ),
                width: 44,
                height: 44,
                child: _TrackRouteChooserThumbnail(item: item),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackRouteChooserThumbnail extends StatelessWidget {
  const _TrackRouteChooserThumbnail({required this.item});

  final TrackRouteChooserItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (item.segments.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: CustomPaint(
          painter: _TrackRouteChooserThumbnailPainter(
            segments: item.segments,
            color: item.color,
            background: theme.colorScheme.surface,
          ),
        ),
      ),
    );
  }
}

class _TrackRouteChooserThumbnailPainter extends CustomPainter {
  const _TrackRouteChooserThumbnailPainter({
    required this.segments,
    required this.color,
    required this.background,
  });

  final List<List<LatLng>> segments;
  final Color color;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final fillPaint = Paint()
      ..color = background
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, fillPaint);

    final points = segments
        .expand((segment) => segment)
        .toList(growable: false);
    if (points.length < 2) {
      return;
    }

    final lats = points.map((point) => point.latitude).toList(growable: false);
    final lngs = points.map((point) => point.longitude).toList(growable: false);
    final minLat = lats.reduce((left, right) => left < right ? left : right);
    final maxLat = lats.reduce((left, right) => left > right ? left : right);
    final minLng = lngs.reduce((left, right) => left < right ? left : right);
    final maxLng = lngs.reduce((left, right) => left > right ? left : right);

    final latSpan = math.max((maxLat - minLat).abs(), 0.000001);
    final lngSpan = math.max((maxLng - minLng).abs(), 0.000001);
    final padding = 6.0;
    final usableWidth = (size.width - padding * 2).clamp(1.0, double.infinity);
    final usableHeight = (size.height - padding * 2).clamp(
      1.0,
      double.infinity,
    );
    final scale = math.min(usableWidth / lngSpan, usableHeight / latSpan);
    final pathPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (final segment in segments) {
      if (segment.length < 2) {
        continue;
      }
      for (var i = 0; i < segment.length; i++) {
        final point = segment[i];
        final dx = padding + (point.longitude - minLng) * scale;
        final dy = size.height - padding - (point.latitude - minLat) * scale;
        if (i == 0) {
          path.moveTo(dx, dy);
        } else {
          path.lineTo(dx, dy);
        }
      }
    }
    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(covariant _TrackRouteChooserThumbnailPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.color != color ||
        oldDelegate.background != background;
  }
}

class _VisibilityToggleRow extends StatelessWidget {
  const _VisibilityToggleRow({
    super.key,
    required this.label,
    required this.visible,
    required this.onChanged,
  });

  final String label;
  final bool visible;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          key: const Key('track-info-panel-visibility-switch'),
          value: visible,
          onChanged: onChanged,
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

class _RouteTimingLabeledValueRow extends StatelessWidget {
  const _RouteTimingLabeledValueRow({
    required this.label,
    required this.value,
    required this.infoButtonKey,
    required this.recalculateButtonKey,
    required this.onInfoPressed,
    this.onRecalculate,
    super.key,
  });

  final String label;
  final String value;
  final Key infoButtonKey;
  final Key recalculateButtonKey;
  final ValueChanged<BuildContext> onInfoPressed;
  final VoidCallback? onRecalculate;

  @override
  Widget build(BuildContext context) {
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Builder(
                  builder: (buttonContext) {
                    return IconButton(
                      key: infoButtonKey,
                      onPressed: () => onInfoPressed(buttonContext),
                      icon: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(buttonContext).colorScheme.onSurface,
                      ),
                      tooltip: '$label info',
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.end,
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: recalculateButtonKey,
                  onPressed: onRecalculate,
                  icon: Icon(Icons.refresh, size: 16, color: onSurfaceColor),
                  tooltip: 'Recalculate $label',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RouteTimingInfoDialog extends StatelessWidget {
  const RouteTimingInfoDialog({
    required this.leftInset,
    required this.topInset,
    required this.title,
    required this.message,
    super.key,
  });

  final double leftInset;
  final double topInset;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    return Dialog(
      key: key,
      alignment: Alignment.topLeft,
      insetPadding: EdgeInsets.only(
        left: leftInset,
        top: topInset,
        right: UiConstants.dialogMargin,
        bottom: UiConstants.dialogMargin,
      ),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: UiConstants.peakInfoPopupSize.width,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: UiConstants.peakInfoPopupSize.height,
          ),
          child: PopupShell(
            title: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: onSurfaceColor,
              ),
            ),
            leading: Icon(
              Icons.info_outline,
              size: PopupUIConstants.headerIconSize,
              color: onSurfaceColor,
            ),
            onClose: () => Navigator.of(context).pop(),
            closeButtonKey: const Key('route-timing-info-popup-close'),
            closeTooltip: 'Close route timing info',
            bodyFlexible: true,
            body: SingleChildScrollView(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onSurfaceColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showRouteTimingInfoDialog({
  required BuildContext panelContext,
  required BuildContext anchorContext,
  required Key popupKey,
  required String title,
  required String message,
}) {
  final panelRenderBox = panelContext.findRenderObject() as RenderBox?;
  final anchorRenderBox = anchorContext.findRenderObject() as RenderBox?;
  final panelTopLeft =
      panelRenderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
  final anchorTopLeft =
      anchorRenderBox?.localToGlobal(Offset.zero) ?? panelTopLeft;
  final panelWidth =
      panelRenderBox?.size.width ?? UiConstants.preferredLeftWidth;
  showDialog<void>(
    context: panelContext,
    builder: (context) => RouteTimingInfoDialog(
      key: popupKey,
      leftInset: panelTopLeft.dx + panelWidth + UiConstants.dialogMargin,
      topInset: anchorTopLeft.dy,
      title: title,
      message: message,
    ),
  );
}

class _RouteWalkingSpeedControl extends StatefulWidget {
  const _RouteWalkingSpeedControl({
    required this.speedKmh,
    required this.enabled,
    required this.onChanged,
  });

  final double speedKmh;
  final bool enabled;
  final ValueChanged<double>? onChanged;

  @override
  State<_RouteWalkingSpeedControl> createState() =>
      _RouteWalkingSpeedControlState();
}

class _RouteWalkingSpeedControlState extends State<_RouteWalkingSpeedControl> {
  late final FocusNode _textFieldFocusNode;
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _textFieldFocusNode = FocusNode(debugLabel: 'route-walking-speed-field')
      ..addListener(_handleTextFieldFocusChange);
    _controller = TextEditingController(text: _formatSpeed(widget.speedKmh));
  }

  @override
  void dispose() {
    _textFieldFocusNode
      ..removeListener(_handleTextFieldFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RouteWalkingSpeedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_textFieldFocusNode.hasFocus &&
        widget.speedKmh != oldWidget.speedKmh) {
      _controller.value = TextEditingValue(
        text: _formatSpeed(widget.speedKmh),
        selection: TextSelection.collapsed(
          offset: _formatSpeed(widget.speedKmh).length,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.minus): () =>
            _changeSpeed(-routeTimingWalkingSpeedStepKmh),
        const SingleActivator(LogicalKeyboardKey.minus, shift: true): () =>
            _changeSpeed(-routeTimingWalkingSpeedStepKmh),
        const SingleActivator(LogicalKeyboardKey.equal): () =>
            _changeSpeed(routeTimingWalkingSpeedStepKmh),
        const SingleActivator(LogicalKeyboardKey.equal, shift: true): () =>
            _changeSpeed(routeTimingWalkingSpeedStepKmh),
        const SingleActivator(LogicalKeyboardKey.numpadAdd): () =>
            _changeSpeed(routeTimingWalkingSpeedStepKmh),
        const SingleActivator(LogicalKeyboardKey.numpadSubtract): () =>
            _changeSpeed(-routeTimingWalkingSpeedStepKmh),
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Walking Speed', style: textStyle),
                ),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _textFieldFocusNode.requestFocus(),
                        child: Row(
                          key: const Key('route-walking-speed-control'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: const Key('route-walking-speed-decrement'),
                              onPressed: widget.enabled
                                  ? () {
                                      _textFieldFocusNode.requestFocus();
                                      _changeSpeed(
                                        -routeTimingWalkingSpeedStepKmh,
                                      );
                                    }
                                  : null,
                              icon: Icon(Icons.remove, color: onSurfaceColor),
                              tooltip: 'Decrease walking speed',
                              visualDensity: VisualDensity.compact,
                            ),
                            SizedBox(
                              width: 68,
                              child: TextField(
                                key: const Key('route-walking-speed-field'),
                                controller: _controller,
                                focusNode: _textFieldFocusNode,
                                enabled: widget.enabled,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textAlign: TextAlign.center,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (_) {
                                  if (_errorText != null) {
                                    setState(() => _errorText = null);
                                  }
                                },
                                onSubmitted: (_) => _commitTextField(),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'km/h',
                              key: const Key('route-walking-speed-value'),
                            ),
                            IconButton(
                              key: const Key('route-walking-speed-increment'),
                              onPressed: widget.enabled
                                  ? () {
                                      _textFieldFocusNode.requestFocus();
                                      _changeSpeed(
                                        routeTimingWalkingSpeedStepKmh,
                                      );
                                    }
                                  : null,
                              icon: Icon(Icons.add, color: onSurfaceColor),
                              tooltip: 'Increase walking speed',
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _errorText!,
                  key: const Key('route-walking-speed-error'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _changeSpeed(double delta) {
    if (!widget.enabled || widget.onChanged == null) {
      return;
    }

    final nextValue = normalizeWalkingSpeedKmh(
      ((widget.speedKmh * 10).round() + (delta * 10).round()) / 10,
    );
    if (nextValue == widget.speedKmh) {
      return;
    }
    _controller.value = TextEditingValue(
      text: _formatSpeed(nextValue),
      selection: TextSelection.collapsed(
        offset: _formatSpeed(nextValue).length,
      ),
    );
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
    widget.onChanged!(nextValue);
  }

  void _handleTextFieldFocusChange() {
    if (!_textFieldFocusNode.hasFocus) {
      _commitTextField();
    }
  }

  void _commitTextField() {
    if (!widget.enabled) {
      return;
    }

    final trimmed = _controller.text.trim();
    final parsed = double.tryParse(trimmed);
    if (trimmed.isEmpty || parsed == null) {
      setState(() => _errorText = 'Enter 0.5 to 9.9');
      return;
    }
    if (parsed < routeTimingMinWalkingSpeedKmh ||
        parsed > routeTimingMaxWalkingSpeedKmh) {
      setState(() => _errorText = 'Enter 0.5 to 9.9');
      return;
    }

    final nextValue = normalizeWalkingSpeedKmh(parsed);
    _controller.value = TextEditingValue(
      text: _formatSpeed(nextValue),
      selection: TextSelection.collapsed(
        offset: _formatSpeed(nextValue).length,
      ),
    );
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
    if (nextValue != widget.speedKmh) {
      widget.onChanged?.call(nextValue);
    }
  }

  String _formatSpeed(double value) => value.toStringAsFixed(1);
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
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

String _formatTrackSpeed(double speedKmh, {required int? durationMillis}) {
  if (durationMillis == null || durationMillis == 0) {
    return 'Unknown';
  }
  return formatSpeedKmh(speedKmh);
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
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
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
                    decoration: InputDecoration(
                      hintText: 'Search peaks',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: onSurfaceColor,
                      ),
                    ),
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('peak-search-close'),
                  icon: Icon(Icons.close, color: onSurfaceColor),
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
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
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
                  icon: Icon(Icons.close, color: onSurfaceColor),
                  onPressed: onClose,
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
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    return PopupShell(
      key: const Key('map-info-popup'),
      leading: Icon(
        Icons.map,
        size: PopupUIConstants.headerIconSize,
        color: onSurfaceColor,
      ),
      title: Text(
        infoMapName ?? 'Unknown',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      closeButtonKey: const Key('map-info-popup-close'),
      closeTooltip: 'Close map info',
      onClose: onClose,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (infoMgrs != null)
            Text(
              infoMgrs!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
          if (infoPeakName != null) ...[
            if (infoMgrs != null) const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.terrain, size: 16, color: onSurfaceColor),
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
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: onSurfaceColor,
                ),
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
                Icon(Icons.route, size: 16, color: onSurfaceColor),
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
    );
  }
}

class MapTapActionPopupCard extends StatelessWidget {
  const MapTapActionPopupCard({
    required this.onDropMarker,
    required this.onDropFavourite,
    required this.onClose,
    this.onDriveEtaHome,
    this.onDriveEtaMarker,
    super.key,
  });

  final VoidCallback onDropMarker;
  final VoidCallback onDropFavourite;
  final VoidCallback onClose;
  final VoidCallback? onDriveEtaHome;
  final VoidCallback? onDriveEtaMarker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    return SizedBox(
      width: 260,
      child: PopupShell(
        key: const Key('map-tap-action-popup'),
        title: Text(
          'Drop Marker',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        onClose: onClose,
        closeButtonKey: const Key('map-tap-action-close'),
        closeTooltip: 'Close Drop Marker',
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
              minTileHeight: 44,
              key: const Key('map-tap-action-drop-marker'),
              leading: const Icon(Icons.my_location, color: Colors.amber),
              title: const Text('Drop Marker'),
              onTap: onDropMarker,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              visualDensity: VisualDensity.compact,
              minTileHeight: 44,
              key: const Key('map-tap-action-drop-favourite'),
              leading: const Icon(Icons.favorite, color: favouriteMarkerColour),
              title: const Text('Drop Favourite'),
              onTap: onDropFavourite,
            ),
            if (onDriveEtaHome != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                minTileHeight: 44,
                key: const Key('map-tap-action-drive-home'),
                leading: Icon(Icons.drive_eta, color: onSurfaceColor),
                title: const Text('Get driving time from Home'),
                onTap: onDriveEtaHome,
              ),
            if (onDriveEtaMarker != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: VisualDensity.compact,
                minTileHeight: 44,
                key: const Key('map-tap-action-drive-marker'),
                leading: Icon(Icons.drive_eta, color: onSurfaceColor),
                title: const Text('Get driving time from Marker'),
                onTap: onDriveEtaMarker,
              ),
          ],
        ),
      ),
    );
  }
}

class FavouritesPopupCard extends StatelessWidget {
  const FavouritesPopupCard({
    required this.favourites,
    required this.onSelect,
    required this.onClose,
    super.key,
  });

  final List<Waypoints> favourites;
  final ValueChanged<Waypoints> onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: PopupShell(
          key: const Key('favourites-popup'),
          title: Text(
            'Favourites',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          onClose: onClose,
          closeButtonKey: const Key('favourites-popup-close'),
          closeTooltip: 'Close favourites',
          bodyFlexible: favourites.isNotEmpty,
          body: favourites.isEmpty
              ? const Padding(
                  key: Key('favourites-popup-empty'),
                  padding: EdgeInsets.only(top: 4),
                  child: Text('No favourites saved yet.'),
                )
              : ListView.builder(
                  primary: false,
                  shrinkWrap: true,
                  itemCount: favourites.length,
                  itemBuilder: (context, index) {
                    final favourite = favourites[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      minTileHeight: 44,
                      key: Key('favourites-popup-row-${favourite.id}'),
                      leading: const Icon(
                        Icons.favorite,
                        color: favouriteMarkerColour,
                      ),
                      title: Text(
                        favourite.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        favourite.mgrs,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSelect(favourite),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

Future<String?> showFavouriteNameDialog(
  BuildContext context, {
  required bool Function(String name) nameExists,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => FavouriteNameDialog(nameExists: nameExists),
  );
}

class FavouriteNameDialog extends StatefulWidget {
  const FavouriteNameDialog({required this.nameExists, super.key});

  final bool Function(String name) nameExists;

  @override
  State<FavouriteNameDialog> createState() => _FavouriteNameDialogState();
}

class _FavouriteNameDialogState extends State<FavouriteNameDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    final errorText = switch (trimmed) {
      '' => 'Enter a favourite name.',
      _ when widget.nameExists(trimmed) =>
        'A favourite with that name already exists.',
      _ => null,
    };
    if (errorText != null) {
      setState(() {
        _errorText = errorText;
      });
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return PopupKeyboardDismiss(
      onDismiss: () => Navigator.of(context).pop(),
      child: AlertDialog(
        key: const Key('favourite-name-dialog'),
        title: const Text('Save Favourite'),
        content: TextField(
          key: const Key('favourite-name-input'),
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(errorText: _errorText),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
            key: const Key('favourite-name-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('favourite-name-save'),
            onPressed: _submit,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class PeakInfoPopupCard extends StatefulWidget {
  const PeakInfoPopupCard({
    required this.content,
    required this.onClose,
    this.onEdit,
    this.onSaveEdit,
    this.currentMarker,
    this.onEditInAdmin,
    this.onDropMarker,
    super.key,
  });

  final PeakInfoContent content;
  final VoidCallback onClose;
  final PeakInfoPopupEditCallback? onEdit;
  final PeakInfoPopupSaveCallback? onSaveEdit;
  final Waypoints? currentMarker;
  final VoidCallback? onEditInAdmin;
  final VoidCallback? onDropMarker;

  @override
  State<PeakInfoPopupCard> createState() => _PeakInfoPopupCardState();
}

class _PeakInfoPopupCardState extends State<PeakInfoPopupCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _elevationController;
  late Peak _draftPeak;
  String? _nameError;
  String? _elevationError;
  String? _submitError;
  bool _isEditing = false;
  bool _isSaving = false;

  bool get _canEdit => widget.onEdit != null && widget.onSaveEdit != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _elevationController = TextEditingController();
    _syncDraftFromContent();
  }

  @override
  void didUpdateWidget(covariant PeakInfoPopupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content.peak.osmId != widget.content.peak.osmId ||
        (!_isEditing && oldWidget.content.peak != widget.content.peak)) {
      _syncDraftFromContent();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _elevationController.dispose();
    super.dispose();
  }

  void _syncDraftFromContent() {
    _draftPeak = widget.content.peak;
    _nameController.text = _draftPeak.name;
    _elevationController.text = _formatOptionalElevation(_draftPeak.elevation);
    _nameError = null;
    _elevationError = null;
    _submitError = null;
    _isSaving = false;
  }

  Future<void> _startEditing() async {
    final onEdit = widget.onEdit;
    if (onEdit == null || _isSaving) {
      return;
    }

    await onEdit();
    if (!mounted) {
      return;
    }

    setState(() {
      _syncDraftFromContent();
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    if (_isSaving) {
      return;
    }

    setState(() {
      _syncDraftFromContent();
      _isEditing = false;
    });
  }

  void _clearFieldErrors() {
    if (_nameError == null && _elevationError == null && _submitError == null) {
      return;
    }

    setState(() {
      _nameError = null;
      _elevationError = null;
      _submitError = null;
    });
  }

  Future<void> _saveEditing() async {
    final onSaveEdit = widget.onSaveEdit;
    if (onSaveEdit == null || _isSaving) {
      return;
    }

    final name = _nameController.text.trim();
    final elevationText = _elevationController.text.trim();
    String? nameError;
    String? elevationError;
    double? elevation;

    if (name.isEmpty) {
      nameError = PeakAdminEditor.nameRequiredError;
    }
    if (elevationText.isNotEmpty) {
      final parsedElevation = int.tryParse(elevationText);
      if (parsedElevation == null) {
        elevationError = PeakAdminEditor.elevationError;
      } else {
        elevation = parsedElevation.toDouble();
      }
    }

    if (nameError != null || elevationError != null) {
      setState(() {
        _nameError = nameError;
        _elevationError = elevationError;
        _submitError = null;
      });
      return;
    }

    final draft = _draftPeak.copyWith(
      name: name,
      elevation: elevation,
      verified: true,
      sourceOfTruth: Peak.sourceOfTruthHwc,
    );

    setState(() {
      _nameError = null;
      _elevationError = null;
      _submitError = null;
      _isSaving = true;
    });

    final error = await onSaveEdit(draft);
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
      if (error == null) {
        _draftPeak = draft;
        _isEditing = false;
        _submitError = null;
      } else {
        _submitError = error;
      }
    });
  }

  void _moveToMarker() {
    final marker = widget.currentMarker;
    if (marker == null || _isSaving) {
      return;
    }

    final result = PeakAdminEditor.updatePeakFromLatLng(
      source: _draftPeak,
      location: LatLng(marker.latitude, marker.longitude),
    );
    final peak = result.peak;
    setState(() {
      if (peak != null) {
        _draftPeak = peak;
        _submitError = null;
      } else {
        _submitError =
            result.coordinateError ?? PeakAdminEditor.latLngConversionError;
      }
    });
  }

  static String _formatOptionalElevation(double? value) {
    if (value == null) {
      return '';
    }
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;
    final content = widget.content;
    final peak = _draftPeak;
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

    final headerActions = <Widget>[
      if (_canEdit)
        IconButton(
          key: const Key('peak-info-popup-edit'),
          tooltip: 'Edit Peak',
          icon: Icon(
            Icons.edit,
            size: PopupUIConstants.closeIconSize,
            color: onSurfaceColor,
          ),
          onPressed: _isEditing ? null : _startEditing,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      if (!_isEditing && widget.onDropMarker != null)
        IconButton(
          key: const Key('peak-info-popup-drop-marker'),
          tooltip: 'Drop a Marker on the Peak',
          icon: Icon(
            Icons.my_location,
            color: Colors.amber,
            size: PopupUIConstants.closeIconSize,
          ),
          onPressed: _isSaving ? null : widget.onDropMarker,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
    ];

    final footer = switch ((_isEditing, widget.onEditInAdmin)) {
      (true, _) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonal(
            key: const Key('peak-info-popup-cancel'),
            onPressed: _isSaving ? null : _cancelEditing,
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('peak-info-popup-save'),
            onPressed: _isSaving ? null : _saveEditing,
            child: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      (false, final onEditInAdmin?) => FilledButton.tonal(
        key: const Key('peak-info-popup-edit-admin'),
        onPressed: onEditInAdmin,
        child: const Text('Edit in Peak Admin'),
      ),
      _ => null,
    };

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: UiConstants.peakInfoPopupSize.height,
      ),
      child: PopupShell(
        leading: Icon(
          Icons.terrain,
          size: PopupUIConstants.headerIconSize,
          color: onSurfaceColor,
        ),
        title: Text(
          peak.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        headerActions: headerActions,
        onClose: _isEditing || _isSaving ? null : widget.onClose,
        closeButtonKey: const Key('peak-info-popup-close'),
        closeTooltip: 'Close Peak Info',
        bodyFlexible: true,
        body: SingleChildScrollView(
          child: Column(
            key: _isEditing ? const Key('peak-info-popup-edit-form') : null,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditing) ...[
                TextField(
                  key: const Key('peak-info-popup-name'),
                  controller: _nameController,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    errorText: _nameError,
                  ),
                  onChanged: (_) => _clearFieldErrors(),
                ),
                const SizedBox(height: 8),
                Tooltip(
                  message: 'Move Peak to Marker',
                  child: InkWell(
                    key: const Key('peak-info-popup-move-to-marker'),
                    onTap: widget.currentMarker == null || _isSaving
                        ? null
                        : _moveToMarker,
                    borderRadius: BorderRadius.circular(4),
                    child: Opacity(
                      opacity: widget.currentMarker == null ? 0.5 : 1,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: PeakMarkerGlyph(ticked: false, size: 16),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_right_alt,
                              size: 16,
                              color: onSurfaceColor,
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.my_location,
                              size: 16,
                              color: Colors.amber,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('peak-info-popup-elevation'),
                  controller: _elevationController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Height',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixText: 'm',
                    errorText: _elevationError,
                  ),
                  onChanged: (_) => _clearFieldErrors(),
                ),
                if (mgrsText != null) ...[
                  const SizedBox(height: 8),
                  _PeakInfoLabeledValueRow(
                    label: 'MGRS:',
                    value: mgrsText,
                    monospaceValue: true,
                  ),
                ],
                if (_submitError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _submitError!,
                    key: const Key('peak-info-popup-error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
              ] else ...[
                if (altName.isNotEmpty) ...[
                  _PeakInfoLabeledValueRow(label: 'Alt Name:', value: altName),
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
                    child: Text('My Ascents:', style: TextStyle(fontSize: 13)),
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
                if (content.ascentRows.isNotEmpty) const SizedBox(height: 4),
                _PeakInfoLabeledValueRow(
                  label: content.mapLabel,
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
            ],
          ),
        ),
        footer: footer,
      ),
    );
  }
}

class PeakInfoPopupSurface extends StatelessWidget {
  const PeakInfoPopupSurface({
    required this.content,
    required this.onClose,
    this.onEdit,
    this.onSaveEdit,
    this.currentMarker,
    this.onEditInAdmin,
    this.onDropMarker,
    required this.bridgeOnLeft,
    super.key,
  });

  static const bridgeWidth = 12.0;

  final PeakInfoContent content;
  final VoidCallback onClose;
  final PeakInfoPopupEditCallback? onEdit;
  final PeakInfoPopupSaveCallback? onSaveEdit;
  final Waypoints? currentMarker;
  final VoidCallback? onEditInAdmin;
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
          alignment: bridgeOnLeft
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: SizedBox(
            width: popupWidth,
            child: PeakInfoPopupCard(
              key: const Key('peak-info-popup'),
              content: content,
              onClose: onClose,
              onEdit: onEdit,
              onSaveEdit: onSaveEdit,
              currentMarker: currentMarker,
              onEditInAdmin: onEditInAdmin,
              onDropMarker: onDropMarker,
            ),
          ),
        ),
      ),
    );
  }
}

class DriveEtaPopupSurface extends StatelessWidget {
  const DriveEtaPopupSurface({
    required this.state,
    required this.onClose,
    required this.bridgeOnLeft,
    super.key,
  });

  final DriveEtaPopupState state;
  final VoidCallback onClose;
  final bool bridgeOnLeft;

  @override
  Widget build(BuildContext context) {
    final popupWidth = UiConstants.peakInfoPopupSize.width;
    final totalWidth = popupWidth + PeakInfoPopupSurface.bridgeWidth;

    return MouseRegion(
      child: SizedBox(
        width: totalWidth,
        child: Align(
          alignment: bridgeOnLeft
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: SizedBox(
            width: popupWidth,
            child: DriveEtaPopupCard(state: state, onClose: onClose),
          ),
        ),
      ),
    );
  }
}

class DriveEtaPopupCard extends StatelessWidget {
  const DriveEtaPopupCard({
    required this.state,
    required this.onClose,
    super.key,
  });

  final DriveEtaPopupState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final body = switch (state.status) {
      DriveEtaPopupStatus.loading => const Align(
        alignment: Alignment.centerLeft,
        child: Text('Calculating Route', key: Key('drive-eta-popup-loading')),
      ),
      DriveEtaPopupStatus.error => Align(
        alignment: Alignment.centerLeft,
        child: Text(
          state.errorMessage ?? 'Drive ETA unavailable.',
          key: const Key('drive-eta-popup-error'),
        ),
      ),
      DriveEtaPopupStatus.success => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _DriveEtaLabeledValueRow(
            key: const Key('drive-eta-popup-duration-row'),
            label: 'Duration:',
            value: formatDuration(
              (state.durationSeconds ?? 0) * Duration.millisecondsPerSecond,
            ),
          ),
          const SizedBox(height: 4),
          _DriveEtaLabeledValueRow(
            key: const Key('drive-eta-popup-distance-row'),
            label: 'Distance:',
            value: formatDistance(state.distanceMeters ?? 0, decimalPlaces: 1),
          ),
        ],
      ),
    };

    return PopupShell(
      key: const Key('drive-eta-popup-root'),
      leading: Icon(
        Icons.directions_car,
        size: PopupUIConstants.headerIconSize,
        color: onSurfaceColor,
      ),
      title: Text(
        state.title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      onClose: onClose,
      closeButtonKey: const Key('drive-eta-popup-close'),
      closeTooltip: 'Close drive ETA',
      body: body,
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

    return PopupShell(
      title: Text('Edit Point', style: theme.textTheme.titleSmall),
      onClose: onClose,
      closeButtonKey: const Key('route-draft-delete-popup-close'),
      closeTooltip: 'Close point actions',
      body: TextButton.icon(
        key: const Key('route-draft-delete-action'),
        onPressed: onDelete,
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        icon: const Icon(Icons.delete_forever, color: Colors.red),
        label: const Text('Delete Point'),
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

class _DriveEtaLabeledValueRow extends StatelessWidget {
  const _DriveEtaLabeledValueRow({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          TextSpan(text: label),
          const TextSpan(text: ' '),
          TextSpan(
            text: value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
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
