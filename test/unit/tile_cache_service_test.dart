import 'dart:async';

import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/tile_cache_download_scope.dart';
import 'package:peak_bagger/services/tile_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TileCacheService.resetLowZoomWarmupStateForTesting();
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
      Basemap.values.map((b) => b.name).toList(growable: false),
    );
    expect(basemaps, expectedWarmupBasemaps);
    expect(regions, hasLength(expectedWarmupBasemaps.length));
    expect(basemaps, isNot(contains(Basemap.sloveniaTopo)));
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
}
