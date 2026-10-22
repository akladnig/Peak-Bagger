// Isolated native macOS input/render checks; no application startup or live data.
// flutter run -d macos -t test/harness/verify_peak_list_fields.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/map_metadata_filter_popup.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';
import 'package:peak_bagger/widgets/peak_list_peak_dialog.dart';

import 'test_peak_list_file_picker.dart';
import 'test_tasmap_repository.dart';

Element element(String key) {
  Element? found;
  void visit(Element e) {
    if (e.widget.key == Key(key)) found = e;
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement!.visitChildren(visit);
  return found ?? (throw StateError('Missing $key'));
}

bool has(String key) {
  try {
    element(key);
    return true;
  } on StateError {
    return false;
  }
}

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 500));

Future<ProcessResult> script(String body) => Process.run('/usr/bin/osascript', [
  '-e',
  'tell application "System Events" to tell (first application process whose unix id is $pid)\nset frontmost to true\ndelay 0.1\n$body\nend tell',
]);

Future<void> input(String body) async {
  final result = await script(body);
  check(result.exitCode == 0, 'Native input failed: ${result.stderr}');
  await settle();
}

Future<void> click(String key) async {
  await Scrollable.ensureVisible(element(key));
  await settle();
  final box = element(key).findRenderObject()! as RenderBox;
  final point = box.localToGlobal(box.size.center(Offset.zero));
  final result = await script('get {position of window 1, size of window 1}');
  final frame = result.stdout
      .toString()
      .trim()
      .split(',')
      .map((s) => double.parse(s.trim()))
      .toList();
  final view = WidgetsBinding.instance.platformDispatcher.views.single;
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
  check(pointer.exitCode == 0, 'Native pointer failed: ${pointer.stderr}');
  await settle();
}

TextField field(String key) => element(key).widget as TextField;

Future<void> commandF() async {
  await input('delay 0.3');
  final result = await Process.run('/usr/bin/swift', [
    '-e',
    '''
import CoreGraphics
import Darwin
import AppKit
let application = NSRunningApplication(processIdentifier: $pid)!
application.activate(options: [.activateIgnoringOtherApps])
usleep(300000)
guard NSWorkspace.shared.frontmostApplication?.processIdentifier == $pid else {
  fputs("Fixture is not foreground for shortcut injection\\n", stderr)
  exit(1)
}
let source = CGEventSource(stateID: .hidSystemState)
func post(_ key: CGKeyCode, _ down: Bool, _ flags: CGEventFlags) {
  let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
  if key == 55 { event?.type = .flagsChanged }
  event?.flags = flags
  event?.post(tap: .cghidEventTap)
  usleep(100000)
}
// Flutter tracks left/right device flags, not only the generic Command bit.
// NX_DEVICELCMDKEYMASK from IOKit/hidsystem/IOLLEvent.h is 0x00000008.
let leftCommand = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x8)
post(55, true, leftCommand)
post(3, true, leftCommand)
post(3, false, leftCommand)
post(55, false, [])
''',
  ]);
  check(
    result.exitCode == 0,
    'Physical key injection failed: ${result.stderr}',
  );
  await settle();
}

Future<void> resizeContent(Size size) async {
  final result = await script('get size of window 1');
  final frame = result.stdout
      .toString()
      .trim()
      .split(',')
      .map((s) => double.parse(s.trim()))
      .toList();
  final view = WidgetsBinding.instance.platformDispatcher.views.single;
  final chrome = frame[1] - view.physicalSize.height / view.devicePixelRatio;
  await input(
    'set size of window 1 to {${size.width.round()}, ${(size.height + chrome).round()}}',
  );
  check(
    (view.physicalSize.width / view.devicePixelRatio - size.width).abs() < 2 &&
        (view.physicalSize.height / view.devicePixelRatio - size.height).abs() <
            2,
    'Native content resize did not reach $size',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('PEAK_LIST_NATIVE_TRACE_KEYS')) {
    HardwareKeyboard.instance.addHandler((event) {
      stdout.writeln('Native key $event');
      if (event.logicalKey == LogicalKeyboardKey.keyF &&
          has('peak-list-peak-search-input')) {
        final context = element('peak-list-peak-search-input');
        var navigator = Navigator.maybeOf(context);
        stdout.writeln(
          'Find eligibility meta=${HardwareKeyboard.instance.isMetaPressed} ticker=${TickerMode.valuesOf(context).enabled} route=${ModalRoute.of(context)?.isCurrent}/${ModalRoute.of(context)?.willHandlePopInternally}',
        );
        while (navigator != null) {
          stdout.writeln(
            'Parent route=${ModalRoute.of(navigator.context)?.isCurrent}/${ModalRoute.of(navigator.context)?.willHandlePopInternally}',
          );
          navigator = navigator.context
              .findAncestorStateOfType<NavigatorState>();
        }
      }
      return false;
    });
  }
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = (details) {
    errors.add(details);
    FlutterError.presentError(details);
  };
  final scene = GlobalKey<_SceneState>();
  final tasmap = await TestTasmapRepository.create(maps: []);
  final peaks = PeakRepository.test(
    InMemoryPeakStorage([
      Peak(
        osmId: 1,
        name: 'Native Peak',
        latitude: -41,
        longitude: 146,
        difficulty: 'Easy',
      ),
    ]),
  );
  runApp(
    ProviderScope(
      overrides: [
        peakRepositoryProvider.overrideWithValue(peaks),
        tasmapRepositoryProvider.overrideWithValue(tasmap),
      ],
      child: _Scene(key: scene),
    ),
  );
  try {
    await settle();
    await input(
      'repeat 50 times\nif (count of windows) > 0 then exit repeat\ndelay 0.2\nend repeat\nset position of window 1 to {0, 25}\nset size of window 1 to {1680, 1100}',
    );
    final state = scene.currentState!;
    for (final size in [const Size(1280, 960), const Size(1600, 1000)]) {
      for (final scale in [1.0, 2.0]) {
        state.update(() {
          state.size = size;
          state.scale = scale;
          state.mode = PeakListPeakDialogMode.add;
          state.filter = false;
        });
        await resizeContent(size);
        await settle();
        await click('peak-list-peak-search-input');
        await input('keystroke "Native"');
        await click('peak-multi-select-checkbox-1');
        check(
          has('peak-selected-points-1'),
          'Native checkbox did not select peak',
        );
        await commandF();
        stdout.writeln(
          'Cmd+F query=${field('peak-list-peak-search-input').controller!.value} focus=${field('peak-list-peak-search-input').focusNode!.hasFocus}',
        );
        check(
          field('peak-list-peak-search-input').controller!.selection.textInside(
                field('peak-list-peak-search-input').controller!.text,
              ) ==
              'Native',
          'Local Cmd+F failed',
        );
        await commandF();
        check(
          field(
                'peak-list-peak-search-input',
              ).controller!.selection.baseOffset ==
              0,
          'Repeated native Cmd+F failed',
        );
        await click('peak-selected-points-up');
        check(
          field('peak-selected-points-1').controller!.text == '2',
          'Native Points increment failed',
        );
        state.update(() {
          state.mode = PeakListPeakDialogMode.edit;
        });
        await settle();
        await commandF();
        await click('peak-list-peak-duration');
        await input('keystroke "tomorrow"');
        await click('peak-list-peak-save');
        check(has('peak-list-peak-duration-error'), 'Duration error missing');
        await click('peak-list-peak-points');
        check(has('shared-dropdown-menu'), 'Points menu not open');
        await input('key code 36');
        check(
          !has('shared-dropdown-menu') && has('peak-list-peak-dialog'),
          'Immediate Enter cascaded',
        );
        state.update(() {
          state.size = size == const Size(1280, 960)
              ? const Size(1600, 1000)
              : const Size(1280, 960);
        });
        await resizeContent(state.size);
        await settle();
        check(
          field('peak-list-peak-duration').controller!.text == 'tomorrow',
          'Resize lost edit',
        );
        state.update(() {
          state.filter = true;
          state.difficulty = const PeakDifficultyFilterOption(
            region: 'slovenia',
            difficulty: 'T4',
          );
        });
        await settle();
        await click('map-metadata-filter-difficulty-trigger');
        check(
          has('map-metadata-filter-difficulty-unavailable'),
          'Retained choice missing',
        );
        await input('key code 125\nkey code 36');
        check(
          state.difficulty == null,
          'Unavailable navigation did not start at Any',
        );
        await click('map-metadata-filter-rating-trigger');
        check(has('shared-dropdown-menu'), 'Rating menu not open');
        state.update(() {
          state.size = size;
        });
        await resizeContent(size);
        await settle();
        await input('key code 53');
        check(!has('shared-dropdown-menu'), 'Resized menu did not dismiss');
        stdout.writeln(
          'PASS Peak List native fields $size scale=$scale; Cmd+F=verified',
        );
      }
    }
    await click('open-import');
    await click('peak-list-select-file');
    await click('peak-list-name-field');
    await input('keystroke "Native list"');
    await click('peak-list-import-button');
    check(
      has('peak-list-import-error'),
      'Failed starter did not retain actionable error',
    );
    check(
      field('peak-list-name-field').controller!.text == 'Native list',
      'Import lost name',
    );
    await click('peak-list-import-cancel');
    check(!has('peak-list-import-dialog'), 'Idle Cancel failed');
    check(errors.isEmpty, 'Flutter rendering errors: ${errors.length}');
    stdout.writeln('PASS native import recovery; no Flutter errors.');
    exit(0);
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
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
  bool filter = false;
  PeakListPeakDialogMode mode = PeakListPeakDialogMode.add;
  PeakDifficultyFilterOption? difficulty = const PeakDifficultyFilterOption(
    region: 'slovenia',
    difficulty: 'T4',
  );
  final repository = PeakListRepository.test(InMemoryPeakListStorage());
  void update(VoidCallback change) => setState(change);
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: MyTheme.dark,
    builder: (context, child) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: size, textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => filter
            ? Column(
                children: [
                  Flexible(
                    child: SizedBox(
                      width: 360,
                      child: MapMetadataFilterPopup(
                        ratingFilter: PeakRatingFilterOption.any,
                        difficultyFilter: difficulty,
                        durationFilter: PeakDurationFilterOption.any,
                        difficultyOptions: const [
                          PeakDifficultyFilterOption(
                            region: 'tasmania',
                            difficulty: 'Easy',
                          ),
                        ],
                        onSelectDifficultyFilter: (value) =>
                            update(() => difficulty = value),
                        onSelectRatingFilter: (_) {},
                        onSelectDurationFilter: (_) {},
                        onClearFilters: () {},
                        onClose: () {},
                      ),
                    ),
                  ),
                  FilledButton(
                    key: const Key('open-import'),
                    onPressed: () => showPeakListImportDialog(
                      context: context,
                      filePicker: TestPeakListFilePicker(
                        selectedFilePath: '/fixture/peaks.csv',
                      ),
                      duplicateNameChecker: (_) async => false,
                      onImport: ({required listName, required csvPath}) async =>
                          throw StateError('fixture failure'),
                    ),
                    child: const Text('Import'),
                  ),
                ],
              )
            : PeakListPeakDialog(
                key: ValueKey(mode),
                mode: mode,
                peakList: PeakList(peakListId: 1, name: 'Fixture'),
                peakListRepository: repository,
                peakItems: const [],
                ascentRows: const [],
                points: 3,
                peak: mode == PeakListPeakDialogMode.edit
                    ? Peak(
                        osmId: 1,
                        name: 'Native Peak',
                        latitude: -41,
                        longitude: 146,
                      )
                    : null,
              ),
      ),
    ),
  );
}
