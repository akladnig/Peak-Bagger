// Isolated macOS render/input probe; no app startup, Store or network.
// flutter run -d macos -t test/harness/verify_map_fields.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route.dart' as domain;
import 'package:peak_bagger/screens/map_screen_panels.dart';
import 'package:peak_bagger/services/map_name_resolution.dart';
import 'package:peak_bagger/services/map_search_service.dart';
import 'package:peak_bagger/services/peak_info_content_resolver.dart';
import 'package:peak_bagger/services/track_date_query_parser.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/map_search_popup.dart';

int _pointerDowns = 0;
Offset? _lastPointer;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = (details) {
    errors.add(details);
    FlutterError.presentError(details);
  };
  final key = GlobalKey<_SceneState>();
  Future<ProcessResult> script(
    String body,
  ) => Process.run('/usr/bin/osascript', [
    '-e',
    'tell application "System Events" to tell (first application process whose unix id is $pid)\n$body\nend tell',
  ]);
  Future<void> input(String body) async {
    final result = await script('set frontmost to true\ndelay 0.1\n$body');
    _check(result.exitCode == 0, 'OS input failed: ${result.stderr}');
    await _settle();
  }

  Future<void> click(String key) async {
    await Scrollable.ensureVisible(
      _element(key),
      duration: const Duration(milliseconds: 100),
    );
    await _settle();
    final result = await script('get {position of window 1, size of window 1}');
    final frame = result.stdout
        .toString()
        .trim()
        .split(',')
        .map((s) => double.parse(s.trim()))
        .toList();
    final view = WidgetsBinding.instance.platformDispatcher.views.single;
    final box = _element(key).findRenderObject()! as RenderBox;
    final point = box.localToGlobal(box.size.center(Offset.zero));
    final x = frame[0] + point.dx;
    final y =
        frame[1] +
        frame[3] -
        view.physicalSize.height / view.devicePixelRatio +
        point.dy;
    await script('set frontmost to true\ndelay 0.2');
    final before = _pointerDowns;
    stdout.writeln('Native click $key content=$point screen=($x,$y)');
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
    _check(pointer.exitCode == 0, 'OS pointer failed: ${pointer.stderr}');
    await _wait(
      () => _pointerDowns > before,
      'OS pointer down was not delivered for $key',
    );
    _check(
      (_lastPointer! - point).distance < 3,
      'OS pointer missed $key: $_lastPointer versus $point',
    );
    await _settle();
  }

  runApp(_Scene(key: key));
  try {
    await _settle();
    await input(
      'set position of window 1 to {0, 25}\nset size of window 1 to {1680, 1100}',
    );
    final state = key.currentState!;
    var count = 0;
    const resizeOnly = bool.fromEnvironment('MAP_FIELDS_RESIZE_ONLY');
    for (final size
        in resizeOnly
            ? <Size>[]
            : [const Size(1280, 960), const Size(1600, 1000)]) {
      for (final theme in [MyTheme.dark]) {
        for (final scale in [1.0, 2.0]) {
          state.update(() {
            state.size = size;
            state.theme = theme;
            state.scale = scale;
            state.panels = false;
          });
          await _settle();
          _check(
            (_element('map-field-content').findRenderObject()! as RenderBox)
                    .size ==
                size,
            'Scene size mismatch',
          );
          await click('map-search-date-trigger');
          await click('map-search-date-start-year');
          final year = _textField('map-search-date-start-year');
          year.controller!.selection = TextSelection(
            baseOffset: 0,
            extentOffset: year.controller!.text.length,
          );
          await input('keystroke "10000"\nkey code 36');
          await _wait(
            () => _containsText('Enter a year from 1 to 9999'),
            'Year error not rendered',
          );
          _check(
            (_element('map-search-date-start-calendar-label').widget as Text)
                    .data ==
                'Jul 2024',
            'Invalid navigation changed calendar',
          );
          await click('map-search-date-start-month');
          await _wait(() => _has('shared-dropdown-menu'), 'Month did not open');
          await input('key code 36');
          await _wait(
            () => !_has('shared-dropdown-menu'),
            'Immediate Return did not dismiss',
          );
          _check(
            _has('map-search-date-picker'),
            'Month dismissal closed picker',
          );
          await click('map-search-date-start-month');
          await _wait(
            () => _has('shared-dropdown-menu'),
            'Pointer Month did not open',
          );
          await click('map-search-date-start-month-8');
          await _wait(
            () => !_has('shared-dropdown-menu'),
            'Pointer selection did not close Month',
          );
          _check(
            _has('map-search-date-picker'),
            'Pointer selection cascaded into picker dismissal',
          );
          _check(
            (_element('map-search-date-start-calendar-label').widget as Text)
                    .data ==
                'Aug 2024',
            'Pointer Month did not navigate',
          );
          await click('map-search-date-start-month');
          await _wait(
            () => _has('shared-dropdown-menu'),
            'Outside gesture menu did not open',
          );
          await click('map-search-entity-natural');
          await _wait(
            () => !_has('shared-dropdown-menu'),
            'Outside gesture did not dismiss menu',
          );
          _check(
            _has('map-search-date-picker'),
            'Consumed outside gesture dismissed picker',
          );
          await click('map-search-date-apply');
          await _wait(
            () => !_has('map-search-date-picker'),
            'Apply did not close',
          );
          _check(
            state.range.start == const TrackCalendarDay(2024, 7, 28),
            'Invalid Year changed selected date',
          );
          state.update(() => state.panels = true);
          await _settle();
          await click('peak-info-popup-edit');
          await _wait(
            () => _has('peak-info-popup-name'),
            'Peak edit did not open',
          );
          final name = _textField('peak-info-popup-name');
          name.controller!.text = 'Unsaved native peak';
          await click('route-walking-speed-field');
          final speed = _textField('route-walking-speed-field');
          speed.controller!.selection = TextSelection(
            baseOffset: 0,
            extentOffset: speed.controller!.text.length,
          );
          await input('keystroke "11"\nkey code 36');
          await _wait(
            () => _has('route-walking-speed-error'),
            'Walking Speed error not rendered',
          );
          _check(
            state.route.walkingSpeedKmh == 4,
            'Invalid Walking Speed persisted',
          );
          state.update(() => state.theme = MyTheme.dark);
          await _settle();
          _check(
            name.controller!.text == 'Unsaved native peak',
            'Theme lost Peak draft',
          );
          _check(errors.isEmpty, 'Native framework errors: ${errors.length}');
          count++;
          stdout.writeln(
            'PASS native Map fields $size ${theme.brightness.name} seed=${theme.seedColor.toARGB32()} scale=$scale',
          );
        }
      }
    }
    state.update(() {
      state.panels = false;
      state.scale = 2;
      state.size = const Size(1280, 960);
    });
    await _settle();
    final query = _textField('map-search-input').controller!;
    query.text = 'Unsaved native query';
    for (final size in [
      const Size(1280, 960),
      const Size(1600, 1000),
      const Size(1280, 960),
    ]) {
      await click('map-search-group-button');
      await _wait(
        () => _has('shared-dropdown-menu'),
        'Resize menu did not open',
      );
      final frameResult = await script('get size of window 1');
      final frame = frameResult.stdout
          .toString()
          .trim()
          .split(',')
          .map((s) => double.parse(s.trim()))
          .toList();
      final view = WidgetsBinding.instance.platformDispatcher.views.single;
      final currentSize = view.physicalSize / view.devicePixelRatio;
      final width = (frame[0] + size.width - currentSize.width).round();
      final height = (frame[1] + size.height - currentSize.height).round();
      await input('set size of window 1 to {$width, $height}');
      await _wait(() {
        final actual = view.physicalSize / view.devicePixelRatio;
        return (actual.width - size.width).abs() < 2 &&
            (actual.height - size.height).abs() < 2;
      }, 'Native content resize failed');
      state.update(() {
        state.size = size;
        state.theme = MyTheme.dark;
      });
      await _settle();
      _check(query.text == 'Unsaved native query', 'Resize/theme lost query');
      if (_has('shared-dropdown-menu')) {
        await input('key code 53');
        await _wait(
          () => !_has('shared-dropdown-menu'),
          'Resize left an orphan menu',
        );
      }
      _check(errors.isEmpty, 'Resize framework errors');
    }
    stdout.writeln(
      'PASS native resize/open menu/theme/raw query 1280x960 -> 1600x1000 -> 1280x960',
    );
    runApp(const SizedBox.shrink());
    await _settle();
    _check(errors.isEmpty, 'Cleanup framework errors');
    stdout.writeln(
      'PASS $count native Map configurations; Year/menu/Apply/Peak draft/Walking Speed input',
    );
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
  ThemeData theme = MyTheme.dark;
  double scale = 1;
  bool panels = false;
  final searchFocus = FocusNode();
  final route = domain.Route(
    name: 'Native route',
    walkingSpeedKmh: 4,
    gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.51, 146.51)],
    gpxRouteElevations: const [100, 120],
  );
  final peak = Peak(
    osmId: 1,
    name: 'Native peak',
    latitude: -41.5,
    longitude: 146.5,
    elevation: 1200,
  );
  TrackDateRange range = const TrackDateRange(
    start: TrackCalendarDay(2024, 7, 28),
    end: TrackCalendarDay(2024, 7, 28),
  );
  void update(VoidCallback action) => setState(action);
  @override
  void dispose() {
    searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) => Listener(
      onPointerDown: (event) {
        _pointerDowns++;
        _lastPointer = event.position;
      },
      child: child,
    ),
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            key: const Key('map-field-content'),
            body: panels
                ? SingleChildScrollView(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 360,
                          child: PeakInfoPopupCard(
                            key: const Key('native-peak-card'),
                            content: PeakInfoContent(
                              peak: peak,
                              mapName: 'Tasmania',
                              mapNameOrigin: MapNameOrigin.region,
                              listNames: const [],
                              ascentRows: const [],
                            ),
                            onClose: () {},
                            onEdit: () {},
                            onSaveEdit: (_) async => null,
                          ),
                        ),
                        SizedBox(
                          width: 520,
                          child: MapTrackInfoPanel(
                            route: route,
                            onClose: () {},
                            onRouteWalkingSpeedChanged: (value) =>
                                setState(() => route.walkingSpeedKmh = value),
                          ),
                        ),
                      ],
                    ),
                  )
                : Align(
                    alignment: Alignment.topCenter,
                    child: MapSearchPopup(
                      focusNode: searchFocus,
                      searchResults: const [],
                      isLoadingMore: false,
                      isExhausted: true,
                      searchQuery: '',
                      trackDateRange: range,
                      categories: MapSearchService.defaultCategories,
                      selectedRegionKey: null,
                      sort: MapSearchSort.nameAscending,
                      group: MapSearchGroup.none,
                      availableRegions: const [],
                      onChanged: (_) {},
                      onToggleCategory: (_) {},
                      onSelectTrackDateRange: (value) {
                        if (value != null) setState(() => range = value);
                      },
                      onSelectRegionKey: (_) {},
                      onSelectSort: (_) {},
                      onSelectGroup: (_) {},
                      onLoadMore: () {},
                      onClose: () {},
                      onSelectResult: (_) {},
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 250));
Future<void> _wait(bool Function() condition, String message) async {
  for (var i = 0; i < 100; i++) {
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
bool _containsText(String text) => _find(
  (e) => e.widget is Text && (e.widget as Text).data == text,
).isNotEmpty;
TextField _textField(String key) {
  TextField? field;
  void visit(Element e) {
    if (e.widget is TextField) field = e.widget as TextField;
    e.visitChildren(visit);
  }

  visit(_element(key));
  return field!;
}

List<Element> _find(bool Function(Element) predicate) {
  final matches = <Element>[];
  void visit(Element e) {
    if (predicate(e)) matches.add(e);
    e.visitChildren(visit);
  }

  visit(WidgetsBinding.instance.rootElement!);
  return matches;
}
