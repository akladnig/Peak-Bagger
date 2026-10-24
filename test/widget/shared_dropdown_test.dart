import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/objectbox_admin_form_field.dart';
import 'package:peak_bagger/widgets/shared_dropdown.dart';
import 'package:peak_bagger/widgets/shared_field_decoration.dart';

import '../harness/shared_dropdown_fixture.dart';

final _menu = find.byKey(const Key('shared-dropdown-menu'));
final _dropdown = find.byKey(const Key('fixture-dropdown'));

Future<SharedDropdownFixtureState> _pump(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 960));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final key = GlobalKey<SharedDropdownFixtureState>();
  await tester.pumpWidget(SharedDropdownFixture(key: key));
  await tester.pumpAndSettle();
  return key.currentState!;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_dropdown);
  await tester.pumpAndSettle();
  expect(_menu, findsOneWidget);
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'open menu cleans up on resize, route obscuring and removed anchor; drafts survive',
    (tester) async {
      final state = await _pump(tester);
      await _open(tester);
      await tester.binding.setSurfaceSize(const Size(1920, 1200));
      state.update(() => state.size = const Size(1920, 1200));
      await tester.pumpAndSettle();
      expect(state.selected, 'a');
      expect(state.draft.text, 'Unsaved draft');
      // RawMenuAnchor may close on metrics changes; neither closure nor reopening commits.
      if (!state.menu.isOpen) await _open(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final route = MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other route')),
      );
      navigator.push(route);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shared-dropdown-menu')), findsNothing);
      expect(state.selections, 0);
      navigator.pop();
      await tester.pumpAndSettle();
      await _open(tester);
      state.update(() => state.choices = const []);
      await tester.pumpAndSettle();
      expect(_menu, findsNothing);
      state.focus.requestFocus();
      await tester.pumpAndSettle();
      expect(state.focus.hasFocus, isTrue); // validation focus, not selection
      await _key(tester, LogicalKeyboardKey.enter);
      expect(_menu, findsNothing);
      state.update(() => state.enabled = false);
      await tester.pumpAndSettle();
      state.focus.requestFocus();
      await tester.pumpAndSettle();
      expect(state.focus.hasFocus, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final trigger in SharedDropdownTrigger.values) {
    for (final rows in SharedDropdownRows.values) {
      testWidgets(
        '$trigger / $rows: independent variants, navigation and no-op Enter',
        (tester) async {
          final state = await _pump(tester);
          state.update(() {
            state.trigger = trigger;
            state.rows = rows;
          });
          await tester.pumpAndSettle();
          await _open(tester);
          expect(state.focus.hasFocus, isFalse);
          expect(
            FocusManager.instance.primaryFocus!.debugLabel,
            'Dropdown menu',
          );
          expect(find.byIcon(Icons.check), findsOneWidget);
          expect(
            find.descendant(of: _menu, matching: find.byIcon(Icons.show_chart)),
            rows == SharedDropdownRows.iconAndLabel
                ? findsOneWidget
                : findsNothing,
          );
          expect(
            find.descendant(of: _dropdown, matching: find.byType(Tooltip)),
            trigger == SharedDropdownTrigger.iconOnly
                ? findsOneWidget
                : findsNothing,
          );
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.moveTo(
            tester.getCenter(find.byKey(const Key('choice-c'))),
          );
          await tester.pumpAndSettle();
          await _key(tester, LogicalKeyboardKey.enter);
          expect(_menu, findsNothing);
          expect(state.selections, 0);
          expect(state.closeReasons.last, SharedDropdownCloseReason.unchanged);
          expect(state.focus.hasFocus, isTrue);
          await mouse.moveTo(const Offset(1100, 800));
          await mouse.removePointer();

          await _open(tester);
          await _key(tester, LogicalKeyboardKey.keyJ); // skips disabled Beta
          expect(state.selected, 'a');
          expect(state.selections, 0);
          await _key(tester, LogicalKeyboardKey.enter);
          expect(state.selected, 'c');
          expect(state.selections, 1);
          expect(state.closeReasons.last, SharedDropdownCloseReason.selected);
          await _open(tester);
          await _key(
            tester,
            LogicalKeyboardKey.arrowDown,
          ); // wraps to nullable Any
          await _key(tester, LogicalKeyboardKey.enter);
          expect(state.selected, isNull);
          await _open(tester);
          await _key(tester, LogicalKeyboardKey.keyK); // wraps back
          await _key(tester, LogicalKeyboardKey.enter);
          expect(state.selected, 'c');
          await _open(tester);
          await tester.tap(find.byKey(const Key('choice-any')));
          await tester.pumpAndSettle();
          expect(state.selected, isNull);
          expect(state.draft.text, 'Unsaved draft');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final selected in <String?>['a', null, 'b', 'missing']) {
    testWidgets('immediate Enter never selects: committed=$selected', (
      tester,
    ) async {
      final state = await _pump(tester);
      state.update(() {
        state.selected = selected;
        state.hint = 'Choose a complete longer retained hint';
      });
      await tester.pumpAndSettle();
      final hintedWidth = tester.getSize(_dropdown).width;
      await _open(tester);
      await _key(tester, LogicalKeyboardKey.enter);
      expect(state.selections, 0);
      expect(state.selected, selected);
      if (selected == 'b' || selected == 'missing') {
        await _open(tester);
        await _key(tester, LogicalKeyboardKey.arrowDown);
        await _key(tester, LogicalKeyboardKey.enter);
        expect(state.selected, isNull);
        expect(tester.getSize(_dropdown).width, hintedWidth);
      }
      state.update(
        () => state.choices = const [
          SharedDropdownChoice(
            value: 'b',
            label: 'Unavailable',
            enabled: false,
          ),
        ],
      );
      await tester.pumpAndSettle();
      state.menu.open();
      await tester.pumpAndSettle();
      await _key(tester, LogicalKeyboardKey.arrowDown);
      final calls = state.selections;
      await _key(tester, LogicalKeyboardKey.enter);
      expect(state.selections, calls);
      expect(_menu, findsNothing);
    });
  }

  testWidgets(
    'outside gesture consumed; Escape/Ctrl+C/back isolate dismissal and return focus',
    (tester) async {
      final state = await _pump(tester);
      await _open(tester);
      await tester.tap(find.byKey(const Key('outside-action')));
      await tester.pumpAndSettle();
      expect(state.outsideActions, 0);
      expect(_menu, findsNothing);
      await tester.tap(find.byKey(const Key('outside-action')));
      expect(state.outsideActions, 1);
      for (final dismissal in ['escape', 'control-c', 'back']) {
        await _open(tester);
        final keys = state.backgroundKeys;
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await _key(tester, LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        expect(state.backgroundKeys, keys);
        expect(_menu, findsOneWidget);
        if (dismissal == 'escape') {
          await _key(tester, LogicalKeyboardKey.escape);
        } else if (dismissal == 'control-c') {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await _key(tester, LogicalKeyboardKey.keyC);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        } else {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        expect(_menu, findsNothing);
        expect(state.selections, 0);
        expect(state.focus.hasFocus, isTrue);
        expect(find.byType(Scaffold), findsOneWidget);
      }
      await _open(tester);
      await _key(tester, LogicalKeyboardKey.tab);
      expect(state.closeReasons.last, SharedDropdownCloseReason.tabForward);
      await _open(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await _key(tester, LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(state.closeReasons.last, SharedDropdownCloseReason.tabBackward);
    },
  );

  testWidgets(
    'current lock rejects captured activation/commit before rebuild, without replay or forced focus',
    (tester) async {
      final state = await _pump(tester);
      await _open(tester);
      final tap = tester
          .widget<GestureDetector>(
            find.descendant(
              of: find.byKey(const Key('choice-c')),
              matching: find.byType(GestureDetector),
            ),
          )
          .onTap!;
      state.allowed = false; // deliberately no rebuild
      tap();
      await tester.pumpAndSettle();
      expect(state.selections, 0);
      expect(state.focus.hasFocus, isFalse);
      expect(_menu, findsNothing);
      state.update(() => state.allowed = true);
      await tester.pumpAndSettle();
      expect(state.selections, 0);
      await _open(tester);
      state.update(() => state.enabled = false);
      await tester.pumpAndSettle();
      expect(_menu, findsNothing);
      expect(state.focus.hasFocus, isFalse);
      state.menu.open();
      await tester.pumpAndSettle();
      expect(_menu, findsNothing);
      state.update(() {
        state.enabled = true;
        state.show = true;
      });
      await tester.pumpAndSettle();
      await _open(tester);
      state.update(() => state.show = false);
      await tester.pumpAndSettle();
      tap();
      expect(state.selections, 0);
      expect(_menu, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [MyTheme.dark]) {
    for (final trigger in SharedDropdownTrigger.values) {
      testWidgets(
        'rendered roles, width and error recovery: ${theme.brightness}, ${theme.seedColor}, $trigger',
        (tester) async {
          final state = await _pump(tester);
          state.update(() {
            state.theme = theme;
            state.trigger = trigger;
          });
          await tester.pumpAndSettle();
          final width = tester.getSize(_dropdown).width;
          expect(width, lessThan(600));
          await _open(tester);
          expect(tester.getSize(_menu).width, greaterThanOrEqualTo(width));
          final tick = tester.widget<Icon>(find.byIcon(Icons.check));
          expect(tick.color, theme.seedColor);
          final colors = theme.colorScheme;
          final first = find.byKey(const Key('choice-any'));
          final material = tester.widget<Material>(_menu);
          expect(
            material.shape,
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.outlineVariant),
            ),
          );
          expect(tester.getSize(first).height, 40);
          expect(tester.getRect(first).left, tester.getRect(_menu).left);
          expect(tester.getRect(first).right, tester.getRect(_menu).right);
          final fills = find.descendant(
            of: first,
            matching: find.byType(ColoredBox),
          );
          expect(
            tester.widget<ColoredBox>(fills).color,
            colors.surfaceContainer,
          );
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.moveTo(tester.getCenter(first));
          await tester.pumpAndSettle();
          expect(
            tester.widget<ColoredBox>(fills).color,
            SharedDropdownStyle.rowFill(theme),
          );
          await mouse.down(tester.getCenter(first));
          await tester.pump(const Duration(milliseconds: 200));
          expect(
            tester.widget<ColoredBox>(fills).color,
            SharedDropdownStyle.rowFill(theme, pressed: true),
          );
          await mouse.cancel();
          await mouse.removePointer();
          await tester.pumpAndSettle();
          if (trigger == SharedDropdownTrigger.labelledField) {
            final decorator = tester.widget<InputDecorator>(
              find.byType(InputDecorator).first,
            );
            expect(decorator.isFocused, isTrue);
            expect(
              decorator.decoration.focusedBorder!.borderSide,
              BorderSide(color: theme.seedColor, width: 2),
            );
          } else {
            final ring = tester
                .widgetList<Material>(
                  find.descendant(
                    of: _dropdown,
                    matching: find.byType(Material),
                  ),
                )
                .where((m) => m.shape is CircleBorder)
                .single;
            expect(
              ring.shape,
              CircleBorder(side: BorderSide(color: colors.primary, width: 2)),
            );
          }
          state.update(() => state.error = 'Recoverable error');
          await tester.pumpAndSettle();
          expect(
            tester.widget<Icon>(find.byIcon(Icons.check)).color,
            colors.error,
          );
          state.update(() => state.error = null);
          await tester.pumpAndSettle();
          expect(
            tester.widget<Icon>(find.byIcon(Icons.check)).color,
            theme.seedColor,
          );
          expect(state.selections, 0);
          expect(state.draft.text, 'Unsaved draft');
          await _key(tester, LogicalKeyboardKey.escape);
          await _open(tester);
          await tester.tap(find.byKey(const Key('choice-c')));
          await tester.pumpAndSettle();
          expect(tester.getSize(_dropdown).width, width);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'scaled constrained labels/values/menus wrap and scroll to last choice at viewport edges',
    (tester) async {
      final state = await _pump(tester);
      for (final size in [const Size(1280, 960), const Size(1920, 1200)]) {
        await tester.binding.setSurfaceSize(size);
        for (final trigger in SharedDropdownTrigger.values) {
          state.update(() {
            state.size = size;
            state.scale = 2;
            state.fieldWidth = 220;
            state.alignment = Alignment.bottomRight;
            state.trigger = trigger;
            state.label = 'Complete meaningful floating field label';
            state.rows = SharedDropdownRows.iconAndLabel;
            state.choices = [
              for (var i = 0; i < 35; i++)
                SharedDropdownChoice<String?>(
                  value: '$i',
                  label: 'Option $i with complete long wrapped words',
                  key: Key('long-$i'),
                  icon: Icons.bar_chart,
                ),
            ];
            state.selected = '0';
          });
          await tester.pumpAndSettle();
          if (trigger == SharedDropdownTrigger.labelledField) {
            final label = find.descendant(
              of: _dropdown,
              matching: find.text(state.label),
            );
            final paragraph = tester.renderObject<RenderParagraph>(
              find.descendant(of: label, matching: find.byType(RichText)),
            );
            expect(paragraph.didExceedMaxLines, isFalse);
            final labelBounds = MatrixUtils.transformRect(
              paragraph.getTransformTo(null),
              Offset.zero & paragraph.size,
            );
            expect(
              labelBounds.top,
              greaterThanOrEqualTo(tester.getRect(_dropdown).top),
            );
            final value = find.descendant(
              of: _dropdown,
              matching: find.text(state.choices.first.label),
            );
            expect(
              labelBounds.bottom,
              lessThanOrEqualTo(tester.getRect(value).top),
              reason:
                  'label=$labelBounds raw=${paragraph.size}, field=${tester.getRect(_dropdown)}, value=${tester.getRect(value)}, decoration=${tester.widget<InputDecorator>(find.descendant(of: _dropdown, matching: find.byType(InputDecorator))).decoration.contentPadding}',
            );
          }
          await _open(tester);
          final rect = tester.getRect(_menu);
          expect(rect.left, greaterThanOrEqualTo(8));
          expect(rect.right, lessThanOrEqualTo(size.width - 8));
          expect(rect.bottom, lessThanOrEqualTo(size.height - 8));
          expect(
            tester.getSize(find.byKey(const Key('long-0'))).height,
            greaterThan(40),
          );
          await tester.scrollUntilVisible(
            find.byKey(const Key('long-34')),
            300,
            scrollable: find.descendant(
              of: _menu,
              matching: find.byType(Scrollable),
            ),
          );
          await tester.tap(find.byKey(const Key('long-34')));
          await tester.pumpAndSettle();
          expect(state.selected, '34');
          await _open(tester);
          expect(find.byIcon(Icons.check).hitTestable(), findsOneWidget);
          await _key(tester, LogicalKeyboardKey.enter);
          expect(state.selected, '34');
          expect(state.draft.text, 'Unsaved draft');
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'shared Admin errors truly wrap beyond five lines outside editable cap and retain input',
    (tester) async {
      const message =
          'Complete validation guidance that explains the recoverable field problem and how to correct it. '
          'Every word including the final sentinel must remain visible beside this field, not clipped or ellipsized. END ERROR';
      final controller = TextEditingController(text: '12');
      addTearDown(controller.dispose);
      final entity = ObjectBoxAdminRepositoryImpl().getEntities().singleWhere(
        (e) => e.name == 'Peak',
      );
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: MyTheme.dark,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: SizedBox(
                    width: 180,
                    child: objectBoxAdminTextFormField(
                      entity: entity,
                      field: 'notes',
                      recordId: 1,
                      key: const Key('wrapping-admin-field'),
                      controller: controller,
                      enabled: true,
                      multiline: true,
                      onChanged: (_) {},
                      decoration: sharedFieldDecoration(
                        labelText: 'Notes',
                        errorText: message,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byType(SharedFieldError),
            matching: find.byType(RichText),
          ),
        );
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: TextDirection.ltr,
          textScaler: TextScaler.linear(scale),
        )..layout(maxWidth: paragraph.size.width);
        expect(painter.computeLineMetrics().length, greaterThan(5));
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.height, closeTo(painter.height, .01));
        expect(
          tester.getRect(find.byType(SharedFieldError)).top,
          greaterThan(tester.getRect(find.byType(EditableText)).bottom),
        );
        expect(controller.text, '12');
        painter.dispose();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
