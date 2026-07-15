import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:peak_bagger/providers/background_jobs_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_region_filter_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/screens/dashboard_screen.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/screens/peak_lists_screen.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/services/fab_colour_resolver.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/background_jobs_panel.dart';
import 'package:peak_bagger/widgets/peak_list_control_visual_style.dart';
import 'package:peak_bagger/widgets/peak_list_selection_summary.dart';
import 'package:peak_bagger/widgets/side_menu.dart';

import 'core/constants.dart';
import 'core/app_sizes.dart';

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
  final Widget icon;
  final String keyName;
  final String? legacyKeyName;
}

const shellDestinations = <ShellDestination>[
  ShellDestination(
    branchIndex: 0,
    routePath: '/',
    label: 'Dashboard',
    title: 'Dashboard',
    icon: Icon(Icons.dashboard),
    keyName: 'nav-dashboard',
  ),
  ShellDestination(
    branchIndex: 1,
    routePath: '/map',
    label: 'Map',
    title: 'Map',
    icon: Icon(Icons.map),
    keyName: 'nav-map',
  ),
  ShellDestination(
    branchIndex: 2,
    routePath: '/peaks',
    label: 'My Peak Lists',
    title: 'My Peak Lists',
    icon: Icon(Icons.landscape),
    keyName: 'nav-peak-lists',
  ),
  ShellDestination(
    branchIndex: 3,
    routePath: '/objectbox-admin',
    label: 'ObjectBox Admin',
    title: 'ObjectBox Admin',
    icon: FaIcon(FontAwesomeIcons.database),
    keyName: 'nav-objectbox-admin',
    legacyKeyName: 'side-menu-objectbox-admin',
  ),
  ShellDestination(
    branchIndex: 4,
    routePath: '/settings',
    label: 'Settings',
    title: 'Settings',
    icon: Icon(Icons.settings),
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
    ref.read(mapProvider.notifier).closeSearchPopup();
  }
  if (ref.read(mapProvider).showPeakMetadataFilters) {
    ref.read(mapProvider.notifier).closePeakMetadataFilters();
  }
  if (ref.read(mapProvider).showGotoInput) {
    ref.read(mapProvider.notifier).setGotoInputVisible(false);
  }
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Consumer(
            builder: (context, ref, _) {
              final currentDestination = shellDestinations.firstWhere(
                (destination) =>
                    destination.branchIndex == navigationShell.currentIndex,
              );

              void goToDestination(ShellDestination destination) {
                if (destination.branchIndex == navigationShell.currentIndex) {
                  return;
                }
                _runShellPreNavigationCleanup(ref);
                navigationShell.goBranch(destination.branchIndex);
              }

              Widget buildShellBody() {
                return Stack(
                  children: [
                    Row(
                      children: [
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
                        final snackBarEvent = ref
                            .read(backgroundJobsProvider.notifier)
                            .consumeSnackBarEvent();
                        if (snackBarEvent != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Expanded(
                                      child: Text(snackBarEvent.message),
                                    ),
                                    for (final action in snackBarEvent.actions)
                                      TextButton(
                                        key: action.key,
                                        onPressed: action.onPressed,
                                        child: Text(action.label),
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
                          final trackShellState = ref.watch(
                            mapProvider.select(
                              (state) => (
                                hasTrackRecoveryIssue:
                                    state.hasTrackRecoveryIssue,
                                trackOperationStatus:
                                    state.trackOperationStatus,
                                trackOperationWarning:
                                    state.trackOperationWarning,
                              ),
                            ),
                          );
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
                          if (!trackShellState.hasTrackRecoveryIssue) {
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
                                      gapWXS,
                                      const Text(
                                        'Some tracks need to be rebuilt.',
                                      ),
                                      gapWSML,
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
                    Consumer(
                      builder: (context, ref, _) {
                        final backgroundJobsState = ref.watch(
                          backgroundJobsProvider,
                        );
                        if (!backgroundJobsState.isPanelOpen) {
                          return const SizedBox.shrink();
                        }

                        return Positioned(
                          top: 16,
                          right: 16,
                          bottom: 16,
                          child: BackgroundJobsPanel(
                            jobs: backgroundJobsState.visibleJobs,
                            onClose: () {
                              ref
                                  .read(backgroundJobsProvider.notifier)
                                  .closePanel();
                            },
                            onToggleExpanded: (jobId) {
                              ref
                                  .read(backgroundJobsProvider.notifier)
                                  .toggleJobExpanded(jobId);
                            },
                            onDismissJob: (jobId) {
                              ref
                                  .read(backgroundJobsProvider.notifier)
                                  .dismissJob(jobId);
                            },
                            onClearFinishedJobs: () {
                              ref
                                  .read(backgroundJobsProvider.notifier)
                                  .clearFinishedJobs();
                            },
                          ),
                        );
                      },
                    ),
                  ],
                );
              }

              final backgroundJobsState = ref.watch(backgroundJobsProvider);

              return Scaffold(
                appBar: AppBar(
                  key: const Key('shared-app-bar'),
                  automaticallyImplyLeading: false,
                  centerTitle: false,
                  titleSpacing: 0,
                  title: _SharedAppBarTitle(
                    currentDestination: currentDestination,
                    showSearch: currentDestination.branchIndex == 1,
                    summary: ref.watch(peakListSelectionSummaryProvider),
                  ),
                  actions: [
                    if (backgroundJobsState.hasJobs)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: TextButton.icon(
                          key: const Key('background-jobs-entry'),
                          onPressed: () {
                            ref
                                .read(backgroundJobsProvider.notifier)
                                .togglePanel();
                          },
                          icon: const Icon(Icons.work_history_outlined),
                          label: const Text('Background Jobs'),
                        ),
                      ),
                  ],
                ),
                body: buildShellBody(),
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
                builder: (context, state) => PeakListsScreen(
                  initialPeakListId: int.tryParse(
                    state.uri.queryParameters['selectedPeakListId'] ?? '',
                  ),
                ),
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
}

class _SharedAppBarTitle extends StatelessWidget {
  const _SharedAppBarTitle({
    required this.currentDestination,
    required this.showSearch,
    required this.summary,
  });

  static const _laneGap = 12.0;

  final ShellDestination currentDestination;
  final bool showSearch;
  final PeakListSelectionSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!showSearch) {
          if (currentDestination.branchIndex == 2) {
            return _PeaksAppBarTitle(title: currentDestination.title);
          }
          return Row(
            children: [
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: RouterConstants.wideNavigationWidth,
                    right: _laneGap,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: KeyedSubtree(
                      key: const Key('app-bar-title'),
                      child: Text(
                        currentDestination.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(left: _laneGap, right: 8),
                  child: const Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          );
        }

        return SizedBox(
          height: kToolbarHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: RouterConstants.wideNavigationWidth,
                  right: _laneGap,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    key: const Key('map-app-bar-content'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const KeyedSubtree(
                        key: Key('app-bar-title'),
                        child: SizedBox.shrink(),
                      ),
                      const _AppBarSearchTrigger(compact: false),
                      const SizedBox(width: 8),
                      const _AppBarMapFilterTrigger(),
                      const SizedBox(width: 8),
                      SizedBox(
                        key: const Key('app-bar-map-filter-divider'),
                        height: 24,
                        child: VerticalDivider(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: _laneGap, right: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: PeakListSelectionSummaryStrip(summary: summary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PeaksAppBarTitle extends ConsumerWidget {
  const _PeaksAppBarTitle({required this.title});

  static const _laneGap = 12.0;

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regions = ref.watch(peakListRegionFilterOptionsProvider);
    final selectedRegionKeys = ref.watch(peakListRegionFilterProvider);

    return Row(
      key: const Key('peak-lists-app-bar-content'),
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              left: RouterConstants.wideNavigationWidth,
              right: _laneGap,
            ),
            child: Row(
              children: [
                Flexible(
                  child: KeyedSubtree(
                    key: const Key('app-bar-title'),
                    child: Text(title, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SingleChildScrollView(
                      key: const Key('peak-lists-region-fab-scroller'),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (
                            var index = 0;
                            index < regions.length;
                            index++
                          ) ...[
                            _PeakRegionFab(
                              region: regions[index],
                              isSelected: selectedRegionKeys.contains(
                                regions[index].key,
                              ),
                              colourValue:
                                  defaultFABPalette[index %
                                      defaultFABPalette.length],
                            ),
                            if (index < regions.length - 1)
                              const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PeakRegionFab extends ConsumerWidget {
  const _PeakRegionFab({
    required this.region,
    required this.isSelected,
    required this.colourValue,
  });

  final RegionManifestRegionData region;
  final bool isSelected;
  final int colourValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controlStyle = peakListControlVisualStyle(
      context,
      isSelected: isSelected,
      colourValue: colourValue,
    );

    return Tooltip(
      message: region.name,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: region.name,
        child: ExcludeSemantics(
          child: OutlinedButton(
            key: Key('peak-lists-region-fab-${region.key}'),
            style: controlStyle.buttonStyle,
            onPressed: () {
              ref
                  .read(peakListRegionFilterProvider.notifier)
                  .toggleRegion(region.key);
            },
            child: Text(
              region.shortName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: UiConstants.drawerControlFontSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBarSearchTrigger extends ConsumerWidget {
  const _AppBarSearchTrigger({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    void onPressed() {
      ref.read(mapProvider.notifier).openSearchPopup();
    }

    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: colorScheme.onSurface,
      side: BorderSide(color: colorScheme.outlineVariant),
    );

    if (compact) {
      return OutlinedButton(
        key: const Key('app-bar-search-trigger'),
        style: buttonStyle,
        onPressed: onPressed,
        child: const Icon(Icons.search),
      );
    }

    return OutlinedButton.icon(
      key: const Key('app-bar-search-trigger'),
      style: buttonStyle,
      onPressed: onPressed,
      icon: const Icon(Icons.search),
      label: const Text('Search ⌘F'),
    );
  }
}

class _AppBarMapFilterTrigger extends ConsumerWidget {
  const _AppBarMapFilterTrigger();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(
      mapProvider.select(
        (state) => (
          isSelected: state.hasActivePeakMetadataFilters,
          count: state.activePeakMetadataFilterCount,
        ),
      ),
    );
    final theme = Theme.of(context);
    final searchButtonTheme = theme.extension<SearchButtonThemeData>();
    final buttonStyle =
        searchButtonTheme?.styleFor(filterState.isSelected) ??
        const ButtonStyle();
    final label = switch (filterState.count) {
      0 => 'Filter',
      1 => '1 Filter',
      2 => '2 Filters',
      _ => '3 Filters',
    };

    return OutlinedButton.icon(
      key: const Key('app-bar-map-filter-trigger'),
      style: buttonStyle,
      onPressed: () =>
          ref.read(mapProvider.notifier).togglePeakMetadataFilters(),
      icon: const Icon(Icons.filter_list),
      label: Text(label),
    );
  }
}

GoRouter router = createRouter();
