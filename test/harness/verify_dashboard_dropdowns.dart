// Isolated production Time/summary callers, without startup, Store or network.
// flutter run -d macos -t test/harness/verify_dashboard_dropdowns.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/track_date_status.dart';
import 'package:peak_bagger/providers/time_chart_type_provider.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/dashboard/dashboard_card_keyboard.dart';
import 'package:peak_bagger/widgets/dashboard/time_card.dart';

import 'time_chart_preference_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = (details) {
    errors.add(details);
    FlutterError.presentError(details);
  };
  final storage = TestTimeChartPreferenceStorage();
  final container = ProviderContainer(
    overrides: [timeChartPreferenceStorageProvider.overrideWithValue(storage)],
  );
  final scene = GlobalKey<_SceneState>();
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

  Future<void> click(String key) async {
    final result = await script('get {position of window 1, size of window 1}');
    final frame = result.stdout
        .toString()
        .trim()
        .split(',')
        .map((v) => double.parse(v.trim()))
        .toList();
    final view = WidgetsBinding.instance.platformDispatcher.views.single;
    final box = _element(key)!.findRenderObject()! as RenderBox;
    final point = box.localToGlobal(box.size.center(Offset.zero));
    final x = frame[0] + point.dx;
    final y =
        frame[1] +
        frame[3] -
        view.physicalSize.height / view.devicePixelRatio +
        point.dy;
    final pointer = await Process.run('/usr/bin/swift', [
      '-e',
      '''
import CoreGraphics
import Darwin
let point = CGPoint(x: $x, y: $y)
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(100000)
CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(100000)
CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
''',
    ]);
    _check(pointer.exitCode == 0, 'Native pointer failed: ${pointer.stderr}');
    await _settle();
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: _Scene(key: scene),
    ),
  );
  try {
    await _settle();
    await input(
      'set position of window 1 to {0, 25}\nset size of window 1 to {1680, 1100}',
    );
    final view = WidgetsBinding.instance.platformDispatcher.views.single;
    final chromeHeight =
        1100 - view.physicalSize.height / view.devicePixelRatio;
    for (final size in [const Size(1280, 960), const Size(1600, 1000)]) {
      for (final scale in [1.0, 1.5]) {
        await input(
          'set size of window 1 to {${size.width.round()}, ${(size.height + chromeHeight).round()}}',
        );
        scene.currentState!.update(size, scale);
        await _settle();
        final state = scene.currentState!;
        final box =
            _element('native-dashboard-content')!.findRenderObject()!
                as RenderBox;
        _check(
          box.size == size,
          'Native scene constrained below $size: ${box.size}',
        );
        for (final shortcut in ['p', 'c']) {
          final writes = storage.writes.length;
          state.owner.focus();
          await _settle();
          await input('keystroke "$shortcut"');
          _check(
            _element('shared-dropdown-menu') != null,
            'P/C failed to open',
          );
          _check(
            !state.owner.focusNode.hasPrimaryFocus &&
                FocusManager.instance.primaryFocus?.debugLabel ==
                    'Dropdown menu',
            'Menu did not take focus',
          );
          await input('key code 36');
          _check(
            _element('shared-dropdown-menu') == null &&
                state.owner.focusNode.hasPrimaryFocus,
            'Unchanged Enter/focus failed',
          );
          _check(storage.writes.length == writes, 'Unchanged Enter wrote');
          await input('keystroke "$shortcut"');
          await input('key code 125');
          await input('key code 36');
          _check(
            _element('shared-dropdown-menu') == null &&
                state.owner.focusNode.hasPrimaryFocus,
            'Directional selection/focus failed',
          );
          if (shortcut == 'c') {
            _check(
              storage.writes.length == writes + 1,
              'Chart selection did not write once',
            );
          }
          for (final dismissal in [
            'key code 53',
            'key code 8 using control down',
          ]) {
            await input('keystroke "$shortcut"');
            await input(dismissal);
            _check(
              _element('shared-dropdown-menu') == null &&
                  state.owner.focusNode.hasPrimaryFocus,
              'Dismissal/focus failed: $dismissal',
            );
          }
          final trigger = shortcut == 'p'
              ? 'summary-period-dropdown'
              : 'time-chart-type-button';
          await click(trigger);
          _check(
            _element('shared-dropdown-menu') != null,
            'Pointer trigger failed',
          );
          await click('native-draft');
          _check(
            _element('shared-dropdown-menu') == null &&
                !state.draftFocus.hasFocus,
            'Outside gesture was not consumed',
          );
          await click('native-draft');
          _check(
            state.draftFocus.hasFocus,
            'Second gesture did not focus draft',
          );
          await click(trigger);
          final pointerType =
              container.read(timeChartTypeProvider).selected ==
                  TimeChartType.line
              ? TimeChartType.clusteredColumn
              : TimeChartType.line;
          await click(
            shortcut == 'p'
                ? 'time-period-week'
                : 'time-chart-type-${pointerType.name}',
          );
          _check(
            _element('shared-dropdown-menu') == null,
            'Pointer selection did not close',
          );
          if (shortcut == 'c') {
            _check(
              container.read(timeChartTypeProvider).selected == pointerType,
              'Pointer selected wrong chart type',
            );
          }
          await click(trigger);
          final selected = container.read(timeChartTypeProvider).selected;
          final before = storage.writes.length;
          await input('set size of window 1 to {1740, 1150}');
          _check(
            state.draft.text == 'Unsaved draft' &&
                container.read(timeChartTypeProvider).selected == selected &&
                storage.writes.length == before,
            'Resize changed draft/value',
          );
          if (_element('shared-dropdown-menu') != null) {
            await input('key code 53');
          }
          await input(
            'set size of window 1 to {${size.width.round()}, ${(size.height + chromeHeight).round()}}',
          );
        }
        _check(errors.isEmpty, '${errors.length} native framework errors');
        stdout.writeln(
          'PASS native Dashboard dropdown callers $size scale=$scale My Seed Colour/dark (Time height gate excluded)',
        );
      }
    }
    stdout.writeln(
      'PASS native Dashboard dropdown verification; no human visual acceptance claimed',
    );
    runApp(const SizedBox.shrink());
    await _settle();
    container.dispose();
    exit(0);
  } catch (error, stack) {
    stderr.writeln('FAIL native Dashboard dropdown: $error\n$stack');
    exit(1);
  }
}

class _Scene extends StatefulWidget {
  const _Scene({super.key});
  @override
  State<_Scene> createState() => _SceneState();
}

class _SceneState extends State<_Scene> {
  Size size = const Size(1280, 960);
  double scale = 1;
  final draft = TextEditingController(text: 'Unsaved draft');
  final draftFocus = FocusNode();
  late final owner = DashboardCardKeyboardController(
    title: 'Native Time',
    traverse: (_) {},
  )..isActive = () => mounted;
  final tracks = [
    GpxTrack(
      gpxTrackId: 1,
      contentHash: 'native-dropdown',
      trackName: 'Fixture',
      trackDate: DateTime.utc(2026, 9, 15),
      trackDateStatus: TrackDateStatus.resolved,
      totalTimeMillis: 18000000,
      movingTime: 14400000,
    ),
  ];
  void update(Size value, double textScale) => setState(() {
    size = value;
    scale = textScale;
  });
  @override
  void dispose() {
    owner.dispose();
    draft.dispose();
    draftFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: MyTheme.dark,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          key: const Key('native-dashboard-content'),
          width: size.width,
          height: size.height,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(size: size, textScaler: TextScaler.linear(scale)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  TextField(
                    key: const Key('native-draft'),
                    controller: draft,
                    focusNode: draftFocus,
                    decoration: const InputDecoration(
                      labelText: 'Fixture draft',
                    ),
                  ),
                  Expanded(
                    child: DashboardCardKeyboard(
                      controller: owner,
                      child: Focus(
                        focusNode: owner.focusNode,
                        onKeyEvent: (_, event) {
                          if (event is KeyDownEvent &&
                              !owner.menuOwnsFocus &&
                              !dashboardHasCommandModifier) {
                            final action = owner.actions[event.logicalKey];
                            if (action != null) {
                              action();
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TimeCard(
                          tracks: tracks,
                          isLoading: false,
                          now: DateTime(2026, 10, 15),
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'Independent dropdown probe — not Time header/plot-height acceptance',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Element? _element(String key) {
  Element? result;
  void visit(Element element) {
    if (element.widget.key == ValueKey(key)) result = element;
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return result;
}

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 350));
  await WidgetsBinding.instance.endOfFrame;
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}
