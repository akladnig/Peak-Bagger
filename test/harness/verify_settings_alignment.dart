// Isolated native probe: mock preferences/catalog/HTTP, no app startup or Store.
// flutter run -d macos -t test/harness/verify_settings_alignment.dart \
//   --dart-define=SETTINGS_PROJECT_ROOT="$PWD"
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/local_topo_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/open_route_service_api_key_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:peak_bagger/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controlled_preferences.dart';
import 'mapping_catalog_fixture.dart';
import 'test_map_notifier.dart';
import 'test_tasmap_notifier.dart';
import 'test_tasmap_repository.dart';

int _pointerDowns = 0;
Offset? _lastPointer;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Directory.current = const String.fromEnvironment(
    'SETTINGS_PROJECT_ROOT',
    defaultValue: '.',
  );
  SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
  final keyPrefs = ControlledPreferences({
    openRouteServiceApiKeyPrefsKey: 'fixture-old-key',
  });
  final topoPrefs = ControlledPreferences();
  final repository = await TestTasmapRepository.create();
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = (details) {
    errors.add(details);
    FlutterError.presentError(details);
  };
  final container = ProviderContainer(
    overrides: [
      ...mappingCatalogTestOverrides,
      mapProvider.overrideWith(
        () => TestMapNotifier(
          const MapState(
            center: LatLng(-41.5, 146.5),
            zoom: 10,
            basemap: Basemap.tracestrack,
          ),
        ),
      ),
      tasmapRepositoryProvider.overrideWithValue(repository),
      tasmapStateProvider.overrideWith(() => TestTasmapNotifier(repository)),
      openRouteServiceApiKeyPreferencesLoaderProvider.overrideWithValue(
        () async => keyPrefs,
      ),
      localTopoSettingsPreferencesLoaderProvider.overrideWithValue(
        () async => topoPrefs,
      ),
      localTopoSettingsHttpClientProvider.overrideWithValue(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'service': 'peak-bagger-local-topo',
              'version': 1,
              'basemaps': [
                {
                  'key': 'localTopo',
                  'label': 'Local Topo',
                  'regions': [
                    {
                      'regionKey': 'tasmania',
                      'tilePathTemplate':
                          '/tasmania/local-topo/{z}/{x}/{y}.png',
                    },
                  ],
                },
              ],
            }),
            200,
          ),
        ),
      ),
    ],
  );
  final scene = GlobalKey<_SceneState>();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _Scene(key: scene),
    ),
  );
  try {
    await _settle();
    await _input(
      'set position of window 1 to {0, 25}\nset size of window 1 to {1680, 1100}',
    );
    var checks = 0;
    for (final size in [const Size(1280, 960), const Size(1600, 1000)]) {
      const selectedWidth = int.fromEnvironment('SETTINGS_NATIVE_WIDTH');
      if (selectedWidth != 0 && size.width != selectedWidth) continue;
      await _resize(size);
      for (final scale in [1.0, 2.0]) {
        const selectedScale = int.fromEnvironment('SETTINGS_NATIVE_SCALE');
        if (selectedScale != 0 && scale != selectedScale) continue;
        scene.currentState!.updateScale(scale);
        await _settle();
        await _click('open-route-service-api-key-tile');
        await _replace(
          'open-route-service-api-key-field',
          'fixture-native-draft',
        );
        keyPrefs.onWrite = (_, _) async => false;
        await _click('open-route-service-api-key-save');
        await _wait(
          () => _hasText(
            'Could not save the API key. Try Save again, or Cancel.',
          ),
          'API failure not visible',
        );
        _check(
          _field('open-route-service-api-key-field').controller!.text ==
              'fixture-native-draft',
          'API draft lost',
        );
        // Native resize with a retained failed draft and live dialog.
        await _resize(
          size == const Size(1280, 960)
              ? const Size(1600, 1000)
              : const Size(1280, 960),
        );
        _check(
          _field('open-route-service-api-key-field').controller!.text ==
              'fixture-native-draft',
          'Resize lost API draft',
        );
        await _resize(size);
        keyPrefs.onWrite = null;
        await _click('open-route-service-api-key-save');
        await _wait(
          () => !_has('open-route-service-api-key-dialog'),
          'API success did not close',
        );
        await _replace('local-topo-base-url-field', 'ftp://retained.invalid');
        await _click('local-topo-save-button');
        _check(
          _hasText('Enter a valid http or https base URL.'),
          'URL syntax error missing',
        );
        _check(
          _field('local-topo-base-url-field').controller!.text ==
              'ftp://retained.invalid',
          'URL draft lost',
        );
        await _replace('local-topo-base-url-field', 'http://fixture.invalid');
        topoPrefs.onWrite = (key, _) async =>
            key != localTopoCapabilitySnapshotPrefsKey;
        await _click('local-topo-save-button');
        await _wait(
          () => _hasText('Validation state: Validation failed'),
          'URL persistence failure missing',
        );
        _check(
          _hasText('Saved URL: http://fixture.invalid'),
          'Confirmed saved URL missing',
        );
        _check(
          !localTopoRuntime.hasCapabilitySnapshot,
          'Unpersisted snapshot activated',
        );
        topoPrefs.onWrite = null;
        await _click('local-topo-retry-button');
        await _wait(
          () => _hasText('Validation state: Live validated'),
          'URL Retry did not succeed',
        );
        await _click('theme-scheme-variant-dropdown');
        await _wait(
          () => _has('shared-dropdown-menu'),
          'Settings menu did not open',
        );
        await _input('key code 36');
        await _wait(
          () => !_has('shared-dropdown-menu'),
          'Immediate Enter did not dismiss',
        );
        await _click('theme-scheme-variant-dropdown');
        await _input('key code 125\nkey code 36');
        await _wait(
          () => !_has('shared-dropdown-menu'),
          'Navigated Enter did not select',
        );
        await _clickText('Map Tile Cache');
        await _wait(
          () => _has('tile-cache-scrollable'),
          'Tile Cache did not open',
        );
        await _replace('tile-cache-map-search-field', 'native query');
        await _input('keystroke "f" using command down');
        _check(
          _field('tile-cache-map-search-field').controller!.selection ==
              const TextSelection(baseOffset: 0, extentOffset: 12),
          'Native Cmd+F did not select query',
        );
        await _click('tile-cache-min-zoom');
        final field = _field('tile-cache-map-search-field');
        field.controller!.selection = const TextSelection.collapsed(offset: 2);
        await _input('keystroke "f" using command down');
        _check(
          field.controller!.selection.extentOffset == 2 &&
              _has('shared-dropdown-menu'),
          'Menu did not exclude Search',
        );
        await _resize(
          size == const Size(1280, 960)
              ? const Size(1600, 1000)
              : const Size(1280, 960),
        );
        _check(
          field.controller!.text == 'native query',
          'Resize lost Search query',
        );
        // Resize may intentionally dismiss an unavailable anchor; neither path commits.
        if (_has('shared-dropdown-menu')) await _input('key code 53');
        await _resize(size);
        await _click('tile-cache-max-zoom');
        await _input('keystroke "c" using control down');
        await _wait(
          () => !_has('shared-dropdown-menu'),
          'Ctrl+C did not close only menu',
        );
        _check(
          _has('tile-cache-scrollable'),
          'Menu dismissal cascaded into route',
        );
        Navigator.of(_element('tile-cache-scrollable')).pop();
        await _settle();
        _check(
          errors.isEmpty,
          'Flutter errors during native checks: ${errors.length}',
        );
        stdout.writeln(
          'SETTINGS_NATIVE_PASS content=$size scale=$scale theme=MySeed/dark',
        );
        checks++;
      }
    }
    stdout.writeln(
      'SETTINGS_NATIVE_COMPLETE $checks configurations; OS pointer/keyboard, no human visual acceptance claimed',
    );
    exit(0);
  } catch (error, stackTrace) {
    stderr.writeln('SETTINGS_NATIVE_FAIL $error\n$stackTrace');
    exit(1);
  }
}

class _Scene extends StatefulWidget {
  const _Scene({super.key});
  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  double scale = 1;
  void updateScale(double value) => setState(() => scale = value);
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      _pointerDowns++;
      _lastPointer = event.position;
    },
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MyTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const SettingsScreen(),
    ),
  );
}

Future<ProcessResult> _script(
  String body,
) => Process.run('/usr/bin/osascript', [
  '-e',
  'tell application "System Events" to tell (first application process whose unix id is $pid)\n$body\nend tell',
]);
Future<void> _input(String body) async {
  final result = await _script(
    'set frontmost to true\ndelay 0.1\n$body\nkey up command\nkey up control\nkey up option\nkey up shift',
  );
  _check(result.exitCode == 0, 'OS input failed: ${result.stderr}');
  await _settle();
}

Future<List<double>> _frame() async =>
    (await _script('get {position of window 1, size of window 1}')).stdout
        .toString()
        .trim()
        .split(',')
        .map((s) => double.parse(s.trim()))
        .toList();
Future<void> _resize(Size target) async {
  final frame = await _frame();
  final view = WidgetsBinding.instance.platformDispatcher.views.single;
  final content = view.physicalSize / view.devicePixelRatio;
  final titleHeight = frame[3] - content.height;
  // AX can temporarily omit the window while AppKit settles a preceding frame.
  // Retrying an idempotent resize is safe; never replay keyboard/selection input.
  ProcessResult? resized;
  for (var attempt = 0; attempt < 5; attempt++) {
    resized = await _script(
      'set frontmost to true\ndelay 0.2\nset size of window 1 to {${target.width.round()}, ${(target.height + titleHeight).round()}}',
    );
    if (resized.exitCode == 0) break;
    await _settle();
  }
  _check(resized?.exitCode == 0, 'Native resize failed: ${resized?.stderr}');
  await _settle();
  final actual = view.physicalSize / view.devicePixelRatio;
  _check(actual == target, 'Native content size $actual differs from $target');
}

Future<void> _reveal(String key) async {
  if (!_has(key)) {
    final listKey = _has('tile-cache-scrollable')
        ? 'tile-cache-scrollable'
        : 'settings-scrollable';
    ScrollableState? scroll;
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        scroll ??= element.state as ScrollableState;
      }
      element.visitChildren(visit);
    }

    visit(_element(listKey));
    _check(scroll != null, 'No scroll owner');
    scroll!.position.jumpTo(0);
    await _settle();
    for (var i = 0; !_has(key) && i < 40; i++) {
      scroll!.position.jumpTo(
        (scroll!.position.pixels + 300).clamp(
          0,
          scroll!.position.maxScrollExtent,
        ),
      );
      await _settle();
    }
  }
  await Scrollable.ensureVisible(
    _element(key),
    duration: const Duration(milliseconds: 100),
  );
  await _settle();
}

Future<void> _clickText(String text) async {
  // The Settings entry is at the top of its ListView.
  await _reveal('open-route-service-api-key-tile');
  final element = _find(
    (e) => e.widget is Text && (e.widget as Text).data == text,
  ).single;
  await Scrollable.ensureVisible(element);
  await _settle();
  await _clickElement(element);
}

Future<void> _click(String key) async {
  await _reveal(key);
  final element = _element(key);
  Element? field;
  Element? editable;
  void visit(Element child) {
    if (child.widget is InputDecorator) field ??= child;
    if (child.widget is EditableText) editable ??= child;
    child.visitChildren(visit);
  }

  visit(element);
  await _clickElement(editable ?? field ?? element);
}

Future<void> _clickElement(Element element) async {
  await _input('set frontmost to true');
  final frame = await _frame();
  final view = WidgetsBinding.instance.platformDispatcher.views.single;
  final box = element.findRenderObject()! as RenderBox;
  final point = box.localToGlobal(box.size.center(Offset.zero));
  stdout.writeln(
    'SETTINGS_NATIVE_CLICK ${element.widget.runtimeType} at $point size=${box.size}',
  );
  final x = frame[0] + point.dx;
  final y =
      frame[1] +
      frame[3] -
      view.physicalSize.height / view.devicePixelRatio +
      point.dy;
  final before = _pointerDowns;
  final result = await Process.run('/usr/bin/swift', [
    '-e',
    '''
import CoreGraphics
import Darwin
let p = CGPoint(x: $x, y: $y)
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(100000)
CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(100000)
CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
''',
  ]);
  _check(result.exitCode == 0, 'OS pointer failed: ${result.stderr}');
  await _wait(() => _pointerDowns > before, 'Native pointer was not delivered');
  _check(
    (_lastPointer! - point).distance < 3,
    'Native pointer missed the target',
  );
  await _settle();
}

Future<void> _replace(String key, String value) async {
  await _click(key);
  await _input('keystroke "a" using command down');
  await _input(
    'repeat with letter in characters of "$value"\nkeystroke letter\ndelay 0.02\nend repeat',
  );
  _check(
    _field(key).controller!.text == value,
    'Native text entry not delivered to $key (length=${_field(key).controller!.text.length}, expected=${value.length}, focus=${FocusManager.instance.primaryFocus?.debugLabel})',
  );
}

TextField _field(String key) {
  TextField? field;
  void visit(Element e) {
    if (e.widget is TextField) field = e.widget as TextField;
    e.visitChildren(visit);
  }

  visit(_element(key));
  return field!;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 250));
Future<void> _wait(bool Function() condition, String message) async {
  for (var i = 0; i < 80; i++) {
    if (condition()) return;
    await _settle();
  }
  throw StateError(message);
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Element _element(String key) =>
    _find((e) => e.widget.key == ValueKey(key)).single;
bool _has(String key) => _find((e) => e.widget.key == ValueKey(key)).isNotEmpty;
bool _hasText(String text) => _find(
  (e) => e.widget is Text && (e.widget as Text).data == text,
).isNotEmpty;
List<Element> _find(bool Function(Element) predicate) {
  final matches = <Element>[];
  void visit(Element e) {
    if (predicate(e)) matches.add(e);
    e.visitChildren(visit);
  }

  visit(WidgetsBinding.instance.rootElement!);
  return matches;
}
