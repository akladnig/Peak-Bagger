// Isolated native rendering + macOS-delivered keyboard/pointer input.
// flutter run -d macos -t test/harness/verify_admin_live_search.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_map_notifier.dart';
import 'test_objectbox_admin_repository.dart';

Future<void> main() async {
  // Explicitly separate native text/render verification from the optional
  // modifier probe; some hosts drop injected Command/Control key transitions.
  const verifyModifiers = bool.fromEnvironment(
    'ADMIN_SEARCH_NATIVE_MODIFIERS',
    defaultValue: true,
  );
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final errors = <FlutterErrorDetails>[];
  final nativeKeys = <String>[];
  bool recordKey(KeyEvent event) {
    nativeKeys.add(
      '${event.runtimeType}:${event.logicalKey.keyLabel}:meta=${HardwareKeyboard.instance.isMetaPressed}',
    );
    return false;
  }

  HardwareKeyboard.instance.addHandler(recordKey);
  FlutterError.onError = (details) {
    errors.add(details);
    FlutterError.presentError(details);
  };
  final peaks = PeakRepository.test(
    InMemoryPeakStorage([
      Peak(id: 1, osmId: 101, name: 'Ossa', latitude: -41.5, longitude: 146.5),
      Peak(id: 2, osmId: 202, name: 'Anne', latitude: -41.5, longitude: 146.5),
    ]),
  );
  final descriptor = ObjectBoxAdminRepositoryImpl().getEntities().singleWhere(
    (e) => e.name == 'Peak',
  );
  final repository = TestObjectBoxAdminRepository(entities: [descriptor])
    ..rowLoader = (_) async => peaks.getAllPeaks().map(peakToAdminRow).toList();
  final container = ProviderContainer(
    overrides: [
      objectboxAdminRepositoryProvider.overrideWithValue(repository),
      peakRepositoryProvider.overrideWithValue(peaks),
      mapProvider.overrideWith(
        () => TestMapNotifier(
          MapState(
            center: const LatLng(-41.5, 146.5),
            zoom: 10,
            basemap: Basemap.tracestrack,
          ),
        ),
      ),
    ],
  );
  final key = GlobalKey<_SceneState>();
  String? originalFrame;
  Future<ProcessResult> script(
    String body,
  ) => Process.run('/usr/bin/osascript', [
    '-e',
    'tell application "System Events" to tell (first application process whose unix id is $pid)\n$body\nend tell',
  ]);
  Future<void> input(String body) async {
    final result = await script('set frontmost to true\ndelay 0.1\n$body');
    _check(result.exitCode == 0, 'Native input: ${result.stderr}');
    await _settle();
  }

  Future<void> keyboard(String body) async {
    await script('set frontmost to true\ndelay 0.1');
    final result = await Process.run('/usr/bin/swift', [
      '-e',
      '''
import CoreGraphics
import Darwin
func key(_ code: CGKeyCode, _ flags: CGEventFlags = []) {
  if flags.contains(.maskCommand) {
    let modifier = CGEvent(keyboardEventSource: nil, virtualKey: 55, keyDown: true)!
    modifier.flags = .maskCommand
    modifier.post(tap: .cghidEventTap)
    usleep(100000)
  }
  for down in [true, false] {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
    event.flags = flags
    event.post(tap: .cghidEventTap)
    usleep(100000)
  }
  if flags.contains(.maskCommand) {
    let modifier = CGEvent(keyboardEventSource: nil, virtualKey: 55, keyDown: false)!
    modifier.flags = []
    modifier.post(tap: .cghidEventTap)
    usleep(100000)
  }
}
func text(_ value: String) {
  for char in value {
    let units = Array(String(char).utf16)
    for down in [true, false] {
      let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)!
      units.withUnsafeBufferPointer { buffer in
        event.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress!)
      }
      event.post(tap: .cghidEventTap)
      usleep(30000)
    }
  }
}
$body
''',
    ]);
    _check(
      result.exitCode == 0,
      'Native CoreGraphics keyboard failed: ${result.stderr}',
    );
    await _settle();
  }

  Future<void> focusSearch() async {
    if (verifyModifiers) {
      await keyboard('key(3, .maskCommand)');
    } else {
      final field =
          _element('objectbox-admin-search-field').widget as TextField;
      field.focusNode!.requestFocus();
      field.controller!.selection = TextSelection(
        baseOffset: 0,
        extentOffset: field.controller!.text.length,
      );
      await _settle();
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _Scene(key: key),
    ),
  );
  try {
    await _settle();
    final frame = await script(
      'set frontmost to true\nrepeat 600 times\nif exists window 1 then exit repeat\ndelay 0.1\nend repeat\nget {position of window 1, size of window 1}',
    );
    _check(frame.exitCode == 0, 'Native window unavailable: ${frame.stderr}');
    originalFrame = frame.stdout.toString().trim();
    await input(
      'set position of window 1 to {0, 25}\nset size of window 1 to {1680, 1100}',
    );
    container
        .read(objectboxAdminProvider.notifier)
        .selectRow(peakToAdminRow(peaks.findById(1)!));
    await _settle();
    (_element('objectbox-admin-peak-edit').widget as IconButton).onPressed!();
    await _settle();
    final draft =
        (_element('objectbox-admin-peak-name').widget as TextFormField)
            .controller!;
    _editable('objectbox-admin-peak-name').widget.focusNode.requestFocus();
    draft.selection = TextSelection(
      baseOffset: 0,
      extentOffset: draft.text.length,
    );
    await _settle();
    final nativeFrame = await script(
      'get {position of window 1, size of window 1}',
    );
    final coordinates = nativeFrame.stdout
        .toString()
        .trim()
        .split(',')
        .map((v) => double.parse(v.trim()))
        .toList();
    final view = WidgetsBinding.instance.platformDispatcher.views.single;
    final viewSize = view.physicalSize / view.devicePixelRatio;
    final field =
        _element('objectbox-admin-peak-name').findRenderObject()! as RenderBox;
    final point = field.localToGlobal(field.size.center(Offset.zero));
    final x = (coordinates[0] + point.dx).round();
    final y = (coordinates[1] + coordinates[3] - viewSize.height + point.dy)
        .round();
    final click = await Process.run('/usr/bin/swift', [
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
    _check(click.exitCode == 0, 'Native pointer failed: ${click.stderr}');
    if (!verifyModifiers) {
      draft.selection = TextSelection(
        baseOffset: 0,
        extentOffset: draft.text.length,
      );
    }
    await keyboard(
      '${verifyModifiers ? 'key(0, .maskCommand)\n' : ''}text("Unsaved draft")',
    );
    _check(
      draft.text == 'Unsaved draft',
      'Native editor input not delivered: text=${draft.text}, focus=${_editable('objectbox-admin-peak-name').widget.focusNode.hasFocus}, events=$nativeKeys',
    );
    var count = 0;
    for (final size in [
      const Size(1280, 960),
      const Size(1600, 1000),
      const Size(1280, 960),
    ]) {
      final frameResult = await script('get size of window 1');
      final frame = frameResult.stdout
          .toString()
          .trim()
          .split(',')
          .map((v) => double.parse(v.trim()))
          .toList();
      final view = WidgetsBinding.instance.platformDispatcher.views.single;
      final client = view.physicalSize / view.devicePixelRatio;
      await input(
        'set size of window 1 to {${(frame[0] + size.width - client.width).round()}, ${(frame[1] + size.height - client.height).round()}}',
      );
      for (final theme in [MyTheme.dark]) {
        for (final scale in [1.0, 2.0]) {
          key.currentState!.configure(size, theme, scale);
          await _settle();
          final scene =
              _element('admin-search-scene').findRenderObject()! as RenderBox;
          _check(scene.size == size, 'Native scene constrained: ${scene.size}');
          await focusSearch();
          await keyboard('text("Anne")');
          final search =
              _element('objectbox-admin-search-field').widget as TextField;
          _check(
            search.controller!.text == 'Anne' && search.focusNode!.hasFocus,
            'Native Search typing/focus failed (modifier probe=$verifyModifiers)',
          );
          _check(
            container
                    .read(objectboxAdminProvider)
                    .rows
                    .single
                    .primaryKeyValue ==
                2,
            'Not live filtered',
          );
          await focusSearch();
          _check(
            search.controller!.selection ==
                const TextSelection(baseOffset: 0, extentOffset: 4),
            'Search selection did not cover the raw query',
          );
          await keyboard('text("no matches")\nkey(36)');
          _check(
            container.read(objectboxAdminProvider).rows.isEmpty,
            'Zero matches / Enter',
          );
          _check(
            container
                    .read(objectboxAdminProvider)
                    .selectedRow
                    ?.primaryKeyValue ==
                1,
            'Search lost identity',
          );
          _check(
            identical(
                  (_element('objectbox-admin-peak-name').widget
                          as TextFormField)
                      .controller,
                  draft,
                ) &&
                draft.text == 'Unsaved draft',
            'Draft/controller lost on search/resize/theme',
          );
          await focusSearch();
          await keyboard('key(51)');
          _check(
            container.read(objectboxAdminProvider).rows.length == 2,
            'Native clearing did not restore rows',
          );
          final footer =
              _element('objectbox-admin-peak-submit').findRenderObject()!
                  as RenderBox;
          final rect = footer.localToGlobal(Offset.zero) & footer.size;
          _check(
            rect.bottom <= size.height && rect.right <= size.width,
            'Save inaccessible',
          );
          _check(errors.isEmpty, 'Native framework errors');
          count++;
          stdout.writeln(
            'PASS native Admin live Search $size ${theme.brightness.name} seed=${theme.seedColor.toARGB32()} scale=$scale',
          );
        }
      }
    }
    stdout.writeln(
      'PASS native Admin Search: $count render/text/Enter/clear/resize configurations; modifier probe=$verifyModifiers; no production services or Store',
    );
    await _restore(script, originalFrame);
    runApp(const SizedBox.shrink());
    await _settle();
    container.dispose();
    HardwareKeyboard.instance.removeHandler(recordKey);
    exit(0);
  } catch (error, stack) {
    stderr.writeln('FAIL native Admin Search: $error\n$stack');
    await _restore(script, originalFrame);
    HardwareKeyboard.instance.removeHandler(recordKey);
    exit(1);
  }
}

Future<void> _restore(
  Future<ProcessResult> Function(String) script,
  String? original,
) async {
  final values = original?.split(',').map((s) => int.parse(s.trim())).toList();
  if (values == null || values.length != 4) return;
  await script(
    'set position of window 1 to {${values[0]}, ${values[1]}}\nset size of window 1 to {${values[2]}, ${values[3]}}',
  );
}

Element _element(String key) {
  Element? found;
  void visit(Element element) {
    if (element.widget.key == Key(key)) found = element;
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  if (found == null) throw StateError('Missing $key');
  return found!;
}

EditableTextState _editable(String key) {
  EditableTextState? found;
  void visit(Element element) {
    if (element is StatefulElement && element.state is EditableTextState) {
      found = element.state as EditableTextState;
    }
    element.visitChildren(visit);
  }

  _element(key).visitChildren(visit);
  return found!;
}

void _check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await WidgetsBinding.instance.endOfFrame;
}

class _Scene extends StatefulWidget {
  const _Scene({super.key});
  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  Size size = const Size(1280, 960);
  ThemeData theme = MyTheme.dark;
  double scale = 1;
  void configure(Size nextSize, ThemeData nextTheme, double nextScale) =>
      setState(() {
        size = nextSize;
        theme = nextTheme;
        scale = nextScale;
      });
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Align(
      alignment: Alignment.topLeft,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: size.width,
        maxWidth: size.width,
        minHeight: size.height,
        maxHeight: size.height,
        child: SizedBox(
          key: const Key('admin-search-scene'),
          width: size.width,
          height: size.height,
          child: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: const ObjectBoxAdminScreen(),
          ),
        ),
      ),
    ),
  );
}
