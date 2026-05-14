import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/constants.dart';
import '../../models/gpx_track.dart';
import '../../providers/map_provider.dart';
import '../../screens/map_screen_layers.dart';
import '../../services/latest_walk_summary.dart';

class LatestWalkCard extends StatelessWidget {
  const LatestWalkCard({super.key, required this.tracks});

  final List<GpxTrack> tracks;

  @override
  Widget build(BuildContext context) {
    final summary = LatestWalkSummary.fromTracks(tracks);
    return KeyedSubtree(
      key: const Key('latest-walk-card'),
      child: summary.isEmpty
          ? const _LatestWalkEmptyState()
          : _LatestWalkContent(summary: summary),
    );
  }
}

class _LatestWalkEmptyState extends StatelessWidget {
  const _LatestWalkEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      key: const Key('latest-walk-empty-state'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No walks yet',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _LatestWalkContent extends StatelessWidget {
  const _LatestWalkContent({required this.summary});

  final LatestWalkSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final textStyle = theme.textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            summary.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.dateText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary.distanceText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary.ascentText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _LatestWalkMiniMap(summary: summary),
          ),
        ],
      ),
    );
  }
}

class _LatestWalkMiniMap extends StatelessWidget {
  const _LatestWalkMiniMap({required this.summary});

  final LatestWalkSummary summary;

  @override
  Widget build(BuildContext context) {
    final track = summary.track!;
    final points = summary.points;
    final theme = Theme.of(context);

    final options = points.length == 1
        ? MapOptions(
            initialCenter: points.single,
            initialZoom: MapConstants.defaultMapZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          )
        : MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(24),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          );

    return KeyedSubtree(
      key: const Key('latest-walk-mini-map'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          child: FlutterMap(
            options: options,
            children: [
              TileLayer(
                urlTemplate: mapTileUrl(Basemap.openstreetmap),
                userAgentPackageName: 'com.peak_bagger.app',
                tileProvider: NetworkTileProvider(),
              ),
              if (points.length == 1)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: points.single,
                      radius: 7,
                      color: Color(track.trackColour).withValues(alpha: 0.25),
                      borderColor: Color(track.trackColour),
                      borderStrokeWidth: 2,
                    ),
                  ],
                )
              else
                PolylineLayer(
                  polylines: [
                    for (final segment in summary.segments)
                      Polyline(
                        points: segment,
                        color: Color(track.trackColour),
                        strokeWidth: 3,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
