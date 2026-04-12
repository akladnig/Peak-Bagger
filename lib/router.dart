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
                                  FloatingActionButton.small(
                                    heroTag: 'search',
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    onPressed: () {
                                      if (ref.read(mapProvider).showInfoPopup) {
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
                                  const SizedBox(height: 8),
                                  FloatingActionButton.small(
                                    heroTag: 'layers',
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    onPressed: () {
                                      if (ref.read(mapProvider).showInfoPopup) {
                                        ref
                                            .read(mapProvider.notifier)
                                            .toggleInfoPopup();
                                      }
                                      ref
                                          .read(mapProvider.notifier)
                                          .togglePeakSearch();
                                    },
                                    child: Icon(
                                      Icons.layers,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FloatingActionButton.small(
                                    heroTag: 'mylocation',
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    onPressed: () async {
                                      if (ref.read(mapProvider).showInfoPopup) {
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
                                      if (ref.read(mapProvider).showGotoInput) {
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
                                            LocationPermission.deniedForever) {
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
                                  const SizedBox(height: 8),
                                  FloatingActionButton.small(
                                    heroTag: 'centermarker',
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    onPressed: () {
                                      if (ref.read(mapProvider).showInfoPopup) {
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
                                      if (ref.read(mapProvider).showGotoInput) {
                                        ref
                                            .read(mapProvider.notifier)
                                            .setGotoInputVisible(false);
                                      }
                                      ref
                                          .read(mapProvider.notifier)
                                          .centerOnSelectedLocation();
                                    },
                                    child: Icon(
                                      Icons.my_location,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  FloatingActionButton.small(
                                    heroTag: 'goto',
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    onPressed: () {
                                      if (ref.read(mapProvider).showInfoPopup) {
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
                                      if (ref.read(mapProvider).showGotoInput) {
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
                                  const SizedBox(height: 8),
                                  FloatingActionButton.small(
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
                                  const SizedBox(height: 8),
                                  FloatingActionButton.small(
                                    heroTag: 'info',
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    onPressed: () {
                                      if (ref.read(mapProvider).showInfoPopup) {
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
                                      if (ref.read(mapProvider).showGotoInput) {
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
                                  const SizedBox(height: 8),
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final mapState = ref.watch(mapProvider);
                                      final isEmpty = mapState.tracks.isEmpty;
                                      return FloatingActionButton.small(
                                        heroTag: 'tracks',
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        onPressed: isEmpty
                                            ? null
                                            : () {
                                                ref
                                                    .read(mapProvider.notifier)
                                                    .toggleTracks();
                                              },
                                        child: Icon(
                                          Icons.route,
                                          color: isEmpty
                                              ? Colors.red
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurface,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  FloatingActionButton.small(
                                    heroTag: 'import',
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    onPressed: null,
                                    child: Icon(
                                      Icons.input,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withOpacity(0.38),
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
