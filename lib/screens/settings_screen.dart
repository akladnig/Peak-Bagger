import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/tile_downloader.dart';
import 'package:peak_bagger/providers/map_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDownloading = false;
  bool _isRefreshingPeaks = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
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
}
