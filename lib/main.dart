import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/csv_importer.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';

late final Store objectboxStore;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  objectboxStore = await openStore();

  final tasmapRepo = TasmapRepository(objectboxStore);

  try {
    // Clear and re-import to ensure new schema fields are populated
    await tasmapRepo.clearAll();
    final maps = await CsvImporter.importFromCsv('assets/tasmap50k.csv');
    if (maps.isNotEmpty) {
      await tasmapRepo.addMaps(maps);
    }
  } catch (e) {
    // Continue with empty database if import fails
  }

  runApp(
    ProviderScope(
      overrides: [
        tasmapRepositoryProvider.overrideWithValue(tasmapRepo),
        objectboxAdminRepositoryProvider.overrideWithValue(
          ObjectBoxAdminRepositoryImpl(store: objectboxStore),
        ),
      ],
      child: const App(),
    ),
  );
}
