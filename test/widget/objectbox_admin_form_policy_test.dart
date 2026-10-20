import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/objectbox_admin_field_policy.dart';
import 'package:peak_bagger/services/route_admin_editor.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/objectbox_admin_read_only_value.dart';

import '../harness/admin_form_fixture.dart';

// Independent expected capabilities, not expectations computed from the policy.
const _textFields = {
  'Peak': [
    'name',
    'alt-name',
    'osm-id',
    'peakbagger-pid',
    'elevation',
    'prominence',
    'country',
    'county',
    'range',
    'rating',
    'duration',
    'difficulty',
    'via-ferrata',
    'notes',
    'latitude',
    'longitude',
    'region',
    'mgrs100k-id',
    'easting',
    'northing',
  ],
  'NaturalFeature': [
    'name',
    'alt-name',
    'tag',
    'country',
    'county',
    'region',
    'latitude',
    'longitude',
    'mgrs100k-id',
    'easting',
    'northing',
  ],
  'Contact': ['first-name', 'surname', 'nickname'],
  'Route': [
    'name',
    'desc',
    'colour',
    'distance2d',
    'distance3d',
    'ascent',
    'descent',
    'start-elevation',
    'end-elevation',
    'lowest-elevation',
    'highest-elevation',
  ],
  'PeakList': ['colour'],
};

void main() {
  for (final name in AdminFormFixture.names) {
    testWidgets('$name record/route replacement disposes the old draft owner', (
      tester,
    ) async {
      final fixture = AdminFormFixture(name);
      await _pump(tester, fixture);
      await _edit(tester, fixture);
      final suffix = name == 'PeakList'
          ? 'colour'
          : name == 'Contact'
          ? 'nickname'
          : 'name';
      final field = find.byKey(
        Key('objectbox-admin-${fixture.prefix}-$suffix'),
      );
      await _reveal(tester, fixture, field);
      final controller = tester.widget<TextFormField>(field).controller!;
      await tester.enterText(field, 'Abandoned draft');
      await _pump(tester, AdminFormFixture(name, id: 99));
      expect(() => controller.addListener(() {}), throwsFlutterError);
      expect(find.text('Abandoned draft'), findsNothing);
      expect(fixture.submitted, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name retains exact controls; read-only values are not inputs', (
      tester,
    ) async {
      final fixture = AdminFormFixture(name);
      await _pump(tester, fixture);
      await _edit(tester, fixture);
      for (final suffix in _textFields[name]!) {
        final field = find.byKey(
          Key('objectbox-admin-${fixture.prefix}-$suffix'),
        );
        await _reveal(tester, fixture, field);
        expect(tester.widget(field), isA<TextFormField>());
        final input = tester.widget<TextFormField>(field);
        expect(input.enabled, isTrue);
        final decoration = tester
            .widget<TextField>(
              find.descendant(of: field, matching: find.byType(TextField)),
            )
            .decoration!;
        expect(decoration.prefixIcon, isNull);
        expect(decoration.suffixIcon, isNull);
        expect(decoration.labelText, isNotEmpty);
        expect(decoration.labelStyle!.fontSize, searchControlFontSize);
      }
      if (name == 'Peak' || name == 'Route') {
        final boolean = find.byKey(
          Key(
            'objectbox-admin-${fixture.prefix}-${name == 'Peak' ? 'verified' : 'visible'}',
          ),
        );
        await _reveal(tester, fixture, boolean);
        expect(
          tester.widget(boolean),
          name == 'Peak' ? isA<CheckboxListTile>() : isA<SwitchListTile>(),
        );
      }
      if (name == 'NaturalFeature') {
        final selector = find.byKey(
          const Key('objectbox-admin-natural-feature-source-of-truth'),
        );
        await _reveal(tester, fixture, selector);
        final dropdown = tester.widget<DropdownButton<String>>(
          find.descendant(
            of: selector,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        expect(dropdown.items!.map((item) => item.value), ['OSM', 'Manual']);
        expect(dropdown.onChanged, isNotNull);
      }
      final id = find.byKey(Key('objectbox-admin-${fixture.prefix}-id'));
      await _reveal(tester, fixture, id);
      expect(
        find.descendant(of: id, matching: find.byType(TextFormField)),
        findsNothing,
      );
      expect(
        find.descendant(of: id, matching: find.byType(TextField)),
        findsNothing,
      );
      expect(
        find.descendant(of: id, matching: find.byType(SelectionArea)),
        findsOneWidget,
      );
      expect(find.descendant(of: id, matching: find.text('7')), findsOneWidget);
      expect(find.text('Not yet assigned'), findsNothing);
      final semantics = tester.ensureSemantics();
      final value = find.descendant(
        of: id,
        matching: find.byType(ObjectBoxAdminReadOnlyValue),
      );
      void checkNode(SemanticsNode node) {
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.setText),
          isFalse,
        );
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.paste),
          isFalse,
        );
        expect(
          node.getSemanticsData().hasAction(ui.SemanticsAction.cut),
          isFalse,
        );
        node.visitChildren((child) {
          checkNode(child);
          return true;
        });
      }

      checkNode(tester.getSemantics(value));
      semantics.dispose();
      expect(fixture.submitted, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name fails closed when app metadata is unavailable', (
      tester,
    ) async {
      final fixture = AdminFormFixture(name, metadata: const {});
      await _pump(tester, fixture);
      await _edit(tester, fixture);
      for (final suffix in _textFields[name]!) {
        final field = find.byKey(
          Key('objectbox-admin-${fixture.prefix}-$suffix'),
        );
        await _reveal(tester, fixture, field);
        expect(tester.widget(field), isA<ObjectBoxAdminReadOnlyFormValue>());
        expect(
          find.descendant(of: field, matching: find.byType(TextField)),
          findsNothing,
        );
      }
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(fixture.submitted, isEmpty);
      expect(fixture.entity.fields.every((field) => !field.canEdit), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name pending/failing save retains the same full draft', (
      tester,
    ) async {
      final pending = Completer<String?>();
      final fixture = AdminFormFixture(name)..save = () => pending.future;
      await _pump(tester, fixture);
      await _edit(tester, fixture);
      final suffix = name == 'PeakList'
          ? 'colour'
          : name == 'Contact'
          ? 'nickname'
          : 'name';
      final field = find.byKey(
        Key('objectbox-admin-${fixture.prefix}-$suffix'),
      );
      await _reveal(tester, fixture, field);
      final draft = name == 'PeakList' ? '0xFFABCDEF' : 'Unsaved draft';
      await tester.enterText(field, draft);
      final controller = tester.widget<TextFormField>(field).controller!;
      await tester.tap(find.byKey(Key(fixture.saveKey)));
      await tester.pump();
      expect(fixture.submitted, hasLength(1));
      expect(tester.widget<TextFormField>(field).enabled, isFalse);
      pending.complete('Could not save. Retry.');
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(field).controller, same(controller));
      expect(controller.text, draft);
      expect(tester.widget<TextFormField>(field).enabled, isTrue);
      fixture.save = () async => null;
      await tester.tap(find.byKey(Key(fixture.saveKey)));
      await tester.pumpAndSettle();
      expect(fixture.submitted, hasLength(2));
      expect(find.byKey(Key(fixture.formKey)), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'generated create placeholder does not replace assignable/stored zero',
    (tester) async {
      for (final name in ['Contact', 'Peak']) {
        final fixture = AdminFormFixture(name, id: 0, createMode: true);
        await _pump(tester, fixture, newIdentity: true);
        final id = find.byKey(Key('objectbox-admin-${fixture.prefix}-id'));
        expect(
          find.descendant(
            of: id,
            matching: find.text(name == 'Contact' ? 'Not yet assigned' : '0'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: id, matching: find.byType(TextField)),
          findsNothing,
        );
        expect(fixture.submitted, isEmpty);
      }
      final stored = AdminFormFixture('Contact', id: 0);
      await _pump(tester, stored, newIdentity: true);
      await _edit(tester, stored);
      expect(find.text('Not yet assigned'), findsNothing);
      expect(find.text('0'), findsOneWidget);
    },
  );

  testWidgets('explicit PK/generated flags override permissive text metadata', (
    tester,
  ) async {
    // Covered through the production descriptor gate, not Attributes parsing.
    final fixture = AdminFormFixture(
      'Peak',
      metadata: {
        'Peak': {
          ...objectBoxAdminAppMetadata['Peak']!,
          'id': const AdminFieldMetadata('int', input: AdminFieldInput.text),
          'name': const AdminFieldMetadata(
            'String',
            input: AdminFieldInput.text,
            generated: true,
          ),
        },
      },
    );
    await _pump(tester, fixture);
    await _edit(tester, fixture);
    final name = find.byKey(const Key('objectbox-admin-peak-name'));
    expect(tester.widget(name), isA<ObjectBoxAdminReadOnlyFormValue>());
    expect(
      fixture.entity.fields.singleWhere((f) => f.name == 'name').attributes,
      contains('Read-only'),
    );
    expect(
      find.descendant(of: name, matching: find.byType(TextField)),
      findsNothing,
    );
  });

  for (final name in ['Peak', 'Route']) {
    testWidgets(
      '$name multiline measures five lines; copy/resize/save retains complete draft',
      (tester) async {
        String? clipboard;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String;
            }
            if (call.method == 'Clipboard.getData') {
              return {'text': clipboard};
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
        final text =
            '${List.filled(35, 'Wrapped complete draft').join(' ')}\n${List.generate(10, (i) => 'Line $i').join('\n')}\nSENTINEL';
        final fixture = AdminFormFixture(name, text: text);
        await _pump(tester, fixture);
        await _edit(tester, fixture);
        final field = find.byKey(
          Key(
            'objectbox-admin-${fixture.prefix}-${name == 'Peak' ? 'notes' : 'desc'}',
          ),
        );
        await _reveal(tester, fixture, field);
        final controller = tester.widget<TextFormField>(field).controller!;
        for (final content in ['', 'Short', text]) {
          await tester.enterText(field, content);
          await tester.pumpAndSettle();
          final editable = find.descendant(
            of: field,
            matching: find.byType(EditableText),
          );
          final render = tester
              .state<EditableTextState>(editable)
              .renderEditable;
          final lineHeight = render.preferredLineHeight;
          final scroll = tester.state<ScrollableState>(
            find.descendant(of: field, matching: find.byType(Scrollable)),
          );
          expect(
            scroll.position.viewportDimension,
            closeTo(lineHeight * (content == text ? 5 : 1), .1),
          );
          if (content == text) {
            expect(
              scroll.position.maxScrollExtent,
              greaterThan(lineHeight * 5),
            );
          }
        }
        final editable = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        final render = tester.state<EditableTextState>(editable).renderEditable;
        final inner = tester.state<ScrollableState>(
          find.descendant(of: field, matching: find.byType(Scrollable)),
        );
        final outer = _outer(tester, fixture);
        final outerBefore = outer.position.pixels;
        inner.position.jumpTo(inner.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(outer.position.pixels, outerBefore);
        final sentinel = render
            .getBoxesForSelection(
              TextSelection(
                baseOffset: text.indexOf('SENTINEL'),
                extentOffset: text.length,
              ),
            )
            .last;
        expect(
          tester
              .getRect(editable)
              .contains(render.localToGlobal(sentinel.toRect().center)),
          isTrue,
        );
        controller.selection = TextSelection(
          baseOffset: text.indexOf('SENTINEL'),
          extentOffset: text.length,
        );
        final state = tester.state<EditableTextState>(editable);
        state.copySelection(SelectionChangedCause.keyboard);
        await tester.pump();
        expect(clipboard, 'SENTINEL');
        final selection = controller.selection;
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
              await _reveal(tester, fixture, field);
              expect(
                tester.widget<TextFormField>(field).controller,
                same(controller),
              );
              expect(controller.text, text);
              expect(controller.selection, selection);
              final current = tester
                  .state<EditableTextState>(
                    find.descendant(
                      of: field,
                      matching: find.byType(EditableText),
                    ),
                  )
                  .renderEditable;
              final scroll = tester.state<ScrollableState>(
                find.descendant(of: field, matching: find.byType(Scrollable)),
              );
              expect(
                scroll.position.viewportDimension,
                closeTo(current.preferredLineHeight * 5, .1),
              );
              expect(
                find.byKey(Key(fixture.saveKey)).hitTestable(),
                findsOneWidget,
              );
              expect(fixture.submitted, isEmpty);
              expect(tester.takeException(), isNull);
            }
          }
        }
        await tester.tap(find.byKey(Key(fixture.saveKey)));
        await tester.pumpAndSettle();
        final submitted = fixture.submitted.single;
        expect(
          submitted is Peak
              ? submitted.notes
              : (submitted as RouteAdminFormState).desc,
          text,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(() => controller.addListener(() {}), throwsFlutterError);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }

  testWidgets(
    'long read-only form value scrolls/selects/copies beyond line five without mutation',
    (tester) async {
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
      final text =
          '${List.filled(40, 'Full read-only value').join(' ')}\nSENTINEL';
      final fixture = AdminFormFixture('PeakList', text: text);
      await _pump(tester, fixture, scale: 2);
      await _edit(tester, fixture);
      final field = find.byKey(
        const Key('objectbox-admin-peak-list-name-read-only'),
      );
      await _reveal(tester, fixture, field);
      final value = find.descendant(
        of: field,
        matching: find.byType(ObjectBoxAdminReadOnlyValue),
      );
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: value, matching: find.byType(Scrollable)),
      );
      final before = _outer(tester, fixture).position.pixels;
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(_outer(tester, fixture).position.pixels, before);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: value, matching: find.byType(RichText)),
      );
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(
              baseOffset: text.indexOf('SENTINEL'),
              extentOffset: text.length,
            ),
          )
          .last;
      final point = paragraph.localToGlobal(box.toRect().center);
      expect(tester.getRect(value).contains(point), isTrue);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: point);
      await mouse.down(point);
      await mouse.up();
      await tester.pump(const Duration(milliseconds: 50));
      await mouse.down(point);
      await mouse.up();
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(clipboard, 'SENTINEL');
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(fixture.peakList.name, text);
      expect(fixture.submitted, isEmpty);
      await mouse.removePointer();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}

Future<void> _edit(WidgetTester tester, AdminFormFixture fixture) async {
  await tester.tap(find.byKey(Key(fixture.editKey)));
  await tester.pumpAndSettle();
}

ScrollableState _outer(WidgetTester tester, AdminFormFixture fixture) =>
    tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(Key(fixture.formKey)),
            matching: find.byType(Scrollable),
          )
          .first,
    );

Future<void> _reveal(
  WidgetTester tester,
  AdminFormFixture fixture,
  Finder field,
) async {
  final outer = _outer(tester, fixture);
  outer.position.jumpTo(0);
  await tester.pumpAndSettle();
  for (var i = 0; field.evaluate().isEmpty && i < 60; i++) {
    outer.position.jumpTo(
      (outer.position.pixels + 150).clamp(0, outer.position.maxScrollExtent),
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  AdminFormFixture fixture, {
  Size size = const Size(1280, 960),
  double scale = 1,
  ThemeData? theme,
  bool newIdentity = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      key: newIdentity ? UniqueKey() : null,
      theme: theme ?? MyTheme.light,
      themeAnimationDuration: Duration.zero,
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: Row(
            children: [
              const Expanded(child: Text('Data table fixture')),
              SizedBox(width: size.width / 3, child: fixture.pane()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
