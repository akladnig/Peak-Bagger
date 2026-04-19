import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/screens/peak_lists_screen.dart';
import 'package:peak_bagger/services/peak_list_file_picker.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';

class PeakListsRobot {
  PeakListsRobot(this.tester);

  final WidgetTester tester;

  Finder get importFab => find.byKey(const Key('peak-lists-import-fab'));
  Finder get importDialog => find.byKey(const Key('peak-list-import-dialog'));
  Finder get selectFileButton => find.byKey(const Key('peak-list-select-file'));
  Finder get nameField => find.byKey(const Key('peak-list-name-field'));
  Finder get importButton => find.byKey(const Key('peak-list-import-button'));
  Finder get updateConfirm => find.byKey(const Key('peak-list-update-confirm'));
  Finder get errorClose =>
      find.byKey(const Key('peak-list-import-error-close'));

  Future<void> pumpApp({
    required PeakListFilePicker filePicker,
    PeakListImportRunner? importRunner,
    PeakListDuplicateNameChecker? duplicateNameChecker,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peakListFilePickerProvider.overrideWithValue(filePicker),
          peakListImportRunnerProvider.overrideWithValue(
            importRunner ??
                ({required String listName, required String csvPath}) async {
                  return const PeakListImportPresentationResult(
                    updated: false,
                    importedCount: 1,
                    skippedCount: 0,
                  );
                },
          ),
          peakListDuplicateNameCheckerProvider.overrideWithValue(
            duplicateNameChecker ?? ((name) async => false),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/peaks');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openImportDialog() async {
    await tester.tap(importFab);
    await tester.pumpAndSettle();
  }

  Future<void> chooseFile() async {
    await tester.tap(selectFileButton);
    await tester.pumpAndSettle();
  }

  Future<void> enterName(String value) async {
    await tester.enterText(nameField, value);
    await tester.pump();
  }

  Future<void> submitImport() async {
    await tester.tap(importButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }
}
