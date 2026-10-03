import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/contact_provider.dart';
import 'package:peak_bagger/providers/natural_feature_provider.dart';
import 'package:peak_bagger/services/peak_delete_guard.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/contact_repository.dart';
import 'package:peak_bagger/services/natural_feature_repository.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/objectbox_schema_guard.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/objectbox_store_directory.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:peak_bagger/services/route_graph_import_service.dart';
import 'package:peak_bagger/services/route_graph_import_coordinator.dart';
import 'package:peak_bagger/services/route_graph_coverage_resolver.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/background_jobs_provider.dart';
import 'package:peak_bagger/providers/theme_provider.dart';
import 'package:peak_bagger/services/tile_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peak_bagger/startup_shell.dart';
import 'package:peak_bagger/router.dart' show createRouter, router;

late final Store objectboxStore;
late final Widget Function(MappingCatalog catalog) _readyAppBuilder;

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _logStartup('Widgets binding initialized');

  runApp(
    StartupShell(
      coordinator: MappingStoreStartupCoordinator(
        isMacOS: Platform.isMacOS,
        mappingDataStore: MappingDataStore(),
        initialize: _initializeReadyDependencies,
      ),
      readyBuilder: (catalog) => _readyAppBuilder(catalog),
      onQuit: () => exit(0),
    ),
  );
}

Future<void> _initializeReadyDependencies(MappingCatalog catalog) async {
  Store? store;
  try {
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
    store = await _runStartupPhase('ObjectBox store open', () {
      return openStore(
        directory: primaryObjectBoxDirectory,
        maxDBSizeInKB: _objectBoxMaxDbSizeInKB,
      );
    });
    final initializedStore = store!;
    await _runStartupPhase('ObjectBox schema verification', () {
      return ObjectBoxSchemaGuard().verify();
    });
    registerLocalTopoRegionKeyValidator(
      (regionKey) => catalog.regionByKey(regionKey) != null,
    );
    await _runStartupPhase('local topo runtime restore', () {
      return localTopoRuntime.restore();
    });
    final themePreferences = await _runStartupPhase(
      'SharedPreferences load',
      SharedPreferences.getInstance,
    );

    final peakListRewritePort = ObjectBoxPeakListRewritePort(initializedStore);
    final peakDeleteGuard = PeakDeleteGuard(
      ObjectBoxPeakDeleteGuardSource(initializedStore),
    );
    final peakRepository = PeakRepository(
      initializedStore,
      peakListRewritePort: peakListRewritePort,
    );
    final peakListRepo = PeakListRepository(
      initializedStore,
      peakRepository: peakRepository,
    );
    final contactRepository = ContactRepository(initializedStore);
    final naturalFeatureRepository = NaturalFeatureRepository(initializedStore);
    final overpassService = OverpassService();
    final routeGraphRepository = RouteGraphRepository.objectBox(
      initializedStore,
    );
    final routeGraphImportService = RouteGraphImportService(
      routeGraphRepository,
    );
    final routeGraphImportCoordinator = RouteGraphImportCoordinator(
      coverageResolver: RouteGraphCoverageResolver(),
      importService: routeGraphImportService,
      repository: routeGraphRepository,
    );
    final routeGraphStore = ObjectBoxRouteGraphStore(
      repository: routeGraphRepository,
      importService: routeGraphImportService,
      importCoordinator: routeGraphImportCoordinator,
    );
    final tasmapRepo = TasmapRepository(initializedStore);

    await _runStartupPhase('tile cache initialization', () {
      return TileCacheService.initialize();
    });
    objectboxStore = initializedStore;
    _readyAppBuilder = (catalog) {
      router = createRouter();
      return ProviderScope(
        overrides: [
          mappingCatalogProvider.overrideWithValue(catalog),
          peakRepositoryProvider.overrideWithValue(peakRepository),
          contactRepositoryProvider.overrideWithValue(contactRepository),
          naturalFeatureRepositoryProvider.overrideWithValue(
            naturalFeatureRepository,
          ),
          peakListRewritePortProvider.overrideWithValue(peakListRewritePort),
          peakDeleteGuardProvider.overrideWithValue(peakDeleteGuard),
          peakListRepositoryProvider.overrideWithValue(peakListRepo),
          overpassServiceProvider.overrideWithValue(overpassService),
          tasmapRepositoryProvider.overrideWithValue(tasmapRepo),
          routeGraphStoreProvider.overrideWithValue(routeGraphStore),
          routeGraphImportCoordinatorProvider.overrideWithValue(
            routeGraphImportCoordinator,
          ),
          objectboxAdminRepositoryProvider.overrideWithValue(
            ObjectBoxAdminRepositoryImpl(store: initializedStore),
          ),
          bootstrappedThemePreferencesProvider.overrideWithValue(
            themePreferences,
          ),
          bootstrappedBackgroundJobsPreferencesProvider.overrideWithValue(
            themePreferences,
          ),
        ],
        child: App(router: router),
      );
    };
    unawaited(TileCacheService.ensureLowZoomWarmup());
  } catch (_) {
    store?.close();
    rethrow;
  }
}
