import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';

import '../harness/test_peak_list_file_picker.dart';

Finder key(String value) => find.byKey(Key(value));

Future<GlobalKey<NavigatorState>> open(
  WidgetTester tester, {
  required PeakListDuplicateNameChecker check,
  required PeakListImportStarter start,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 960));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      theme: MyTheme.dark,
      navigatorKey: navigator,
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => showPeakListImportDialog(
              context: context,
              filePicker: TestPeakListFilePicker(
                selectedFilePath: '/fixture/peaks.csv',
              ),
              duplicateNameChecker: check,
              onImport: start,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await tester.tap(key('peak-list-select-file'));
  await tester.pumpAndSettle();
  await tester.enterText(key('peak-list-name-field'), 'Retained list');
  return navigator;
}

void main() {
  testWidgets(
    'owner removal during duplicate checking never starts work or updates disposed UI',
    (tester) async {
      final duplicate = Completer<bool>();
      var starts = 0;
      await open(
        tester,
        check: (_) => duplicate.future,
        start: ({required listName, required csvPath}) async {
          starts++;
          return true;
        },
      );
      await tester.tap(key('peak-list-import-button'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      duplicate.complete(false);
      await tester.pump();
      expect(starts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'early gate rejects stale submit/cancel and every parent dismissal; failure retries retained input',
    (tester) async {
      final duplicate = Completer<bool>();
      var checks = 0;
      var starts = 0;
      final navigator = await open(
        tester,
        check: (_) {
          checks++;
          return checks == 1 ? duplicate.future : Future.value(false);
        },
        start: ({required listName, required csvPath}) async {
          starts++;
          expect(listName, 'Retained list');
          expect(csvPath, '/fixture/peaks.csv');
          return true;
        },
      );
      final submit = tester
          .widget<FilledButton>(key('peak-list-import-button'))
          .onPressed!;
      final cancel = tester
          .widget<FilledButton>(key('peak-list-import-cancel'))
          .onPressed!;
      submit();
      submit();
      cancel();
      navigator.currentState!.pop();
      await navigator.currentState!.maybePop();
      await tester.pump();
      expect(checks, 1);
      expect(starts, 0);
      expect(key('peak-list-import-dialog'), findsOneWidget);
      expect(
        tester.widget<TextField>(key('peak-list-name-field')).enabled,
        false,
      );
      await tester.tapAt(const Offset(4, 4));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(key('peak-list-import-dialog'), findsOneWidget);
      duplicate.completeError(StateError('private payload must not be shown'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Try Import again'), findsOneWidget);
      expect(find.textContaining('private payload'), findsNothing);
      expect(
        tester.widget<TextField>(key('peak-list-name-field')).controller!.text,
        'Retained list',
      );
      expect(find.text('/fixture/peaks.csv'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(key('peak-list-import-cancel')).onPressed,
        isNotNull,
      );
      await tester.tap(key('peak-list-import-button'));
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(key('peak-list-import-dialog'), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    },
  );

  testWidgets(
    'duplicate child can cancel, dismiss and confirm while parent stays locked',
    (tester) async {
      var starts = 0;
      final handoff = Completer<bool>();
      await open(
        tester,
        check: (_) async => true,
        start: ({required listName, required csvPath}) {
          starts++;
          return handoff.future;
        },
      );
      for (final escape in [false, true]) {
        await tester.tap(key('peak-list-import-button'));
        await tester.pumpAndSettle();
        expect(key('peak-list-update-confirm'), findsOneWidget);
        if (escape) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.tap(key('peak-list-update-cancel'));
        }
        await tester.pumpAndSettle();
        expect(starts, 0);
        expect(key('peak-list-import-dialog'), findsOneWidget);
      }
      await tester.tap(key('peak-list-import-button'));
      await tester.pumpAndSettle();
      await tester.tap(key('peak-list-update-confirm'));
      await tester.pump();
      expect(starts, 1);
      handoff.completeError(StateError('failed preparation'));
      await tester.pumpAndSettle();
      expect(key('peak-list-import-dialog'), findsOneWidget);
      expect(find.textContaining('Try Import again'), findsOneWidget);
      await tester.tap(key('peak-list-import-cancel'));
      await tester.pumpAndSettle();
      expect(key('peak-list-import-dialog'), findsNothing);
    },
  );

  testWidgets(
    'rejected handoff retains form and idle outside dismissal discards without work',
    (tester) async {
      await open(
        tester,
        check: (_) async => false,
        start: ({required listName, required csvPath}) async => false,
      );
      await tester.tap(key('peak-list-import-button'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Check Background Jobs'), findsOneWidget);
      expect(key('peak-list-import-dialog'), findsOneWidget);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(key('peak-list-import-dialog'), findsNothing);
    },
  );
}
