import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/objectbox_admin_read_only_value.dart';

import '../harness/admin_detail_value_fixture.dart';

final _text =
    '${List.filled(40, 'Long wrapped detail value').join(' ')} SENTINEL';

void main() {
  for (final entity in AdminDetailValueFixture.entities) {
    testWidgets(
      '$entity details measure/scroll independently and retain identity',
      (tester) async {
        final fixture = AdminDetailValueFixture(entity, _text);
        for (final scale in [1.0, 2.0]) {
          await _pump(tester, fixture, scale: scale);
          final outer = find
              .descendant(
                of: find.byKey(const Key('objectbox-admin-details-list')),
                matching: find.byType(Scrollable),
              )
              .first;
          final value = find.byWidgetPredicate(
            (widget) =>
                widget is ObjectBoxAdminReadOnlyValue &&
                widget.label == fixture.longField,
          );
          await tester.scrollUntilVisible(value, 100, scrollable: outer);
          await tester.pumpAndSettle();
          await tester.ensureVisible(value);
          await tester.pumpAndSettle();
          final scroll = tester.state<ScrollableState>(
            find.descendant(of: value, matching: find.byType(Scrollable)),
          );
          final outerScroll = tester.state<ScrollableState>(outer);
          final before = outerScroll.position.pixels;
          final richText = find.descendant(
            of: value,
            matching: find.byType(RichText),
          );
          final paragraph = tester.renderObject<RenderParagraph>(richText);
          final lineTops =
              paragraph
                  .getBoxesForSelection(
                    TextSelection(baseOffset: 0, extentOffset: _text.length),
                    boxHeightStyle: ui.BoxHeightStyle.strut,
                  )
                  .map((box) => box.top)
                  .toSet()
                  .toList()
                ..sort();
          expect(scroll.position.viewportDimension, closeTo(lineTops[5], .1));
          await tester.drag(value, const Offset(0, -10000));
          await tester.pumpAndSettle();
          expect(scroll.position.pixels, scroll.position.maxScrollExtent);
          expect(outerScroll.position.pixels, before);
          final sentinel = paragraph
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: _text.indexOf('SENTINEL'),
                  extentOffset: _text.length,
                ),
              )
              .last;
          final point = paragraph.localToGlobal(sentinel.toRect().center);
          expect(tester.getRect(value).contains(point), isTrue);
          expect(fixture.writes, 0);
          expect(fixture.closes, 0);
          expect(
            find
                .byKey(const Key('objectbox-admin-details-close'))
                .hitTestable(),
            findsOneWidget,
          );
          expect(find.byType(TextField), findsNothing);
          expect(tester.takeException(), isNull);
        }
        final replacement = AdminDetailValueFixture(
          entity,
          'Another record',
          id: 2,
        );
        final oldSelections = tester
            .widgetList<SelectionArea>(find.byType(SelectionArea))
            .map((area) => area.focusNode!)
            .toList();
        await _pump(tester, replacement);
        for (final focus in oldSelections) {
          expect(() => focus.addListener(() {}), throwsFlutterError);
        }
        expect(find.text(_text), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('supported sizes/themes/scales rewrap; draft survives resizing', (
    tester,
  ) async {
    final fixture = AdminDetailValueFixture('Route', _text);
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
            size: size,
            theme: theme,
            scale: scale,
            paneWidth: size.width / 3,
          );
          expect(find.byType(ObjectBoxAdminReadOnlyValue), findsWidgets);
          final value = find.byWidgetPredicate(
            (widget) =>
                widget is ObjectBoxAdminReadOnlyValue && widget.label == 'desc',
          );
          final outer = find
              .descendant(
                of: find.byKey(const Key('objectbox-admin-details-list')),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(value, 100, scrollable: outer);
          await tester.pumpAndSettle();
          await tester.ensureVisible(value);
          await tester.pumpAndSettle();
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: value, matching: find.byType(RichText)),
          );
          final tops =
              paragraph
                  .getBoxesForSelection(
                    TextSelection(baseOffset: 0, extentOffset: _text.length),
                    boxHeightStyle: ui.BoxHeightStyle.strut,
                  )
                  .map((box) => box.top)
                  .toSet()
                  .toList()
                ..sort();
          final inner = tester.state<ScrollableState>(
            find.descendant(of: value, matching: find.byType(Scrollable)),
          );
          expect(inner.position.viewportDimension, closeTo(tops[5], .1));
          expect(
            find
                .byKey(const Key('objectbox-admin-details-close'))
                .hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('objectbox-admin-route-edit')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      }
    }
    await tester.tap(find.byKey(const Key('objectbox-admin-route-edit')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('objectbox-admin-route-name'));
    await tester.enterText(field, 'Unsaved draft');
    final controller = tester.widget<TextFormField>(field).controller!;
    controller.selection = const TextSelection(baseOffset: 2, extentOffset: 6);
    for (final size in [
      const Size(1600, 960),
      const Size(1920, 1200),
      const Size(1280, 960),
    ]) {
      await _pump(tester, fixture, size: size, paneWidth: size.width / 3);
      expect(tester.widget<TextFormField>(field).controller, same(controller));
      expect(controller.text, 'Unsaved draft');
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 6),
      );
      expect(fixture.route.name, 'Fixture');
      expect(fixture.writes, 0);
      expect(
        find.byKey(const Key('objectbox-admin-route-save')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  AdminDetailValueFixture fixture, {
  Size size = const Size(1280, 960),
  double scale = 1,
  ThemeData? theme,
  double paneWidth = 320,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? MyTheme.dark,
      themeAnimationDuration: Duration.zero,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Center(child: Text('Data table fixture'))),
              SizedBox(width: paneWidth, child: fixture.pane()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
