import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';

import '../core/constants.dart';
import 'drawer_outline_button.dart';

class MapTracksRoutesDrawer extends ConsumerWidget {
  const MapTracksRoutesDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTracks = ref.watch(
      mapProvider.select((state) => state.showTracks),
    );
    final showRoutes = ref.watch(
      mapProvider.select((state) => state.showRoutes),
    );
    final showTrails = ref.watch(
      mapProvider.select((state) => state.showTrails),
    );
    final trackAvailability = ref.watch(trackAvailabilityProvider);
    final routeAvailability = ref.watch(routeAvailabilityProvider);
    final routeGraphReadiness = ref.watch(routeGraphReadinessProvider);
    final trailsEnabled =
        routeGraphReadiness.status != RouteGraphReadinessStatus.failed;

    return Drawer(
      key: const Key('tracks-routes-drawer'),
      width: drawerWidthForLabels(context, const [
        'Show Tracks',
        'Show Routes',
        'Show Trails',
      ]),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(UiConstants.drawerHorizontalPadding),
          children: [
            const Text(
              'Tracks / Routes',
              style: TextStyle(
                fontSize: UiConstants.drawerTitleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            DrawerOutlineButton(
              buttonKey: const Key('show-tracks-button'),
              icon: Icons.route,
              label: 'Show Tracks',
              isSelected: showTracks,
              onPressed: trackAvailability.isEnabled
                  ? () {
                      ref.read(mapProvider.notifier).toggleTracks();
                    }
                  : null,
            ),
            if (trackAvailability.helperText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Text(
                  trackAvailability.helperText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: UiConstants.drawerSupportingFontSize,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
            DrawerOutlineButton(
              buttonKey: const Key('show-routes-button'),
              icon: Icons.alt_route,
              label: 'Show Routes',
              isSelected: showRoutes,
              onPressed: routeAvailability.isAvailable
                  ? () {
                      ref.read(mapProvider.notifier).setShowRoutes(!showRoutes);
                    }
                  : null,
            ),
            if (routeAvailability.helperText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Text(
                  routeAvailability.helperText!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: UiConstants.drawerSupportingFontSize,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
            DrawerOutlineButton(
              buttonKey: const Key('show-trails-button'),
              icon: Icons.hiking_outlined,
              label: 'Show Trails',
              isSelected: showTrails,
              onPressed: trailsEnabled
                  ? () {
                      ref.read(mapProvider.notifier).toggleTrails();
                    }
                  : null,
            ),
            if (routeGraphReadiness.status == RouteGraphReadinessStatus.failed)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text(
                  'Route graph unavailable. Use Refresh Route Graph to retry.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: UiConstants.drawerSupportingFontSize,
                  ),
                ),
              )
            else if (routeGraphReadiness.status ==
                RouteGraphReadinessStatus.preloading)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text(
                  'Loading route graph...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: UiConstants.drawerSupportingFontSize,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
