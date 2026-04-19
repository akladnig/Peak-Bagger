import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/peak_list_file_picker.dart';
import '../widgets/peak_list_import_dialog.dart';

final peakListImportRunnerProvider = Provider<PeakListImportRunner>((ref) {
  return ({required String listName, required String csvPath}) async {
    return const PeakListImportPresentationResult(
      updated: false,
      importedCount: 0,
      skippedCount: 0,
    );
  };
});

final peakListDuplicateNameCheckerProvider =
    Provider<PeakListDuplicateNameChecker>((ref) {
      return (name) async => false;
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
      body: const Center(child: Text('Peak Lists')),
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
