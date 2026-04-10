import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/csv_importer.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

late final Store objectboxStore;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  objectboxStore = await openStore();

  // Import tasmap data - clear and re-import to handle schema changes
  final tasmapRepo = TasmapRepository(objectboxStore);
  try {
    await tasmapRepo.clearAll();
    final maps = await CsvImporter.importFromCsv('assets/tasmap50k.csv');
    if (maps.isNotEmpty) {
      await tasmapRepo.addMaps(maps);
    }
  } catch (e) {
    // Continue with empty database if import fails
  }

  runApp(ProviderScope(child: App()));
}
