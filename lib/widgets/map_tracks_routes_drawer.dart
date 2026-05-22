import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/gpx_export_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/widgets/dialog_helpers.dart';

class MapTracksRoutesDrawer extends ConsumerWidget {
  const MapTracksRoutesDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTracks = ref.watch(mapProvider.select((state) => state.showTracks));
    final showRoutes = ref.watch(mapProvider.select((state) => state.showRoutes));
    final trackAvailability = ref.watch(trackAvailabilityProvider);
    final routeAvailability = ref.watch(routeAvailabilityProvider);
    final exportSelection = _resolveExportSelection(ref);

    return Drawer(
      key: const Key('tracks-routes-drawer'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: FilledButton.icon(
              key: const Key('tracks-routes-export-button'),
              onPressed: exportSelection == null
                  ? null
                  : () => _exportSelection(context, ref, exportSelection),
              icon: const Icon(Icons.download),
              label: const Text('Export Selected'),
            ),
          ),
        ],
      ),
    );
  }

  _ExportSelection? _resolveExportSelection(WidgetRef ref) {
    final mapState = ref.read(mapProvider);
    final selectedTrackId = mapState.selectedTrackId;
    final selectedRouteId = mapState.selectedRouteId;
    final hasSingleSelection =
        (selectedTrackId == null) != (selectedRouteId == null);
    if (!hasSingleSelection) {
      return null;
    }

    if (selectedTrackId != null) {
      final track = ref.read(gpxTrackRepositoryProvider).findById(selectedTrackId);
      if (track == null) {
        return null;
      }
      return _ExportSelection.track(track);
    }

    final route = ref.read(routeRepositoryProvider).findById(selectedRouteId!);
    if (route == null) {
      return null;
    }
    return _ExportSelection.route(route);
  }

  Future<void> _exportSelection(
    BuildContext context,
    WidgetRef ref,
    _ExportSelection selection,
  ) async {
    final service = ref.read(gpxExportServiceProvider);

    try {
      final plan = switch (selection) {
        _TrackExportSelection(:final track) => service.planTrackExport(track),
        _RouteExportSelection(:final route) => service.planRouteExport(route),
      };

      if (service.fileExists(plan)) {
        final confirmed = await showDangerConfirmDialog(
          context: context,
          title: 'Overwrite Export?',
          message: 'This file already exists. Do you want to overwrite it?',
          cancelKey: 'tracks-routes-export-cancel',
          cancelLabel: 'Cancel',
          confirmKey: 'tracks-routes-export-confirm',
          confirmLabel: 'Overwrite',
        );
        if (confirmed != true || !context.mounted) {
          return;
        }
      }

      await service.writeExport(plan);
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported to ${plan.path}')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $error')),
      );
    }
  }
}

sealed class _ExportSelection {
  const _ExportSelection();

  factory _ExportSelection.track(GpxTrack track) = _TrackExportSelection;
  factory _ExportSelection.route(app_route.Route route) = _RouteExportSelection;
}

final class _TrackExportSelection extends _ExportSelection {
  const _TrackExportSelection(this.track);

  final GpxTrack track;
}

final class _RouteExportSelection extends _ExportSelection {
  const _RouteExportSelection(this.route);

  final app_route.Route route;
}
