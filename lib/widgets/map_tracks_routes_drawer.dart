import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';

class MapTracksRoutesDrawer extends ConsumerWidget {
  const MapTracksRoutesDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTracks = ref.watch(mapProvider.select((state) => state.showTracks));
    final showRoutes = ref.watch(mapProvider.select((state) => state.showRoutes));
    final showTrails = ref.watch(mapProvider.select((state) => state.showTrails));
    final trackAvailability = ref.watch(trackAvailabilityProvider);
    final routeAvailability = ref.watch(routeAvailabilityProvider);
    final routeGraphReadiness = ref.watch(routeGraphReadinessProvider);
    final trailsEnabled = routeGraphReadiness.status != RouteGraphReadinessStatus.failed;

    return Drawer(
      key: const Key('tracks-routes-drawer'),
      child: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Tracks / Routes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: const Text('Show Tracks'),
              subtitle: trackAvailability.helperText == null
                  ? null
                  : Text(trackAvailability.helperText!),
              onTap: trackAvailability.isEnabled
                  ? () {
                      ref.read(mapProvider.notifier).toggleTracks();
                    }
                  : null,
              leading: IgnorePointer(
                child: Switch.adaptive(
                  key: const Key('show-tracks-switch'),
                  value: showTracks,
                  onChanged: trackAvailability.isEnabled
                      ? (_) {
                          ref.read(mapProvider.notifier).toggleTracks();
                        }
                      : null,
                ),
              ),
            ),
            ListTile(
              title: const Text('Show Routes'),
              subtitle: routeAvailability.helperText == null
                  ? null
                  : Text(routeAvailability.helperText!),
              onTap: routeAvailability.isAvailable
                  ? () {
                      ref.read(mapProvider.notifier).setShowRoutes(!showRoutes);
                    }
                  : null,
              leading: IgnorePointer(
                child: Switch.adaptive(
                  key: const Key('show-routes-switch'),
                  value: showRoutes,
                  onChanged: routeAvailability.isAvailable
                      ? (_) {
                          ref.read(mapProvider.notifier).setShowRoutes(!showRoutes);
                        }
                      : null,
                ),
              ),
            ),
            ListTile(
              title: const Text('Show Trails'),
              subtitle: routeGraphReadiness.status ==
                      RouteGraphReadinessStatus.failed
                  ? const Text(
                      'Route graph unavailable. Use Refresh Route Graph to retry.',
                    )
                  : routeGraphReadiness.status ==
                        RouteGraphReadinessStatus.preloading
                      ? const Text('Loading route graph...')
                      : null,
              onTap: trailsEnabled
                  ? () {
                      ref.read(mapProvider.notifier).toggleTrails();
                    }
                  : null,
              leading: IgnorePointer(
                child: Switch.adaptive(
                  key: const Key('show-trails-switch'),
                  value: showTrails,
                  onChanged: trailsEnabled
                      ? (_) {
                          ref.read(mapProvider.notifier).toggleTrails();
                        }
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
