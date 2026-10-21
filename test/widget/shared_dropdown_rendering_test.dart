import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/shared_dropdown.dart';

import '../harness/shared_dropdown_fixture.dart';

void main() {
  const custom = ThemeConfig(
    seedColor: Colors.teal,
    dynamicSchemeVariant: DynamicSchemeVariant.expressive,
    contrastLevel: .5,
  );
  for (final theme in [
    MyTheme.light,
    MyTheme.dark,
    MyTheme.lightWith(custom),
    MyTheme.darkWith(custom),
  ]) {
    for (final trigger in SharedDropdownTrigger.values) {
      testWidgets(
        'painted dropdown states: ${theme.brightness} ${theme.seedColor} $trigger',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 960));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final key = GlobalKey<SharedDropdownFixtureState>();
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: SharedDropdownFixture(key: key),
            ),
          );
          final state = key.currentState!;
          state.update(() {
            state.theme = theme;
            state.trigger = trigger;
          });
          await tester.pumpAndSettle();
          final dropdown = find.byKey(const Key('fixture-dropdown'));
          final target = trigger == SharedDropdownTrigger.labelledField
              ? find.descendant(
                  of: dropdown,
                  matching: find.byType(InputDecorator),
                )
              : find.descendant(
                  of: dropdown,
                  matching: find.byType(IconButton),
                );
          final rect = tester.getRect(target);
          final colors = theme.colorScheme;
          final fillPoint = trigger == SharedDropdownTrigger.labelledField
              ? Offset(rect.right - 16, rect.top + 24)
              : Offset(rect.center.dx, rect.top + 10);
          final borderPoint = trigger == SharedDropdownTrigger.labelledField
              ? Offset(rect.right - 1, rect.top + 24)
              : Offset(rect.center.dx, rect.top + 1);
          Future<void> pixel(Offset point, Color expected) async {
            final actual = await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final data = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              final offset =
                  (point.dy.floor() * image.width + point.dx.floor()) * 4;
              final result = Color.fromARGB(
                data.getUint8(offset + 3),
                data.getUint8(offset),
                data.getUint8(offset + 1),
                data.getUint8(offset + 2),
              );
              image.dispose();
              return result;
            });
            for (final shift in [0, 8, 16]) {
              expect(
                ((actual!.toARGB32() >> shift) & 255) -
                    ((expected.toARGB32() >> shift) & 255),
                inInclusiveRange(-1, 1),
                reason: 'Paint at $point, expected $expected, actual $actual',
              );
            }
          }

          await pixel(fillPoint, colors.surface);
          if (trigger == SharedDropdownTrigger.labelledField) {
            await pixel(borderPoint, colors.outline);
          }
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          await mouse.moveTo(rect.center);
          await tester.pumpAndSettle();
          await pixel(
            fillPoint,
            trigger == SharedDropdownTrigger.labelledField
                ? hoveredSelectedModeFill(colors)
                : Color.alphaBlend(
                    colors.onSurface.withValues(alpha: .08),
                    colors.surface,
                  ),
          );
          state.focus.requestFocus();
          await tester.pumpAndSettle();
          await pixel(
            borderPoint,
            trigger == SharedDropdownTrigger.labelledField
                ? theme.seedColor
                : colors.primary,
          );
          await mouse.moveTo(const Offset(1100, 800));
          await tester.pumpAndSettle();
          await pixel(fillPoint, colors.surface);
          await tester.tap(target);
          await tester.pumpAndSettle();
          expect(state.focus.hasFocus, isFalse);
          await pixel(
            borderPoint,
            trigger == SharedDropdownTrigger.labelledField
                ? theme.seedColor
                : colors.primary,
          );
          final row = find.byKey(const Key('choice-c'));
          final rowRect = tester.getRect(row);
          final edge = Offset(rowRect.left + 2, rowRect.center.dy);
          await pixel(edge, colors.surfaceContainer);
          await mouse.moveTo(rowRect.center);
          await tester.pumpAndSettle();
          await pixel(
            edge,
            Color.alphaBlend(
              colors.onSurface.withValues(alpha: .08),
              colors.surfaceContainer,
            ),
          );
          await mouse.down(rowRect.center);
          await tester.pump(const Duration(milliseconds: 200));
          await pixel(
            edge,
            Color.alphaBlend(
              colors.onSurface.withValues(alpha: .12),
              colors.surfaceContainer,
            ),
          );
          await mouse.cancel();
          await mouse.moveTo(const Offset(1100, 800));
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          await pixel(
            edge,
            Color.alphaBlend(
              colors.onSurface.withValues(alpha: .08),
              colors.surfaceContainer,
            ),
          );
          state.update(() => state.error = 'Error');
          await tester.pumpAndSettle();
          await pixel(borderPoint, colors.error);
          state.menu.close();
          state.update(() {
            state.enabled = false;
            state.error = null;
          });
          await tester.pumpAndSettle();
          await mouse.moveTo(rect.center);
          await tester.pumpAndSettle();
          await pixel(fillPoint, colors.surface);
          await mouse.removePointer();
          await tester.pumpWidget(const SizedBox.shrink());
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'action/value/expanded and disabled selected semantics; no decorative icon names',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final key = GlobalKey<SharedDropdownFixtureState>();
      await tester.pumpWidget(SharedDropdownFixture(key: key));
      final state = key.currentState!;
      for (final trigger in SharedDropdownTrigger.values) {
        state.update(() {
          state.trigger = trigger;
          state.rows = SharedDropdownRows.iconAndLabel;
          state.selected = 'b';
        });
        await tester.pumpAndSettle();
        final target = find.bySemanticsLabel('Selection');
        expect(target, findsOneWidget);
        final data = tester.getSemantics(target).getSemanticsData();
        expect(data.value, 'Beta unavailable');
        expect(data.label, 'Selection');
        expect(data.flagsCollection.isExpanded, ui.Tristate.isFalse);
        state.menu.open();
        await tester.pumpAndSettle();
        final selected = tester
            .getSemantics(find.byKey(const Key('choice-b')))
            .getSemanticsData();
        expect(selected.flagsCollection.isSelected, ui.Tristate.isTrue);
        expect(selected.flagsCollection.isEnabled, ui.Tristate.isFalse);
        expect(selected.label, 'Beta unavailable');
        expect(selected.hasAction(ui.SemanticsAction.tap), isFalse);
        final tick = tester.widget<Icon>(find.byIcon(Icons.check));
        expect(tick.color, state.theme.seedColor.withValues(alpha: .38));
        state.menu.close();
        await tester.pumpAndSettle();
      }
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
