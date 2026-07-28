import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/services/peak_delete_guard.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/objectbox_schema_guard.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/objectbox_store_directory.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:peak_bagger/services/route_graph_import_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/background_jobs_provider.dart';
import 'package:peak_bagger/providers/theme_provider.dart';
import 'package:peak_bagger/services/tile_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

late final Store objectboxStore;

const _objectBoxMaxDbSizeInKB = 8 * 1024 * 1024;

void _logStartup(String message) {
  debugPrint('[startup ${DateTime.now().toIso8601String()}] $message');
}

Future<T> _runStartupPhase<T>(String label, Future<T> Function() action) async {
  final stopwatch = Stopwatch()..start();
  _logStartup('Starting $label');
  try {
    final result = await action();
    _logStartup('Finished $label in ${stopwatch.elapsedMilliseconds}ms');
    return result;
  } catch (error) {
    _logStartup(
      'Failed $label after ${stopwatch.elapsedMilliseconds}ms: $error',
    );
    rethrow;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _logStartup('Widgets binding initialized');

  registerLocalTopoRegionKeyValidator(
    (regionKey) => regionManifestCatalog.regionByKey(regionKey) != null,
  );
  _logStartup('Registered local topo region key validator');
  await _runStartupPhase('local topo runtime restore', () {
    return localTopoRuntime.restore();
  });
  await _runStartupPhase('tile cache initialization', () {
    return TileCacheService.initialize();
  });
  unawaited(TileCacheService.ensureLowZoomWarmup());
  _logStartup('Scheduled low zoom tile warmup');

  final primaryObjectBoxDirectory = await _runStartupPhase(
    'ObjectBox directory prepare',
    () {
      return preparePrimaryObjectBoxDirectory(log: _logStartup);
    },
  );
  _logStartup(
    'Primary ObjectBox directory: '
    '${primaryObjectBoxDirectory ?? '<ObjectBox default>'}',
  );
  final store = await _runStartupPhase('ObjectBox store open', () {
    return openStore(
      directory: primaryObjectBoxDirectory,
      maxDBSizeInKB: _objectBoxMaxDbSizeInKB,
    );
  });
  try {
    await _runStartupPhase('ObjectBox schema verification', () {
      return ObjectBoxSchemaGuard().verify();
    });
    objectboxStore = store;
  } catch (_) {
    store.close();
    rethrow;
  }

  final peakListRewritePort = ObjectBoxPeakListRewritePort(objectboxStore);
  final peakDeleteGuard = PeakDeleteGuard(
    ObjectBoxPeakDeleteGuardSource(objectboxStore),
  );
  final peakRepository = PeakRepository(
    objectboxStore,
    peakListRewritePort: peakListRewritePort,
  );
  final peakListRepo = PeakListRepository(
    objectboxStore,
    peakRepository: peakRepository,
  );
  final overpassService = OverpassService();
  final routeGraphRepository = RouteGraphRepository.objectBox(objectboxStore);
  final routeGraphImportService = RouteGraphImportService(routeGraphRepository);
  final routeGraphStore = ObjectBoxRouteGraphStore(
    repository: routeGraphRepository,
    importService: routeGraphImportService,
  );
  final tasmapRepo = TasmapRepository(objectboxStore);
  try {
    await _runStartupPhase('Tasmap CSV bootstrap', () {
      return tasmapRepo.loadFromCsvIfEmpty('assets/tasmap50k.csv');
    });
  } catch (_) {
    // Continue with an empty database if the import fails.
    _logStartup('Tasmap CSV bootstrap failed; continuing with empty database');
  }

  final themePreferences = await _runStartupPhase('SharedPreferences load', () {
    return SharedPreferences.getInstance();
  });

  _logStartup('Calling runApp');

  runApp(
    ProviderScope(
      overrides: [
        peakRepositoryProvider.overrideWithValue(peakRepository),
        peakListRewritePortProvider.overrideWithValue(peakListRewritePort),
        peakDeleteGuardProvider.overrideWithValue(peakDeleteGuard),
        peakListRepositoryProvider.overrideWithValue(peakListRepo),
        overpassServiceProvider.overrideWithValue(overpassService),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepo),
        routeGraphStoreProvider.overrideWithValue(routeGraphStore),
        objectboxAdminRepositoryProvider.overrideWithValue(
          ObjectBoxAdminRepositoryImpl(store: objectboxStore),
        ),
        bootstrappedThemePreferencesProvider.overrideWithValue(
          themePreferences,
        ),
        bootstrappedBackgroundJobsPreferencesProvider.overrideWithValue(
          themePreferences,
        ),
      ],
      child: const App(),
    ),
  );

  _logStartup('runApp completed');
}
