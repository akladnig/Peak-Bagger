import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/theme_provider.dart';
import 'package:peak_bagger/screens/dashboard_screen.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/screens/peak_lists_screen.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/widgets/side_menu.dart';

import 'core/constants.dart';

class ShellDestination {
  const ShellDestination({
    required this.branchIndex,
    required this.routePath,
    required this.label,
    required this.title,
    required this.icon,
    required this.keyName,
    this.legacyKeyName,
  });

  final int branchIndex;
  final String routePath;
  final String label;
  final String title;
  final IconData icon;
  final String keyName;
  final String? legacyKeyName;
}

const shellDestinations = <ShellDestination>[
  ShellDestination(
    branchIndex: 0,
    routePath: '/',
    label: 'Dashboard',
    title: 'Dashboard',
    icon: Icons.dashboard,
    keyName: 'nav-dashboard',
  ),
  ShellDestination(
    branchIndex: 1,
    routePath: '/map',
    label: 'Map',
    title: 'Map',
    icon: Icons.map,
    keyName: 'nav-map',
  ),
  ShellDestination(
    branchIndex: 2,
    routePath: '/peaks',
    label: 'Peak Lists',
    title: 'Peak Lists',
    icon: Icons.landscape,
    keyName: 'nav-peak-lists',
  ),
  ShellDestination(
    branchIndex: 3,
    routePath: '/objectbox-admin',
    label: 'ObjectBox Admin',
    title: 'ObjectBox Admin',
    icon: FontAwesomeIcons.database,
    keyName: 'nav-objectbox-admin',
    legacyKeyName: 'side-menu-objectbox-admin',
  ),
  ShellDestination(
    branchIndex: 4,
    routePath: '/settings',
    label: 'Settings',
    title: 'Settings',
    icon: Icons.settings,
    keyName: 'nav-settings',
  ),
];

void _runShellPreNavigationCleanup(WidgetRef ref) {
  if (ref.read(mapProvider).peakInfoPeak != null) {
    ref.read(mapProvider.notifier).closePeakInfoPopup();
  }
  if (ref.read(mapProvider).showInfoPopup) {
    ref.read(mapProvider.notifier).toggleInfoPopup();
  }
  if (ref.read(mapProvider).showPeakSearch) {
    ref.read(mapProvider.notifier).setPeakSearchVisible(false);
  }
  if (ref.read(mapProvider).showGotoInput) {
    ref.read(mapProvider.notifier).setGotoInputVisible(false);
  }
}

final router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return Consumer(
          builder: (context, ref, _) {
            final themeMode = ref.watch(themeModeProvider);
            final isDark = themeMode == ThemeMode.dark;
            final currentDestination = shellDestinations.firstWhere(
              (destination) =>
                  destination.branchIndex == navigationShell.currentIndex,
            );

            void goToDestination(
              ShellDestination destination, {
              bool closeCompactNavigation = false,
            }) {
              if (closeCompactNavigation) {
                Navigator.of(context).pop();
              }
              if (destination.branchIndex == navigationShell.currentIndex) {
                return;
              }
              _runShellPreNavigationCleanup(ref);
              navigationShell.goBranch(destination.branchIndex);
            }

            Widget buildShellBody(bool isWide) {
              return Stack(
                children: [
                  Row(
                    children: [
                      if (isWide)
                        SideMenu(
                          destinations: shellDestinations,
                          selectedBranchIndex: navigationShell.currentIndex,
                          onDestinationSelected: goToDestination,
                        ),
                      Expanded(child: navigationShell),
                    ],
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final startupWarning = ref
                          .read(mapProvider.notifier)
                          .consumeStartupBackfillWarningMessage();
                      if (startupWarning != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Expanded(child: Text(startupWarning)),
                                  TextButton(
                                    key: const Key(
                                      'startup-backfill-warning-open-settings',
                                    ),
                                    onPressed: () {
                                      goToDestination(shellDestinations[4]);
                                    },
                                    child: const Text('Open Settings'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        });
                      }
                      return const SizedBox.shrink();
                    },
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(trackSnackbar)),
                            );
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
                                    goToDestination(shellDestinations[4]);
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
                                    const Text(
                                      'Some tracks need to be rebuilt.',
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton(
                                      key: const Key(
                                        'open-track-recovery-settings',
                                      ),
                                      onPressed: () {
                                        goToDestination(shellDestinations[4]);
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
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= RouterConstants.shellBreakpoint;

                return Scaffold(
                  drawer: isWide
                      ? null
                      : Drawer(
                          child: SafeArea(
                            child: SideMenu(
                              destinations: shellDestinations,
                              selectedBranchIndex: navigationShell.currentIndex,
                              compact: true,
                              onDestinationSelected: (destination) {
                                goToDestination(
                                  destination,
                                  closeCompactNavigation: true,
                                );
                              },
                            ),
                          ),
                        ),
                  appBar: AppBar(
                    key: const Key('shared-app-bar'),
                    automaticallyImplyLeading: false,
                    centerTitle: false,
                    leadingWidth: isWide ? RouterConstants.wideNavigationWidth : null,
                    leading: isWide
                        ? Center(
                            child: IconButton(
                              key: const Key('app-bar-home'),
                              tooltip: 'Dashboard',
                              onPressed: () {
                                goToDestination(shellDestinations.first);
                              },
                              icon: const FaIcon(FontAwesomeIcons.mountain),
                            ),
                          )
                        : Builder(
                            builder: (context) {
                              return IconButton(
                                key: const Key('app-bar-menu'),
                                tooltip: 'Menu',
                                onPressed: () {
                                  Scaffold.of(context).openDrawer();
                                },
                                icon: const Icon(Icons.menu),
                              );
                            },
                          ),
                    titleSpacing: 0,
                    title: isWide
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: KeyedSubtree(
                              key: const Key('app-bar-title'),
                              child: Text(currentDestination.title),
                            ),
                          )
                        : Row(
                            children: [
                              IconButton(
                                key: const Key('app-bar-home'),
                                tooltip: 'Dashboard',
                                onPressed: () {
                                  goToDestination(shellDestinations.first);
                                },
                                icon: const FaIcon(FontAwesomeIcons.mountain),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: KeyedSubtree(
                                  key: const Key('app-bar-title'),
                                  child: Text(
                                    currentDestination.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(
                          right: RouterConstants.themeActionRightInset,
                        ),
                        child: IconButton(
                          key: const Key('app-bar-theme-action'),
                          tooltip: 'Toggle theme',
                          onPressed: () {
                            ref.read(themeModeProvider.notifier).toggleTheme();
                          },
                          icon: Icon(
                            isDark ? Icons.light_mode : Icons.dark_mode,
                          ),
                        ),
                      ),
                    ],
                  ),
                  body: buildShellBody(isWide),
                );
              },
            );
          },
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
