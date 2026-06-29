import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/widgets/dialog_helpers.dart';

void main() {
  testWidgets('export conflict dialog keeps stable secondary and primary actions', (
    tester,
  ) async {
    late Future<ExportConflictAction> resultFuture;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                resultFuture = showExportConflictDialog(
                  context: context,
                  title: 'Conflict',
                  message: 'Choose an action.',
                  cancelKey: 'cancel',
                  overwriteKey: 'overwrite',
                  newVersionKey: 'new-version',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('overwrite')), findsOneWidget);
    expect(find.byKey(const Key('new-version')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('overwrite'))),
      isA<FilledButton>(),
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('new-version'))),
      isA<OutlinedButton>(),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(await resultFuture, ExportConflictAction.cancel);
  });

  testWidgets('single action dialog dismisses on ctrl+c', (tester) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                opened = true;
                showSingleActionDialog(
                  context: context,
                  title: 'Done',
                  closeKey: 'close-dialog',
                  content: const Text('Body'),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(find.text('Done'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('Done'), findsNothing);
  });
}
