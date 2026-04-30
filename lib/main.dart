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
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/services/tile_cache_service.dart';

late final Store objectboxStore;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TileCacheService.initialize();

  final store = await openStore();
  try {
    await ObjectBoxSchemaGuard().verify();
    objectboxStore = store;
  } catch (_) {
    store.close();
    rethrow;
  }

  final peakListRewritePort = ObjectBoxPeakListRewritePort(objectboxStore);
  final peakDeleteGuard = PeakDeleteGuard(
    ObjectBoxPeakDeleteGuardSource(objectboxStore),
  );
  final peakListRepo = PeakListRepository(objectboxStore);
  final overpassService = OverpassService();
  final tasmapRepo = TasmapRepository(objectboxStore);
  try {
    await tasmapRepo.loadFromCsvIfEmpty('assets/tasmap50k.csv');
  } catch (_) {
    // Continue with an empty database if the import fails.
  }

  runApp(
    ProviderScope(
      overrides: [
        peakRepositoryProvider.overrideWithValue(
          PeakRepository(
            objectboxStore,
            peakListRewritePort: peakListRewritePort,
          ),
        ),
        peakListRewritePortProvider.overrideWithValue(peakListRewritePort),
        peakDeleteGuardProvider.overrideWithValue(peakDeleteGuard),
        peakListRepositoryProvider.overrideWithValue(peakListRepo),
        overpassServiceProvider.overrideWithValue(overpassService),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepo),
        objectboxAdminRepositoryProvider.overrideWithValue(
          ObjectBoxAdminRepositoryImpl(store: objectboxStore),
        ),
      ],
      child: const App(),
    ),
  );
}
