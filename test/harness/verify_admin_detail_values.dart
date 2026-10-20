// Isolated native smoke: flutter run -d macos -t test/harness/verify_admin_detail_values.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/objectbox_admin_read_only_value.dart';

import 'admin_detail_value_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = (details) {
    errors.add(details);
    FlutterError.presentError(details);
  };
  final key = GlobalKey<_SmokeState>();
  runApp(_Smoke(key: key));
  String? originalFrame;
  final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
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

  try {
    await _settle();
    final original = await script(
      'set frontmost to true\nrepeat 200 times\nif exists window 1 then exit repeat\ndelay 0.1\nend repeat\nget {position of window 1, size of window 1}',
    );
    _check(
      original.exitCode == 0,
      'Cannot inspect fixture window: ${original.stderr}',
    );
    originalFrame = original.stdout.toString().trim();
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
    for (final name in AdminDetailValueFixture.entities) {
      final fixture = AdminDetailValueFixture(name, _longText);
      key.currentState!.select(fixture);
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
              (w) => w.key == const Key('detail-smoke-content'),
            )!;
            _check(
              (scene.findRenderObject()! as RenderBox).size == size,
              'Native scene constrained',
            );
            final outer = _find(
              (w) => w.key == const Key('objectbox-admin-details-list'),
            )!;
            final outerScroll = _states<ScrollableState>(outer).first;
            Element? value() => _find(
              (w) =>
                  w is ObjectBoxAdminReadOnlyValue &&
                  w.label == fixture.longField,
            );
            for (var i = 0; value() == null && i < 30; i++) {
              outerScroll.position.jumpTo(
                (outerScroll.position.pixels + 300).clamp(
                  0,
                  outerScroll.position.maxScrollExtent,
                ),
              );
              await _settle();
            }
            final element =
                value() ?? (throw StateError('Missing $name long value'));
            await Scrollable.ensureVisible(element);
            await _settle();
            final scroll = _states<ScrollableState>(element).single;
            final before = outerScroll.position.pixels;
            _check(
              scroll.position.maxScrollExtent > 0,
              '$name does not scroll',
            );
            scroll.position.jumpTo(scroll.position.maxScrollExtent);
            await _settle();
            _check(
              outerScroll.position.pixels == before,
              '$name scrolled outer panel',
            );
            final area = _states<SelectionAreaState>(element).single;
            area.selectableRegion.selectAll(SelectionChangedCause.keyboard);
            area.selectableRegion.contextMenuButtonItems
                .singleWhere((item) => item.type == ContextMenuButtonType.copy)
                .onPressed!();
            await _settle();
            _check(
              (await Clipboard.getData(Clipboard.kTextPlain))?.text ==
                  _longText,
              '$name native copy lost text',
            );
            final close = _find(
              (w) => w.key == const Key('objectbox-admin-details-close'),
            )!;
            final closeBox = close.findRenderObject()! as RenderBox;
            final sceneBox = scene.findRenderObject()! as RenderBox;
            final bounds = sceneBox.localToGlobal(Offset.zero) & sceneBox.size;
            _check(
              bounds.contains(
                closeBox.localToGlobal(closeBox.size.center(Offset.zero)),
              ),
              'Close out of bounds',
            );
            _check(
              fixture.writes == 0 && fixture.closes == 0,
              'Read-only interaction mutated state',
            );
            _check(errors.isEmpty, '${errors.length} framework errors');
            count++;
          }
        }
      }
      stdout.writeln(
        'PASS native $name details: 32 size/theme/scale configurations; independent scrolling/full copy',
      );
    }

    final route = AdminDetailValueFixture('Route', _longText);
    key.currentState!.select(route);
    await _settle();
    (_find((w) => w.key == const Key('objectbox-admin-route-edit'))!.widget
            as IconButton)
        .onPressed!();
    await _settle();
    final field =
        _find((w) => w.key == const Key('objectbox-admin-route-name'))!.widget
            as TextFormField;
    final controller = field.controller!;
    controller.value = const TextEditingValue(
      text: 'Unsaved native draft',
      selection: TextSelection(baseOffset: 2, extentOffset: 6),
    );
    for (final size in [
      const Size(1600, 960),
      const Size(1600, 1000),
      const Size(1280, 960),
    ]) {
      key.currentState!.configure(size, MyTheme.darkWith(custom), 2);
      await _settle();
      final current =
          _find((w) => w.key == const Key('objectbox-admin-route-name'))!.widget
              as TextFormField;
      _check(
        identical(current.controller, controller),
        'Draft controller replaced',
      );
      _check(
        controller.text == 'Unsaved native draft' &&
            controller.selection ==
                const TextSelection(baseOffset: 2, extentOffset: 6),
        'Draft/selection lost',
      );
      _check(
        route.writes == 0 && route.route.name == 'Fixture',
        'Resize wrote draft',
      );
    }
    runApp(const SizedBox.shrink());
    await _settle();
    _check(errors.isEmpty, 'Disposal errors');
    await restore();
    stdout.writeln(
      'PASS native details: $count configurations; resize-preserved draft/selection; cleanup; no writes',
    );
    exit(0);
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    await restore();
    exit(1);
  }
}

final _longText =
    '${List.filled(50, 'Long wrapped detail value').join(' ')}\nSENTINEL';
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

class _Smoke extends StatefulWidget {
  const _Smoke({super.key});
  @override
  State<_Smoke> createState() => _SmokeState();
}

class _SmokeState extends State<_Smoke> {
  var fixture = AdminDetailValueFixture('Waypoints', _longText);
  var size = const Size(1280, 960);
  var theme = MyTheme.light;
  double scale = 1;
  void select(AdminDetailValueFixture next) => setState(() => fixture = next);
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
        key: const Key('detail-smoke-content'),
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
                  child: Center(child: Text('Isolated native detail fixture')),
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
