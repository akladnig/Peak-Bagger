import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/providers/peak_correlation_settings_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/gpx_track_statistics_calculator.dart';
import 'package:peak_bagger/services/tile_cache_service.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/peak_refresh_result.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/widgets/dialog_helpers.dart';

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
  late final VoidCallback _routerListener;

  @override
  void initState() {
    super.initState();
    _routerListener = _clearStatusWhenHidden;
    router.routerDelegate.addListener(_routerListener);
  }

  @override
  void dispose() {
    router.routerDelegate.removeListener(_routerListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);
    final filterState = ref.watch(gpxFilterSettingsProvider);
    final peakCorrelationState = ref.watch(peakCorrelationSettingsProvider);

    return Scaffold(
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Map Tile Cache'),
            subtitle: const Text('Download and manage offline map tiles'),
            trailing: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _isDownloading
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TileCacheSettingsScreen(),
                      ),
                    );
                  },
          ),
          ListTile(
            key: const Key('refresh-peak-data-tile'),
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
            onTap: _isRefreshingPeaks ? null : _confirmRefreshPeakData,
          ),
          ListTile(
            key: const Key('reset-map-data-tile'),
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
          ListTile(
            key: const Key('recalculate-track-statistics-tile'),
            leading: const Icon(Icons.query_stats),
            title: const Text('Recalculate Track Statistics'),
            subtitle: const Text(
              'Rebuild track statistics and peak correlation from stored GPX XML',
            ),
            trailing: mapState.isLoadingTracks
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: mapState.isLoadingTracks
                ? null
                : _recalculateTrackStatistics,
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
          _buildTrackFilterSection(context, filterState),
          _buildPeakCorrelationSection(context, peakCorrelationState),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_status, key: const Key('peak-refresh-status')),
            ),
        ],
      ),
    );
  }

  void _clearStatusWhenHidden() {
    if (_status.isEmpty) {
      return;
    }

    final currentPath = _currentPath();
    if (currentPath == '/settings') {
      return;
    }

    if (mounted) {
      setState(() {
        _status = '';
      });
    }
  }

  String? _currentPath() {
    try {
      return router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _confirmRefreshPeakData() async {
    final confirmed = await showDangerConfirmDialog(
      context: context,
      title: 'Refresh Peak Data?',
      message:
          'This will overwrite the current peak set. Do you want to proceed?',
      cancelKey: 'peak-refresh-cancel',
      cancelLabel: 'Cancel',
      confirmKey: 'peak-refresh-confirm',
      confirmLabel: 'Refresh',
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isRefreshingPeaks = true;
      _status = 'Refreshing peak data...';
    });

    try {
      final result = await ref.read(mapProvider.notifier).refreshPeaks();
      if (!mounted) {
        return;
      }

      setState(() {
        _status = '${result.importedCount} Peaks imported';
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showPeakRefreshResult(result);
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Error refreshing peak data: $e';
      });

      await _showPeakRefreshFailure(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingPeaks = false;
        });
      }
    }
  }

  Future<void> _resetMapData() async {
    setState(() {
      _isResettingMaps = true;
      _status = 'Clearing map data...';
    });

    try {
      final result = await ref
          .read(tasmapStateProvider.notifier)
          .resetAndReimport();
      setState(() {
        _status = result.warning == null
            ? 'Map data reset successfully!'
            : 'Map data reset successfully! ${result.warning}';
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
    final confirmed = await showDangerConfirmDialog(
      context: context,
      title: 'Reset Track Data?',
      message:
          'This will wipe all track data and re-import tracks from disk. If source files are missing or unreadable, you may end up with fewer imported tracks than before. Do you wish to proceed?',
      cancelKey: 'reset-track-data-cancel',
      cancelLabel: 'Cancel',
      confirmKey: 'reset-track-data-confirm',
      confirmLabel: 'Reset',
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

  Future<void> _recalculateTrackStatistics() async {
    final result = await ref
        .read(mapProvider.notifier)
        .recalculateTrackStatistics();
    if (!mounted) {
      return;
    }

    if (result == null) {
      await _showRecalculateTrackStatisticsFailure();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showRecalculateTrackStatisticsResult(result);
      }
    });
  }

  Future<void> _showResetTrackDataResult(TrackImportResult? result) async {
    if (!mounted || result == null) {
      return;
    }

    await showSingleActionDialog(
      context: context,
      title: 'Track Data Reset',
      closeKey: 'track-reset-result-close',
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

    await showSingleActionDialog(
      context: context,
      title: 'Track Data Reset Failed',
      closeKey: 'track-reset-error-close',
      content: Text(error),
    );
  }

  Future<void> _showPeakRefreshResult(PeakRefreshResult result) async {
    if (!mounted) {
      return;
    }

    await showSingleActionDialog(
      context: context,
      title: 'Peak Data Refreshed',
      closeKey: 'peak-refresh-result-close',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${result.importedCount} Peaks imported'),
          if (result.warning != null) ...[
            const SizedBox(height: 12),
            Text(result.warning!),
          ],
        ],
      ),
    );
  }

  Future<void> _showPeakRefreshFailure(String error) async {
    if (!mounted) {
      return;
    }

    await showSingleActionDialog(
      context: context,
      title: 'Peak Data Refresh Failed',
      closeKey: 'peak-refresh-error-close',
      content: Text(error),
    );
  }

  Future<void> _showRecalculateTrackStatisticsResult(
    TrackStatisticsRecalcResult result,
  ) async {
    await showSingleActionDialog(
      context: context,
      title: 'Track Statistics Recalculated',
      closeKey: 'track-stats-recalc-result-close',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Updated ${result.updatedCount} tracks, refreshed peak correlation, skipped ${result.skippedCount} tracks',
          ),
          if (result.warning != null) ...[
            const SizedBox(height: 12),
            Text(result.warning!),
          ],
        ],
      ),
    );
  }

  Future<void> _showRecalculateTrackStatisticsFailure() async {
    final error = ref.read(mapProvider).trackImportError;
    if (error == null) {
      return;
    }

    await showSingleActionDialog(
      context: context,
      title: 'Track Statistics Recalculation Failed',
      closeKey: 'track-stats-recalc-error-close',
      content: Text(error),
    );
  }

  Widget _buildTrackFilterSection(
    BuildContext context,
    AsyncValue<GpxFilterConfig> filterState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: switch (filterState) {
        AsyncData<GpxFilterConfig>(:final value) => ExpansionTile(
          key: const Key('gpx-filter-settings-section'),
          title: const Text('Track Filter'),
          subtitle: Text(_describeFilterConfig(value)),
          childrenPadding: const EdgeInsets.only(bottom: 16),
          children: [
            _buildEnumDropdown<GpxTrackOutlierFilter>(
              key: const Key('gpx-filter-outlier-filter'),
              label: 'Outlier Filter',
              value: value.outlierFilter,
              options: GpxTrackOutlierFilter.values,
              labelBuilder: (entry) => switch (entry) {
                GpxTrackOutlierFilter.none => 'None',
                GpxTrackOutlierFilter.hampel => 'Hampel Filter',
              },
              onChanged: (selected) {
                if (selected == null) return;
                unawaited(
                  ref
                      .read(gpxFilterSettingsProvider.notifier)
                      .setOutlierFilter(selected),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildIntegerDropdown(
              key: const Key('gpx-filter-hampel-window'),
              label: 'Hampel window',
              value: value.hampelWindow,
              options: const [5, 7, 9, 11],
              onChanged: value.outlierFilter == GpxTrackOutlierFilter.none
                  ? null
                  : (selected) {
                      if (selected == null) return;
                      unawaited(
                        ref
                            .read(gpxFilterSettingsProvider.notifier)
                            .setHampelWindow(selected),
                      );
                    },
            ),
            const SizedBox(height: 12),
            _buildEnumDropdown<GpxTrackElevationSmoother>(
              key: const Key('gpx-filter-elevation-smoother'),
              label: 'Elevation smoother',
              value: value.elevationSmoother,
              options: GpxTrackElevationSmoother.values,
              labelBuilder: (entry) => switch (entry) {
                GpxTrackElevationSmoother.none => 'None',
                GpxTrackElevationSmoother.median => 'Median',
                GpxTrackElevationSmoother.savitzkyGolay => 'Savitzky-Golay',
              },
              onChanged: (selected) {
                if (selected == null) return;
                unawaited(
                  ref
                      .read(gpxFilterSettingsProvider.notifier)
                      .setElevationSmoother(selected),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildIntegerDropdown(
              key: const Key('gpx-filter-elevation-window'),
              label: 'Elevation window',
              value: value.elevationWindow,
              options: const [5, 7, 9],
              onChanged:
                  value.elevationSmoother == GpxTrackElevationSmoother.none
                  ? null
                  : (selected) {
                      if (selected == null) return;
                      unawaited(
                        ref
                            .read(gpxFilterSettingsProvider.notifier)
                            .setElevationWindow(selected),
                      );
                    },
            ),
            const SizedBox(height: 12),
            _buildEnumDropdown<GpxTrackPositionSmoother>(
              key: const Key('gpx-filter-position-smoother'),
              label: 'Position smoother',
              value: value.positionSmoother,
              options: GpxTrackPositionSmoother.values,
              labelBuilder: (entry) => switch (entry) {
                GpxTrackPositionSmoother.none => 'None',
                GpxTrackPositionSmoother.movingAverage => 'Moving average',
                GpxTrackPositionSmoother.kalman => 'Kalman',
              },
              onChanged: (selected) {
                if (selected == null) return;
                unawaited(
                  ref
                      .read(gpxFilterSettingsProvider.notifier)
                      .setPositionSmoother(selected),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildIntegerDropdown(
              key: const Key('gpx-filter-position-window'),
              label: 'Position window',
              value: value.positionWindow,
              options: const [3, 5, 7],
              onChanged: value.positionSmoother == GpxTrackPositionSmoother.none
                  ? null
                  : (selected) {
                      if (selected == null) return;
                      unawaited(
                        ref
                            .read(gpxFilterSettingsProvider.notifier)
                            .setPositionWindow(selected),
                      );
                    },
            ),
          ],
        ),
        AsyncLoading<GpxFilterConfig>() => const ListTile(
          key: Key('gpx-filter-settings-section'),
          title: Text('Track Filter'),
          subtitle: Text('Loading filter settings...'),
          trailing: Text('...'),
        ),
        AsyncError<GpxFilterConfig>() => const ListTile(
          key: Key('gpx-filter-settings-section'),
          title: Text('Track Filter'),
          subtitle: Text('Unable to load filter settings.'),
        ),
      },
    );
  }

  Widget _buildPeakCorrelationSection(
    BuildContext context,
    AsyncValue<int> peakCorrelationState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: switch (peakCorrelationState) {
        AsyncData<int>(:final value) => ExpansionTile(
          key: const Key('peak-correlation-settings-section'),
          initiallyExpanded: true,
          title: const Text('Peak Correlation'),
          subtitle: Text('Threshold ${value}m'),
          childrenPadding: const EdgeInsets.only(bottom: 16),
          children: [
            _buildIntegerDropdown(
              key: const Key('peak-correlation-distance-meters'),
              label: 'Distance threshold',
              value: value,
              options: peakCorrelationDistanceOptions,
              onChanged: (selected) {
                if (selected == null) return;
                unawaited(
                  ref
                      .read(peakCorrelationSettingsProvider.notifier)
                      .setDistanceMeters(selected),
                );
              },
            ),
          ],
        ),
        AsyncLoading<int>() => const ListTile(
          key: Key('peak-correlation-settings-section'),
          title: Text('Peak Correlation'),
          subtitle: Text('Loading correlation settings...'),
          trailing: Text('...'),
        ),
        AsyncError<int>() => const ListTile(
          key: Key('peak-correlation-settings-section'),
          title: Text('Peak Correlation'),
          subtitle: Text('Unable to load correlation settings.'),
        ),
      },
    );
  }

  Widget _buildIntegerDropdown({
    required Key key,
    required String label,
    required int value,
    required List<int> options,
    required ValueChanged<int?>? onChanged,
  }) {
    return DropdownButtonFormField<int>(
      key: key,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: options
          .map(
            (option) => DropdownMenuItem<int>(
              value: option,
              child: Text(option.toString()),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }

  Widget _buildEnumDropdown<T extends Enum>({
    required Key key,
    required String label,
    required T value,
    required List<T> options,
    required String Function(T value) labelBuilder,
    required ValueChanged<T?>? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: key,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: options
          .map(
            (option) => DropdownMenuItem<T>(
              value: option,
              child: Text(labelBuilder(option)),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }

  String _describeFilterConfig(GpxFilterConfig config) {
    return 'Outlier Filter: ${_describeOutlierFilter(config.outlierFilter)} • Elevation smoother: ${_describeElevationSmoother(config.elevationSmoother)} • Position smoother: ${_describePositionSmoother(config.positionSmoother)}';
  }

  String _describeOutlierFilter(GpxTrackOutlierFilter value) {
    return switch (value) {
      GpxTrackOutlierFilter.none => 'None',
      GpxTrackOutlierFilter.hampel => 'Hampel Filter',
    };
  }

  String _describeElevationSmoother(GpxTrackElevationSmoother value) {
    return switch (value) {
      GpxTrackElevationSmoother.none => 'None',
      GpxTrackElevationSmoother.median => 'Median',
      GpxTrackElevationSmoother.savitzkyGolay => 'Savitzky-Golay',
    };
  }

  String _describePositionSmoother(GpxTrackPositionSmoother value) {
    return switch (value) {
      GpxTrackPositionSmoother.none => 'None',
      GpxTrackPositionSmoother.movingAverage => 'Moving average',
      GpxTrackPositionSmoother.kalman => 'Kalman',
    };
  }
}

class TileCacheSettingsScreen extends ConsumerStatefulWidget {
  const TileCacheSettingsScreen({super.key});

  @override
  ConsumerState<TileCacheSettingsScreen> createState() =>
      _TileCacheSettingsScreenState();
}

class _TileCacheSettingsScreenState
    extends ConsumerState<TileCacheSettingsScreen>
    with WidgetsBindingObserver
    implements RouteAware {
  Basemap _selectedBasemap = Basemap.openstreetmap;
  bool _isDownloading = false;
  String _status = '';
  int _minZoom = 6;
  int _maxZoom = 14;
  bool _skipExistingTiles = true;
  Map<String, StoreStats> _allStats = {};
  bool _loadingStats = true;

  static final RouteObserver<Route<dynamic>> _routeObserver =
      RouteObserver<Route<dynamic>>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    _loadAllStats();
  }

  @override
  void didPush() {}

  @override
  void didPushNext() {}

  @override
  void didPop() {}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAllStats();
    }
  }

  Future<void> _loadAllStats() async {
    setState(() => _loadingStats = true);
    final stats = TileCacheService.getStats();
    setState(() {
      _allStats = stats;
      _loadingStats = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Tile Cache'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllStats),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cache Status',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          if (_loadingStats)
            const ListTile(title: Text('Loading...'))
          else
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Basemap')),
                  DataColumn(label: Text('Tiles'), numeric: true),
                  DataColumn(label: Text('Size'), numeric: true),
                ],
                rows: TileCacheService.storeNames.asMap().entries.map((e) {
                  final idx = e.key;
                  final name = e.value;
                  final stat = _allStats[name];
                  return DataRow(
                    key: ValueKey(idx),
                    cells: [
                      DataCell(Text(name)),
                      DataCell(
                        FutureBuilder(
                          key: ValueKey('tiles_$idx'),
                          future:
                              stat?.all ??
                              Future.value((
                                length: 0,
                                size: 0.0,
                                hits: 0,
                                misses: 0,
                              )),
                          builder: (ctx, snap) {
                            if (!snap.hasData) return const Text('-');
                            return Text('${snap.data!.length}');
                          },
                        ),
                      ),
                      DataCell(
                        FutureBuilder(
                          key: ValueKey('size_$idx'),
                          future:
                              stat?.all ??
                              Future.value((
                                length: 0,
                                size: 0.0,
                                hits: 0,
                                misses: 0,
                              )),
                          builder: (ctx, snap) {
                            if (!snap.hasData) return const Text('-');
                            return Text(
                              '${snap.data!.size.toStringAsFixed(1)} KiB',
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Basemap'),
            trailing: DropdownButton<Basemap>(
              value: _selectedBasemap,
              items: Basemap.values
                  .map((b) => DropdownMenuItem(value: b, child: Text(b.name)))
                  .toList(),
              onChanged: (b) {
                if (b != null) {
                  setState(() => _selectedBasemap = b);
                }
              },
            ),
          ),
          ListTile(
            title: const Text('Min Zoom'),
            trailing: DropdownButton<int>(
              value: _minZoom,
              items: List.generate(19, (i) => i)
                  .map((z) => DropdownMenuItem(value: z, child: Text('$z')))
                  .toList(),
              onChanged: (z) {
                if (z != null && z <= _maxZoom) setState(() => _minZoom = z);
              },
            ),
          ),
          ListTile(
            title: const Text('Max Zoom'),
            trailing: DropdownButton<int>(
              value: _maxZoom,
              items: List.generate(19, (i) => i)
                  .map((z) => DropdownMenuItem(value: z, child: Text('$z')))
                  .toList(),
              onChanged: (z) {
                if (z != null && z >= _minZoom) setState(() => _maxZoom = z);
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Skip existing tiles'),
            subtitle: const Text('Only download missing tiles'),
            value: _skipExistingTiles,
            onChanged: _isDownloading
                ? null
                : (v) => setState(() => _skipExistingTiles = v),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Download'),
            onTap: _isDownloading ? null : _startDownload,
          ),
          if (_status.isNotEmpty) ListTile(title: Text(_status)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Clear Cache'),
            subtitle: const Text(
              'Delete all cached tiles for selected basemap',
            ),
            onTap: _clearCache,
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _status = 'Starting download...';
    });

    try {
      final store = TileCacheService.getStoreForBasemap(_selectedBasemap);
      if (store == null) {
        setState(() => _status = 'Store not found');
        return;
      }

      final tileLayer = TileLayer(
        urlTemplate: mapTileUrl(_selectedBasemap),
        userAgentPackageName: 'com.peak_bagger.app',
      );
      final bounds = LatLngBounds(
        const LatLng(-43.8, 144.0),
        const LatLng(-40.5, 149.0),
      );
      final region = RectangleRegion(bounds).toDownloadable(
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        options: tileLayer,
      );

      final result = store.download.startForeground(
        region: region,
        skipExistingTiles: _skipExistingTiles,
      );

      await for (final progress in result.downloadProgress) {
        if (!mounted) return;
        setState(
          () => _status =
              '${progress.successfulTilesCount} downloaded, ${progress.existingTilesCount} skipped (${progress.percentageProgress.toStringAsFixed(1)}%)',
        );
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: Text('Delete all cached tiles for ${_selectedBasemap.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await TileCacheService.clearStore(_selectedBasemap.name);
      _loadAllStats();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
    }
  }
}
