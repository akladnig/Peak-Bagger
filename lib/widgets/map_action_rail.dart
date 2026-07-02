import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/constants.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/services/gpx_file_picker.dart';
import 'package:peak_bagger/widgets/gpx_import_dialog.dart';
import 'package:peak_bagger/widgets/left_tooltip_fab.dart';
import 'package:peak_bagger/widgets/map_rebuild_debug_counters.dart';

class MapActionRail extends ConsumerWidget {
  const MapActionRail({
    super.key,
    this.onCreateRoute,
    this.onShowBasemaps,
    this.onDropMarker,
    this.onShowFavourites,
  });

  final VoidCallback? onCreateRoute;
  final VoidCallback? onShowBasemaps;
  final VoidCallback? onDropMarker;
  final VoidCallback? onShowFavourites;

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
    if (closeInfoPopup && mapState.peakInfoPeak != null) {
      notifier.closePeakInfoPopup();
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
    MapRebuildDebugCounters.recordActionRailBuild();
    final (
      :isLoadingTracks,
      :hasTrackRecoveryIssue,
      :isRouteDrafting,
      :gridTooltipMessage,
    ) = ref.watch(
      mapProvider.select(
        (state) => (
          isLoadingTracks: state.isLoadingTracks,
          hasTrackRecoveryIssue: state.hasTrackRecoveryIssue,
          isRouteDrafting: state.isRouteDrafting,
          gridTooltipMessage: state.mapGridTooltipMessage,
        ),
      ),
    );
    final routeGraphReady = ref.watch(
      routeGraphReadinessProvider.select(
        (state) => state.status != RouteGraphReadinessStatus.failed,
      ),
    );
    ref.watch(routeAvailabilityProvider);
    final viewPaddingBottom = MediaQuery.of(context).viewPadding.bottom;

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: UiConstants.groupSpacing,
            right: RouterConstants.themeActionRightInset,
            bottom: 56.0 + viewPaddingBottom,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isRouteDrafting) ...[
                    _MapActionSection(
                      sectionKey: const Key('map-action-tools-group'),
                      title: 'Tools',
                      sortOrder: 0,
                      children: [
                        LeftTooltipFab(
                          message: 'Import GPX',
                          child: FloatingActionButton.small(
                            key: const Key('import-tracks-fab'),
                            heroTag: 'import',
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            onPressed: isLoadingTracks || hasTrackRecoveryIssue
                                ? null
                                : () => _showGpxImportDialog(context, ref),
                            child: isLoadingTracks
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.input,
                                    color: hasTrackRecoveryIssue
                                        ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.38)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                          ),
                        ),
                        const SizedBox(height: UiConstants.railSpacing),
                        LeftTooltipFab(
                          message: 'Create Route',
                          child: FloatingActionButton.small(
                            key: const Key('create-route-fab'),
                            heroTag: 'create-route',
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            onPressed: onCreateRoute,
                            child: SvgPicture.asset(
                              'assets/route.svg',
                              width: 18,
                              height: 18,
                              colorFilter: ColorFilter.mode(
                                onCreateRoute == null
                                    ? Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.38)
                                    : Theme.of(context).colorScheme.onSurface,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: UiConstants.groupSpacing),
                  ],
                  _MapActionSection(
                    sectionKey: const Key('map-action-view-group'),
                    title: 'View',
                    sortOrder: 1,
                    children: [
                      LeftTooltipFab(
                        message: 'Select Basemaps',
                        child: FloatingActionButton.small(
                          key: const Key('show-basemaps-fab'),
                          heroTag: 'layers',
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          onPressed:
                              onShowBasemaps ??
                              () {
                                _dismissTransientUi(
                                  ref,
                                  closeInfoPopup: true,
                                  closePeakSearch: true,
                                  closeGotoInput: true,
                                );
                                ref
                                    .read(mapProvider.notifier)
                                    .setEndDrawerMode(EndDrawerMode.basemaps);
                                Scaffold.of(context).openEndDrawer();
                              },
                          child: Icon(
                            Icons.layers,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: UiConstants.railSpacing),
                      LeftTooltipFab(
                        message: gridTooltipMessage,
                        child: FloatingActionButton.small(
                          key: const Key('grid-map-fab'),
                          heroTag: 'grid',
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          onPressed: () {
                            ref.read(mapProvider.notifier).toggleMapOverlay();
                          },
                          child: Icon(
                            Icons.grid_on,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: UiConstants.railSpacing),
                      LeftTooltipFab(
                        message: 'Select Peak List',
                        child: FloatingActionButton.small(
                          key: const Key('show-peaks-fab'),
                          heroTag: 'peaks',
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          onPressed: () {
                            _dismissTransientUi(
                              ref,
                              closeInfoPopup: true,
                              closePeakSearch: true,
                              closeGotoInput: true,
                            );
                            ref
                                .read(mapProvider.notifier)
                                .reconcileSelectedPeakList();
                            ref
                                .read(mapProvider.notifier)
                                .setEndDrawerMode(EndDrawerMode.peakLists);
                            Scaffold.of(context).openEndDrawer();
                          },
                          child: Icon(
                            Icons.landscape,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: UiConstants.railSpacing),
                      LeftTooltipFab(
                        message: 'Show Tracks/Routes (T)',
                        child: FloatingActionButton.small(
                          key: const Key('show-tracks-fab'),
                          heroTag: 'tracks',
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          onPressed: () {
                            ref
                                .read(mapProvider.notifier)
                                .setEndDrawerMode(EndDrawerMode.tracksRoutes);
                            Scaffold.of(context).openEndDrawer();
                          },
                          child: Icon(
                            Icons.route,
                            color: (isLoadingTracks || hasTrackRecoveryIssue)
                                ? Colors.red
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: UiConstants.railSpacing),
                      LeftTooltipFab(
                        message: 'Show Trails',
                        child: FloatingActionButton.small(
                          key: const Key('show-trails-fab'),
                          heroTag: 'trails',
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          onPressed: routeGraphReady
                              ? () {
                                  ref.read(mapProvider.notifier).toggleTrails();
                                }
                              : null,
                          child: Icon(
                            Icons.hiking_outlined,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isRouteDrafting) ...[
                    const SizedBox(height: UiConstants.groupSpacing),
                    _MapActionSection(
                      sectionKey: const Key('map-action-location-group'),
                      title: 'Loc',
                      sortOrder: 2,
                      children: [
                        LeftTooltipFab(
                          message: 'Search',
                          child: FloatingActionButton.small(
                            key: const Key('search-peaks-fab'),
                            heroTag: 'search',
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            onPressed: () {
                              _dismissTransientUi(
                                ref,
                                closeInfoPopup: true,
                                closeGotoInput: true,
                              );
                              ref.read(mapProvider.notifier).togglePeakSearch();
                            },
                            child: Icon(
                              Icons.search,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: UiConstants.railSpacing),
                        LeftTooltipFab(
                          message: 'Drop Marker',
                          child: FloatingActionButton.small(
                            key: const Key('drop-marker-fab'),
                            heroTag: 'drop-marker',
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            onPressed: onDropMarker == null
                                ? null
                                : () {
                                    _dismissTransientUi(
                                      ref,
                                      closeInfoPopup: true,
                                      closePeakSearch: true,
                                      closeGotoInput: true,
                                    );
                                    onDropMarker!();
                                  },
                            child: Icon(
                              Icons.location_pin,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: UiConstants.railSpacing),
                        LeftTooltipFab(
                          message: 'Center on marker',
                          child: FloatingActionButton.small(
                            key: const Key('center-marker-fab'),
                            heroTag: 'centermarker',
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            onPressed: () {
                              _dismissTransientUi(
                                ref,
                                closeInfoPopup: true,
                                closePeakSearch: true,
                                closeGotoInput: true,
                              );
                              ref
                                  .read(mapProvider.notifier)
                                  .centerOnSelectedLocation();
                            },
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        const SizedBox(height: UiConstants.railSpacing),
                        LeftTooltipFab(
                          message: 'Goto Favourite',
                          child: FloatingActionButton.small(
                            key: const Key('goto-favourite-fab'),
                            heroTag: 'goto-favourite',
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            onPressed: onShowFavourites == null
                                ? null
                                : () {
                                    _dismissTransientUi(
                                      ref,
                                      closeInfoPopup: true,
                                      closePeakSearch: true,
                                      closeGotoInput: true,
                                    );
                                    onShowFavourites!();
                                  },
                            child: Icon(
                              Icons.favorite,
                              color: favouriteMarkerColour,
                            ),
                          ),
                        ),
                        const SizedBox(height: UiConstants.railSpacing),
                        LeftTooltipFab(
                          message: 'My location',
                          child: FloatingActionButton.small(
                            heroTag: 'mylocation',
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
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
                                        content: Text(
                                          'Location services are disabled',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                var permission =
                                    await Geolocator.checkPermission();
                                if (permission == LocationPermission.denied) {
                                  permission =
                                      await Geolocator.requestPermission();
                                  if (permission == LocationPermission.denied) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Location permission denied',
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                }

                                if (permission ==
                                    LocationPermission.deniedForever) {
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

                                final position =
                                    await Geolocator.getCurrentPosition(
                                      locationSettings: const LocationSettings(
                                        accuracy: LocationAccuracy.high,
                                      ),
                                    );
                                ref
                                    .read(mapProvider.notifier)
                                    .centerOnLocation(
                                      LatLng(
                                        position.latitude,
                                        position.longitude,
                                      ),
                                    );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Location error: $e'),
                                    ),
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
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: RouterConstants.themeActionRightInset,
            bottom: UiConstants.railSpacing * 2 + viewPaddingBottom,
            child: _InfoActionButton(
              onPressed: () {
                _dismissTransientUi(
                  ref,
                  closeInfoPopup: true,
                  closePeakSearch: true,
                  closeGotoInput: true,
                );
                ref.read(mapProvider.notifier).toggleInfoPopup();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGpxImportDialog(BuildContext context, WidgetRef ref) async {
    final filePicker = ref.read(gpxFilePickerProvider);

    await showDialog<dynamic>(
      context: context,
      builder: (dialogContext) {
        return GpxImportDialog(
          filePicker: filePicker,
          importAsRoute: false,
          onImport:
              ({
                required bool importAsRoute,
                required Map<String, String> pathToEditedNames,
              }) {
                final notifier = ref.read(mapProvider.notifier);
                return importAsRoute
                    ? notifier.importRouteFiles(
                        pathToEditedNames: pathToEditedNames,
                      )
                    : notifier.importGpxFiles(
                        pathToEditedNames: pathToEditedNames,
                      );
              },
        );
      },
    );
  }
}

class _MapActionSection extends StatelessWidget {
  const _MapActionSection({
    required this.sectionKey,
    required this.title,
    required this.sortOrder,
    required this.children,
  });

  final Key sectionKey;
  final String title;
  final double sortOrder;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    );

    return FocusTraversalOrder(
      order: NumericFocusOrder(sortOrder),
      child: Semantics(
        sortKey: OrdinalSortKey(sortOrder),
        child: Container(
          key: sectionKey,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: labelStyle),
              ),
              const SizedBox(height: 4),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: _withSpacing(children),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> children) {
    final spaced = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        spaced.add(const SizedBox(height: 4));
      }
      spaced.add(children[index]);
    }
    return spaced;
  }
}

class _InfoActionButton extends StatelessWidget {
  const _InfoActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: const NumericFocusOrder(3),
      child: Semantics(
        sortKey: OrdinalSortKey(3),
        child: LeftTooltipFab(
          message: 'Info',
          child: FloatingActionButton.small(
            key: const Key('map-info-fab'),
            heroTag: 'info',
            backgroundColor: Theme.of(context).colorScheme.surface,
            onPressed: onPressed,
            child: Icon(
              Icons.info,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
