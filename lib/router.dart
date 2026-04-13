import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/theme_provider.dart';
import 'package:peak_bagger/screens/dashboard_screen.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/screens/peak_lists_screen.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/widgets/side_menu.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return Scaffold(
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
                    return FloatingActionButton.small(
                      heroTag: 'theme',
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      onPressed: () {
                        ref.read(themeModeProvider.notifier).toggleTheme();
                      },
                      child: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
                                navigationShell.goBranch(4);
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
                                    navigationShell.goBranch(4);
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
              name: 'dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              name: 'map',
              builder: (context, state) => const MapScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/peaks',
              name: 'peaks',
              builder: (context, state) => const PeakListsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/objectbox-admin',
              name: 'objectboxAdmin',
              builder: (context, state) => const ObjectBoxAdminScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
