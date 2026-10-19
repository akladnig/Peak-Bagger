import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_table.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/theme.dart';

const _custom = ThemeConfig(
  seedColor: Colors.teal,
  dynamicSchemeVariant: DynamicSchemeVariant.expressive,
  contrastLevel: .5,
);

void main() {
  for (final brightness in Brightness.values) {
    for (final custom in [false, true]) {
      final theme = brightness == Brightness.light
          ? (custom ? MyTheme.lightWith(_custom) : MyTheme.light)
          : (custom ? MyTheme.darkWith(_custom) : MyTheme.dark);
      final description = '${brightness.name}, custom=$custom';

      testWidgets(
        'rendered fields resolve hover/focus/error/disabled: $description',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 960));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = TextEditingController(text: 'Retained draft');
          final focus = FocusNode();
          addTearDown(controller.dispose);
          addTearDown(focus.dispose);
          var enabled = true;
          String? error;
          late StateSetter update;
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: 480,
                      child: RepaintBoundary(
                        key: boundary,
                        child: StatefulBuilder(
                          builder: (context, setState) {
                            update = setState;
                            return TextField(
                              controller: controller,
                              focusNode: focus,
                              enabled: enabled,
                              decoration: InputDecoration(
                                labelText: 'Ordinary field',
                                errorText: error,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final colors = theme.colorScheme;
          final field = find.byType(TextField);
          Future<void> expectPaint(Color fill, Color border) async {
            final rect = tester.getRect(field);
            final image = await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              final width = image.width;
              image.dispose();
              return (bytes!, width);
            });
            Color pixel(int x, int y) {
              final offset = (y * image!.$2 + x) * 4;
              final bytes = image.$1;
              return Color.fromARGB(
                bytes.getUint8(offset + 3),
                bytes.getUint8(offset),
                bytes.getUint8(offset + 1),
                bytes.getUint8(offset + 2),
              );
            }

            // Sample the actual painted decoration away from glyphs and the label gap.
            expect(
              pixel(rect.width.toInt() - 16, 24).toARGB32(),
              fill.toARGB32(),
            );
            expect(
              pixel(rect.width.toInt() - 1, 24).toARGB32(),
              border.toARGB32(),
            );
          }

          await expectPaint(colors.surface, colors.outline);
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          addTearDown(mouse.removePointer);
          await mouse.moveTo(tester.getCenter(field));
          await tester.pumpAndSettle();
          final hovered = Color.alphaBlend(
            colors.primary.withValues(alpha: .08),
            Color.alphaBlend(
              colors.primary.withValues(alpha: .12),
              colors.surface,
            ),
          );
          await expectPaint(hovered, theme.seedColor);
          focus.requestFocus();
          await tester.pumpAndSettle();
          await expectPaint(hovered, theme.seedColor);
          await mouse.moveTo(const Offset(1000, 900));
          await tester.pumpAndSettle();
          await expectPaint(colors.surface, theme.seedColor);
          update(
            () => error =
                'A recoverable validation error that remains beside the field',
          );
          await mouse.moveTo(tester.getCenter(field));
          await tester.pumpAndSettle();
          await expectPaint(hovered, colors.error);
          update(() => enabled = false);
          await tester.pumpAndSettle();
          // Flutter retains an existing validation border even when disabled.
          await expectPaint(colors.surface, colors.error);
          expect(find.text(error!), findsOneWidget);
          update(() => error = null);
          await tester.pumpAndSettle();
          await expectPaint(
            colors.surface,
            Color.alphaBlend(
              colors.onSurface.withValues(alpha: .38),
              colors.surface,
            ),
          );
          expect(controller.text, 'Retained draft');
          expect(find.text('Ordinary field'), findsOneWidget);
          expect(find.byIcon(Icons.search), findsNothing);
          expect(find.byType(Tooltip), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );

      testWidgets(
        'Admin row paints precedence, independent focus and locked trash: $description',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 960));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final scroll = ScrollController();
          addTearDown(scroll.dispose);
          var selected = false;
          var enabled = true;
          var taps = 0;
          var deletes = 0;
          late StateSetter update;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Align(
                      alignment: Alignment.topLeft,
                      child: ObjectBoxAdminDataRowTile(
                        entityName: 'Peak',
                        row: const ObjectBoxAdminRow(
                          primaryKeyValue: 1,
                          values: {'name': 'Peak'},
                        ),
                        primaryField: _name,
                        otherFields: const [],
                        primaryColumnWidth: 144,
                        actionsColumnWidth: 72,
                        selected: selected,
                        horizontalController: scroll,
                        onTap: enabled ? () => taps++ : null,
                        showActionsColumn: true,
                        onDeletePressed: enabled ? () => deletes++ : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          final row = find.byType(ObjectBoxAdminDataRowTile);
          final container = find
              .descendant(of: row, matching: find.byType(Container))
              .first;
          BoxDecoration? decoration() =>
              tester.widget<Container>(container).decoration as BoxDecoration?;
          final grid = theme.extension<DataGridTheme>()!;
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          addTearDown(mouse.removePointer);
          await mouse.moveTo(tester.getCenter(find.text('Peak')));
          await tester.pump();
          expect(decoration()!.color, grid.hoverColor);
          final press = await tester.startGesture(
            tester.getCenter(find.text('Peak')),
          );
          await tester.pump();
          expect(decoration()!.color, grid.pressedRowColor);
          await press.up();
          update(() => selected = true);
          await tester.pump();
          expect(decoration()!.color, grid.selectedRowColor);
          final selectedPress = await tester.startGesture(
            tester.getCenter(find.text('Peak')),
          );
          await tester.pump();
          expect(decoration()!.color, grid.selectedRowColor);
          await selectedPress.up();
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focusDecoration =
              tester.widget<Container>(container).foregroundDecoration!
                  as BoxDecoration;
          expect(
            focusDecoration.border,
            Border.all(color: theme.colorScheme.primary, width: 2),
          );
          expect(decoration()!.color, grid.selectedRowColor);
          final trash = find.byType(IconButton);
          final icon = tester.widget<IconButton>(trash);
          expect(icon.style!.foregroundColor!.resolve({}), Colors.red);
          expect(
            IconTheme.of(
              tester.element(find.byIcon(Icons.delete_forever)),
            ).color,
            Colors.red,
          );
          expect(
            theme.iconButtonTheme.style!.backgroundColor!.resolve({}),
            Colors.transparent,
          );
          await tester.tap(trash);
          expect(deletes, 1);
          final previousTaps = taps;
          update(() {
            selected = false;
            enabled = false;
          });
          await tester.pump();
          await mouse.moveTo(tester.getCenter(find.text('Peak')));
          await tester.pump();
          expect(decoration(), isNull);
          await tester.tap(find.text('Peak'));
          await tester.tap(trash);
          expect(taps, previousTaps);
          expect(deletes, 1);
          expect(tester.widget<IconButton>(trash).onPressed, isNull);
          expect(
            IconTheme.of(
              tester.element(find.byIcon(Icons.delete_forever)),
            ).color,
            Colors.red.withValues(alpha: .38),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );

      testWidgets(
        'mode and circular icon states are rendered once: $description',
        (tester) async {
          final boundary = GlobalKey();
          final focus = FocusNode();
          addTearDown(focus.dispose);
          var enabled = true;
          late StateSetter update;
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: RepaintBoundary(
                    key: boundary,
                    child: ColoredBox(
                      color: theme.colorScheme.surface,
                      child: StatefulBuilder(
                        builder: (context, setState) {
                          update = setState;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                focusNode: focus,
                                tooltip: 'Edit',
                                onPressed: enabled ? () {} : null,
                                icon: const Icon(Icons.edit),
                              ),
                              FilledButton(
                                style: theme
                                    .extension<SearchButtonThemeData>()!
                                    .selectedStyle,
                                onPressed: () {},
                                child: const Text('Data'),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final icon = find.byType(IconButton);
          final data = find.byType(FilledButton);
          final mouse = await tester.createGesture(
            kind: ui.PointerDeviceKind.mouse,
          );
          addTearDown(mouse.removePointer);
          final colors = theme.colorScheme;
          Future<Color> sample(Finder target) async {
            final rect = tester.getRect(target);
            final origin = tester.getTopLeft(find.byKey(boundary));
            return _paintedPixel(
              tester,
              boundary,
              Offset(
                (target == data ? rect.left + 5 : rect.center.dx) - origin.dx,
                (target == data ? rect.center.dy : rect.top + 10) - origin.dy,
              ),
            );
          }

          expect((await sample(icon)).toARGB32(), colors.surface.toARGB32());
          await mouse.moveTo(tester.getCenter(icon));
          await tester.pumpAndSettle();
          _expectOverlayPixel(
            await sample(icon),
            Color.alphaBlend(
              colors.onSurface.withValues(alpha: .08),
              colors.surface,
            ),
          );
          await mouse.down(tester.getCenter(icon));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pumpAndSettle();
          _expectOverlayPixel(
            await sample(icon),
            Color.alphaBlend(
              colors.onSurface.withValues(alpha: .12),
              colors.surface,
            ),
          );
          await mouse.up();
          await mouse.moveTo(const Offset(700, 500));
          focus.requestFocus();
          await tester.pumpAndSettle();
          expect((await sample(icon)).toARGB32(), colors.surface.toARGB32());
          final material = tester
              .widgetList<Material>(
                find.descendant(of: icon, matching: find.byType(Material)),
              )
              .where((material) => material.shape is CircleBorder)
              .single;
          expect(
            material.shape,
            CircleBorder(side: BorderSide(color: colors.primary, width: 2)),
          );
          update(() => enabled = false);
          await mouse.moveTo(tester.getCenter(icon));
          await tester.pumpAndSettle();
          expect((await sample(icon)).toARGB32(), colors.surface.toARGB32());
          await mouse.moveTo(tester.getCenter(data));
          await tester.pumpAndSettle();
          expect(
            (await sample(data)).toARGB32(),
            hoveredSelectedModeFill(colors).toARGB32(),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'live scheme changes and rollback retain a scaled draft at supported sizes',
    (tester) async {
      final controller = TextEditingController(text: 'Unsaved text');
      final focus = FocusNode();
      final boundary = GlobalKey();
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      addTearDown(mouse.removePointer);
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final size in [
        const Size(1280, 960),
        const Size(1920, 1200),
        const Size(1600, 960),
      ]) {
        await tester.binding.setSurfaceSize(size);
        for (final theme in [
          MyTheme.light,
          MyTheme.darkWith(_custom),
          MyTheme.light,
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: RepaintBoundary(
                        key: boundary,
                        child: TextField(
                          controller: controller,
                          focusNode: focus,
                          decoration: const InputDecoration(
                            labelText: 'Persistent label',
                            errorText: 'Inline validation remains reachable',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          focus.requestFocus();
          await mouse.moveTo(
            tester.getTopLeft(find.byType(TextField)) + const Offset(40, 30),
          );
          await tester.pumpAndSettle();
          final painted = await _paintedPixel(
            tester,
            boundary,
            Offset(size.width - 48 - 16, 30),
          );
          expect(
            painted.toARGB32(),
            hoveredSelectedModeFill(theme.colorScheme).toARGB32(),
          );
          final decorator = tester.widget<InputDecorator>(
            find.byType(InputDecorator),
          );
          expect(
            decorator.decoration.focusedBorder!.borderSide,
            BorderSide(color: theme.seedColor, width: 2),
          );
          expect(controller.text, 'Unsaved text');
          expect(
            tester.getSize(find.text('Persistent label')).height,
            greaterThanOrEqualTo(20),
          );
          expect(
            tester
                .getSize(find.text('Inline validation remains reachable'))
                .height,
            greaterThanOrEqualTo(20),
          );
          expect(
            tester.getRect(find.text('Persistent label')).bottom,
            lessThan(size.height),
          );
          expect(
            tester
                .getRect(find.text('Inline validation remains reachable'))
                .bottom,
            lessThan(size.height),
          );
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

const _name = ObjectBoxAdminFieldDescriptor(
  name: 'name',
  typeLabel: 'String',
  nullable: false,
  isPrimaryKey: false,
  isPrimaryName: true,
);

Future<Color> _paintedPixel(
  WidgetTester tester,
  GlobalKey key,
  Offset location,
) async {
  return (await tester.runAsync(() async {
    final render =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset =
        (location.dy.toInt() * image.width + location.dx.toInt()) * 4;
    image.dispose();
    return Color.fromARGB(
      bytes.getUint8(offset + 3),
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
  }))!;
}

void _expectOverlayPixel(Color actual, Color expected) {
  // GPU alpha layers quantize to 8-bit channels before compositing. The exact
  // floating-point roles are separately checked in theme_test.dart.
  for (final channel in [16, 8, 0]) {
    expect(
      ((actual.toARGB32() >> channel) & 255) -
          ((expected.toARGB32() >> channel) & 255),
      inInclusiveRange(-1, 1),
    );
  }
}
