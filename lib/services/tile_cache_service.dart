import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/services/tile_cache_download_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TileCacheService {
  static List<String> get storeNames => [
    for (final basemap in Basemap.values) basemap.name,
  ];
  static Iterable<Basemap> get warmupBasemaps =>
      Basemap.values.where((basemap) => basemap != Basemap.sloveniaTopo);
  @visibleForTesting
  static const lowZoomWarmupVersionKey = 'tile_cache_low_zoom_warmup_version';

  @visibleForTesting
  static const lowZoomWarmupVersion = 3;

  static final Map<String, FMTCStore> _stores = {};
  static Future<void>? _lowZoomWarmupFuture;

  static Future<void> initialize() async {
    final backend = FMTCObjectBoxBackend();
    await backend.initialise();

    for (final storeName in storeNames) {
      final store = FMTCStore(storeName);
      await store.manage.create();
      _stores[storeName] = store;
    }
  }

  static FMTCStore? getStore(String storeName) {
    return _stores[storeName];
  }

  static FMTCStore? getStoreForBasemap(Basemap basemap) {
    return _stores[basemap.name];
  }

  static String transformUrl(Basemap basemap, int z, int x, int y) {
    final url = mapTileUrl(basemap);
    if (basemap == Basemap.tasmapTopo ||
        basemap == Basemap.tasmap50k ||
        basemap == Basemap.tasmap25k) {
      return url
          .replaceAll('{z}', '$z')
          .replaceAll('{y}', '$y')
          .replaceAll('{x}', '$x');
    }
    return url
        .replaceAll('{z}', '$z')
        .replaceAll('{x}', '$x')
        .replaceAll('{y}', '$y');
  }

  static Map<String, StoreStats> getStats() {
    final stats = <String, StoreStats>{};
    for (final entry in _stores.entries) {
      stats[entry.key] = entry.value.stats;
    }
    return stats;
  }

  static Future<void> clearStore(String storeName) async {
    final store = _stores[storeName];
    if (store != null) {
      await store.manage.delete();
    }
  }

  static Future<void> clearAllStores() async {
    for (final store in _stores.values) {
      await store.manage.delete();
    }
  }

  static Future<void> ensureLowZoomWarmup({
    TileCacheDownloadStarter? downloadStarter,
    Future<SharedPreferences> Function()? sharedPreferencesLoader,
  }) {
    final inFlight = _lowZoomWarmupFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _ensureLowZoomWarmupInternal(
      downloadStarter: downloadStarter ?? _startWarmupDownload,
      sharedPreferencesLoader:
          sharedPreferencesLoader ?? SharedPreferences.getInstance,
    );
    _lowZoomWarmupFuture = future;
    return future.whenComplete(() {
      if (identical(_lowZoomWarmupFuture, future)) {
        _lowZoomWarmupFuture = null;
      }
    });
  }

  static Future<void> _ensureLowZoomWarmupInternal({
    required TileCacheDownloadStarter downloadStarter,
    required Future<SharedPreferences> Function() sharedPreferencesLoader,
  }) async {
    final prefs = await sharedPreferencesLoader();
    if (prefs.getInt(lowZoomWarmupVersionKey) == lowZoomWarmupVersion) {
      return;
    }

    var completed = true;
    for (final basemap in warmupBasemaps) {
      try {
        final result = downloadStarter(
          basemap: basemap,
          region: buildLowZoomTileCacheWarmupRegion(
            options: buildBasemapTileLayer(
              basemap,
              userAgentPackageName: 'com.peak_bagger.app',
            ),
          ),
          skipExistingTiles: true,
        );
        await result.downloadProgress.drain<void>();
      } catch (error, stackTrace) {
        completed = false;
        developer.log(
          'Low zoom tile warmup failed for ${basemap.name}',
          error: error,
          stackTrace: stackTrace,
          name: 'TileCacheService',
        );
      }
    }

    if (completed) {
      await prefs.setInt(lowZoomWarmupVersionKey, lowZoomWarmupVersion);
    }
  }

  static ({
    Stream<TileEvent> tileEvents,
    Stream<DownloadProgress> downloadProgress,
  })
  _startWarmupDownload({
    required Basemap basemap,
    required DownloadableRegion region,
    required bool skipExistingTiles,
  }) {
    final store = getStoreForBasemap(basemap);
    if (store == null) {
      throw StateError('Store not found for ${basemap.name}');
    }

    return store.download.startForeground(
      region: region,
      skipExistingTiles: skipExistingTiles,
    );
  }

  @visibleForTesting
  static void resetLowZoomWarmupStateForTesting() {
    _lowZoomWarmupFuture = null;
  }
}
