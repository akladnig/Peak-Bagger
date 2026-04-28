import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/screens/peak_lists_screen.dart';
import 'package:peak_bagger/services/peak_list_file_picker.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';

class PeakListsRobot {
  PeakListsRobot(this.tester);

  final WidgetTester tester;

  Finder get importFab => find.byKey(const Key('peak-lists-import-fab'));
  Finder get importDialog => find.byKey(const Key('peak-list-import-dialog'));
  Finder get createFab => find.byKey(const Key('peak-lists-add-list-fab'));
  Finder get createDialog => find.byKey(const Key('peak-list-create-dialog'));
  Finder get addPeakButton => find.byKey(const Key('peak-lists-add-peak'));
  Finder get addPeakDialog => find.byKey(const Key('peak-list-peak-dialog'));
  Finder get addSearchInput => find.byKey(const Key('peak-list-peak-search-input'));
  Finder get addSaveButton => find.byKey(const Key('peak-list-peak-save'));
  Finder get summaryPane => find.byKey(const Key('peak-lists-summary-pane'));
  Finder get detailsPane => find.byKey(const Key('peak-lists-details-pane'));
  Finder get selectedTitle =>
      find.byKey(const Key('peak-lists-selected-title'));
  Finder get selectFileButton => find.byKey(const Key('peak-list-select-file'));
  Finder get nameField => find.byKey(const Key('peak-list-name-field'));
  Finder get importButton => find.byKey(const Key('peak-list-import-button'));
  Finder get updateConfirm => find.byKey(const Key('peak-list-update-confirm'));
  Finder get createNameField =>
      find.byKey(const Key('peak-list-create-name-field'));
  Finder get createButton =>
      find.byKey(const Key('peak-list-create-button'));
  Finder get createCancel =>
      find.byKey(const Key('peak-list-create-cancel'));
  Finder get createErrorClose =>
      find.byKey(const Key('peak-list-create-error-close'));
  Finder deleteButtonFor(int peakListId) =>
      find.byKey(Key('peak-lists-delete-$peakListId'));
  Finder get deleteConfirm => find.byKey(const Key('confirm-delete'));
  Finder get deleteCancel => find.byKey(const Key('cancel-delete'));
  Finder get resultClose =>
      find.byKey(const Key('peak-list-import-result-close'));
  Finder get errorClose =>
      find.byKey(const Key('peak-list-import-error-close'));
  Finder addRow(int peakId) => find.byKey(Key('peak-multi-select-row-$peakId'));
  Finder addCheckbox(int peakId) =>
      find.byKey(Key('peak-multi-select-checkbox-$peakId'));
  Finder addSelectedRow(int peakId) =>
      find.byKey(Key('peak-selected-row-$peakId'));
  Finder addSelectedCheckbox(int peakId) =>
      find.byKey(Key('peak-selected-checkbox-$peakId'));
  Finder addPointsField(int peakId) =>
      find.byKey(Key('peak-selected-points-$peakId'));

  Future<void> pumpApp({
    required PeakListFilePicker filePicker,
    PeakListRepository? repository,
    PeakRepository? peakRepository,
    PeaksBaggedRepository? peaksBaggedRepository,
    PeakListImportRunner? importRunner,
    PeakListDuplicateNameChecker? duplicateNameChecker,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peakRepositoryProvider.overrideWithValue(
            peakRepository ?? PeakRepository.test(InMemoryPeakStorage()),
          ),
          peakListRepositoryProvider.overrideWithValue(
            repository ?? PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          peaksBaggedRepositoryProvider.overrideWithValue(
            peaksBaggedRepository ??
                PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
          ),
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
        child: const MaterialApp(home: PeakListsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openImportDialog() async {
    await tester.tap(importFab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openCreateDialog() async {
    await tester.tap(createFab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openAddPeakDialog() async {
    await tester.tap(addPeakButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> toggleAddPeak(int peakId) async {
    await tester.tap(addCheckbox(peakId));
    await tester.pump();
  }

  Future<void> enterAddPeakPoints(int peakId, String value) async {
    await tester.enterText(addPointsField(peakId), value);
    await tester.pump();
  }

  Future<void> submitAddPeakDialog() async {
    await tester.tap(addSaveButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> chooseFile() async {
    await tester.tap(selectFileButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> enterName(String value) async {
    await tester.enterText(nameField, value);
    await tester.pump();
  }

  Future<void> enterCreateName(String value) async {
    await tester.enterText(createNameField, value);
    await tester.pump();
  }

  Future<void> submitImport() async {
    await tester.tap(importButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> submitCreate() async {
    await tester.tap(createButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> closeResultDialog() async {
    await tester.tap(resultClose);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> deleteRow(int peakListId) async {
    tester.widget<IconButton>(deleteButtonFor(peakListId)).onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}
