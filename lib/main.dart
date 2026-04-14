import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/objectbox.g.dart';
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
    await tasmapRepo.loadFromCsvIfEmpty('assets/tasmap50k.csv');
  } catch (_) {
    // Continue with an empty database if the import fails.
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
