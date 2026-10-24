// Real Dashboard grid with deterministic local data; no production startup/Store.
// flutter run -d macos -t test/harness/verify_time_card_layout.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/track_date_status.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/time_chart_type_provider.dart';
import 'package:peak_bagger/screens/dashboard_screen.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/dashboard/dashboard_card_keyboard.dart';
import 'package:peak_bagger/widgets/dashboard/summary_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mapping_catalog_fixture.dart';
import 'test_map_notifier.dart';
import 'time_chart_preference_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({
    dashboardCardOrderStorageKey: [
      'time',
      ...dashboardDefaultCardOrder.where((id) => id != 'time'),
    ],
  });
  final errors = <FlutterErrorDetails>[];
  FlutterError.onError = (details) {
    errors.add(details);
    FlutterError.presentError(details);
  };
  const duration =
      123456 * Duration.millisecondsPerDay +
      23 * Duration.millisecondsPerHour +
      59 * Duration.millisecondsPerMinute;
  final container = ProviderContainer(
    overrides: [
      ...mappingCatalogTestOverrides,
      timeChartPreferenceStorageProvider.overrideWithValue(
        TestTimeChartPreferenceStorage(),
      ),
      mapProvider.overrideWith(
        () => TestMapNotifier(
          MapState(
            center: const LatLng(-41.5, 146.5),
            zoom: 10,
            basemap: Basemap.tracestrack,
            tracks: [
              GpxTrack(
                gpxTrackId: 1,
                contentHash: 'native-time-layout',
                trackName: 'Fixture',
                trackDate: DateTime.utc(2026, 10, 15),
                trackDateStatus: TrackDateStatus.resolved,
                totalTimeMillis: duration,
                movingTime: duration,
              ),
            ],
          ),
        ),
      ),
      peakListRepositoryProvider.overrideWithValue(
        PeakListRepository.test(InMemoryPeakListStorage()),
      ),
      peaksBaggedRepositoryProvider.overrideWithValue(
        PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
      ),
    ],
  );
  final scale = ValueNotifier(1.0);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MyTheme.dark,
        home: ValueListenableBuilder(
          valueListenable: scale,
          builder: (context, value, _) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(value)),
            child: DashboardScreen(now: DateTime(2026, 10, 15)),
          ),
        ),
      ),
    ),
  );
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

  Future<void> wheel(int delta) async {
    final frame = (await script('get {position of window 1, size of window 1}'))
        .stdout
        .toString()
        .trim()
        .split(',')
        .map((v) => double.parse(v.trim()))
        .toList();
    final view = WidgetsBinding.instance.platformDispatcher.views.single;
    final box = _element('time-card-viewport').findRenderObject()! as RenderBox;
    final point = box.localToGlobal(box.size.center(Offset.zero));
    final result = await Process.run('/usr/bin/swift', [
      '-e',
      '''
import CoreGraphics
import Darwin
let point = CGPoint(x: ${frame[0] + point.dx}, y: ${frame[1] + frame[3] - view.physicalSize.height / view.devicePixelRatio + point.dy})
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(100000)
CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: $delta, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
''',
    ]);
    _check(result.exitCode == 0, 'Native wheel failed: ${result.stderr}');
    await _settle();
  }

  try {
    await _settle();
    await input(
      'set position of window 1 to {0, 25}\nset size of window 1 to {1680, 1100}',
    );
    final view = WidgetsBinding.instance.platformDispatcher.views.single;
    final initialFrame = (await script('get size of window 1')).stdout
        .toString()
        .trim()
        .split(',')
        .map((v) => double.parse(v.trim()))
        .toList();
    final chrome =
        initialFrame[1] - view.physicalSize.height / view.devicePixelRatio;
    for (final size in [const Size(1280, 960), const Size(1600, 1000)]) {
      for (final value in [1.0, 1.5, 2.0]) {
        await input(
          'set size of window 1 to {${size.width.round()}, ${(size.height + chrome).round()}}',
        );
        scale.value = value;
        await _settle();
        final actual = view.physicalSize / view.devicePixelRatio;
        _check(
          actual == size,
          'Native content size $actual differs from $size',
        );
        final owner = _descendants<DashboardCardKeyboard>(
          _element('dashboard-card-time'),
        ).single.controller;
        owner.focus();
        await _settle();
        final current = _descendants<SummaryChart>(
          _element('time-card-viewport'),
        ).single.period.index;
        await input('keystroke "p"');
        for (var i = current; i < SummaryPeriodPreset.allTime.index; i++) {
          await input('key code 125');
        }
        await input('key code 36');
        final viewport = _element('time-card-viewport');
        final scroll = Scrollable.of(
          _element('dashboard-card-time-drag-handle'),
        ).position;
        final outerSize =
            (_element('dashboard-card-time').findRenderObject()! as RenderBox)
                .size;
        for (final type in TimeChartType.values) {
          await container.read(timeChartTypeProvider.notifier).select(type);
          await _settle();
          if (scroll.maxScrollExtent > 0) {
            await wheel(1600);
            _check(
              scroll.pixels == 0,
              'Native upward wheel did not reach header',
            );
            await wheel(-1600);
            _check(
              scroll.pixels == scroll.maxScrollExtent,
              'Native downward wheel did not reach chart',
            );
          }
          owner.focus();
          await _settle();
          if (scroll.maxScrollExtent > 0) {
            await input(
              'key code 116',
            ); // Page Up scrolls card content, not calendar.
            _check(
              scroll.pixels < scroll.maxScrollExtent,
              'Page Up did not reveal content',
            );
            await input('key code 121'); // Page Down
            _check(
              scroll.pixels == scroll.maxScrollExtent,
              'Page Down did not reveal chart',
            );
          }
          await input('key code 123'); // Inspect/reveal with Left.
          final chart = _descendants<SummaryChart>(viewport).single;
          final chartElement = _element('time-scroll-view');
          final plot = chartElement.findRenderObject()! as RenderBox;
          final card =
              _element('dashboard-card-time').findRenderObject()! as RenderBox;
          _check(
            plot.size.height >= SummaryChart.minimumUsableHeight(chartElement),
            'Chart lost minimum height',
          );
          _check(
            (plot.localToGlobal(Offset.zero).dy + plot.size.height) <=
                card.localToGlobal(Offset.zero).dy + card.size.height + 1,
            'Chart not reachable',
          );
          _check(
            chart.period == SummaryPeriodPreset.allTime,
            'Scroll/resize changed calendar page',
          );
          _check(card.size == outerSize, 'Chart type changed card geometry');
          await input('keystroke "c"');
          await input('key code 36');
          _check(
            container.read(timeChartTypeProvider).selected == type,
            'Unchanged menu changed preference',
          );
          _check(errors.isEmpty, '${errors.length} framework errors');
        }
        stdout.writeln(
          'PASS native Time overflow $size scale=$value all chart types; wheel/keyboard/menu reachability',
        );
      }
    }
    stdout.writeln(
      'PASS Time layout native verification; no human visual acceptance claimed',
    );
    runApp(const SizedBox.shrink());
    await _settle();
    container.dispose();
    scale.dispose();
    exit(0);
  } catch (error, stack) {
    stderr.writeln('FAIL Time layout: $error\n$stack');
    exit(1);
  }
}

Iterable<T> _descendants<T extends Widget>(Element root) sync* {
  final values = <T>[];
  void visit(Element element) {
    if (element.widget is T) values.add(element.widget as T);
    element.visitChildren(visit);
  }

  visit(root);
  yield* values;
}

Element _element(String key) {
  Element? result;
  void visit(Element element) {
    if (element.widget.key == ValueKey(key)) result = element;
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return result ?? (throw StateError('Missing element $key'));
}

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 350));
  await WidgetsBinding.instance.endOfFrame;
}

void _check(bool value, String message) {
  if (!value) throw StateError(message);
}
