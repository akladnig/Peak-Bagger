import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants.dart';
import '../../models/gpx_track.dart';
import '../../providers/map_provider.dart';
import '../../screens/map_screen_layers.dart';
import '../../services/latest_walk_summary.dart';
import '../../services/tile_cache_service.dart';

class LatestWalkCard extends StatefulWidget {
  const LatestWalkCard({super.key, required this.tracks});

  final List<GpxTrack> tracks;

  @override
  State<LatestWalkCard> createState() => _LatestWalkCardState();
}

class _LatestWalkCardState extends State<LatestWalkCard> {
  int? _selectedTrackId;

  @override
  void initState() {
    super.initState();
    _selectedTrackId = LatestWalkSummary.selectLatestTrack(widget.tracks)?.gpxTrackId;
  }

  @override
  void didUpdateWidget(covariant LatestWalkCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedTrackId == null) {
      _selectedTrackId = LatestWalkSummary.selectLatestTrack(widget.tracks)?.gpxTrackId;
      return;
    }

    final orderedTracks = LatestWalkSummary.orderedTracks(widget.tracks);
    if (LatestWalkSummary.indexOfTrackId(orderedTracks, _selectedTrackId!) == -1) {
      _selectedTrackId = LatestWalkSummary.selectLatestTrack(widget.tracks)?.gpxTrackId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderedTracks = LatestWalkSummary.orderedTracks(widget.tracks);
    if (orderedTracks.isEmpty) {
      return const KeyedSubtree(
        key: Key('latest-walk-card'),
        child: _LatestWalkEmptyState(),
      );
    }

    final selectedIndex = _resolveSelectedIndex(orderedTracks);
    final selectedTrack = orderedTracks[selectedIndex];
    final summary = LatestWalkSummary.fromTrack(selectedTrack);
    return KeyedSubtree(
      key: const Key('latest-walk-card'),
      child: summary.isEmpty
          ? const _LatestWalkEmptyState()
          : _LatestWalkContent(
              summary: summary,
              selectedIndex: selectedIndex,
              trackCount: orderedTracks.length,
              onPrevious: () => _selectTrack(orderedTracks[selectedIndex + 1].gpxTrackId),
              onNext: () => _selectTrack(orderedTracks[selectedIndex - 1].gpxTrackId),
            ),
    );
  }

  int _resolveSelectedIndex(List<GpxTrack> orderedTracks) {
    final selectedTrackId = _selectedTrackId;
    if (selectedTrackId != null) {
      final selectedIndex = LatestWalkSummary.indexOfTrackId(
        orderedTracks,
        selectedTrackId,
      );
      if (selectedIndex != -1) {
        return selectedIndex;
      }
    }

    _selectedTrackId = orderedTracks.first.gpxTrackId;
    return 0;
  }

  void _selectTrack(int trackId) {
    if (_selectedTrackId == trackId) {
      return;
    }
    setState(() => _selectedTrackId = trackId);
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
  const _LatestWalkContent({
    required this.summary,
    required this.selectedIndex,
    required this.trackCount,
    required this.onPrevious,
    required this.onNext,
  });

  final LatestWalkSummary summary;
  final int selectedIndex;
  final int trackCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.title,
                  key: const Key('latest-walk-track-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
              ),
              IconButton(
                key: const Key('latest-walk-prev-track'),
                tooltip: 'Previous track',
                onPressed: selectedIndex < trackCount - 1 ? onPrevious : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                key: const Key('latest-walk-next-track'),
                tooltip: 'Next track',
                onPressed: selectedIndex > 0 ? onNext : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
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

  static final _tickedPeakMarker = SvgPicture.asset(
    'assets/peak_marker_ticked.svg',
  );
  static final _untickedPeakMarker = SvgPicture.asset(
    'assets/peak_marker.svg',
    colorFilter: const ColorFilter.mode(Color(0xFFD66A6D), BlendMode.srcIn),
  );

  @override
  Widget build(BuildContext context) {
    final track = summary.track!;
    final points = summary.points;
    final trackPeaks = track.peaks.toList(growable: false);
    final correlatedPeakIds = buildCorrelatedPeakIds([track]);
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
            key: ValueKey('latest-walk-map-${track.gpxTrackId}'),
            options: options,
            children: [
              TileLayer(
                urlTemplate: mapTileUrl(Basemap.openstreetmap),
                userAgentPackageName: 'com.peak_bagger.app',
                tileProvider: buildLatestWalkTileProvider(
                  cacheAvailable:
                      TileCacheService.getStoreForBasemap(
                            Basemap.openstreetmap,
                          ) !=
                      null,
                ),
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
              if (trackPeaks.isNotEmpty)
                MarkerLayer(
                  markers: buildPeakMarkers(
                    peaks: trackPeaks,
                    zoom: 0,
                    correlatedPeakIds: correlatedPeakIds,
                    tickedPeakMarker: _tickedPeakMarker,
                    untickedPeakMarker: _untickedPeakMarker,
                    suppressBelowZoom: false,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

TileProvider buildLatestWalkTileProvider({required bool cacheAvailable}) {
  if (!cacheAvailable) {
    return NetworkTileProvider();
  }

  return FMTCTileProvider(
    stores: {
      'openstreetmap': BrowseStoreStrategy.readUpdateCreate,
    },
    loadingStrategy: BrowseLoadingStrategy.cacheFirst,
    urlTransformer: (url) => url,
  );
}
