import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/track_date_status.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/summary_page_controller.dart';
import 'package:peak_bagger/providers/time_chart_type_provider.dart';
import 'package:peak_bagger/screens/dashboard_screen.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/dashboard/dashboard_card_keyboard.dart';
import 'package:peak_bagger/widgets/dashboard/summary_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/mapping_catalog_fixture.dart';
import '../harness/dashboard_order_writer.dart';
import '../harness/test_map_notifier.dart';
import '../harness/time_chart_preference_storage.dart';
import '../harness/summary_chart_controls.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final theme in [MyTheme.dark]) {
    testWidgets(
      'keyboard reorder retains/reveals ID and full traversal ${theme.brightness}',
      (tester) async {
        final writer = ControlledDashboardOrderWriter();
        final h = await _Harness.pump(
          tester,
          theme: theme,
          scale: 1.5,
          size: const Size(1400, 520),
          orderWriter: writer,
        );
        expect(h.card('my-ascents'), findsNothing);
        await h.focus('elevation');
        await h.reorder(forward: false);
        expect(writer.writes, isEmpty);
        for (var i = 1; i < dashboardCards.length; i++) {
          await h.reorder(forward: true);
          expect(
            h.container.read(dashboardLayoutProvider).indexOf('elevation'),
            i,
          );
          h.expectFocus('elevation');
          expect(h.card('elevation').hitTestable(), findsOneWidget);
          expect(h.border('elevation').color, theme.colorScheme.primary);
          expect(
            MediaQuery.textScalerOf(
              tester.element(h.card('elevation')),
            ).scale(1),
            1.5,
          );
        }
        expect(writer.writes, hasLength(7));
        await h.reorder(forward: true);
        expect(writer.writes, hasLength(7));
        // Overlap repeats with reconstruction instead of waiting after each move.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        for (var i = 0; i < 4; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pumpAndSettle();
        expect(
          h.container.read(dashboardLayoutProvider).indexOf('elevation'),
          3,
        );
        h.expectFocus('elevation');
        final order = h.container.read(dashboardLayoutProvider);
        for (var i = 0; i <= order.length; i++) {
          await h.key(LogicalKeyboardKey.tab);
          h.expectFocus(order[(4 + i) % order.length]);
        }
        for (var i = 0; i <= order.length; i++) {
          await h.tabBack();
          h.expectFocus(order[(3 - i) % order.length]);
        }
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getStringList(dashboardCardOrderStorageKey), order);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final thrown in [false, true]) {
    testWidgets(
      'pointer reorder failure retains focus and pointer Retry ($thrown)',
      (tester) async {
        final writer = ControlledDashboardOrderWriter()
          ..steps.add(() async {
            if (thrown) throw StateError('private failure details');
            return false;
          });
        final retry = Completer<bool>();
        writer.steps.add(() => retry.future);
        final h = await _Harness.pump(
          tester,
          orderWriter: writer,
          theme: MyTheme.dark,
          scale: 1.5,
        );
        await h.focus('distance');
        final handle = find.byKey(
          const Key('dashboard-card-distance-drag-handle'),
        );
        await tester.drag(
          handle,
          tester.getCenter(h.card('peaks-bagged')) - tester.getCenter(handle),
        );
        await tester.pumpAndSettle();
        final order = h.container.read(dashboardLayoutProvider);
        expect(order.indexOf('distance'), 3);
        h.expectFocus('distance');
        expect(
          find.byKey(const Key('dashboard-order-save-warning')),
          findsOneWidget,
        );
        expect(
          find.textContaining('save Dashboard card order'),
          findsOneWidget,
        );
        expect(find.textContaining('private failure'), findsNothing);
        final action = find.byKey(const Key('dashboard-order-retry'));
        final button = tester.widget<TextButton>(action);
        expect(
          button.child,
          isA<Text>().having((t) => t.data, 'label', 'Retry'),
        );
        expect(button.focusNode?.skipTraversal, isTrue);
        expect(button.focusNode?.canRequestFocus, isFalse);
        await h.key(LogicalKeyboardKey.keyR);
        expect(writer.writes, hasLength(1));
        await tester.tap(action);
        button.onPressed!(); // same pending action is deduplicated
        await tester.pump();
        expect(writer.writes, [order, order]);
        h.expectFocus('distance');
        expect(h.container.read(dashboardOrderSaveProvider)?.isLoading, isTrue);
        expect(
          find.byKey(const Key('dashboard-order-save-pending')),
          findsOneWidget,
        );
        expect(tester.widget<TextButton>(action).onPressed, isNull);
        retry.complete(true);
        await tester.pumpAndSettle();
        expect(h.container.read(dashboardOrderSaveProvider)?.hasValue, isTrue);
        await h.key(LogicalKeyboardKey.tab);
        h.expectFocus('peaks-bagged');
        await h.tabBack();
        h.expectFocus('distance');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'keyboard save failure Retry saves further moves and keeps chart state ($thrown)',
      (tester) async {
        Future<bool> fail() async {
          if (thrown) throw StateError('controlled keyboard failure');
          return false;
        }

        final writer = ControlledDashboardOrderWriter()
          ..steps.addAll([fail, fail]);
        final h = await _Harness.pump(
          tester,
          orderWriter: writer,
          tracks: [_timeTrack(1, 2024, 6, 15), _timeTrack(2, 2026, 10, 15)],
        );
        await h.focus('time');
        await h.period('time', SummaryPeriodPreset.month);
        await h.key(LogicalKeyboardKey.keyB);
        await h.key(LogicalKeyboardKey.keyC);
        await h.key(LogicalKeyboardKey.keyJ);
        await h.key(LogicalKeyboardKey.enter);
        await h.key(LogicalKeyboardKey.keyL);
        final before = h.chart('time');
        await h.reorder(forward: false);
        final failed = h.container.read(dashboardLayoutProvider);
        expect(failed.indexOf('time'), 1);
        h.expectFocus('time');
        expect(find.byKey(const Key('dashboard-order-retry')), findsOneWidget);
        await h.reorder(forward: false);
        final latest = h.container.read(dashboardLayoutProvider);
        h.expectFocus('time');
        expect(h.chart('time').period, before.period);
        expect(h.chart('time').mode, before.mode);
        expect(h.chart('time').buckets.first.start, before.buckets.first.start);
        expect(h.chart('time').inspection?.index, before.inspection?.index);
        final reloadBefore = ProviderContainer();
        addTearDown(reloadBefore.dispose);
        await reloadBefore.read(dashboardLayoutProvider.notifier).load();
        expect(
          reloadBefore.read(dashboardLayoutProvider),
          dashboardDefaultCardOrder,
        );
        await h.key(LogicalKeyboardKey.keyR);
        expect(writer.writes, [failed, latest]);
        await tester.tap(find.byKey(const Key('dashboard-order-retry')));
        await tester.pumpAndSettle();
        expect(writer.writes, [failed, latest, latest]);
        h.expectFocus('time');
        final reloadAfter = ProviderContainer();
        addTearDown(reloadAfter.dispose);
        await reloadAfter.read(dashboardLayoutProvider.notifier).load();
        expect(reloadAfter.read(dashboardLayoutProvider), latest);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'reorder chords preserve menu, shell, editing and inactive key ownership',
    (tester) async {
      final writer = ControlledDashboardOrderWriter();
      final h = await _Harness.pump(
        tester,
        orderWriter: writer,
        populated: true,
      );
      await h.focus('time');
      await h.key(LogicalKeyboardKey.keyP);
      await h.reorder(forward: true);
      await h.key(LogicalKeyboardKey.escape);
      h.expectFocus('time');
      await h.key(LogicalKeyboardKey.keyC);
      await h.reorder(forward: false);
      await h.key(LogicalKeyboardKey.escape);
      h.shellFocus.requestFocus();
      await tester.pump();
      await h.reorder(forward: true);
      h.editFocus.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'editable text');
      await h.reorder(forward: false);
      expect(find.text('editable text'), findsOneWidget);
      await h.focus('time');
      for (final modifier in [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        await h.reorder(forward: true);
        await tester.sendKeyUpEvent(modifier);
      }
      h.active.value = false;
      await tester.pump();
      await h.reorder(forward: false);
      h.active.value = true;
      await tester.pumpAndSettle();
      expect(writer.writes, isEmpty);
      expect(
        h.container.read(dashboardLayoutProvider),
        dashboardDefaultCardOrder,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending reorder reveal yields to newer traversal, pointer order and scope loss',
    (tester) async {
      final h = await _Harness.pump(tester, size: const Size(1400, 520));
      await h.focus('time');
      await h.reorder(forward: true, settle: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await h.container
          .read(dashboardLayoutProvider.notifier)
          .moveCard('my-ascents', 'elevation');
      await tester.pumpAndSettle();
      h.expectFocus('peaks-bagged');
      await h.reorder(forward: true, settle: false);
      h.shellFocus.requestFocus();
      await tester.pumpAndSettle();
      expect(h.shellFocus.hasPrimaryFocus, isTrue);
      await h.focus('time');
      await h.reorder(forward: true, settle: false);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'order failure after Dashboard inactivity/disposal never publishes stale feedback',
    (tester) async {
      final gate = Completer<bool>();
      final writer = ControlledDashboardOrderWriter()
        ..steps.add(() => gate.future);
      final h = await _Harness.pump(tester, orderWriter: writer);
      await h.focus('time');
      await h.reorder(forward: true);
      h.active.value = false;
      await tester.pump();
      gate.complete(false);
      await tester.pump();
      h.active.value = true;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('dashboard-order-save-warning')),
        findsNothing,
      );
      final disposed = Completer<bool>();
      writer.steps.add(() => disposed.future);
      await h.focus('time');
      await h.reorder(forward: true);
      await tester.pumpWidget(const SizedBox.shrink());
      disposed.completeError(StateError('after screen disposal'));
      await tester.pumpAndSettle();
      expect(h.container.read(dashboardOrderSaveProvider)?.hasError, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real Time/order failures keep warning identity, delivery and Retry domains distinct',
    (tester) async {
      final timeStorage = TestTimeChartPreferenceStorage()
        ..readSteps.add(() => Future.error(StateError('Time read')));
      final writer = ControlledDashboardOrderWriter()
        ..steps.add(() async => false);
      final h = await _Harness.pump(
        tester,
        orderWriter: writer,
        timeStorage: timeStorage,
      );
      await h.focus('distance');
      expect(find.text('Couldn’t load Time chart preference.'), findsOneWidget);
      await h.reorder(forward: true);
      expect(
        find.byKey(const Key('dashboard-order-save-warning')),
        findsNothing,
      );
      await h.key(LogicalKeyboardKey.keyR);
      expect(timeStorage.reads, 2);
      expect(writer.writes, hasLength(1));
      expect(h.container.read(timeChartTypeProvider).visibleWarningId, isNull);
      expect(
        find.byKey(const Key('dashboard-order-save-warning')),
        findsOneWidget,
      );
      final oldOrderRetry = tester
          .widget<TextButton>(find.byKey(const Key('dashboard-order-retry')))
          .onPressed!;
      timeStorage.writeSteps.add(() async => false);
      await h.container
          .read(timeChartTypeProvider.notifier)
          .select(TimeChartType.line);
      await tester.pumpAndSettle();
      expect(find.text('Couldn’t save Time chart preference.'), findsOneWidget);
      expect(
        find.byKey(const Key('dashboard-order-save-warning')),
        findsNothing,
      );
      oldOrderRetry();
      expect(writer.writes, hasLength(1));
      await h.key(LogicalKeyboardKey.keyR);
      expect(timeStorage.writes, ['line', 'line']);
      expect(find.byKey(const Key('dashboard-order-retry')), findsOneWidget);
      await h.key(LogicalKeyboardKey.keyR);
      expect(writer.writes, hasLength(1));
      await tester.tap(find.byKey(const Key('dashboard-order-retry')));
      await tester.pumpAndSettle();
      expect(writer.writes, hasLength(2));
      expect(find.byType(SnackBar), findsNothing);
      h.expectFocus('distance');
      expect(tester.takeException(), isNull);
    },
  );

  for (final type in TimeChartType.values) {
    testWidgets(
      '${type.name} focus, zero activity, keys and accessible pointer equivalence',
      (tester) async {
        final h = await _Harness.pump(
          tester,
          tracks: [
            _timeTrack(1, 2026, 8, 10),
            _timeTrack(2, 2026, 9, 15, total: 0, moving: 0),
            _timeTrack(3, 2026, 10, 1, total: 1, moving: 2),
            _timeTrack(4, 2026, 10, 16),
          ],
          type: type,
        );
        final semantics = tester.ensureSemantics();
        await h.focus('time');
        h.expectInspection('Sep', total: '0d 0h 0m', moving: '0d 0h 0m');
        expect(h.chart('time').inspection?.index, 10);
        await h.key(LogicalKeyboardKey.arrowLeft);
        h.expectInspection('Aug');
        await h.key(LogicalKeyboardKey.keyH);
        h.expectInspection('Jul', total: '0d 0h 0m', moving: '0d 0h 0m');
        await h.key(LogicalKeyboardKey.arrowRight);
        h.expectInspection('Aug');
        await h.key(LogicalKeyboardKey.keyL);
        h.expectInspection('Sep', total: '0d 0h 0m', moving: '0d 0h 0m');
        await h.key(LogicalKeyboardKey.escape);
        h.expectNoInspection();
        h.expectFocus('time');
        // An incidental notification on the same focused card must not re-enter.
        h.owner('time').focus();
        await tester.pump();
        h.expectNoInspection();
        await h.key(LogicalKeyboardKey.keyH);
        expect(h.chart('time').inspection?.index, 10);
        await h.key(LogicalKeyboardKey.keyH);
        expect(h.chart('time').inspection?.index, 9);
        final keyboardRows = h.inspectionRows();
        final label = tester
            .getSemantics(find.byKey(const Key('time-inspection')))
            .getSemanticsData()
            .label;
        expect(label, keyboardRows.join('\n'));
        await h.key(LogicalKeyboardKey.escape);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(1, 1));
        await mouse.moveTo(
          tester.getCenter(h.control('time', 'time-bucket-9')),
        );
        await tester.pumpAndSettle();
        expect(h.inspectionRows(), keyboardRows);
        await tester.tap(h.control('time', 'time-bucket-9'));
        await mouse.moveTo(const Offset(1, 1));
        await tester.pumpAndSettle();
        expect(h.inspectionRows(), keyboardRows);
        await mouse.removePointer();
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${type.name} directional boundaries visit empty pages with last/first landings and bounds',
      (tester) async {
        final h = await _Harness.pump(
          tester,
          tracks: [_timeTrack(1, 2026, 8, 1), _timeTrack(2, 2026, 10, 15)],
          type: type,
        );
        await h.focus('time');
        await h.period('time', SummaryPeriodPreset.month);
        h.expectNoInspection();
        await h.key(LogicalKeyboardKey.arrowLeft); // initialize, not step
        h.expectInspection('Thu 15 Oct');
        for (var i = 0; i < 14; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
        }
        await tester.pumpAndSettle();
        h.expectInspection('Thu 1 Oct', total: '0d 0h 0m', moving: '0d 0h 0m');
        await h.key(LogicalKeyboardKey.arrowLeft);
        expect(h.page('time'), DateTime(2026, 9));
        expect(h.chart('time').inspection?.index, 29);
        h.expectInspection('Wed 30 Sep', total: '0d 0h 0m', moving: '0d 0h 0m');
        await h.key(LogicalKeyboardKey.arrowRight);
        expect(h.page('time'), DateTime(2026, 10));
        expect(h.chart('time').inspection?.index, 0);
        // W/B use latest-eligible / first-empty, not directional landing policy.
        await h.key(LogicalKeyboardKey.keyB);
        expect(h.chart('time').inspection?.index, 0);
        h.expectInspection('Tue 1 Sep', total: '0d 0h 0m', moving: '0d 0h 0m');
        await h.key(LogicalKeyboardKey.keyB);
        expect(h.chart('time').inspection?.index, 0);
        h.expectInspection('Sat 1 Aug');
        final earliest = h.page('time');
        await h.key(LogicalKeyboardKey.keyH);
        expect(h.page('time'), earliest);
        h.expectInspection('Sat 1 Aug');
        await h.key(LogicalKeyboardKey.keyW);
        expect(h.chart('time').inspection?.index, 0);
        await h.key(LogicalKeyboardKey.keyW);
        h.expectInspection('Thu 15 Oct');
        for (var i = 0; i < 18; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
        }
        await tester.pumpAndSettle();
        expect(h.page('time'), DateTime(2026, 10));
        expect(h.chart('time').inspection?.index, 30);
        h.expectInspection('Sat 31 Oct', total: '0d 0h 0m', moving: '0d 0h 0m');
        expect(h.button('time', 'next').onPressed, isNull);
        h.expectFocus('time');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${type.name} menus preserve inspection or clear until directional initialization',
      (tester) async {
        final h = await _Harness.pump(
          tester,
          type: type,
          tracks: [_timeTrack(1, 2026, 10, 15)],
        );
        await h.focus('time');
        await h.key(LogicalKeyboardKey.keyH);
        h.expectInspection('Sep', total: '0d 0h 0m', moving: '0d 0h 0m');
        for (final key in [LogicalKeyboardKey.keyP, LogicalKeyboardKey.keyC]) {
          await h.key(key);
          for (final blocked in [
            LogicalKeyboardKey.keyH,
            LogicalKeyboardKey.keyL,
            LogicalKeyboardKey.arrowLeft,
            LogicalKeyboardKey.arrowRight,
            LogicalKeyboardKey.keyW,
            LogicalKeyboardKey.keyB,
          ]) {
            await h.key(blocked);
          }
          await h.key(LogicalKeyboardKey.arrowDown);
          await h.key(LogicalKeyboardKey.keyK);
          await h.key(LogicalKeyboardKey.escape);
          h.expectInspection('Sep', total: '0d 0h 0m', moving: '0d 0h 0m');
          await h.key(key);
          await h.key(LogicalKeyboardKey.enter); // same selection
          h.expectInspection('Sep', total: '0d 0h 0m', moving: '0d 0h 0m');
        }
        final page = h.page('time');
        await h.key(LogicalKeyboardKey.keyC);
        await h.key(LogicalKeyboardKey.keyJ);
        await h.key(LogicalKeyboardKey.enter);
        expect(h.page('time'), page);
        h.expectNoInspection();
        await h.key(LogicalKeyboardKey.keyC);
        await h.key(LogicalKeyboardKey.escape);
        h.expectNoInspection();
        await h.key(LogicalKeyboardKey.keyL);
        h.expectInspection('Oct');
        await h.period('time', SummaryPeriodPreset.month);
        h.expectNoInspection();
        await h.key(LogicalKeyboardKey.keyL);
        h.expectInspection('Thu 15 Oct');
        await h.key(LogicalKeyboardKey.keyC);
        await h.key(LogicalKeyboardKey.tab);
        h.expectFocus('latest-walk');
        await h.tabBack();
        h.expectInspection('Thu 15 Oct');
        await h.key(LogicalKeyboardKey.keyP);
        await h.tabBack();
        h.expectFocus('distance');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Time loading/empty focus has no inspection; empty page starts at first bucket',
    (tester) async {
      final h = await _Harness.pump(tester);
      await h.focus('time');
      h.expectNoInspection();
      await h.key(LogicalKeyboardKey.keyL);
      h.expectNoInspection();
      h.setTracks([_timeTrack(1, 2024, 6, 15)], loading: true);
      await tester.pump();
      h.owner('time').focus();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pump();
      expect(h.control('time', 'time-loading-state'), findsOneWidget);
      h.expectNoInspection();
      h.setTracks([_timeTrack(1, 2024, 6, 15)]);
      await tester.pumpAndSettle();
      h.expectNoInspection();
      await h.key(LogicalKeyboardKey.keyL);
      h.expectInspection('Nov', total: '0d 0h 0m', moving: '0d 0h 0m');
      await h.key(LogicalKeyboardKey.tab);
      await h.tabBack();
      expect(h.chart('time').inspection?.index, 0);
      h.expectFocus('time');
      expect(tester.takeException(), isNull);
    },
  );

  for (final type in TimeChartType.values) {
    testWidgets(
      '${type.name} overlapping page/inspection/menu/data inputs reject stale callbacks',
      (tester) async {
        final h = await _Harness.pump(
          tester,
          type: type,
          tracks: [_timeTrack(1, 2026, 8, 1), _timeTrack(2, 2026, 10, 15)],
        );
        await h.focus('time');
        await h.period('time', SummaryPeriodPreset.month);
        await h.key(LogicalKeyboardKey.keyL);
        final oldHover = tester
            .widget<MouseRegion>(h.control('time', 'time-bucket-0'))
            .onEnter!;
        // An in-page key supersedes accumulated trackpad input as well.
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(h.control('time', 'time-page-browser')),
            scrollDelta: const Offset(-160, 0),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
        await tester.pump(const Duration(milliseconds: 150));
        expect(h.page('time'), DateTime(2026, 10));
        h.expectInspection('Wed 14 Oct', total: '0d 0h 0m', moving: '0d 0h 0m');
        // Reach/cross a boundary and immediately reverse before it paints.
        for (var i = 0; i < 14; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
        await tester.pump();
        expect(h.page('time'), DateTime(2026, 10));
        expect(h.chart('time').inspection?.index, 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
        await tester.pump();
        h.expectInspection('Thu 15 Oct');
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(h.control('time', 'time-page-browser')),
            scrollDelta: const Offset(-160, 0),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        h.setTracks([_timeTrack(1, 2026, 8, 1)]);
        await tester.pump();
        oldHover(const PointerEnterEvent());
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(h.page('time'), DateTime(2026, 10));
        h.expectNoInspection();
        h.expectFocus('time');
        expect(h.chart('time').buckets.every((b) => b.value == 0), isTrue);
        expect(
          tester
              .widget<Text>(
                h.control('time', 'dashboard-card-summary-total-value'),
              )
              .data,
          'Total: 0d 0h 0m',
        );
        expect(
          tester
              .widget<Text>(
                h.control('time', 'dashboard-card-summary-average-value'),
              )
              .data,
          'Weekly Avg: 0d 0h 0m',
        );
        expect(h.button('time', 'next').onPressed, isNull);
        await h.key(LogicalKeyboardKey.keyL);
        h.expectInspection('Thu 1 Oct', total: '0d 0h 0m', moving: '0d 0h 0m');
        // Refresh before history clamps the page; it must not retain that index.
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        h.setTracks([_timeTrack(3, 2026, 9, 2, total: 0, moving: 0)]);
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(h.page('time'), DateTime(2026, 9));
        h.expectNoInspection();
        await h.key(LogicalKeyboardKey.keyL);
        h.expectInspection('Wed 2 Sep', total: '0d 0h 0m', moving: '0d 0h 0m');
        final owner = h.owner('time');
        final staleStep = owner.actions[LogicalKeyboardKey.keyH]!;
        final staleClear = owner.actions[LogicalKeyboardKey.escape]!;
        await tester.sendEventToBinding(
          PointerScrollEvent(
            position: tester.getCenter(h.control('time', 'time-page-browser')),
            scrollDelta: const Offset(160, 0),
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
        await tester.pumpWidget(const SizedBox.shrink());
        staleStep();
        staleClear();
        oldHover(const PointerEnterEvent());
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Time directional boundaries share every preset toolbar sequence',
    (tester) async {
      final h = await _Harness.pump(
        tester,
        tracks: [_timeTrack(1, 1989, 2, 1), _timeTrack(2, 2026, 10, 15)],
      );
      await h.focus('time');
      for (final period in SummaryPeriodPreset.values) {
        await h.period('time', period);
        await h.key(LogicalKeyboardKey.keyB);
        final previousPage = h.page('time');
        final previousLength = h.chart('time').buckets.length;
        await h.key(LogicalKeyboardKey.keyW);
        final current = h.page('time');
        await tester.tap(h.control('time', 'time-bucket-0'));
        await tester.pump();
        h.node('time').requestFocus();
        await tester.pump();
        await h.key(LogicalKeyboardKey.keyH);
        expect(h.page('time'), previousPage, reason: period.name);
        expect(h.chart('time').inspection?.index, previousLength - 1);
        await h.key(LogicalKeyboardKey.keyL);
        expect(h.page('time'), current);
        expect(h.chart('time').inspection?.index, 0);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Time rollover, historical remapping and inactive contexts clear stale inspection',
    (tester) async {
      var now = DateTime(2026, 10, 15);
      final h = await _Harness.pump(
        tester,
        clock: () => now,
        tracks: [
          _timeTrack(1, 2026, 2, 1),
          _timeTrack(2, 2026, 10, 15),
          _timeTrack(3, 2026, 11, 1, total: 0, moving: 0),
        ],
      );
      await h.focus('time');
      h.expectInspection('Oct');
      now = DateTime(2026, 11, 1);
      await h.key(LogicalKeyboardKey.keyH);
      expect(h.page('time'), DateTime(2025, 12));
      h.expectNoInspection();
      await h.key(LogicalKeyboardKey.keyL);
      h.expectInspection('Nov', total: '0d 0h 0m', moving: '0d 0h 0m');
      await h.period('time', SummaryPeriodPreset.last3Months);
      await h.key(LogicalKeyboardKey.keyB);
      expect(h.page('time'), DateTime(2026, 6));
      now = DateTime(2026, 12, 1);
      await h.key(LogicalKeyboardKey.keyL);
      expect(h.page('time'), DateTime(2026, 7));
      h.expectNoInspection();
      await h.key(LogicalKeyboardKey.keyL);
      expect(h.chart('time').inspection?.index, 0);
      // Modified shortcuts, text entry, other cards, shell and inactive Dashboard
      // must not step/clear Time's inspected value or move its page.
      final page = h.page('time');
      final index = h.chart('time').inspection?.index;
      for (final modifier in [
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        for (final key in [
          LogicalKeyboardKey.keyH,
          LogicalKeyboardKey.keyL,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.escape,
          LogicalKeyboardKey.keyC,
        ]) {
          await h.key(key);
        }
        await tester.sendKeyUpEvent(modifier);
      }
      expect(h.chart('time').inspection?.index, index);
      h.shellFocus.requestFocus();
      await tester.pump();
      await h.key(LogicalKeyboardKey.keyH);
      h.editFocus.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'hl');
      await h.key(LogicalKeyboardKey.keyL);
      expect(find.text('hl'), findsOneWidget);
      await h.focus('distance');
      await h.key(LogicalKeyboardKey.keyH);
      expect(h.page('time'), page);
      expect(h.chart('time').inspection?.index, index);
      await h.focus('time');
      h.active.value = false;
      await tester.pump();
      now = DateTime(2027, 1, 1);
      await h.key(LogicalKeyboardKey.keyH);
      h.active.value = true;
      await tester.pumpAndSettle();
      expect(h.page('time'), DateTime(2026, 8));
      h.expectNoInspection();
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [MyTheme.dark]) {
    testWidgets(
      'Time focus/inspection palette and accessible scaled values ${theme.brightness}',
      (tester) async {
        final h = await _Harness.pump(
          tester,
          theme: theme,
          scale: 1.5,
          tracks: [_timeTrack(1, 2026, 10, 15)],
        );
        final semantics = tester.ensureSemantics();
        await h.focus('time');
        final palette = theme.extension<ChartSeriesTheme>()!;
        expect(h.border('time').color, theme.colorScheme.primary);
        expect(h.border('time').color, isNot(palette.primarySeriesColor));
        for (final type in TimeChartType.values) {
          await h.container.read(timeChartTypeProvider.notifier).select(type);
          await tester.pumpAndSettle();
          if (h.chart('time').inspection == null) {
            await h.key(LogicalKeyboardKey.keyL);
          }
          h.expectInspection('Oct');
          final rows = tester
              .widgetList<Text>(
                find.descendant(
                  of: h.control('time', 'time-tooltip'),
                  matching: find.byType(Text),
                ),
              )
              .toList();
          expect(rows.skip(1).map((t) => t.style?.color), [
            lighten(palette.primarySeriesColor),
            lighten(palette.secondarySeriesColor),
          ]);
          expect(
            tester
                .getSemantics(find.byKey(const Key('time-inspection')))
                .getSemanticsData()
                .label,
            'Oct\nTotal Time: 0d 5h 0m\nMoving Time: 0d 4h 0m',
          );
          expect(
            MediaQuery.textScalerOf(tester.element(h.card('time'))).scale(1),
            1.5,
          );
        }
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final size in [const Size(1400, 520), const Size(1600, 520)]) {
    testWidgets('Tab reveals full lazy order and wraps both ways at $size', (
      tester,
    ) async {
      final h = await _Harness.pump(tester, size: size);
      expect(h.card('my-ascents'), findsNothing);
      for (final id in dashboardDefaultCardOrder) {
        await h.key(LogicalKeyboardKey.tab);
        h.expectFocus(id);
        final board = tester.getRect(find.byKey(const Key('dashboard-board')));
        expect(tester.getRect(h.card(id)).overlaps(board), isTrue);
      }
      await h.key(LogicalKeyboardKey.tab);
      h.expectFocus(dashboardDefaultCardOrder.first);
      for (final id in dashboardDefaultCardOrder.reversed) {
        await h.tabBack();
        h.expectFocus(id);
      }
      await h.tabBack();
      h.expectFocus(dashboardDefaultCardOrder.last);

      // The same pointer reorder operation changes the authoritative sequence.
      await h.container
          .read(dashboardLayoutProvider.notifier)
          .moveCard('my-ascents', 'elevation');
      await tester.pumpAndSettle();
      await h.key(LogicalKeyboardKey.tab);
      h.expectFocus('elevation');
      final reordered = h.container.read(dashboardLayoutProvider);
      for (final id in [...reordered.skip(2), reordered.first, reordered[1]]) {
        await h.key(LogicalKeyboardKey.tab);
        h.expectFocus(id);
      }
      for (var i = 0; i < reordered.length; i++) {
        await h.tabBack();
        h.expectFocus(reordered[(1 - i - 1) % reordered.length]);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'pending lazy targets respect newer Tabs, reorder, focus scope and disposal',
    (tester) async {
      final h = await _Harness.pump(tester, size: const Size(1400, 520));
      await h.key(LogicalKeyboardKey.tab);
      h.expectFocus('elevation');
      // Deliberately overlap requests, rather than serializing every reveal.
      for (var i = 0; i < 7; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      }
      await h.container
          .read(dashboardLayoutProvider.notifier)
          .moveCard('my-ascents', 'elevation');
      await tester.pump();
      await tester.pumpAndSettle();
      h.expectFocus('my-ascents');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      h.shellFocus.requestFocus();
      await tester.pumpAndSettle();
      expect(h.shellFocus.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pointer reordering updates subsequent full card traversal', (
    tester,
  ) async {
    final h = await _Harness.pump(tester);
    final handle = find.byKey(const Key('dashboard-card-distance-drag-handle'));
    await tester.drag(
      handle,
      tester.getCenter(h.card('peaks-bagged')) - tester.getCenter(handle),
    );
    await tester.pumpAndSettle();
    final order = h.container.read(dashboardLayoutProvider);
    expect(order.indexOf('distance'), 3);
    for (final id in order) {
      await h.key(LogicalKeyboardKey.tab);
      h.expectFocus(id);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Shift+Tab enters the initially unbuilt last card and reveals reverse order',
    (tester) async {
      final h = await _Harness.pump(tester, size: const Size(1400, 520));
      expect(h.card('my-ascents'), findsNothing);
      for (final id in dashboardDefaultCardOrder.reversed) {
        await h.tabBack();
        h.expectFocus(id);
      }
      await h.tabBack();
      h.expectFocus('my-ascents');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard interactions reconcile an advanced reference clock without a timer',
    (tester) async {
      var now = DateTime(2026, 10, 15);
      final h = await _Harness.pump(tester, populated: true, clock: () => now);
      await h.focus('distance');
      await h.period('distance', SummaryPeriodPreset.month);
      expect(h.page('distance'), DateTime(2026, 10));
      now = DateTime(2026, 11, 1);
      await h.key(LogicalKeyboardKey.keyW);
      expect(h.page('distance'), DateTime(2026, 11));
      await h.key(LogicalKeyboardKey.home);
      expect(h.page('distance'), DateTime(1989, 2));
      await h.key(LogicalKeyboardKey.end);
      expect(h.page('distance'), DateTime(2024, 6));
      now = DateTime(2027, 1, 1);
      await h.key(LogicalKeyboardKey.keyW);
      expect(h.page('distance'), DateTime(2024, 7));
      h.expectFocus('distance');
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [MyTheme.dark]) {
    testWidgets(
      'named card focus is distinct from hover and controls stay pointer-operable ${theme.brightness}',
      (tester) async {
        final h = await _Harness.pump(
          tester,
          theme: theme,
          populated: true,
          scale: 1.5,
        );
        final semantics = tester.ensureSemantics();
        final before = h.border('elevation');
        await h.key(LogicalKeyboardKey.tab);
        h.expectFocus('elevation');
        expect(h.border('elevation').color, theme.colorScheme.primary);
        expect(h.border('elevation').width, 3);
        expect(h.border('elevation'), isNot(before));
        final data = tester
            .getSemantics(
              find.byKey(const Key('dashboard-card-elevation-focus')),
            )
            .getSemanticsData();
        expect(data.label, contains('Elevation'));
        expect(data.flagsCollection.isFocused, Tristate.isTrue);
        final initial = h.chart('elevation').mode;
        await tester.tap(h.control('elevation', 'summary-mode-fab'));
        await tester.pumpAndSettle();
        expect(h.chart('elevation').mode, isNot(initial));
        await h.key(LogicalKeyboardKey.tab);
        h.expectFocus('distance');
        await h.tabBack();
        h.expectFocus('elevation');
        expect(
          MediaQuery.textScalerOf(tester.element(h.card('elevation'))).scale(1),
          1.5,
        );
        final y = tester
            .getCenter(h.control('elevation', 'summary-first-window'))
            .dy;
        for (final action in ['prev', 'next', 'last']) {
          expect(
            tester
                .getCenter(h.control('elevation', 'summary-$action-window'))
                .dy,
            y,
          );
        }
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final kind in ['elevation', 'distance', 'time', 'peaks-bagged']) {
    testWidgets(
      '$kind keyboard page actions share every toolbar destination and bound',
      (tester) async {
        final h = await _Harness.pump(tester, populated: true);
        await h.focus(kind);
        for (final period in SummaryPeriodPreset.values) {
          await h.period(kind, period);
          final current = h.page(kind);
          await h.key(LogicalKeyboardKey.home);
          final first = h.page(kind);
          expect(h.button(kind, 'first').onPressed, isNull);
          await h.key(LogicalKeyboardKey.home);
          expect(h.page(kind), first);
          await h.tap(kind, 'next');
          final next = h.page(kind);
          await h.key(LogicalKeyboardKey.keyB);
          expect(h.page(kind), first);
          await h.key(LogicalKeyboardKey.keyW);
          expect(h.page(kind), next);
          await h.key(LogicalKeyboardKey.end);
          final last = h.page(kind);
          expect(h.button(kind, 'last').onPressed, isNull);
          await h.key(LogicalKeyboardKey.keyB);
          await h.tap(kind, 'last');
          expect(h.page(kind), last);
          await h.key(LogicalKeyboardKey.home);
          await h.tap(kind, 'first');
          expect(h.page(kind), first);
          // Independent current-page state on another card remains unchanged.
          final other = kind == 'elevation' ? 'distance' : 'elevation';
          expect(h.chart(other).period, SummaryPeriodPreset.last12Months);
          expect(current, isNot(first));
          h.expectFocus(kind);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'P/C menu keys, selected choices, Escape/Enter return signals and Tab continuation',
    (tester) async {
      final h = await _Harness.pump(tester, populated: true);
      await h.focus('time');
      final owner = h.owner('time');
      final initial = h.page('time');
      await h.key(LogicalKeyboardKey.keyC);
      expect(
        find.byKey(const Key('time-chart-type-stackedColumn')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('time-chart-type-line')), findsOneWidget);
      expect(
        find.byKey(const Key('time-chart-type-clusteredColumn')),
        findsOneWidget,
      );
      await h.key(LogicalKeyboardKey.keyW);
      await h.key(LogicalKeyboardKey.keyB);
      expect(h.page('time'), initial);
      await h.key(LogicalKeyboardKey.keyJ);
      await h.key(LogicalKeyboardKey.enter);
      expect(
        h.container.read(timeChartTypeProvider).selected,
        TimeChartType.line,
      );
      h.expectFocus('time');
      expect(owner.focusEvents.value.$2, DashboardCardFocusReason.menuChanged);
      expect(h.page('time'), initial);

      await h.key(LogicalKeyboardKey.keyC);
      final dismissedChoice = summaryChoiceAction(
        tester,
        'time-chart-type-clusteredColumn',
      );
      await h.key(LogicalKeyboardKey.arrowDown);
      await h.key(LogicalKeyboardKey.keyK);
      await h.key(LogicalKeyboardKey.arrowUp);
      await h.key(LogicalKeyboardKey.escape);
      dismissedChoice();
      await tester.pumpAndSettle();
      expect(
        h.container.read(timeChartTypeProvider).selected,
        TimeChartType.line,
      );
      h.expectFocus('time');
      expect(owner.focusEvents.value.$2, DashboardCardFocusReason.menuReturn);
      await h.key(LogicalKeyboardKey.keyC);
      await h.key(LogicalKeyboardKey.enter);
      expect(owner.focusEvents.value.$2, DashboardCardFocusReason.menuReturn);
      await h.key(LogicalKeyboardKey.keyP);
      expect(
        tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(sharedSummaryMenuKey),
                matching: find.byType(Text),
              ),
            )
            .map((b) => b.data),
        SummaryPeriodPreset.values.map((p) => p.label),
      );
      await h.key(LogicalKeyboardKey.arrowDown);
      await h.key(LogicalKeyboardKey.enter);
      expect(h.chart('time').period, SummaryPeriodPreset.yearToDate);
      expect(owner.focusEvents.value.$2, DashboardCardFocusReason.menuChanged);
      h.expectFocus('time');
      await h.key(LogicalKeyboardKey.keyP);
      await h.key(LogicalKeyboardKey.tab);
      h.expectFocus('latest-walk');
      await h.tabBack();
      h.expectFocus('time');
      await h.key(LogicalKeyboardKey.keyC);
      await h.tabBack();
      h.expectFocus('distance');
      expect(find.byKey(const Key('time-chart-type-line')), findsNothing);

      for (final id in ['distance', 'elevation', 'peaks-bagged']) {
        await h.focus(id);
        final mode = h.chart(id).mode;
        final page = h.page(id);
        await h.key(LogicalKeyboardKey.keyC);
        expect(h.chart(id).mode, isNot(mode));
        expect(h.page(id), page);
        expect(find.byKey(sharedSummaryMenuKey), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'menu Tab wraps endpoints and unbuilt targets; pointer menu still selects',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        dashboardCardOrderStorageKey: [
          'time',
          'latest-walk',
          'year-to-date',
          'my-lists',
          'my-ascents',
          'elevation',
          'distance',
          'peaks-bagged',
        ],
      });
      final h = await _Harness.pump(
        tester,
        populated: true,
        size: const Size(1400, 520),
      );
      await h.key(LogicalKeyboardKey.tab);
      await h.key(LogicalKeyboardKey.keyP);
      await h.tabBack();
      h.expectFocus('peaks-bagged');
      await h.key(LogicalKeyboardKey.keyP);
      await h.key(LogicalKeyboardKey.tab);
      h.expectFocus('time');
      await tester.tap(h.control('time', 'time-chart-type-button'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clustered column view'));
      await tester.pumpAndSettle();
      expect(
        h.container.read(timeChartTypeProvider).selected,
        TimeChartType.clusteredColumn,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'inactive Dashboard, shell and editing/modified keys cannot dispatch card actions',
    (tester) async {
      final h = await _Harness.pump(tester, populated: true);
      await h.focus('distance');
      final initial = h.page('distance');
      final mode = h.chart('distance').mode;
      for (final modifier in [
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        for (final key in [
          LogicalKeyboardKey.keyB,
          LogicalKeyboardKey.keyC,
          LogicalKeyboardKey.keyP,
          LogicalKeyboardKey.home,
        ]) {
          await h.key(key);
        }
        await tester.sendKeyUpEvent(modifier);
      }
      expect(h.page('distance'), initial);
      expect(h.chart('distance').mode, mode);
      expect(find.byKey(sharedSummaryMenuKey), findsNothing);
      h.shellFocus.requestFocus();
      await tester.pump();
      await h.key(LogicalKeyboardKey.keyB);
      expect(h.page('distance'), initial);
      h.editFocus.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'wbc');
      await h.key(LogicalKeyboardKey.keyP);
      expect(find.text('wbc'), findsOneWidget);
      expect(h.page('distance'), initial);
      await h.focus('distance');
      h.active.value = false;
      await tester.pump();
      await h.key(LogicalKeyboardKey.keyB);
      expect(h.page('distance'), initial);
      h.active.value = true;
      await tester.pumpAndSettle();
      await h.focus('distance');
      await h.key(LogicalKeyboardKey.keyB);
      expect(h.page('distance'), isNot(initial));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'outside gesture only dismisses before another gesture focuses typing',
    (tester) async {
      final h = await _Harness.pump(tester, populated: true);
      await tester.tap(h.control('time', 'time-chart-type-button'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(h.editFocus.hasPrimaryFocus, isFalse);
      expect(h.owner('time').menuOwnsFocus, isFalse);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(h.editFocus.hasPrimaryFocus, isTrue);
      await tester.enterText(find.byType(TextField), 'wbc');
      expect(find.text('wbc'), findsOneWidget);
      expect(find.byKey(sharedSummaryMenuKey), findsNothing);
    },
  );

  testWidgets(
    'unchanged Enter after hover preserves Time inspection and never writes preferences',
    (tester) async {
      final storage = TestTimeChartPreferenceStorage();
      final h = await _Harness.pump(
        tester,
        populated: true,
        timeStorage: storage,
      );
      await h.focus('time');
      final rows = h.inspectionRows();
      final page = h.page('time');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      for (final shortcut in [
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.keyP,
      ]) {
        await h.key(shortcut);
        await mouse.moveTo(
          tester.getCenter(
            find.byKey(
              Key(
                shortcut == LogicalKeyboardKey.keyC
                    ? 'time-chart-type-line'
                    : 'time-period-month',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Hover must not become a keyboard target. Leave the pointer outside the
        // chart before closing so overlay removal is not a separate chart hover.
        await mouse.moveTo(const Offset(1390, 5));
        await tester.pumpAndSettle();
        await h.key(LogicalKeyboardKey.enter);
        expect(find.byKey(sharedSummaryMenuKey), findsNothing);
        expect(h.page('time'), page);
        expect(h.inspectionRows(), rows);
        expect(storage.writes, isEmpty);
        h.expectFocus('time');
        expect(
          h.owner('time').focusEvents.value.$2,
          DashboardCardFocusReason.menuReturn,
        );
      }
    },
  );

  testWidgets(
    'both Dashboard menus reject same-frame obscured-route callbacks and consume dismissal keys',
    (tester) async {
      final storage = TestTimeChartPreferenceStorage();
      final h = await _Harness.pump(
        tester,
        populated: true,
        timeStorage: storage,
      );
      await h.focus('time');
      for (final shortcut in [
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.keyP,
      ]) {
        final choice = shortcut == LogicalKeyboardKey.keyC
            ? 'time-chart-type-line'
            : 'time-period-month';
        await h.key(shortcut);
        final select = summaryChoiceAction(tester, choice);
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Other route')),
          ),
        );
        select(); // Before the obscured owner/anchor rebuilds.
        await tester.pumpAndSettle();
        expect(storage.writes, isEmpty);
        navigator.pop();
        await tester.pumpAndSettle();
        expect(h.chart('time').period, SummaryPeriodPreset.last12Months);
        await h.focus('time');
        for (final dismissal in ['escape', 'control-c', 'back']) {
          final rows = h.inspectionRows();
          await h.key(shortcut);
          await h.key(LogicalKeyboardKey.arrowDown);
          if (dismissal == 'control-c') {
            await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
            await h.key(LogicalKeyboardKey.keyC);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          } else if (dismissal == 'back') {
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          } else {
            await h.key(LogicalKeyboardKey.escape);
          }
          expect(find.byKey(sharedSummaryMenuKey), findsNothing);
          expect(h.inspectionRows(), rows);
          expect(storage.writes, isEmpty);
          h.expectFocus('time');
        }
      }
    },
  );

  testWidgets(
    'caller resize and removed menus preserve values/drafts and reject orphan callbacks',
    (tester) async {
      final storage = TestTimeChartPreferenceStorage();
      final h = await _Harness.pump(
        tester,
        populated: true,
        timeStorage: storage,
      );
      await tester.enterText(find.byType(TextField), 'Unsaved dashboard note');
      for (final shortcut in [
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.keyP,
      ]) {
        await h.focus('time');
        final page = h.page('time');
        await h.key(shortcut);
        await tester.binding.setSurfaceSize(const Size(1920, 1200));
        await tester.pumpAndSettle();
        expect(h.page('time'), page);
        expect(storage.writes, isEmpty);
        expect(find.text('Unsaved dashboard note'), findsOneWidget);
        if (find.byKey(sharedSummaryMenuKey).evaluate().isNotEmpty) {
          await h.key(LogicalKeyboardKey.escape);
        }
        await h.focus('time');
        await h.key(shortcut);
        final captured = summaryChoiceAction(
          tester,
          shortcut == LogicalKeyboardKey.keyC
              ? 'time-chart-type-line'
              : 'time-period-month',
        );
        h.setTracks([]);
        await tester.pumpAndSettle();
        captured();
        await tester.pumpAndSettle();
        expect(find.byKey(sharedSummaryMenuKey), findsNothing);
        expect(h.owner('time').menuOwnsFocus, isFalse);
        expect(storage.writes, isEmpty);
        expect(find.text('Unsaved dashboard note'), findsOneWidget);
        h.setTracks([_track(1, 1989, 2), _track(2, 2024, 6)]);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Time overflow keeps keyboard inspection, P/C menus and full-card traversal reachable',
    (tester) async {
      final track = _track(1, 2026, 10)
        ..totalTimeMillis = 123456 * Duration.millisecondsPerDay
        ..movingTime = 123456 * Duration.millisecondsPerDay;
      final h = await _Harness.pump(
        tester,
        tracks: [track],
        size: const Size(1600, 1000),
        scale: 2,
      );
      await h.focus('time');
      final viewport = h.control('time', 'time-card-viewport');
      final scroll = tester
          .state<ScrollableState>(
            find
                .descendant(of: viewport, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      expect(scroll.maxScrollExtent, greaterThan(0));
      expect(scroll.pixels, scroll.maxScrollExtent);
      final initial = h.chart('time').buckets.first.start;
      final type = h.container.read(timeChartTypeProvider).selected;
      for (var i = 0; i < 4; i++) {
        await h.key(LogicalKeyboardKey.pageUp);
      }
      expect(scroll.pixels, 0);
      final header = h.control('time', 'dashboard-card-time-drag-handle');
      expect(
        tester.getRect(header).top,
        greaterThanOrEqualTo(tester.getRect(viewport).top),
      );
      for (var i = 0; i < 4; i++) {
        await h.key(LogicalKeyboardKey.pageDown);
      }
      expect(scroll.pixels, scroll.maxScrollExtent);
      for (final shortcut in [
        LogicalKeyboardKey.keyP,
        LogicalKeyboardKey.keyC,
      ]) {
        await h.key(shortcut);
        expect(find.byKey(sharedSummaryMenuKey), findsOneWidget);
        await h.key(LogicalKeyboardKey.enter);
        h.expectFocus('time');
        await h.key(LogicalKeyboardKey.arrowLeft);
        expect(scroll.pixels, scroll.maxScrollExtent);
        expect(h.page('time'), initial);
        expect(h.container.read(timeChartTypeProvider).selected, type);
      }
      await h.key(LogicalKeyboardKey.keyP);
      await h.key(LogicalKeyboardKey.tab);
      h.expectFocus('latest-walk');
      await h.tabBack();
      h.expectFocus('time');
      expect(scroll.pixels, scroll.maxScrollExtent);
      for (final chartType in TimeChartType.values) {
        await h.container
            .read(timeChartTypeProvider.notifier)
            .select(chartType);
        await tester.pumpAndSettle();
        await h.key(LogicalKeyboardKey.arrowLeft);
        final page = h.page('time');
        for (final size in [
          const Size(1280, 960),
          const Size(1920, 1200),
          const Size(1600, 1000),
        ]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpAndSettle();
          expect(h.page('time'), page);
          expect(h.container.read(timeChartTypeProvider).selected, chartType);
          await h.key(LogicalKeyboardKey.keyC);
          expect(find.byKey(sharedSummaryMenuKey), findsOneWidget);
          await h.key(LogicalKeyboardKey.escape);
          h.expectFocus('time');
        }
      }
      final page = h.page('time');
      await h.reorder(forward: true);
      h.expectFocus('time');
      expect(h.page('time'), page);
      await h.key(LogicalKeyboardKey.arrowLeft);
      expect(h.control('time', 'time-tooltip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refresh removing a closing menu releases its keyboard ownership',
    (tester) async {
      final h = await _Harness.pump(tester, populated: true);
      await h.focus('time');
      await h.key(LogicalKeyboardKey.keyC);
      final select = summaryChoiceAction(tester, 'time-chart-type-line');
      final owner = h.owner('time');
      select();
      (h.container.read(mapProvider.notifier) as TestMapNotifier).setTracks([]);
      await tester.pumpAndSettle();
      expect(owner.menuOwnsFocus, isFalse);
      h.node('time').requestFocus();
      await tester.pump();
      await h.key(LogicalKeyboardKey.tab);
      h.expectFocus('latest-walk');
      expect(tester.takeException(), isNull);
    },
  );
}

class _Harness {
  _Harness(this.tester, this.container);
  final WidgetTester tester;
  final ProviderContainer container;
  final active = ValueNotifier(true);
  final shellFocus = FocusNode(debugLabel: 'Temporary shell');
  final editFocus = FocusNode(debugLabel: 'Typing');

  static Future<_Harness> pump(
    WidgetTester tester, {
    Size size = const Size(1400, 1800),
    ThemeData? theme,
    bool populated = false,
    double scale = 1,
    DateTime Function()? clock,
    List<GpxTrack>? tracks,
    TimeChartType? type,
    ControlledDashboardOrderWriter? orderWriter,
    TestTimeChartPreferenceStorage? timeStorage,
  }) async {
    if (type != null) {
      SharedPreferences.setMockInitialValues({
        timeChartTypeStorageKey: type.storageId,
      });
    }
    final container = ProviderContainer(
      overrides: [
        if (orderWriter != null)
          dashboardOrderWriterProvider.overrideWithValue(orderWriter.call),
        if (timeStorage != null)
          timeChartPreferenceStorageProvider.overrideWithValue(timeStorage),
        ...mappingCatalogTestOverrides,
        mapProvider.overrideWith(
          () => TestMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
              tracks:
                  tracks ??
                  (populated ? [_track(1, 1989, 2), _track(2, 2024, 6)] : []),
            ),
          ),
        ),
        dashboardReferenceClockProvider.overrideWithValue(
          clock ?? () => DateTime(2026, 10, 15),
        ),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        peaksBaggedRepositoryProvider.overrideWithValue(
          PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
        ),
      ],
    );
    final h = _Harness(tester, container);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      container.dispose();
      h.shellFocus.dispose();
      h.editFocus.dispose();
      h.active.dispose();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: (theme ?? MyTheme.dark).copyWith(
            platform: TargetPlatform.macOS,
          ),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Column(
              children: [
                Row(
                  children: [
                    TextButton(
                      focusNode: h.shellFocus,
                      onPressed: () {},
                      child: const Text('Shell'),
                    ),
                    Expanded(
                      child: Material(child: TextField(focusNode: h.editFocus)),
                    ),
                  ],
                ),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: h.active,
                    builder: (_, enabled, _) => TickerMode(
                      enabled: enabled,
                      child: const HeroMode(
                        enabled: false,
                        child: DashboardScreen(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return h;
  }

  Finder card(String id) => find.byKey(Key('dashboard-card-$id'));
  void setTracks(List<GpxTrack> tracks, {bool loading = false}) {
    final notifier = container.read(mapProvider.notifier) as TestMapNotifier;
    notifier.state = container
        .read(mapProvider)
        .copyWith(tracks: tracks, isLoadingTracks: loading);
  }

  List<String?> inspectionRows() => tester
      .widgetList<Text>(
        find.descendant(
          of: control('time', 'time-tooltip'),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data)
      .toList();
  void expectInspection(
    String title, {
    String total = '0d 5h 0m',
    String moving = '0d 4h 0m',
  }) => expect(inspectionRows(), [
    title,
    'Total Time: $total',
    'Moving Time: $moving',
  ]);
  void expectNoInspection() =>
      expect(control('time', 'time-tooltip'), findsNothing);
  Finder control(String id, String key) =>
      find.descendant(of: card(id), matching: find.byKey(Key(key)));
  FocusNode node(String id) => tester
      .widget<Focus>(find.byKey(Key('dashboard-card-$id-focus')))
      .focusNode!;
  DashboardCardKeyboardController owner(String id) => tester
      .widget<DashboardCardKeyboard>(
        find.descendant(
          of: card(id),
          matching: find.byType(DashboardCardKeyboard),
        ),
      )
      .controller;
  void expectFocus(String id) =>
      expect(FocusManager.instance.primaryFocus, same(node(id)), reason: id);
  SummaryChart chart(String id) => tester.widget<SummaryChart>(
    find.descendant(of: card(id), matching: find.byType(SummaryChart)),
  );
  DateTime page(String id) => chart(id).buckets.first.start;
  IconButton button(String id, String action) =>
      tester.widget<IconButton>(control(id, 'summary-$action-window'));
  BorderSide border(String id) =>
      (tester
                  .widget<Card>(
                    find
                        .descendant(of: card(id), matching: find.byType(Card))
                        .first,
                  )
                  .shape
              as RoundedRectangleBorder)
          .side;
  Future<void> key(LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Future<void> tabBack() async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await key(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }

  Future<void> reorder({required bool forward, bool settle = true}) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(
      forward ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft,
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> focus(String id) async {
    for (var i = 0; i < dashboardCards.length; i++) {
      await key(LogicalKeyboardKey.tab);
      if (FocusManager.instance.primaryFocus?.debugLabel ==
          'Dashboard card: ${dashboardCards.firstWhere((c) => c.id == id).title}') {
        return;
      }
    }
    fail('Could not traverse to $id');
  }

  Future<void> tap(String id, String action) async {
    await tester.tap(control(id, 'summary-$action-window'));
    await tester.pumpAndSettle();
    node(id).requestFocus();
    await tester.pump();
  }

  Future<void> period(String id, SummaryPeriodPreset period) async {
    final current = chart(id).period.index;
    await key(LogicalKeyboardKey.keyP);
    for (var i = 0; i < (period.index - current).abs(); i++) {
      await key(
        period.index < current
            ? LogicalKeyboardKey.arrowUp
            : LogicalKeyboardKey.arrowDown,
      );
    }
    await key(LogicalKeyboardKey.enter);
    expect(chart(id).period, period);
  }
}

GpxTrack _track(int id, int year, int month) {
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'keyboard-$id',
    trackName: 'Track $id',
    trackDate: DateTime.utc(year, month, 15),
    trackDateStatus: TrackDateStatus.resolved,
    totalTimeMillis: 18000000,
    movingTime: 14400000,
    distance2d: 700,
    distance3d: 770,
    ascent: 70,
  );
  track.peaks.add(
    Peak(osmId: id, name: 'Peak $id', latitude: -42, longitude: 146),
  );
  return track;
}

GpxTrack _timeTrack(
  int id,
  int year,
  int month,
  int day, {
  int total = 18000000,
  int moving = 14400000,
}) => GpxTrack(
  gpxTrackId: id,
  contentHash: 'time-keyboard-$id',
  trackName: 'Track $id',
  trackDate: DateTime.utc(year, month, day),
  trackDateStatus: TrackDateStatus.resolved,
  totalTimeMillis: total,
  movingTime: moving,
);
