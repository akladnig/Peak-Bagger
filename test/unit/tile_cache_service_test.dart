import 'dart:async';
import 'dart:io';

import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:peak_bagger/services/objectbox_store_directory.dart';
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

  test(
    'resolveBackendRootDirectory uses Application Support on macOS',
    () async {
      final rootDirectory = await TileCacheService.resolveBackendRootDirectory(
        isMacOS: true,
        applicationSupportDirectoryPathLoader: () async =>
            '/Users/test/Library/Application Support/peak_bagger',
      );

      expect(
        rootDirectory,
        '/Users/test/Library/Application Support/peak_bagger',
      );
    },
  );

  test(
    'resolvePrimaryObjectBoxDirectory uses Application Support on macOS',
    () async {
      final rootDirectory = await resolvePrimaryObjectBoxDirectory(
        isMacOS: true,
        applicationSupportDirectoryPathLoader: () async =>
            '/Users/test/Library/Application Support/peak_bagger',
      );

      expect(
        rootDirectory,
        '/Users/test/Library/Application Support/peak_bagger/${Store.defaultDirectoryPath}',
      );
    },
  );

  test(
    'resolvePrimaryObjectBoxDirectory keeps ObjectBox default off macOS',
    () async {
      var loaderCalled = false;

      final rootDirectory = await resolvePrimaryObjectBoxDirectory(
        isMacOS: false,
        applicationSupportDirectoryPathLoader: () async {
          loaderCalled = true;
          return '/should/not/be/used';
        },
      );

      expect(rootDirectory, isNull);
      expect(loaderCalled, isFalse);
    },
  );

  test(
    'preparePrimaryObjectBoxDirectory migrates legacy store and keeps source',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('objectbox-store');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final documentsDirectory = Directory(p.join(tempDir.path, 'Documents'))
        ..createSync(recursive: true);
      final applicationSupportDirectory = Directory(
        p.join(tempDir.path, 'Application Support'),
      )..createSync(recursive: true);
      final legacyStore = Directory(
        p.join(documentsDirectory.path, Store.defaultDirectoryPath),
      )..createSync(recursive: true);
      File(p.join(legacyStore.path, 'data.mdb')).writeAsStringSync('db-data');
      final nestedDirectory = Directory(p.join(legacyStore.path, 'nested'))
        ..createSync(recursive: true);
      File(
        p.join(nestedDirectory.path, 'index.bin'),
      ).writeAsStringSync('nested-data');
      final logs = <String>[];

      final targetDirectory = await preparePrimaryObjectBoxDirectory(
        isMacOS: true,
        applicationSupportDirectoryPathLoader: () async =>
            applicationSupportDirectory.path,
        applicationDocumentsDirectoryPathLoader: () async =>
            documentsDirectory.path,
        log: logs.add,
      );

      expect(
        targetDirectory,
        p.join(applicationSupportDirectory.path, Store.defaultDirectoryPath),
      );
      expect(
        File(p.join(targetDirectory!, 'data.mdb')).readAsStringSync(),
        'db-data',
      );
      expect(
        File(p.join(targetDirectory, 'nested', 'index.bin')).readAsStringSync(),
        'nested-data',
      );
      expect(
        File(p.join(legacyStore.path, 'data.mdb')).readAsStringSync(),
        'db-data',
      );
      expect(
        logs,
        contains(
          predicate<String>(
            (message) => message.contains('Migrating Primary ObjectBox store'),
          ),
        ),
      );
      expect(logs, contains('Finished Primary ObjectBox store migration'));
    },
  );

  test(
    'preparePrimaryObjectBoxDirectory skips migration when target exists',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('objectbox-store');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final documentsDirectory = Directory(p.join(tempDir.path, 'Documents'))
        ..createSync(recursive: true);
      final applicationSupportDirectory = Directory(
        p.join(tempDir.path, 'Application Support'),
      )..createSync(recursive: true);
      final legacyStore = Directory(
        p.join(documentsDirectory.path, Store.defaultDirectoryPath),
      )..createSync(recursive: true);
      File(
        p.join(legacyStore.path, 'data.mdb'),
      ).writeAsStringSync('legacy-data');
      final targetStore = Directory(
        p.join(applicationSupportDirectory.path, Store.defaultDirectoryPath),
      )..createSync(recursive: true);
      File(
        p.join(targetStore.path, 'data.mdb'),
      ).writeAsStringSync('target-data');
      final logs = <String>[];

      final targetDirectory = await preparePrimaryObjectBoxDirectory(
        isMacOS: true,
        applicationSupportDirectoryPathLoader: () async =>
            applicationSupportDirectory.path,
        applicationDocumentsDirectoryPathLoader: () async =>
            documentsDirectory.path,
        log: logs.add,
      );

      expect(targetDirectory, targetStore.path);
      expect(
        File(p.join(targetStore.path, 'data.mdb')).readAsStringSync(),
        'target-data',
      );
      expect(
        File(p.join(legacyStore.path, 'data.mdb')).readAsStringSync(),
        'legacy-data',
      );
      expect(
        logs,
        contains(
          'Primary ObjectBox store migration skipped because target already exists: '
          '${targetStore.path}',
        ),
      );
    },
  );

  test(
    'prepareBackendRootDirectory migrates legacy tile cache and keeps source',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('tile-cache-store');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final documentsDirectory = Directory(p.join(tempDir.path, 'Documents'))
        ..createSync(recursive: true);
      final applicationSupportDirectory = Directory(
        p.join(tempDir.path, 'Application Support'),
      )..createSync(recursive: true);
      final legacyStore = Directory(p.join(documentsDirectory.path, 'fmtc'))
        ..createSync(recursive: true);
      File(
        p.join(legacyStore.path, 'data.mdb'),
      ).writeAsStringSync('cache-data');
      final nestedDirectory = Directory(p.join(legacyStore.path, 'stores'))
        ..createSync(recursive: true);
      File(
        p.join(nestedDirectory.path, 'store.bin'),
      ).writeAsStringSync('store-data');
      final logs = <String>[];

      final rootDirectory = await TileCacheService.prepareBackendRootDirectory(
        isMacOS: true,
        applicationSupportDirectoryPathLoader: () async =>
            applicationSupportDirectory.path,
        applicationDocumentsDirectoryPathLoader: () async =>
            documentsDirectory.path,
        log: logs.add,
      );

      expect(rootDirectory, applicationSupportDirectory.path);
      expect(
        File(p.join(rootDirectory!, 'fmtc', 'data.mdb')).readAsStringSync(),
        'cache-data',
      );
      expect(
        File(
          p.join(rootDirectory, 'fmtc', 'stores', 'store.bin'),
        ).readAsStringSync(),
        'store-data',
      );
      expect(
        File(p.join(legacyStore.path, 'data.mdb')).readAsStringSync(),
        'cache-data',
      );
      expect(
        logs,
        contains(
          predicate<String>((message) => message.contains('Tile cache store')),
        ),
      );
      expect(logs, contains('Finished Tile cache store migration'));
    },
  );

  test(
    'prepareBackendRootDirectory skips migration when target exists',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('tile-cache-store');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final documentsDirectory = Directory(p.join(tempDir.path, 'Documents'))
        ..createSync(recursive: true);
      final applicationSupportDirectory = Directory(
        p.join(tempDir.path, 'Application Support'),
      )..createSync(recursive: true);
      final legacyStore = Directory(p.join(documentsDirectory.path, 'fmtc'))
        ..createSync(recursive: true);
      File(
        p.join(legacyStore.path, 'data.mdb'),
      ).writeAsStringSync('legacy-cache-data');
      final targetStore = Directory(
        p.join(applicationSupportDirectory.path, 'fmtc'),
      )..createSync(recursive: true);
      File(
        p.join(targetStore.path, 'data.mdb'),
      ).writeAsStringSync('target-cache-data');
      final logs = <String>[];

      final rootDirectory = await TileCacheService.prepareBackendRootDirectory(
        isMacOS: true,
        applicationSupportDirectoryPathLoader: () async =>
            applicationSupportDirectory.path,
        applicationDocumentsDirectoryPathLoader: () async =>
            documentsDirectory.path,
        log: logs.add,
      );

      expect(rootDirectory, applicationSupportDirectory.path);
      expect(
        File(p.join(targetStore.path, 'data.mdb')).readAsStringSync(),
        'target-cache-data',
      );
      expect(
        File(p.join(legacyStore.path, 'data.mdb')).readAsStringSync(),
        'legacy-cache-data',
      );
      expect(
        logs,
        contains(
          'Tile cache store migration skipped because target already exists: '
          '${targetStore.path}',
        ),
      );
    },
  );

  test('resolveBackendRootDirectory skips custom root outside macOS', () async {
    var loaderCalled = false;

    final rootDirectory = await TileCacheService.resolveBackendRootDirectory(
      isMacOS: false,
      applicationSupportDirectoryPathLoader: () async {
        loaderCalled = true;
        return '/should/not/be/used';
      },
    );

    expect(rootDirectory, isNull);
    expect(loaderCalled, isFalse);
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
