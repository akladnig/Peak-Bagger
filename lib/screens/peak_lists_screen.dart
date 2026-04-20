import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/peak_provider.dart';
import '../services/peak_list_file_picker.dart';
import '../services/peak_list_import_service.dart';
import '../services/peak_list_repository.dart';
import '../widgets/peak_list_import_dialog.dart';

final peakListRepositoryProvider = Provider<PeakListRepository>((ref) {
  throw UnimplementedError('peakListRepositoryProvider must be overridden');
});

final peakListImportServiceProvider = Provider<PeakListImportService>((ref) {
  return PeakListImportService(
    peakRepository: ref.watch(peakRepositoryProvider),
    peakListRepository: ref.watch(peakListRepositoryProvider),
  );
});

final peakListImportRunnerProvider = Provider<PeakListImportRunner>((ref) {
  final service = ref.watch(peakListImportServiceProvider);
  return ({required String listName, required String csvPath}) async {
    final result = await service.importPeakList(
      listName: listName,
      csvPath: csvPath,
    );
    return PeakListImportPresentationResult(
      updated: result.updated,
      importedCount: result.importedCount,
      skippedCount: result.skippedCount,
      warningCount: result.warningEntries.length,
      warningMessage: result.warningMessage,
    );
  };
});

final peakListDuplicateNameCheckerProvider =
    Provider<PeakListDuplicateNameChecker>((ref) {
      final repository = ref.watch(peakListRepositoryProvider);
      return (name) async => repository.findByName(name.trim()) != null;
    });

class PeakListsScreen extends ConsumerWidget {
  const PeakListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filePicker = ref.watch(peakListFilePickerProvider);
    final importRunner = ref.watch(peakListImportRunnerProvider);
    final duplicateNameChecker = ref.watch(
      peakListDuplicateNameCheckerProvider,
    );

    return Scaffold(
      body: const SizedBox.expand(),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('peak-lists-import-fab'),
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (context) {
              return PeakListImportDialog(
                filePicker: filePicker,
                onImport: importRunner,
                duplicateNameChecker: duplicateNameChecker,
              );
            },
          );
        },
        label: const Text('Import Peak List'),
        icon: const Icon(Icons.upload_file),
      ),
    );
  }
}
