import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/theme.dart';

import '../harness/admin_form_fixture.dart';

void main() {
  for (final name in AdminFormFixture.names) {
    testWidgets('$name Cancel restores same committed record without writing', (
      tester,
    ) async {
      final fixture = AdminFormFixture(name);
      await _pump(tester, fixture);
      await _edit(tester, fixture);
      await tester.enterText(_field(fixture), _draft(fixture));
      // Admin has no Escape/Ctrl+C dismissal binding; don't introduce one.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(find.byKey(Key(fixture.formKey)), findsOneWidget);
      expect(_controller(tester, fixture).text, _draft(fixture));
      await tester.tap(_cancel(fixture));
      await tester.pumpAndSettle();
      expect(find.byKey(Key(fixture.formKey)), findsNothing);
      expect(find.byKey(Key(fixture.editKey)), findsOneWidget);
      expect(fixture.closes, 0);
      expect(fixture.submitted, isEmpty);
      await _edit(tester, fixture);
      expect(_controller(tester, fixture).text, _committed(fixture));
    });

    testWidgets(
      '$name Save guards stale callbacks before/after rebuild; failure permits Cancel/retry',
      (tester) async {
        final pending = Completer<String?>();
        final fixture = AdminFormFixture(name)..save = () => pending.future;
        await _pump(tester, fixture);
        await _edit(tester, fixture);
        await tester.enterText(_field(fixture), _draft(fixture));
        final controller = _controller(tester, fixture);
        final save = tester.widget<FilledButton>(_save(fixture)).onPressed!;
        final cancel = tester.widget<FilledButton>(_cancel(fixture)).onPressed!;
        final close = tester
            .widget<IconButton>(
              find.byKey(const Key('objectbox-admin-details-close')),
            )
            .onPressed!;
        save();
        save();
        cancel();
        close();
        expect(fixture.submitted, hasLength(1));
        expect(fixture.closes, 0);
        expect(controller.text, _draft(fixture));
        await tester.pump();
        expect(tester.widget<FilledButton>(_cancel(fixture)).onPressed, isNull);
        expect(tester.widget<FilledButton>(_save(fixture)).onPressed, isNull);
        expect(find.text('Saving...'), findsOneWidget);
        save();
        cancel();
        close();
        expect(fixture.submitted, hasLength(1));
        expect(fixture.closes, 0);
        pending.complete('Could not save. Retry.');
        await tester.pumpAndSettle();
        expect(_controller(tester, fixture), same(controller));
        expect(controller.text, _draft(fixture));
        expect(find.text('Could not save. Retry.'), findsOneWidget);
        expect(fixture.closes, 0); // no queued cancellation/dismissal
        await tester.tap(_cancel(fixture));
        await tester.pumpAndSettle();
        await _edit(tester, fixture);
        expect(_controller(tester, fixture).text, _committed(fixture));
        await tester.enterText(_field(fixture), _draft(fixture));
        fixture.save = () async => null;
        await tester.tap(_save(fixture));
        await tester.pumpAndSettle();
        expect(fixture.submitted, hasLength(2));
        expect(find.byKey(Key(fixture.formKey)), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        cancel();
        close();
        save();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$name thrown Save retains input and unlocks cancellation', (
      tester,
    ) async {
      final fixture = AdminFormFixture(name)
        ..save = () async => throw StateError('controlled');
      await _pump(tester, fixture);
      await _edit(tester, fixture);
      await tester.enterText(_field(fixture), _draft(fixture));
      await tester.tap(_save(fixture));
      await tester.pumpAndSettle();
      expect(_controller(tester, fixture).text, _draft(fixture));
      expect(
        find.text('Could not save. Please retry or cancel.'),
        findsOneWidget,
      );
      await tester.tap(_cancel(fixture));
      await tester.pumpAndSettle();
      expect(find.byKey(Key(fixture.editKey)), findsOneWidget);
    });

    testWidgets(
      '$name footer order/theme/focus/copy and resize retain one draft',
      (tester) async {
        final fixture = AdminFormFixture(name);
        String? clipboard;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await _pump(tester, fixture);
        await _edit(tester, fixture);
        await tester.enterText(_field(fixture), _draft(fixture));
        final controller = _controller(tester, fixture);
        for (final theme in [MyTheme.dark]) {
          for (final scale in [1.0, 2.0]) {
            for (final size in [
              const Size(1280, 960),
              const Size(1600, 960),
              const Size(1920, 1200),
              const Size(1280, 960),
            ]) {
              await _pump(
                tester,
                fixture,
                theme: theme,
                scale: scale,
                size: size,
              );
              final cancel = tester.widget<FilledButton>(_cancel(fixture));
              final save = tester.widget<FilledButton>(_save(fixture));
              expect(
                find.descendant(
                  of: _cancel(fixture),
                  matching: find.text('Cancel'),
                ),
                findsOneWidget,
              );
              expect(
                find.descendant(
                  of: _save(fixture),
                  matching: find.text('Save'),
                ),
                findsOneWidget,
              );
              final buttons = find
                  .byType(FilledButton)
                  .evaluate()
                  .map((e) => e.widget)
                  .toList();
              expect(buttons.indexOf(cancel), lessThan(buttons.indexOf(save)));
              final style = FilledButtonTheme.of(
                tester.element(_save(fixture)),
              ).style!;
              expect(
                style.backgroundColor!.resolve({}),
                theme.colorScheme.primaryContainer,
              );
              expect(
                style.foregroundColor!.resolve({}),
                theme.colorScheme.onPrimaryContainer,
              );
              expect(_cancel(fixture).hitTestable(), findsOneWidget);
              expect(_save(fixture).hitTestable(), findsOneWidget);
              expect(_controller(tester, fixture), same(controller));
              expect(controller.text, _draft(fixture));
              expect(fixture.submitted, isEmpty);
              expect(tester.takeException(), isNull);
            }
          }
        }
        await tester.tap(_field(fixture));
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pumpAndSettle();
        expect(clipboard, _draft(fixture));
        expect(controller.text, _draft(fixture));
        expect(find.byKey(Key(fixture.formKey)), findsOneWidget);
        final semantics = tester.ensureSemantics();
        expect(tester.getSemantics(_cancel(fixture)).label, contains('Cancel'));
        expect(tester.getSemantics(_save(fixture)).label, contains('Save'));
        semantics.dispose();
        await tester.tap(_cancel(fixture));
        await tester.pumpAndSettle();
        expect(fixture.submitted, isEmpty);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }
}

Finder _field(AdminFormFixture f) => find.byKey(
  Key(
    'objectbox-admin-${f.prefix}-${f.name == 'PeakList'
        ? 'colour'
        : f.name == 'Contact'
        ? 'first-name'
        : 'name'}',
  ),
);
Finder _cancel(AdminFormFixture f) =>
    find.byKey(Key('objectbox-admin-${f.prefix}-cancel'));
Finder _save(AdminFormFixture f) => find.byKey(Key(f.saveKey));
String _draft(AdminFormFixture f) =>
    f.name == 'PeakList' ? '0xFFABCDEF' : 'Unsaved draft';
String _committed(AdminFormFixture f) =>
    f.name == 'PeakList' ? '0x00000000' : 'Fixture';
TextEditingController _controller(WidgetTester tester, AdminFormFixture f) =>
    tester.widget<TextFormField>(_field(f)).controller!;
Future<void> _edit(WidgetTester tester, AdminFormFixture f) async {
  await tester.tap(find.byKey(Key(f.editKey)));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  AdminFormFixture f, {
  ThemeData? theme,
  double scale = 1,
  Size size = const Size(1280, 960),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? MyTheme.dark,
      themeAnimationDuration: Duration.zero,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(width: size.width / 3, child: f.pane()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
