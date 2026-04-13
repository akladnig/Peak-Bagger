import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peak_bagger/screens/dashboard_screen.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/screens/peak_lists_screen.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/widgets/side_menu.dart';
import 'package:peak_bagger/providers/theme_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return Scaffold(
          endDrawer: navigationShell.currentIndex == 1
              ? Consumer(
                  builder: (context, ref, _) {
                    final mapState = ref.watch(mapProvider);
                    return Drawer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Basemaps',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.map),
                            title: const Text('Tracestrack Topo'),
                            trailing: mapState.basemap == Basemap.tracestrack
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () {
                              ref
                                  .read(mapProvider.notifier)
                                  .setBasemap(Basemap.tracestrack);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.map_outlined),
                            title: const Text('OpenStreetMap'),
                            trailing: mapState.basemap == Basemap.openstreetmap
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () {
                              ref
                                  .read(mapProvider.notifier)
                                  .setBasemap(Basemap.openstreetmap);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                )
              : null,
          body: Stack(
            children: [
              Row(
                children: [
                  Consumer(
                    builder: (context, ref, _) => SideMenu(
                      navigationShell: navigationShell,
                      onBeforeNavigation: () {
                        if (ref.read(mapProvider).showInfoPopup) {
                          ref.read(mapProvider.notifier).toggleInfoPopup();
                        }
                        if (ref.read(mapProvider).showPeakSearch) {
                          ref
                              .read(mapProvider.notifier)
                              .setPeakSearchVisible(false);
                        }
                        if (ref.read(mapProvider).showGotoInput) {
                          ref
                              .read(mapProvider.notifier)
                              .setGotoInputVisible(false);
                        }
                      },
                    ),
                  ),
                  Expanded(child: navigationShell),
                ],
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Consumer(
                  builder: (context, ref, _) {
                    final themeMode = ref.watch(themeModeProvider);
                    final isDark = themeMode == ThemeMode.dark;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'theme',
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          onPressed: () {
                            ref.read(themeModeProvider.notifier).toggleTheme();
                          },
                          child: Icon(
                            isDark ? Icons.light_mode : Icons.dark_mode,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (navigationShell.currentIndex == 1)
                          Consumer(
                            builder: (context, ref, _) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _LeftTooltipFab(
                                    message: 'Search peaks',
                                    child: FloatingActionButton.small(
                                      heroTag: 'search',
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      onPressed: () {
                                        if (ref
                                            .read(mapProvider)
                                            .showInfoPopup) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .toggleInfoPopup();
                                        }
                                        ref
                                            .read(mapProvider.notifier)
                                            .togglePeakSearch();
                                      },
                                      child: Icon(
                                        Icons.search,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _LeftTooltipFab(
                                    message: 'Basemaps',
                                    child: FloatingActionButton.small(
                                      heroTag: 'layers',
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      onPressed: () {
                                        if (ref
                                            .read(mapProvider)
                                            .showInfoPopup) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .toggleInfoPopup();
                                        }
                                        if (ref
                                            .read(mapProvider)
                                            .showPeakSearch) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .setPeakSearchVisible(false);
                                        }
                                        Scaffold.of(context).openEndDrawer();
                                      },
                                      child: Icon(
                                        Icons.layers,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _LeftTooltipFab(
                                    message: 'My location',
                                    child: FloatingActionButton.small(
                                      heroTag: 'mylocation',
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      onPressed: () async {
                                        if (ref
                                            .read(mapProvider)
                                            .showInfoPopup) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .toggleInfoPopup();
                                        }
                                        if (ref
                                            .read(mapProvider)
                                            .showPeakSearch) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .setPeakSearchVisible(false);
                                        }
                                        if (ref
                                            .read(mapProvider)
                                            .showGotoInput) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .setGotoInputVisible(false);
                                        }
                                        try {
                                          bool serviceEnabled =
                                              await Geolocator.isLocationServiceEnabled();
                                          if (!serviceEnabled) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Location services are disabled',
                                                  ),
                                                ),
                                              );
                                            }
                                            return;
                                          }

                                          LocationPermission permission =
                                              await Geolocator.checkPermission();
                                          if (permission ==
                                              LocationPermission.denied) {
                                            permission =
                                                await Geolocator.requestPermission();
                                            if (permission ==
                                                LocationPermission.denied) {
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
                                              LocationPermission
                                                  .deniedForever) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
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
                                                locationSettings:
                                                    const LocationSettings(
                                                      accuracy:
                                                          LocationAccuracy.high,
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
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Location error: $e',
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: Icon(
                                        Icons.near_me,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _LeftTooltipFab(
                                    message: 'Center on marker',
                                    child: FloatingActionButton.small(
                                      heroTag: 'centermarker',
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      onPressed: () {
                                        if (ref
                                            .read(mapProvider)
                                            .showInfoPopup) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .toggleInfoPopup();
                                        }
                                        if (ref
                                            .read(mapProvider)
                                            .showPeakSearch) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .setPeakSearchVisible(false);
                                        }
                                        if (ref
                                            .read(mapProvider)
                                            .showGotoInput) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .setGotoInputVisible(false);
                                        }
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
                                  const SizedBox(height: 8),
                                  _LeftTooltipFab(
                                    message: 'Goto',
                                    child: FloatingActionButton.small(
                                      heroTag: 'goto',
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      onPressed: () {
                                        if (ref
                                            .read(mapProvider)
                                            .showInfoPopup) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .toggleInfoPopup();
                                        }
                                        if (ref
                                            .read(mapProvider)
                                            .showPeakSearch) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .setPeakSearchVisible(false);
                                        }
                                        if (ref
                                            .read(mapProvider)
                                            .showGotoInput) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .setGotoInputVisible(false);
                                        }
                                        ref
                                            .read(mapProvider.notifier)
                                            .toggleGotoInput();
                                      },
                                      child: Icon(
                                        Icons.directions,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _LeftTooltipFab(
                                    message: 'Grid',
                                    child: FloatingActionButton.small(
                                      heroTag: 'grid',
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      onPressed: () {
                                        if (ref
                                            .read(mapProvider)
                                            .showMapOverlay) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .toggleMapOverlay();
                                        } else {
                                          ref
                                              .read(mapProvider.notifier)
                                              .toggleMapOverlay();
                                        }
                                      },
                                      child: Icon(
                                        Icons.grid_on,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _LeftTooltipFab(
                                    message: 'Info',
                                    child: FloatingActionButton.small(
                                      key: const Key('map-info-fab'),
                                      heroTag: 'info',
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      onPressed: () {
                                        if (ref
                                            .read(mapProvider)
                                            .showInfoPopup) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .toggleInfoPopup();
                                        }
                                        if (ref
                                            .read(mapProvider)
                                            .showPeakSearch) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .setPeakSearchVisible(false);
                                        }
                                        if (ref
                                            .read(mapProvider)
                                            .showGotoInput) {
                                          ref
                                              .read(mapProvider.notifier)
                                              .setGotoInputVisible(false);
                                        }
                                        ref
                                            .read(mapProvider.notifier)
                                            .toggleInfoPopup();
                                      },
                                      child: Icon(
                                        Icons.info,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final mapState = ref.watch(mapProvider);
                                      final isDisabled =
                                          mapState.tracks.isEmpty ||
                                          mapState.isLoadingTracks ||
                                          mapState.hasTrackRecoveryIssue;
                                      return _LeftTooltipFab(
                                        message: 'Show tracks',
                                        child: FloatingActionButton.small(
                                          key: const Key('show-tracks-fab'),
                                          heroTag: 'tracks',
                                          backgroundColor: Theme.of(
                                            context,
                                          ).colorScheme.surface,
                                          onPressed: isDisabled
                                              ? null
                                              : () {
                                                  ref
                                                      .read(
                                                        mapProvider.notifier,
                                                      )
                                                      .toggleTracks();
                                                },
                                          child: Icon(
                                            Icons.route,
                                            color: isDisabled
                                                ? Colors.red
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _LeftTooltipFab(
                                    message: 'Import track',
                                    child: FloatingActionButton.small(
                                      key: const Key('import-tracks-fab'),
                                      heroTag: 'import',
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      onPressed:
                                          ref
                                                  .watch(mapProvider)
                                                  .isLoadingTracks ||
                                              ref
                                                  .watch(mapProvider)
                                                  .hasTrackRecoveryIssue
                                          ? null
                                          : () {
                                              ref
                                                  .read(mapProvider.notifier)
                                                  .rescanTracks();
                                            },
                                      child:
                                          ref.watch(mapProvider).isLoadingTracks
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Icon(
                                              Icons.input,
                                              color:
                                                  ref
                                                      .watch(mapProvider)
                                                      .hasTrackRecoveryIssue
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
                                ],
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (navigationShell.currentIndex == 1)
                Consumer(
                  builder: (context, ref, _) {
                    final mapState = ref.watch(mapProvider);
                    final trackSnackbar = ref
                        .read(mapProvider.notifier)
                        .consumeTrackSnackbarMessage();
                    if (trackSnackbar != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(trackSnackbar)));
                      });
                    }
                    if (!mapState.hasTrackRecoveryIssue) {
                      return const SizedBox.shrink();
                    }
                    if (ref
                        .read(mapProvider.notifier)
                        .consumeRecoverySnackbarSignal()) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Some tracks need to be rebuilt.',
                            ),
                            action: SnackBarAction(
                              label: 'Open Settings',
                              onPressed: () {
                                navigationShell.goBranch(3);
                              },
                            ),
                          ),
                        );
                      });
                    }
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 24,
                      child: Center(
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 3,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded),
                                const SizedBox(width: 8),
                                const Text('Some tracks need to be rebuilt.'),
                                const SizedBox(width: 12),
                                TextButton(
                                  key: const Key(
                                    'open-track-recovery-settings',
                                  ),
                                  onPressed: () {
                                    navigationShell.goBranch(3);
                                  },
                                  child: const Text('Open Settings'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              builder: (context, state) => const MapScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/peaks',
              builder: (context, state) => const PeakListsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class _LeftTooltipFab extends StatefulWidget {
  const _LeftTooltipFab({required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  State<_LeftTooltipFab> createState() => _LeftTooltipFabState();
}

class _LeftTooltipFabState extends State<_LeftTooltipFab> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _visible = true),
      onExit: (_) => setState(() => _visible = false),
      child: Semantics(
        label: widget.message,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.centerRight,
          children: [
            widget.child,
            Positioned(
              right: 48,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.inverseSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
