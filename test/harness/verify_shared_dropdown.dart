// Isolated native rendering AND OS-delivered keyboard/pointer input.
// flutter run -d macos -t test/harness/verify_shared_dropdown.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/shared_dropdown.dart';

import 'shared_dropdown_fixture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = (details) {
    errors.add(details);
    FlutterError.presentError(details);
  };
  final key = GlobalKey<SharedDropdownFixtureState>();
  String? originalFrame;
  Future<ProcessResult> script(
    String body,
  ) => Process.run('/usr/bin/osascript', [
    '-e',
    'tell application "System Events" to tell (first application process whose unix id is $pid)\n$body\nend tell',
  ]);
  Future<void> input(String body) async {
    final result = await script('set frontmost to true\ndelay 0.1\n$body');
    _check(result.exitCode == 0, 'Native input failed: ${result.stderr}');
    await _settle();
  }

  Future<void> restore() async {
    final frame = originalFrame
        ?.split(',')
        .map((v) => int.parse(v.trim()))
        .toList();
    if (frame != null && frame.length == 4) {
      await script(
        'set position of window 1 to {${frame[0]}, ${frame[1]}}\n'
        'set size of window 1 to {${frame[2]}, ${frame[3]}}',
      );
    }
  }

  runApp(SharedDropdownFixture(key: key));
  try {
    await _settle();
    final original = await script(
      'set frontmost to true\nrepeat 600 times\n'
      'if exists window 1 then exit repeat\ndelay 0.1\nend repeat\n'
      'get {position of window 1, size of window 1}',
    );
    final frame = original.stdout.toString().trim();
    _check(
      original.exitCode == 0 &&
          RegExp(r'^-?\d+,\s*-?\d+,\s*\d+,\s*\d+$').hasMatch(frame),
      'Cannot inspect native fixture window: ${original.stderr} $frame',
    );
    originalFrame = frame;
    await input(
      'set position of window 1 to {0, 25}\nset size of window 1 to {1680, 1100}',
    );
    const custom = ThemeConfig(
      seedColor: Colors.teal,
      dynamicSchemeVariant: DynamicSchemeVariant.expressive,
      contrastLevel: .5,
    );
    var count = 0;
    final state = key.currentState!;
    const pointerOnly = bool.fromEnvironment('DROPDOWN_NATIVE_POINTER_ONLY');
    for (final size
        in pointerOnly
            ? <Size>[]
            : [const Size(1280, 960), const Size(1600, 1000)]) {
      for (final theme in [
        MyTheme.light,
        MyTheme.dark,
        MyTheme.lightWith(custom),
        MyTheme.darkWith(custom),
      ]) {
        for (final scale in [1.0, 2.0]) {
          for (final trigger in SharedDropdownTrigger.values) {
            for (final rows in SharedDropdownRows.values) {
              state.update(() {
                state.size = size;
                state.theme = theme;
                state.scale = scale;
                state.trigger = trigger;
                state.rows = rows;
                state.selected = 'a';
              });
              await _settle();
              final content =
                  _element('dropdown-fixture-content').findRenderObject()!
                      as RenderBox;
              _check(
                content.size == size,
                'Content constrained below $size: ${content.size}',
              );
              // Focus programmatically, then use real macOS key events to open,
              // navigate, select, dismiss and prove no-op Enter.
              state.focus.requestFocus();
              await _settle();
              await input('key code 36'); // Return
              await _waitFor(
                () => state.menu.isOpen && !state.focus.hasFocus,
                'OS Return did not open/focus $trigger',
              );
              final menu =
                  _element('shared-dropdown-menu').findRenderObject()!
                      as RenderBox;
              final rect = menu.localToGlobal(Offset.zero) & menu.size;
              _check(
                rect.left >= 8 &&
                    rect.right <= size.width - 8 &&
                    rect.bottom <= size.height - 8,
                'Menu outside native scene: $rect',
              );
              final calls = state.selections;
              await input('key code 36');
              await _waitFor(
                () => !state.menu.isOpen,
                'Immediate Enter did not close',
              );
              _check(state.selections == calls, 'Immediate Enter selected');
              await input('key code 36');
              await _waitFor(
                () => state.menu.isOpen && !state.focus.hasFocus,
                'Reopen did not focus menu',
              );
              await input('key code 125'); // Down skips disabled Beta
              await _waitFor(
                () => _choiceHasFill(
                  'choice-c',
                  SharedDropdownStyle.rowFill(theme),
                ),
                'Native Down did not target next enabled choice',
              );
              _check(state.selected == 'a', 'Movement committed');
              await input('key code 36');
              await _waitFor(
                () => !state.menu.isOpen,
                'Selection did not close',
              );
              _check(
                state.selected == 'c' && state.selections == calls + 1,
                'OS navigation did not select',
              );
              await input('key code 36');
              await _waitFor(
                () => state.menu.isOpen && !state.focus.hasFocus,
                'Ctrl+C menu did not open',
              );
              await input('key code 8 using control down'); // Ctrl+C
              await _waitFor(
                () => !state.menu.isOpen && state.focus.hasFocus,
                'Ctrl+C focus/dismissal failed',
              );
              await input('key code 36');
              await _waitFor(
                () => state.menu.isOpen && !state.focus.hasFocus,
                'Escape menu did not open',
              );
              await input('key code 53'); // Escape
              await _waitFor(
                () => !state.menu.isOpen && state.focus.hasFocus,
                'Escape focus/dismissal failed',
              );
              _check(state.draft.text == 'Unsaved draft', 'Draft changed');
              _check(
                errors.isEmpty,
                '${errors.length} native framework errors',
              );
              count++;
              stdout.writeln(
                'PASS native dropdown $size ${theme.brightness.name} seed=${theme.seedColor.toARGB32()} scale=$scale $trigger $rows',
              );
            }
          }
        }
      }
    }
    // OS pointer events, not Dart callbacks or a brittle assumption that Flutter's
    // nested accessibility button is a direct child of the native window.
    Future<void> click(Element element) async {
      final frameResult = await script(
        'get {position of window 1, size of window 1}',
      );
      _check(frameResult.exitCode == 0, 'Cannot inspect pointer target window');
      final frame = frameResult.stdout
          .toString()
          .trim()
          .split(',')
          .map((v) => double.parse(v.trim()))
          .toList();
      final view = WidgetsBinding.instance.platformDispatcher.views.single;
      final viewSize = view.physicalSize / view.devicePixelRatio;
      final box = element.findRenderObject()! as RenderBox;
      final point = box.localToGlobal(box.size.center(Offset.zero));
      final x = (frame[0] + point.dx).round();
      final y = (frame[1] + frame[3] - viewSize.height + point.dy).round();
      stdout.writeln(
        'Native pointer frame=$frame view=$viewSize content=$point screen=($x,$y)',
      );
      await script('set frontmost to true\ndelay 0.2');
      final result = await Process.run('/usr/bin/swift', [
        '-e',
        '''
import CoreGraphics
import Darwin
let point = CGPoint(x: $x, y: $y)
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(150000)
CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(100000)
CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
''',
      ]);
      _check(
        result.exitCode == 0,
        'Native pointer injection failed: ${result.stderr}',
      );
      await _settle();
    }

    for (final trigger in SharedDropdownTrigger.values) {
      for (final rows in SharedDropdownRows.values) {
        state.update(() {
          state.trigger = trigger;
          state.rows = rows;
          state.selected = 'a';
        });
        await _settle();
        final calls = state.selections;
        await click(_element('fixture-dropdown'));
        await _waitFor(
          () => state.menu.isOpen,
          'OS pointer did not open $trigger/$rows',
        );
        await click(_element('choice-any'));
        await _waitFor(
          () => !state.menu.isOpen,
          'OS pointer did not select/close',
        );
        _check(
          state.selected == null && state.selections == calls + 1,
          'OS pointer selected the wrong value',
        );
        stdout.writeln('PASS native pointer $trigger $rows');
      }
    }
    runApp(const SizedBox.shrink());
    await _settle();
    _check(errors.isEmpty, 'Errors during native cleanup');
    await restore();
    stdout.writeln(
      pointerOnly
          ? 'PASS shared dropdown native pointer: 4 combinations, no production services/data'
          : 'PASS shared dropdown native: $count keyboard configurations and 4 pointer combinations, no production services/data',
    );
    exit(0);
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    await restore();
    exit(1);
  }
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 180));

Future<void> _waitFor(bool Function() condition, String message) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError(message);
}

bool _choiceHasFill(String key, Color color) {
  var found = false;
  void visit(Element element) {
    if (element.widget case ColoredBox(
      color: final actual,
    ) when actual == color) {
      found = true;
    }
    element.visitChildren(visit);
  }

  visit(_element(key));
  return found;
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Element _element(String key) {
  Element? match;
  void visit(Element element) {
    if (element.widget.key == ValueKey(key)) match = element;
    element.visitChildren(visit);
  }

  visit(WidgetsBinding.instance.rootElement!);
  return match ?? (throw StateError('Missing $key'));
}
