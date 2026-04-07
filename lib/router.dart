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
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

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
                  SideMenu(navigationShell: navigationShell),
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
                        IconButton(
                          icon: Icon(
                            isDark ? Icons.light_mode : Icons.dark_mode,
                          ),
                          onPressed: () {
                            ref.read(themeModeProvider.notifier).toggleTheme();
                          },
                        ),
                        const SizedBox(height: 8),
                        if (navigationShell.currentIndex == 1) ...[
                          FloatingActionButton.small(
                            heroTag: 'layers',
                            onPressed: () {
                              Scaffold.of(context).openEndDrawer();
                            },
                            child: const Icon(Icons.layers),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'mylocation',
                            onPressed: () async {
                              try {
                                final response = await http.get(
                                  Uri.parse('https://ipapi.co/json/'),
                                );
                                if (response.statusCode == 200) {
                                  final data = json.decode(response.body);
                                  final lat = data['latitude'];
                                  final lng = data['longitude'];
                                  if (lat != null && lng != null) {
                                    ref
                                        .read(mapProvider.notifier)
                                        .centerOnLocation(
                                          LatLng(
                                            lat.toDouble(),
                                            lng.toDouble(),
                                          ),
                                        );
                                  }
                                }
                              } catch (e) {
                                // Handle error silently
                              }
                            },
                            child: const Icon(Icons.near_me),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'goto',
                            onPressed: () {
                              ref.read(mapProvider.notifier).toggleGotoInput();
                            },
                            child: const Icon(Icons.directions),
                          ),
                        ],
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
