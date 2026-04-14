import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/tile_downloader.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDownloading = false;
  bool _isRefreshingPeaks = false;
  bool _isResettingMaps = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Download Offline Tiles'),
            subtitle: const Text('Download Tasmania map tiles for offline use'),
            trailing: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _isDownloading ? null : _downloadTiles,
          ),
          if (_status.isNotEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text(_status)),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Refresh Peak Data'),
            subtitle: const Text('Re-fetch peaks from Overpass API'),
            trailing: _isRefreshingPeaks
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _isRefreshingPeaks ? null : _refreshPeaks,
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Reset Map Data'),
            subtitle: const Text('Clear and re-import map data'),
            trailing: _isResettingMaps
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _isResettingMaps ? null : _resetMapData,
          ),
          ListTile(
            key: const Key('reset-track-data-tile'),
            leading: const Icon(Icons.route),
            title: const Text('Reset Track Data'),
            subtitle: const Text(
              'Wipe track data and rebuild from Tracks and Tracks/Tasmania',
            ),
            trailing: mapState.isLoadingTracks
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: mapState.isLoadingTracks ? null : _confirmResetTrackData,
          ),
          if (mapState.hasTrackRecoveryIssue)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Some tracks need to be rebuilt.'),
            ),
          if (mapState.trackOperationStatus != null ||
              mapState.trackOperationWarning != null ||
              mapState.trackImportError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mapState.trackOperationStatus != null)
                    Text(mapState.trackOperationStatus!),
                  if (mapState.trackOperationWarning != null) ...[
                    const SizedBox(height: 8),
                    Text(mapState.trackOperationWarning!),
                  ],
                  if (mapState.trackImportError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      mapState.trackImportError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (_status.isNotEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text(_status)),
        ],
      ),
    );
  }

  Future<void> _downloadTiles() async {
    setState(() {
      _isDownloading = true;
      _status = 'Downloading tiles...';
    });

    try {
      await TileDownloader.downloadAllTiles();
      setState(() {
        _status = 'Tiles downloaded successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error downloading tiles: $e';
      });
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _refreshPeaks() async {
    setState(() {
      _isRefreshingPeaks = true;
      _status = 'Refreshing peak data...';
    });

    try {
      await ref.read(mapProvider.notifier).refreshPeaks();
      setState(() {
        _status = 'Peak data refreshed successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error refreshing peak data: $e';
      });
    } finally {
      setState(() {
        _isRefreshingPeaks = false;
      });
    }
  }

  Future<void> _resetMapData() async {
    setState(() {
      _isResettingMaps = true;
      _status = 'Clearing map data...';
    });

    try {
      await ref.read(tasmapStateProvider.notifier).resetAndReimport();
      setState(() {
        _status = 'Map data reset successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error resetting map data: $e';
      });
    } finally {
      setState(() {
        _isResettingMaps = false;
      });
    }
  }

  Future<void> _confirmResetTrackData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Track Data?'),
          content: const Text(
            'This will wipe all track data and re-import tracks from disk. If source files are missing or unreadable, you may end up with fewer imported tracks than before. Do you wish to proceed?',
          ),
          actions: [
            TextButton(
              key: const Key('reset-track-data-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('reset-track-data-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final result = await ref.read(mapProvider.notifier).resetTrackData();
      if (!mounted) {
        return;
      }
      if (result == null) {
        await _showResetTrackDataFailure();
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showResetTrackDataResult(result);
        }
      });
    }
  }

  Future<void> _showResetTrackDataResult(TrackImportResult? result) async {
    if (!mounted || result == null) {
      return;
    }

    await showDialog<void>(
      useRootNavigator: true,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Track Data Reset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Imported ${result.importedCount}, replaced ${result.replacedCount}, unchanged ${result.unchangedCount}, non-Tasmanian ${result.nonTasmanianCount}, errors ${result.errorSkippedCount}',
              ),
              if (result.warning != null) ...[
                const SizedBox(height: 12),
                Text(result.warning!),
              ],
            ],
          ),
          actions: [
            FilledButton(
              key: const Key('track-reset-result-close'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showResetTrackDataFailure() async {
    if (!mounted) {
      return;
    }

    final error = ref.read(mapProvider).trackImportError;
    if (error == null) {
      return;
    }

    await showDialog<void>(
      useRootNavigator: true,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Track Data Reset Failed'),
          content: Text(error),
          actions: [
            FilledButton(
              key: const Key('track-reset-error-close'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
