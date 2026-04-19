import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';

import '../../harness/test_peak_list_file_picker.dart';
import 'peak_lists_robot.dart';

void main() {
  testWidgets('peak lists journey creates and updates via dialog flow', (
    tester,
  ) async {
    final robot = PeakListsRobot(tester);
    var importCallCount = 0;

    await robot.pumpApp(
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/peaks.csv'),
      duplicateNameChecker: (name) async => importCallCount > 0,
      importRunner:
          ({required String listName, required String csvPath}) async {
            importCallCount += 1;
            return PeakListImportPresentationResult(
              updated: importCallCount > 1,
              importedCount: 2,
              skippedCount: 1,
              warningCount: 1,
            );
          },
    );

    await robot.openImportDialog();
    await robot.chooseFile();
    await robot.enterName('Abels');
    await robot.submitImport();

    expect(find.text('Peak List Created'), findsOneWidget);
    expect(find.text('2 Peaks imported'), findsOneWidget);
    expect(find.text('1 peaks skipped'), findsOneWidget);
    expect(find.textContaining('warnings. See import.log'), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-list-import-result-close')));
    await tester.pumpAndSettle();

    await robot.openImportDialog();
    await robot.chooseFile();
    await robot.enterName('Abels');
    await robot.submitImport();

    expect(
      find.text(
        'This list already exists - do you want to update the existing list?',
      ),
      findsOneWidget,
    );

    await tester.tap(robot.updateConfirm);
    await tester.pumpAndSettle();

    expect(find.text('Peak List Updated'), findsOneWidget);
  });
}
