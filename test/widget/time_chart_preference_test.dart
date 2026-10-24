import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/router.dart' as app_router;
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:peak_bagger/providers/dashboard_readiness_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/time_chart_type_provider.dart';
import 'package:peak_bagger/screens/dashboard_screen.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/performance_measurement.dart';
import 'package:peak_bagger/widgets/dashboard/summary_chart.dart';
import 'package:peak_bagger/widgets/dashboard/time_card.dart';
import 'package:peak_bagger/widgets/dashboard/dashboard_preference_feedback.dart';
import 'package:peak_bagger/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/mapping_catalog_fixture.dart';
import '../harness/test_map_notifier.dart';
import '../harness/time_chart_preference_storage.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer createContainer(
    TestTimeChartPreferenceStorage storage, {
    List<Map<String, Object?>>? events,
    TestMapNotifier? map,
  }) {
    final container = ProviderContainer(
      overrides: [
        ...mappingCatalogTestOverrides,
        timeChartPreferenceStorageProvider.overrideWithValue(storage),
        mapProvider.overrideWith(
          () =>
              map ??
              TestMapNotifier(
                const MapState(
                  center: LatLng(-41.5, 146.5),
                  zoom: 10,
                  basemap: Basemap.tracestrack,
                ),
              ),
        ),
        peakRepositoryProvider.overrideWithValue(
          PeakRepository.test(InMemoryPeakStorage()),
        ),
        mapDashboardLoadProvider.overrideWith(_LoadedMap.new),
        if (events != null)
          performanceMeasurementProvider.overrideWithValue(
            PerformanceMeasurement(sink: events.add),
          ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> pumpDashboard(
    WidgetTester tester,
    ProviderContainer container, {
    bool active = true,
    bool mounted = true,
    bool short = false,
    ThemeData? theme,
  }) async {
    await tester.binding.setSurfaceSize(
      short ? const Size(1024, 240) : const Size(1600, 1000),
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: (theme ?? MyTheme.dark).copyWith(
            platform: TargetPlatform.macOS,
          ),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: TickerMode(
              enabled: active,
              child: Offstage(
                offstage: !active,
                child: mounted
                    ? DashboardScreen(now: DateTime(2026, 10, 15))
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final theme in [MyTheme.dark]) {
    testWidgets(
      'pending/read failure/exact pointer Retry at enlarged text ${theme.brightness}',
      (tester) async {
        final read = Completer<String?>();
        final retry = Completer<String?>();
        final storage = TestTimeChartPreferenceStorage()
          ..readSteps.addAll([() => read.future, () => retry.future]);
        final events = <Map<String, Object?>>[];
        final container = createContainer(storage, events: events);
        await pumpDashboard(tester, container, theme: theme);
        expect(find.byKey(const Key('time-loading-state')), findsOneWidget);
        expect(find.text('No time data yet'), findsNothing);
        expect(find.byKey(const Key('time-chart-type-button')), findsNothing);
        expect(_readyEvents(events), isEmpty);
        read.completeError(StateError('private read diagnostic'));
        await tester.pumpAndSettle();
        expect(
          find.text('Couldn’t load Time chart preference.'),
          findsOneWidget,
        );
        expect(find.text('private read diagnostic'), findsNothing);
        expect(find.text('No time data yet'), findsOneWidget);
        expect(_readyEvents(events), isEmpty);
        expect(
          events.where(
            (e) =>
                e['event'] == 'dashboard.dependency.failed' &&
                e['dependency'] == 'time-chart-preference',
          ),
          hasLength(1),
        );
        final state = container.read(timeChartTypeProvider);
        expect(state.warning!.presented, isTrue);
        expect(state.visibleWarningId, state.warning!.id);
        final action = find.byKey(const Key('time-preference-retry'));
        final button = tester.widget<TextButton>(action);
        expect(button.focusNode!.skipTraversal, isTrue);
        expect(MediaQuery.textScalerOf(tester.element(action)).scale(1), 1.5);
        // Pointer Retry uses exactly the same operation path as future card R.
        await tester.tap(action);
        await tester.pump();
        container
            .read(timeChartTypeProvider.notifier)
            .retryWarning(state.warning!.id);
        expect(storage.reads, 2);
        retry.complete('line');
        await tester.pumpAndSettle();
        expect(
          container.read(timeChartTypeProvider).selected,
          TimeChartType.line,
        );
        expect(find.text('Couldn’t load Time chart preference.'), findsNothing);
        expect(_readyEvents(events), hasLength(1));
        final write = Completer<bool>();
        storage.writeSteps.add(() => write.future);
        final saving = container
            .read(timeChartTypeProvider.notifier)
            .select(TimeChartType.clusteredColumn);
        await tester.pump();
        expect(
          find.byKey(const Key('time-preference-pending')),
          findsOneWidget,
        );
        write.complete(false);
        await saving;
        await tester.pumpAndSettle();
        expect(
          find.text('Couldn’t save Time chart preference.'),
          findsOneWidget,
        );
        expect(
          container.read(timeChartTypeProvider).selected,
          TimeChartType.clusteredColumn,
        );
        await tester.tap(find.byKey(const Key('time-preference-retry')));
        await tester.pumpAndSettle();
        expect(storage.stored, 'clustered-column');
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'saved type and summary paint only after actual read completion',
    (tester) async {
      final gate = Completer<String?>();
      final storage = TestTimeChartPreferenceStorage()
        ..readSteps.add(() => gate.future);
      final events = <Map<String, Object?>>[];
      final map = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 10,
          basemap: Basemap.tracestrack,
          // No geometry: the latest-walk preview does not request live tiles.
          tracks: [
            GpxTrack(
              contentHash: 'time',
              trackName: 'Time fixture',
              trackDate: DateTime(2026, 10, 15),
              totalTimeMillis: 18000000,
              movingTime: 14400000,
            ),
          ],
        ),
      );
      final container = createContainer(storage, events: events, map: map);
      await pumpDashboard(tester, container);
      final card = find.byKey(const Key('dashboard-card-time'));
      expect(
        find.descendant(of: card, matching: find.byType(SummaryChart)),
        findsNothing,
      );
      expect(
        find.descendant(of: card, matching: find.text('Total: 0d 5h 0m')),
        findsNothing,
      );
      gate.complete('clustered-column');
      await tester.pumpAndSettle();
      final chart = tester.widget<SummaryChart>(
        find.descendant(of: card, matching: find.byType(SummaryChart)),
      );
      expect(chart.barSeriesStyle, SummaryBarSeriesStyle.grouped);
      expect(
        find.descendant(of: card, matching: find.text('Total: 0d 5h 0m')),
        findsOneWidget,
      );
      expect(_readyEvents(events), hasLength(1));
      // Track loading still takes precedence over empty/header presentation.
      map.setLoadingTracks(true);
      await tester.pump();
      expect(find.byKey(const Key('time-loading-state')), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text('Total: 0d 5h 0m')),
        findsNothing,
      );
      expect(find.text('No time data yet'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offstage failure delivered once next active with Time never constructed',
    (tester) async {
      final gate = Completer<String?>();
      final storage = TestTimeChartPreferenceStorage()
        ..readSteps.add(() => gate.future);
      final container = createContainer(storage);
      await container.read(dashboardLayoutProvider.notifier).setOrder([
        ...dashboardDefaultCardOrder.where((id) => id != 'time'),
        'time',
      ]);
      await pumpDashboard(tester, container, active: false, short: true);
      gate.completeError(StateError('offstage read'));
      await tester.pumpAndSettle();
      expect(find.byType(TimeCard, skipOffstage: false), findsNothing);
      expect(find.byType(SnackBar, skipOffstage: false), findsNothing);
      expect(container.read(timeChartTypeProvider).warning!.presented, isFalse);
      await pumpDashboard(tester, container, short: true);
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t load Time chart preference.'), findsOneWidget);
      expect(find.byType(TimeCard), findsNothing);
      final id = container.read(timeChartTypeProvider).warning!.id;
      await pumpDashboard(tester, container, active: false, short: true);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar, skipOffstage: false), findsNothing);
      expect(container.read(timeChartTypeProvider).visibleWarningId, isNull);
      await pumpDashboard(tester, container, mounted: false, short: true);
      await pumpDashboard(tester, container, short: true);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(container.read(timeChartTypeProvider).warning!.id, id);
      expect(storage.reads, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending save survives disposed Dashboard; latest Retry persists without Time',
    (tester) async {
      final save = Completer<bool>();
      final storage = TestTimeChartPreferenceStorage('stacked-column')
        ..writeSteps.add(() => save.future);
      final container = createContainer(storage);
      await pumpDashboard(tester, container);
      await tester.pumpAndSettle();
      final controller = container.read(timeChartTypeProvider.notifier);
      final saving = controller.select(TimeChartType.line);
      await pumpDashboard(tester, container, mounted: false);
      save.complete(false);
      await saving;
      expect(container.read(timeChartTypeProvider).warning!.presented, isFalse);
      await container.read(dashboardLayoutProvider.notifier).setOrder([
        ...dashboardDefaultCardOrder.where((id) => id != 'time'),
        'time',
      ]);
      await pumpDashboard(tester, container, short: true);
      await tester.pumpAndSettle();
      expect(find.byType(TimeCard), findsNothing);
      expect(find.text('Couldn’t save Time chart preference.'), findsOneWidget);
      expect(
        container.read(timeChartTypeProvider).selected,
        TimeChartType.line,
      );
      await tester.tap(find.byKey(const Key('time-preference-retry')));
      await tester.pumpAndSettle();
      expect(storage.stored, 'line');
      expect(find.byType(SnackBar), findsNothing);
      await pumpDashboard(tester, container, mounted: false);
      await pumpDashboard(tester, container, short: true);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(storage.writes, ['line', 'line']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'success before queued presentation removes warning across remount',
    (tester) async {
      final storage = TestTimeChartPreferenceStorage()
        ..writeSteps.add(() async => false);
      final container = createContainer(storage);
      final controller = container.read(timeChartTypeProvider.notifier);
      await controller.load();
      await controller.select(TimeChartType.line);
      expect(container.read(timeChartTypeProvider).warning!.presented, isFalse);
      await controller.select(TimeChartType.clusteredColumn);
      await pumpDashboard(tester, container, short: true);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(container.read(timeChartTypeProvider).warning, isNull);
    },
  );

  testWidgets(
    'deactivation before scheduled delivery retains an unpresented warning',
    (tester) async {
      final storage = TestTimeChartPreferenceStorage();
      final container = createContainer(storage);
      await pumpDashboard(tester, container);
      await tester.pumpAndSettle();
      storage.writeSteps.add(() async => false);
      await container
          .read(timeChartTypeProvider.notifier)
          .select(TimeChartType.line);
      // There is a scheduled callback, but no warning frame has been presented.
      await pumpDashboard(tester, container, active: false);
      await tester.pumpAndSettle();
      expect(container.read(timeChartTypeProvider).warning!.presented, isFalse);
      expect(find.byType(SnackBar, skipOffstage: false), findsNothing);
      await pumpDashboard(tester, container);
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t save Time chart preference.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'navigation and reordering restore all three types without resetting browsing',
    (tester) async {
      for (final type in TimeChartType.values) {
        final storage = TestTimeChartPreferenceStorage(type.storageId);
        final container = createContainer(storage);
        await pumpDashboard(tester, container);
        await tester.pumpAndSettle();
        expect(container.read(timeChartTypeProvider).selected, type);
        await container.read(dashboardLayoutProvider.notifier).setOrder([
          'time',
          ...dashboardDefaultCardOrder.where((id) => id != 'time'),
        ]);
        await tester.pumpAndSettle();
        await pumpDashboard(tester, container, active: false);
        await pumpDashboard(tester, container);
        await tester.pumpAndSettle();
        expect(container.read(timeChartTypeProvider).selected, type);
        expect(storage.reads, 1);
        expect(storage.writes, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets(
    'menu save failure retains chart and page; browsing remains available during retry',
    (tester) async {
      final gate = Completer<bool>();
      final storage = TestTimeChartPreferenceStorage()
        ..writeSteps.addAll([
          () async => throw StateError('private save fault'),
          () => gate.future,
        ]);
      final container = ProviderContainer(
        overrides: [
          timeChartPreferenceStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: MyTheme.dark,
            home: Scaffold(
              body: SizedBox(
                width: 700,
                height: 400,
                child: DashboardPreferenceFeedback(
                  child: TimeCard(
                    isLoading: false,
                    now: DateTime(2026, 10, 15),
                    tracks: [
                      GpxTrack(
                        contentHash: 'old',
                        trackName: 'Old walk',
                        trackDate: DateTime(2025, 1, 1),
                        totalTimeMillis: 100000,
                        movingTime: 50000,
                      ),
                      GpxTrack(
                        contentHash: 'new',
                        trackName: 'New walk',
                        trackDate: DateTime(2026, 10, 15),
                        totalTimeMillis: 100000,
                        movingTime: 50000,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('summary-prev-window')));
      await tester.pumpAndSettle();
      final page = tester
          .widget<SummaryChart>(find.byType(SummaryChart))
          .buckets
          .first
          .start;
      await tester.tap(find.byKey(const Key('time-chart-type-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('time-chart-type-line')));
      await tester.pumpAndSettle();
      var chart = tester.widget<SummaryChart>(find.byType(SummaryChart));
      expect(chart.mode, SummaryDisplayMode.line);
      expect(chart.buckets.first.start, page);
      final state = container.read(timeChartTypeProvider);
      expect(state.saveOutcome!.hasError, isTrue);
      expect(find.text('Couldn’t save Time chart preference.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('time-preference-retry')));
      final retry = container
          .read(timeChartTypeProvider.notifier)
          .retryWarning(state.warning!.id);
      await tester.tap(find.byKey(const Key('summary-next-window')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      chart = tester.widget<SummaryChart>(find.byType(SummaryChart));
      expect(chart.buckets.first.start, isNot(page));
      expect(chart.mode, SummaryDisplayMode.line);
      expect(find.byKey(const Key('time-preference-pending')), findsOneWidget);
      gate.complete(true);
      await retry;
      await tester.pumpAndSettle();
      expect(storage.stored, 'line');
      // Available keyboard menu paths retain their existing behavior.
      await tester.tap(find.byKey(const Key('time-chart-type-button')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'routed offstage Dashboard delivers once and removes feedback on navigation',
    (tester) async {
      final storage = TestTimeChartPreferenceStorage();
      final container = createContainer(storage);
      final router = GoRouter(
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => shell,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const DashboardScreen(),
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/other',
                    builder: (_, _) =>
                        const Scaffold(body: Text('Other destination')),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/other');
      await tester.pumpAndSettle();
      storage.writeSteps.add(() async => false);
      await container
          .read(timeChartTypeProvider.notifier)
          .select(TimeChartType.line);
      await tester.pumpAndSettle();
      expect(find.text('Other destination'), findsOneWidget);
      expect(find.byType(SnackBar, skipOffstage: false), findsNothing);
      expect(container.read(timeChartTypeProvider).warning!.presented, isFalse);
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t save Time chart preference.'), findsOneWidget);
      expect(container.read(timeChartTypeProvider).visibleWarningId, isNotNull);
      router.go('/other');
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar, skipOffstage: false), findsNothing);
      expect(container.read(timeChartTypeProvider).visibleWarningId, isNull);
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'app bootstrap owns the preference without rebuilding the router on changes',
    (tester) async {
      final storage = TestTimeChartPreferenceStorage();
      final container = createContainer(storage);
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pumpAndSettle();
      final router = app_router.router;
      addTearDown(router.dispose);
      await container
          .read(timeChartTypeProvider.notifier)
          .select(TimeChartType.line);
      await tester.pumpAndSettle();
      expect(app_router.router, same(router));
      expect(storage.reads, 1);
      expect(storage.stored, 'line');
      expect(tester.takeException(), isNull);
    },
  );
}

Iterable<Map<String, Object?>> _readyEvents(
  List<Map<String, Object?>> events,
) => events.where((e) => e['event'] == 'dashboard.local_data_ready.frame');

class _LoadedMap extends MapDashboardLoadNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);
}
