import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_details.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/objectbox_admin_read_only_value.dart';

const _lines = 'first\nsecond\nthird\nfourth\nfifth\nsixth\nSENTINEL';
final _paragraph =
    '${List.filled(80, 'wrapping paragraph').join(' ')} SENTINEL';

String? _clipboard;

void main() {
  setUp(() {
    _clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            _clipboard = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': _clipboard};
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  for (final scale in [1.0, 2.0]) {
    _macTestWidgets(
      'measures short, empty, wrapped and newline values at $scale×',
      (tester) async {
        for (final text in ['', 'Short', 'one\ntwo', _paragraph, _lines]) {
          await _pump(tester, text: text, scale: scale);
          final paragraph = _renderedText(tester, text);
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: text.length),
            boxHeightStyle: ui.BoxHeightStyle.strut,
          );
          final lineTops = boxes.map((box) => box.top).toSet().toList()..sort();
          final viewport = _scroll(tester).position;
          if (lineTops.length > 5) {
            // Measure the real rendered paragraph, not a maxLines widget property.
            expect(viewport.viewportDimension, closeTo(lineTops[5], .1));
            expect(viewport.maxScrollExtent, greaterThan(0));
          } else {
            expect(
              viewport.viewportDimension,
              closeTo(paragraph.size.height, .1),
            );
            expect(viewport.maxScrollExtent, 0);
          }
          expect(find.byType(TextField), findsNothing);
          expect(find.byType(TextFormField), findsNothing);
          expect(tester.takeException(), isNull);
        }
      },
    );

    for (final text in [_lines, _paragraph]) {
      _macTestWidgets(
        'scroll/select/copy previously offscreen content at $scale× '
        '${text == _lines ? 'newlines' : 'wrapped'}',
        (tester) async {
          await _pump(tester, text: text, scale: scale);
          final scroll = _scroll(tester);
          final paragraph = _renderedText(tester, text);
          final sentinelBox = paragraph
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: text.indexOf('SENTINEL'),
                  extentOffset: text.length,
                ),
              )
              .last;
          final viewport = find.byType(SingleChildScrollView);
          final initialBounds = tester.getRect(viewport);
          expect(
            paragraph.localToGlobal(sentinelBox.toRect().center).dy,
            greaterThan(initialBounds.bottom),
          );
          await tester.drag(viewport, const Offset(0, -10000));
          await tester.pumpAndSettle();
          expect(scroll.position.pixels, scroll.position.maxScrollExtent);
          final point = paragraph.localToGlobal(sentinelBox.toRect().center);
          expect(tester.getRect(viewport).contains(point), isTrue);

          // Native-style mouse double click selects the word that was offscreen.
          await tester.tapAt(point, kind: PointerDeviceKind.mouse);
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tapAt(point, kind: PointerDeviceKind.mouse);
          await tester.pumpAndSettle();
          await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
          await tester.pump();
          expect(_clipboard, 'SENTINEL');
          // Typing/delete/paste must never mutate read-only content.
          await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
          await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
          await tester.pump();
          expect(find.text(text), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  _macTestWidgets('labelled non-editable semantics and text cursor/focus', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, text: _lines);
    final value = find.byType(ObjectBoxAdminReadOnlyValue);
    final data = tester.getSemantics(value).getSemanticsData();
    expect(data.label, contains('Notes'));
    void checkNode(SemanticsNode node) {
      final data = node.getSemanticsData();
      expect(data.hasAction(ui.SemanticsAction.setText), isFalse);
      expect(data.hasAction(ui.SemanticsAction.cut), isFalse);
      expect(data.hasAction(ui.SemanticsAction.paste), isFalse);
      expect(data.flagsCollection.isTextField, isFalse);
      node.visitChildren((child) {
        checkNode(child);
        return true;
      });
    }

    checkNode(tester.getSemantics(value));
    expect(
      tester
          .widgetList<MouseRegion>(
            find.descendant(of: value, matching: find.byType(MouseRegion)),
          )
          .any((region) => region.cursor == SystemMouseCursors.text),
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final selection = tester.widget<SelectionArea>(find.byType(SelectionArea));
    expect(selection.focusNode!.hasFocus, isTrue);
    final decoration = tester
        .widgetList<DecoratedBox>(
          find.descendant(of: value, matching: find.byType(DecoratedBox)),
        )
        .firstWhere((box) => (box.decoration as BoxDecoration).border != null);
    expect((decoration.decoration as BoxDecoration).border!.top.width, 2);
    handle.dispose();
  });

  _macTestWidgets(
    'active line metrics and wrapping width recalculate the cap',
    (tester) async {
      const text =
          'A complete descriptive value that wraps at a narrow width but '
          'uses only its needed height when the available width increases.';
      final theme = MyTheme.dark;
      final tallTheme = theme.copyWith(
        textTheme: theme.textTheme.copyWith(
          bodyMedium: theme.textTheme.bodyMedium!.copyWith(
            fontSize: 18,
            height: 2.4,
          ),
        ),
      );
      for (final active in [theme, tallTheme]) {
        await _pump(tester, text: text, theme: active, width: 180);
        final paragraph = _renderedText(tester, text);
        final boxes = paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: text.length),
          boxHeightStyle: ui.BoxHeightStyle.strut,
        );
        final tops = boxes.map((box) => box.top).toSet().toList()..sort();
        expect(
          _scroll(tester).position.viewportDimension,
          closeTo(tops[5], .5),
        );
        final narrowHeight = _scroll(tester).position.viewportDimension;
        await _pump(tester, text: text, theme: active, width: 780);
        expect(_scroll(tester).position.maxScrollExtent, 0);
        expect(
          _scroll(tester).position.viewportDimension,
          lessThan(narrowHeight),
        );
        expect(find.text(text), findsOneWidget);
      }
    },
  );

  _macTestWidgets(
    'resize/theme/scale retain selection; record changes dispose state',
    (tester) async {
      await _pump(tester, text: _lines);
      final oldScroll = _scroll(tester);
      final oldFocus = tester
          .widget<SelectionArea>(find.byType(SelectionArea))
          .focusNode!;
      await tester.tapAt(
        tester.getTopLeft(find.text(_lines)) + const Offset(8, 8),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(
        tester.getTopLeft(find.text(_lines)) + const Offset(8, 8),
      );
      await tester.pumpAndSettle();
      for (final theme in [MyTheme.dark]) {
        await _pump(tester, text: _lines, theme: theme, width: 500, scale: 2);
        expect(_scroll(tester), same(oldScroll));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pump();
        expect(_clipboard, 'first');
      }
      await _pump(tester, text: _lines, recordId: 2);
      expect(oldScroll.mounted, isFalse);
      expect(() => oldFocus.addListener(() {}), throwsFlutterError);
      expect(_scroll(tester).position.pixels, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  _macTestWidgets('formatting/boolean semantics stay display-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              objectBoxAdminDetailsValue(label: 'Verified', value: true),
              objectBoxAdminDetailsValue(label: 'Empty', value: null),
              objectBoxAdminDetailsValue(
                entityName: 'Peak',
                fieldName: 'latitude',
                label: 'Latitude',
                value: 46.12345678,
              ),
              objectBoxAdminDetailsValue(
                entityName: 'Route',
                fieldName: 'colour',
                label: 'Colour',
                value: 0xff123456,
              ),
              objectBoxAdminDetailsValue(
                entityName: 'GpxTrack',
                fieldName: 'trackDate',
                label: 'Track date',
                value: DateTime.utc(2026, 10, 20),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('46.123457'), findsOneWidget);
    expect(find.text('0xFF123456'), findsOneWidget);
    expect(find.text('2026-10-20T00:00:00.000Z'), findsOneWidget);
  });
}

void _macTestWidgets(String description, WidgetTesterCallback callback) =>
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

RenderParagraph _renderedText(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(text), matching: find.byType(RichText)),
    );

ScrollableState _scroll(WidgetTester tester) => tester.state<ScrollableState>(
  find.descendant(
    of: find.byType(SingleChildScrollView),
    matching: find.byType(Scrollable),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required String text,
  double scale = 1,
  double width = 300,
  ThemeData? theme,
  int recordId = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? MyTheme.dark,
      themeAnimationDuration: Duration.zero,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: objectBoxAdminDetailsValue(
                recordId: recordId,
                entityName: 'AnyEntity',
                fieldName: 'anyField',
                label: 'Notes',
                value: text,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
