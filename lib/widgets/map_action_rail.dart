import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_file_picker.dart';
import 'package:peak_bagger/services/import/gpx_track_import_models.dart';
import 'package:peak_bagger/widgets/gpx_track_import_dialog.dart';
import 'package:peak_bagger/widgets/left_tooltip_fab.dart';

class MapActionRail extends ConsumerWidget {
  const MapActionRail({super.key});

  static const _railSpacing = 8.0;

  void _dismissTransientUi(
    WidgetRef ref, {
    bool closeInfoPopup = false,
    bool closePeakSearch = false,
    bool closeGotoInput = false,
  }) {
    final mapState = ref.read(mapProvider);
    final notifier = ref.read(mapProvider.notifier);

    if (closeInfoPopup && mapState.showInfoPopup) {
      notifier.toggleInfoPopup();
    }
    if (closePeakSearch && mapState.showPeakSearch) {
      notifier.setPeakSearchVisible(false);
    }
    if (closeGotoInput && mapState.showGotoInput) {
      notifier.setGotoInputVisible(false);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mapState = ref.watch(mapProvider);
    final isDisabled =
        mapState.tracks.isEmpty ||
        mapState.isLoadingTracks ||
        mapState.hasTrackRecoveryIssue;

    return Positioned(
      top: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: _railSpacing),
          LeftTooltipFab(
            message: 'Search peaks',
            child: FloatingActionButton.small(
              key: const Key('search-peaks-fab'),
              heroTag: 'search',
              backgroundColor: Theme.of(context).colorScheme.surface,
              onPressed: () {
                _dismissTransientUi(ref, closeInfoPopup: true);
                ref.read(mapProvider.notifier).togglePeakSearch();
              },
              child: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: _railSpacing),
          LeftTooltipFab(
            message: 'Select Basemaps',
            child: FloatingActionButton.small(
              heroTag: 'layers',
              backgroundColor: Theme.of(context).colorScheme.surface,
              onPressed: () {
                _dismissTransientUi(
                  ref,
                  closeInfoPopup: true,
                  closePeakSearch: true,
                );
                Scaffold.of(context).openEndDrawer();
              },
              child: Icon(
                Icons.layers,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: _railSpacing),
          LeftTooltipFab(
            message: 'My location',
            child: FloatingActionButton.small(
              heroTag: 'mylocation',
              backgroundColor: Theme.of(context).colorScheme.surface,
              onPressed: () async {
                _dismissTransientUi(
                  ref,
                  closeInfoPopup: true,
                  closePeakSearch: true,
                  closeGotoInput: true,
                );
                try {
                  final serviceEnabled =
                      await Geolocator.isLocationServiceEnabled();
                  if (!serviceEnabled) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Location services are disabled'),
                        ),
                      );
                    }
                    return;
                  }

                  var permission = await Geolocator.checkPermission();
                  if (permission == LocationPermission.denied) {
                    permission = await Geolocator.requestPermission();
                    if (permission == LocationPermission.denied) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location permission denied'),
                          ),
                        );
                      }
                      return;
                    }
                  }

                  if (permission == LocationPermission.deniedForever) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Location permissions are permanently denied',
                          ),
                        ),
                      );
                    }
                    return;
                  }

                  final position = await Geolocator.getCurrentPosition(
                    locationSettings: const LocationSettings(
                      accuracy: LocationAccuracy.high,
                    ),
                  );
                  ref
                      .read(mapProvider.notifier)
                      .centerOnLocation(
                        LatLng(position.latitude, position.longitude),
                      );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Location error: $e')),
                    );
                  }
                }
              },
              child: Icon(
                Icons.near_me,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: _railSpacing),
          LeftTooltipFab(
            message: 'Center on marker',
            child: FloatingActionButton.small(
              heroTag: 'centermarker',
              backgroundColor: Theme.of(context).colorScheme.surface,
              onPressed: () {
                _dismissTransientUi(
                  ref,
                  closeInfoPopup: true,
                  closePeakSearch: true,
                  closeGotoInput: true,
                );
                ref.read(mapProvider.notifier).centerOnSelectedLocation();
              },
              child: const Icon(Icons.my_location, color: Colors.amber),
            ),
          ),
          const SizedBox(height: _railSpacing),
          LeftTooltipFab(
            message: 'Goto Location',
            child: FloatingActionButton.small(
              key: const Key('goto-map-fab'),
              heroTag: 'goto',
              backgroundColor: Theme.of(context).colorScheme.surface,
              onPressed: () {
                _dismissTransientUi(
                  ref,
                  closeInfoPopup: true,
                  closePeakSearch: true,
                  closeGotoInput: true,
                );
                ref.read(mapProvider.notifier).toggleGotoInput();
              },
              child: Icon(
                Icons.directions,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: _railSpacing),
          LeftTooltipFab(
            message: 'Show Map Grid',
            child: FloatingActionButton.small(
              key: const Key('grid-map-fab'),
              heroTag: 'grid',
              backgroundColor: Theme.of(context).colorScheme.surface,
              onPressed: () {
                ref.read(mapProvider.notifier).toggleMapOverlay();
              },
              child: Icon(
                Icons.grid_on,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: _railSpacing),
          LeftTooltipFab(
            message: 'Show tracks',
            child: FloatingActionButton.small(
              key: const Key('show-tracks-fab'),
              heroTag: 'tracks',
              backgroundColor: Theme.of(context).colorScheme.surface,
              onPressed: isDisabled
                  ? null
                  : () {
                      ref.read(mapProvider.notifier).toggleTracks();
                    },
              child: Icon(
                Icons.route,
                color: isDisabled
                    ? Colors.red
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: _railSpacing),
          LeftTooltipFab(
            message: 'Show peaks',
            child: FloatingActionButton.small(
              key: const Key('show-peaks-fab'),
              heroTag: 'peaks',
              backgroundColor: Theme.of(context).colorScheme.surface,
              onPressed: () {
                ref.read(mapProvider.notifier).togglePeaks();
              },
              child: Icon(
                Icons.landscape,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: _railSpacing),
          LeftTooltipFab(
            message: 'Import Track(s)',
            child: FloatingActionButton.small(
              key: const Key('import-tracks-fab'),
              heroTag: 'import',
              backgroundColor: Theme.of(context).colorScheme.surface,
              onPressed:
                  mapState.isLoadingTracks || mapState.hasTrackRecoveryIssue
                  ? null
                  : () => _showGpxImportDialog(context, ref),
              child: mapState.isLoadingTracks
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.input,
                      color: mapState.hasTrackRecoveryIssue
                          ? Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.38)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
            ),
          ),
          const SizedBox(height: _railSpacing),
          LeftTooltipFab(
            message: 'Info',
            child: FloatingActionButton.small(
              key: const Key('map-info-fab'),
              heroTag: 'info',
              backgroundColor: Theme.of(context).colorScheme.surface,
              onPressed: () {
                _dismissTransientUi(
                  ref,
                  closeInfoPopup: true,
                  closePeakSearch: true,
                  closeGotoInput: true,
                );
                ref.read(mapProvider.notifier).toggleInfoPopup();
              },
              child: Icon(
                Icons.info,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGpxImportDialog(BuildContext context, WidgetRef ref) async {
    final filePicker = ref.read(gpxFilePickerProvider);

    await showDialog<GpxTrackImportResult>(
      context: context,
      builder: (dialogContext) {
        return SizedBox(
          width: 320,
          child: Dialog(
            child: GpxTrackImportDialog(
              filePicker: filePicker,
              onImport: ({required Map<String, String> pathToEditedNames}) {
                return ref
                    .read(mapProvider.notifier)
                    .importGpxFiles(pathToEditedNames: pathToEditedNames);
              },
            ),
          ),
        );
      },
    );
  }
}
