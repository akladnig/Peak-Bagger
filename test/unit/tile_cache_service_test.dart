import 'dart:async';

import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:peak_bagger/services/tile_cache_download_scope.dart';
import 'package:peak_bagger/services/tile_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TileCacheService.resetLowZoomWarmupStateForTesting();
    localTopoRuntime.resetForTesting();
  });

  test('ensureLowZoomWarmup downloads missing low zoom tiles once', () async {
    final basemaps = <Basemap>[];
    final regions = <DownloadableRegion>[];
    final expectedWarmupBasemaps = TileCacheService.warmupBasemaps.toList(
      growable: false,
    );

    await TileCacheService.ensureLowZoomWarmup(
      downloadStarter:
          ({required basemap, required region, required skipExistingTiles}) {
            basemaps.add(basemap);
            regions.add(region);
            expect(skipExistingTiles, isTrue);
            return (
              tileEvents: const Stream<TileEvent>.empty(),
              downloadProgress: const Stream<DownloadProgress>.empty(),
            );
          },
    );

    expect(
      TileCacheService.storeNames,
      TileCacheService.availableBasemaps
          .map((basemap) => basemap.name)
          .toList(growable: false),
    );
    expect(basemaps, expectedWarmupBasemaps);
    expect(regions, hasLength(expectedWarmupBasemaps.length));
    expect(basemaps, isNot(contains(Basemap.sloveniaTopo)));
    expect(basemaps, isNot(contains(Basemap.fvgTopo)));
    expect(basemaps.contains(Basemap.mapyCz), hasMapyCzApiKey);
    expect(regions.first.minZoom, lowZoomTileCacheWarmupMinZoom);
    expect(regions.first.maxZoom, lowZoomTileCacheWarmupMaxZoom);

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getInt(TileCacheService.lowZoomWarmupVersionKey),
      TileCacheService.lowZoomWarmupVersion,
    );
  });

  test(
    'ensureLowZoomWarmup skips downloads when version already completed',
    () async {
      SharedPreferences.setMockInitialValues({
        TileCacheService.lowZoomWarmupVersionKey:
            TileCacheService.lowZoomWarmupVersion,
      });

      var callCount = 0;

      await TileCacheService.ensureLowZoomWarmup(
        downloadStarter:
            ({required basemap, required region, required skipExistingTiles}) {
              callCount++;
              return (
                tileEvents: const Stream<TileEvent>.empty(),
                downloadProgress: const Stream<DownloadProgress>.empty(),
              );
            },
      );

      expect(callCount, 0);
    },
  );

  test(
    'ensureLowZoomWarmup does not persist success after a failed basemap',
    () async {
      await TileCacheService.ensureLowZoomWarmup(
        downloadStarter:
            ({required basemap, required region, required skipExistingTiles}) {
              if (basemap == Basemap.tracestrack) {
                throw StateError('boom');
              }
              return (
                tileEvents: const Stream<TileEvent>.empty(),
                downloadProgress: const Stream<DownloadProgress>.empty(),
              );
            },
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey(TileCacheService.lowZoomWarmupVersionKey),
        isFalse,
      );
    },
  );

  test('ensureLowZoomWarmup coalesces duplicate in-flight calls', () async {
    final completer = Completer<void>();
    var callCount = 0;

    Stream<DownloadProgress> pendingProgress() async* {
      await completer.future;
    }

    final first = TileCacheService.ensureLowZoomWarmup(
      downloadStarter:
          ({required basemap, required region, required skipExistingTiles}) {
            callCount++;
            return (
              tileEvents: const Stream<TileEvent>.empty(),
              downloadProgress: pendingProgress(),
            );
          },
    );
    final second = TileCacheService.ensureLowZoomWarmup(
      downloadStarter:
          ({required basemap, required region, required skipExistingTiles}) {
            callCount += 100;
            return (
              tileEvents: const Stream<TileEvent>.empty(),
              downloadProgress: const Stream<DownloadProgress>.empty(),
            );
          },
    );

    await Future<void>.delayed(Duration.zero);
    expect(callCount, 1);

    completer.complete();
    await Future.wait([first, second]);

    expect(callCount, TileCacheService.warmupBasemaps.length);
  });

  test('transformBrowseUrl normalizes wrapped mapy tile coordinates', () {
    expect(
      TileCacheService.transformBrowseUrl(
        Basemap.mapyCz,
        'https://api.mapy.com/v1/maptiles/outdoor/256/10/-1/-1?lang=en&apikey=test-key',
      ),
      'https://api.mapy.com/v1/maptiles/outdoor/256/10/1023/0?lang=en&apikey=test-key',
    );
    expect(
      TileCacheService.transformBrowseUrl(
        Basemap.mapyCz,
        'https://api.mapy.com/v1/maptiles/outdoor/256/10/1024/1024?lang=en&apikey=test-key',
      ),
      'https://api.mapy.com/v1/maptiles/outdoor/256/10/0/1023?lang=en&apikey=test-key',
    );
    expect(
      TileCacheService.transformBrowseUrl(
        Basemap.openstreetmap,
        'https://tile.openstreetmap.org/10/-1/-1.png',
      ),
      'https://tile.openstreetmap.org/10/-1/-1.png',
    );
  });

  test(
    'transformUrl uses the resolved runtime contract for Local Topo',
    () async {
      await localTopoRuntime.saveValidatedSnapshot(
        LocalTopoCapabilitySnapshot(
          baseUrl: Uri.parse('http://127.0.0.1:8090'),
          regions: const [
            LocalTopoRegionCapability(
              regionKey: 'tasmania',
              tilePathTemplate: '/tasmania/local-topo/{z}/{x}/{y}.png',
            ),
          ],
        ),
      );

      expect(
        TileCacheService.transformUrl(Basemap.localTopo, 7, 88, 99),
        'http://127.0.0.1:8090/tasmania/local-topo/7/88/99.png',
      );
    },
  );

  test(
    'Local Topo participates in manual cache basemaps but not warmup',
    () async {
      await localTopoRuntime.saveValidatedSnapshot(
        LocalTopoCapabilitySnapshot(
          baseUrl: Uri.parse('http://127.0.0.1:8090'),
          regions: const [
            LocalTopoRegionCapability(
              regionKey: 'tasmania',
              tilePathTemplate: '/tasmania/local-topo/{z}/{x}/{y}.png',
            ),
          ],
        ),
      );

      expect(TileCacheService.availableBasemaps, contains(Basemap.localTopo));
      expect(
        TileCacheService.warmupBasemaps,
        isNot(contains(Basemap.localTopo)),
      );
    },
  );
}
