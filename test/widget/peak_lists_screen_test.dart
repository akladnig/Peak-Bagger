import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/screens/peak_lists_screen.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';
import 'package:peak_bagger/services/peak_list_file_picker.dart';

import '../harness/test_peak_list_file_picker.dart';

void main() {
  testWidgets('import fab opens dialog and cancel closes it', (tester) async {
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-import-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-list-import-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-import-dialog')), findsNothing);
  });

  testWidgets('import stays disabled until a file is selected', (tester) async {
    await _pumpPeakListsApp(tester, filePicker: TestPeakListFilePicker());

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();

    var importButton = tester.widget<FilledButton>(
      find.byKey(const Key('peak-list-import-button')),
    );
    expect(importButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();

    importButton = tester.widget<FilledButton>(
      find.byKey(const Key('peak-list-import-button')),
    );
    expect(importButton.onPressed, isNull);
  });

  testWidgets(
    'selecting a file enables import and empty name shows validation',
    (tester) async {
      await _pumpPeakListsApp(
        tester,
        filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
      );

      await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('peak-list-select-file')));
      await tester.pumpAndSettle();

      final importButton = tester.widget<FilledButton>(
        find.byKey(const Key('peak-list-import-button')),
      );
      expect(importButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('peak-list-import-button')));
      await tester.pumpAndSettle();

      expect(find.text('A list name is required'), findsOneWidget);
    },
  );

  testWidgets('file picker cancel is a no-op', (tester) async {
    final filePicker = TestPeakListFilePicker(selectedFilePath: null);
    await _pumpPeakListsApp(tester, filePicker: filePicker);

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();

    expect(filePicker.pickCallCount, 1);
    expect(find.text('No file selected'), findsOneWidget);
  });

  testWidgets('duplicate name confirm path updates and shows result dialog', (
    tester,
  ) async {
    var importCallCount = 0;
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
      duplicateNameChecker: (name) async => true,
      importRunner:
          ({required String listName, required String csvPath}) async {
            importCallCount += 1;
            return const PeakListImportPresentationResult(
              updated: true,
              importedCount: 3,
              skippedCount: 1,
            );
          },
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-name-field')),
      'Abels',
    );
    await tester.tap(find.byKey(const Key('peak-list-import-button')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This list already exists - do you want to update the existing list?',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('peak-list-update-confirm')));
    await tester.pumpAndSettle();

    expect(importCallCount, 1);
    expect(find.text('Peak List Updated'), findsOneWidget);
    expect(find.text('3 Peaks imported'), findsOneWidget);
    expect(find.text('1 peaks skipped'), findsOneWidget);
  });

  testWidgets('loading state disables import and failure uses modal pattern', (
    tester,
  ) async {
    final completer = Completer<PeakListImportPresentationResult>();
    await _pumpPeakListsApp(
      tester,
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/test.csv'),
      importRunner: ({required String listName, required String csvPath}) {
        return completer.future;
      },
    );

    await tester.tap(find.byKey(const Key('peak-lists-import-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-select-file')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('peak-list-name-field')),
      'Abels',
    );
    await tester.tap(find.byKey(const Key('peak-list-import-button')));
    await tester.pump();

    final importButton = tester.widget<FilledButton>(
      find.byKey(const Key('peak-list-import-button')),
    );
    expect(importButton.onPressed, isNull);
    expect(find.byKey(const Key('peak-list-import-progress')), findsOneWidget);

    completer.completeError(StateError('boom'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Peak List Import Failed'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(
      find.byKey(const Key('peak-list-import-error-close')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpPeakListsApp(
  WidgetTester tester, {
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
