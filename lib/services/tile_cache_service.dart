import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';

class TileCacheService {
  static const List<String> storeNames = [
    'openstreetmap',
    'tracestrack',
    'tasmapTopo',
    'tasmap50k',
    'tasmap25k',
  ];

  static final Map<String, FMTCStore> _stores = {};

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
}
