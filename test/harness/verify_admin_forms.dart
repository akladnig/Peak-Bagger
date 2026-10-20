// Isolated native smoke: flutter run -d macos -t test/harness/verify_admin_forms.dart
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/objectbox_admin_read_only_value.dart';

import 'admin_form_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = (details) {
    errors.add(details);
    FlutterError.presentError(details);
  };
  final key = GlobalKey<_SmokeState>();
  final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
  String? originalFrame;
  Future<ProcessResult> script(
    String body,
  ) => Process.run('/usr/bin/osascript', [
    '-e',
    'tell application "System Events" to tell (first application process whose unix id is $pid)\n$body\nend tell',
  ]);
  Future<void> restore() async {
    final frame = originalFrame
        ?.split(',')
        .map((s) => int.parse(s.trim()))
        .toList();
    if (frame != null && frame.length == 4) {
      await script(
        'set position of window 1 to {${frame[0]}, ${frame[1]}}\nset size of window 1 to {${frame[2]}, ${frame[3]}}',
      );
    }
    await Clipboard.setData(clipboard ?? const ClipboardData(text: ''));
  }

  runApp(_Smoke(key: key));
  try {
    await _settle();
    final original = await script(
      'set frontmost to true\nrepeat 600 times\nif exists window 1 then exit repeat\ndelay 0.1\nend repeat\nget {position of window 1, size of window 1}',
    );
    _check(
      original.exitCode == 0,
      'Cannot inspect fixture window: ${original.stderr}',
    );
    final frameText = original.stdout.toString().trim();
    _check(
      RegExp(r'^-?\d+,\s*-?\d+,\s*\d+,\s*\d+$').hasMatch(frameText),
      'Fixture has no accessible native window: $frameText',
    );
    originalFrame = frameText;
    final resized = await script(
      'set position of window 1 to {0, 25}\nset size of window 1 to {1680, 1050}',
    );
    _check(resized.exitCode == 0, 'Cannot resize fixture: ${resized.stderr}');
    await _settle();
    const custom = ThemeConfig(
      seedColor: Colors.teal,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      contrastLevel: .5,
    );
    var count = 0;
    for (final name in AdminFormFixture.names) {
      final fixture = AdminFormFixture(name, text: _longText)
        ..save = () async => 'Could not save. Retry.';
      key.currentState!.select(fixture);
      await _settle();
      (_find((w) => w.key == Key(fixture.editKey))!.widget as IconButton)
          .onPressed!();
      await _settle();
      final fieldKey =
          'objectbox-admin-${fixture.prefix}-${switch (name) {
            'Peak' => 'notes',
            'Route' => 'desc',
            'Contact' => 'nickname',
            'PeakList' => 'colour',
            _ => 'name',
          }}';
      final initialField = await _reveal(fixture, fieldKey);
      final controller = (initialField.widget as TextFormField).controller!;
      final draft = name == 'PeakList' ? '0xFFABCDEF' : _longText;
      controller.value = TextEditingValue(
        text: draft,
        selection: const TextSelection(baseOffset: 2, extentOffset: 6),
      );
      for (final size in [
        const Size(1280, 960),
        const Size(1600, 1000),
        const Size(1600, 960),
        const Size(1280, 960),
      ]) {
        for (final theme in [
          MyTheme.light,
          MyTheme.dark,
          MyTheme.lightWith(custom),
          MyTheme.darkWith(custom),
        ]) {
          for (final scale in [1.0, 2.0]) {
            key.currentState!.configure(size, theme, scale);
            await _settle();
            final scene = _find(
              (w) => w.key == const Key('form-smoke-content'),
            )!;
            final sceneBox = scene.findRenderObject()! as RenderBox;
            _check(sceneBox.size == size, 'Native scene constrained');
            final current = await _reveal(fixture, fieldKey);
            _check(
              identical(
                (current.widget as TextFormField).controller,
                controller,
              ),
              'Draft controller replaced',
            );
            _check(
              controller.text == draft &&
                  controller.selection ==
                      const TextSelection(baseOffset: 2, extentOffset: 6),
              'Draft/selection lost',
            );
            if (name == 'Peak' || name == 'Route') {
              final editable = _states<EditableTextState>(current).single;
              final scroll = _states<ScrollableState>(current).single;
              _check(
                (scroll.position.viewportDimension -
                            editable.renderEditable.preferredLineHeight * 5)
                        .abs() <
                    .5,
                '$name five-line content cap',
              );
              final outer = _states<ScrollableState>(
                _find((w) => w.key == Key(fixture.formKey))!,
              ).first;
              final before = outer.position.pixels;
              scroll.position.jumpTo(scroll.position.maxScrollExtent);
              controller.selection = TextSelection(
                baseOffset: draft.indexOf('SENTINEL'),
                extentOffset: draft.length,
              );
              editable.copySelection(SelectionChangedCause.keyboard);
              await _settle();
              _check(
                (await Clipboard.getData(Clipboard.kTextPlain))?.text ==
                    'SENTINEL',
                '$name offscreen copy',
              );
              _check(
                outer.position.pixels == before,
                'Inner scroll moved outer',
              );
              controller.selection = const TextSelection(
                baseOffset: 2,
                extentOffset: 6,
              );
            }
            final id = await _reveal(
              fixture,
              'objectbox-admin-${fixture.prefix}-id',
            );
            _check(
              id.widget is ObjectBoxAdminReadOnlyFormValue,
              '$name ID is an input',
            );
            final area = _states<SelectionAreaState>(id).single;
            area.selectableRegion.selectAll(SelectionChangedCause.keyboard);
            area.selectableRegion.contextMenuButtonItems
                .singleWhere((item) => item.type == ContextMenuButtonType.copy)
                .onPressed!();
            await _settle();
            _check(
              (await Clipboard.getData(Clipboard.kTextPlain))?.text == '7',
              '$name native read-only copy',
            );
            final save = _find((w) => w.key == Key(fixture.saveKey))!;
            final cancel = _find(
              (w) => w.key == Key('objectbox-admin-${fixture.prefix}-cancel'),
            )!;
            _check(cancel.widget is FilledButton, '$name Cancel is not filled');
            final box = save.findRenderObject()! as RenderBox;
            _check(
              (sceneBox.localToGlobal(Offset.zero) & sceneBox.size).contains(
                box.localToGlobal(box.size.center(Offset.zero)),
              ),
              '$name Save unreachable',
            );
            final cancelBox = cancel.findRenderObject()! as RenderBox;
            _check(
              (sceneBox.localToGlobal(Offset.zero) & sceneBox.size).contains(
                cancelBox.localToGlobal(cancelBox.size.center(Offset.zero)),
              ),
              '$name Cancel unreachable',
            );
            final footerTheme = FilledButtonTheme.of(cancel).style!;
            _check(
              footerTheme.backgroundColor!.resolve({}) ==
                      theme.colorScheme.primaryContainer &&
                  footerTheme.foregroundColor!.resolve({}) ==
                      theme.colorScheme.onPrimaryContainer,
              '$name footer colours',
            );
            _check(
              fixture.submitted.isEmpty && fixture.closes == 0,
              'View/rebuild wrote or dismissed',
            );
            _check(errors.isEmpty, '${errors.length} framework errors');
            count++;
          }
        }
      }
      final pending = Completer<String?>();
      fixture.save = () => pending.future;
      final saveAction =
          (_find((w) => w.key == Key(fixture.saveKey))!.widget as FilledButton)
              .onPressed!;
      final cancelAction =
          (_find(
                    (w) =>
                        w.key ==
                        Key('objectbox-admin-${fixture.prefix}-cancel'),
                  )!.widget
                  as FilledButton)
              .onPressed!;
      final closeAction =
          (_find(
                    (w) => w.key == const Key('objectbox-admin-details-close'),
                  )!.widget
                  as IconButton)
              .onPressed!;
      saveAction();
      saveAction();
      cancelAction();
      closeAction();
      await _settle();
      saveAction();
      cancelAction();
      closeAction();
      _check(
        fixture.submitted.length == 1 && fixture.closes == 0,
        '$name stale callback bypassed Save gate',
      );
      _check(
        (_find(
                      (w) =>
                          w.key ==
                          Key('objectbox-admin-${fixture.prefix}-cancel'),
                    )!.widget
                    as FilledButton)
                .onPressed ==
            null,
        '$name pending Cancel enabled',
      );
      pending.complete('Could not save. Retry.');
      await _settle();
      _check(fixture.submitted.length == 1, '$name save did not run');
      final retained = await _reveal(fixture, fieldKey);
      _check(
        identical((retained.widget as TextFormField).controller, controller) &&
            controller.text == draft,
        '$name failed Save lost draft',
      );
      (_find(
                (w) => w.key == Key('objectbox-admin-${fixture.prefix}-cancel'),
              )!.widget
              as FilledButton)
          .onPressed!();
      await _settle();
      _check(
        _find((w) => w.key == Key(fixture.formKey)) == null &&
            fixture.closes == 0 &&
            fixture.submitted.length == 1,
        '$name Cancel did not restore same details without writing',
      );
      (_find((w) => w.key == Key(fixture.editKey))!.widget as IconButton)
          .onPressed!();
      await _settle();
      final restored =
          (await _reveal(fixture, fieldKey)).widget as TextFormField;
      final committed = switch (name) {
        'Peak' || 'Route' => _longText,
        'Contact' => '',
        'NaturalFeature' => 'Fixture',
        _ =>
          '0x${fixture.peakList.colour.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase()}',
      };
      _check(
        restored.controller!.text == committed,
        '$name Cancel retained draft input',
      );
      restored.controller!.text = draft;
      fixture.save = () async => null;
      (_find((w) => w.key == Key(fixture.saveKey))!.widget as FilledButton)
          .onPressed!();
      await _settle();
      _check(fixture.submitted.length == 2, '$name retry did not run');
      _check(
        _find((w) => w.key == Key(fixture.formKey)) == null,
        '$name successful Save did not leave editor',
      );
      stdout.writeln(
        'PASS native $name forms: 32 size/theme/scale configurations; full copy/draft; pending stale callbacks; Cancel / Save failure/retry',
      );
    }
    runApp(const SizedBox.shrink());
    await _settle();
    _check(errors.isEmpty, 'Disposal errors');
    await restore();
    stdout.writeln(
      'PASS native Admin forms: $count configurations; no production services or user database',
    );
    exit(0);
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    await restore();
    exit(1);
  }
}

final _longText =
    '${List.filled(35, 'Complete wrapped native draft').join(' ')}\n${List.generate(10, (i) => 'Line $i').join('\n')}\nSENTINEL';
void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> _settle() async {
  WidgetsBinding.instance.scheduleWarmUpFrame();
  await WidgetsBinding.instance.endOfFrame.timeout(const Duration(seconds: 5));
  await Future<void>.delayed(const Duration(milliseconds: 400));
}

Element? _find(bool Function(Widget) matches) {
  Element? found;
  void visit(Element e) {
    if (matches(e.widget)) found ??= e;
    e.visitChildren(visit);
  }

  visit(WidgetsBinding.instance.rootElement!);
  return found;
}

List<T> _states<T extends State>(Element root) {
  final states = <T>[];
  void visit(Element e) {
    if (e is StatefulElement && e.state is T) states.add(e.state as T);
    e.visitChildren(visit);
  }

  visit(root);
  return states;
}

Future<Element> _reveal(AdminFormFixture fixture, String fieldKey) async {
  final outer = _states<ScrollableState>(
    _find((w) => w.key == Key(fixture.formKey))!,
  ).first;
  outer.position.jumpTo(0);
  await _settle();
  for (var i = 0; _find((w) => w.key == Key(fieldKey)) == null && i < 60; i++) {
    outer.position.jumpTo(
      (outer.position.pixels + 200).clamp(0, outer.position.maxScrollExtent),
    );
    await _settle();
  }
  final field =
      _find((w) => w.key == Key(fieldKey)) ??
      (throw StateError('Missing $fieldKey'));
  await Scrollable.ensureVisible(field);
  await _settle();
  return field;
}

class _Smoke extends StatefulWidget {
  const _Smoke({super.key});
  @override
  State<_Smoke> createState() => _SmokeState();
}

class _SmokeState extends State<_Smoke> {
  var fixture = AdminFormFixture('Peak');
  var size = const Size(1280, 960);
  var theme = MyTheme.light;
  double scale = 1;
  void select(AdminFormFixture next) => setState(() => fixture = next);
  void configure(Size s, ThemeData t, double textScale) => setState(() {
    size = s;
    theme = t;
    scale = textScale;
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    themeAnimationDuration: Duration.zero,
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        key: const Key('form-smoke-content'),
        width: size.width,
        height: size.height,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: Row(
              children: [
                const Expanded(
                  child: Center(
                    child: Text('Isolated native Admin form fixture'),
                  ),
                ),
                SizedBox(width: size.width / 3, child: fixture.pane()),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
