import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/providers/dashboard_browsing_provider.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/my_ascents_summary_provider.dart';
import 'package:peak_bagger/providers/my_lists_summary_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/summary_page_controller.dart';
import 'package:peak_bagger/providers/time_chart_type_provider.dart';
import 'package:peak_bagger/router.dart' as app_router;
import 'package:peak_bagger/screens/dashboard_screen.dart';
import 'package:peak_bagger/services/my_ascents_summary_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_list_summary_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/dashboard/latest_walk_card.dart';
import 'package:peak_bagger/widgets/dashboard/summary_chart.dart';
import 'package:peak_bagger/widgets/shell_destination_keyboard.dart';
import 'package:peak_bagger/widgets/side_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/fixture_tile_provider.dart';
import '../harness/mapping_catalog_fixture.dart';
import '../harness/test_map_notifier.dart';
import '../harness/time_chart_preference_storage.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'rapid browsing uses current selection and year limits before the next paint',
    (tester) async {
      final h = await _Harness.pump(tester, populated: true);
      await h.focus('latest-walk');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(h.map.openedTracks, [1]);
      h.router.go('/');
      await tester.pumpAndSettle();
      await h.focus('year-to-date');
      await h.key(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pumpAndSettle();
      expect(h.text('year-to-date-title'), 'My Walks in 2026');
      h.expectFocus('year-to-date');
    },
  );

  for (final id in ['my-lists', 'my-ascents']) {
    testWidgets(
      '$id rapid row movement/Enter opens current identity before painting',
      (tester) async {
        final h = await _Harness.pump(tester, populated: true);
        await h.focus(id);
        final nextId = h.selection(id).ids[1];
        await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(h.path, '/map');
        if (id == 'my-lists') {
          expect(h.map.preparedLists, [nextId]);
        } else {
          expect(h.map.openedTracks, [100 + nextId]);
        }
      },
    );
  }

  testWidgets(
    'F6 return preserves Time inspection and shell keys do not browse its page',
    (tester) async {
      final h = await _Harness.pump(tester, populated: true);
      await h.focus('time');
      await h.key(LogicalKeyboardKey.keyH);
      SummaryChart chart() => tester.widget<SummaryChart>(
        find.descendant(
          of: h.card('time'),
          matching: find.byType(SummaryChart),
        ),
      );
      final inspected = chart().inspection!.index;
      final first = chart().buckets.first.start;
      await h.key(LogicalKeyboardKey.f6);
      for (final key in [
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyB,
        LogicalKeyboardKey.keyP,
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.keyH,
        LogicalKeyboardKey.keyL,
      ]) {
        await h.key(key);
      }
      expect(chart().buckets.first.start, first);
      expect(chart().inspection!.index, inspected);
      await h.key(LogicalKeyboardKey.escape);
      h.expectFocus('time');
      expect(chart().inspection!.index, inspected);
      await h.key(LogicalKeyboardKey.keyH);
      expect(chart().inspection!.index, inspected - 1);
    },
  );

  testWidgets(
    'Latest Walk B/W match pointer bounds and Enter opens displayed Track',
    (tester) async {
      final h = await _Harness.pump(tester, populated: true);
      await h.focus('latest-walk');
      expect(h.text('latest-walk-track-title'), 'Track 3');
      await h.key(LogicalKeyboardKey.keyW);
      expect(h.text('latest-walk-track-title'), 'Track 3');
      await h.key(LogicalKeyboardKey.keyB);
      expect(h.text('latest-walk-track-title'), 'Track 2');
      h.expectFocus('latest-walk');
      await tester.tap(find.byKey(const Key('latest-walk-prev-track')));
      await tester.pumpAndSettle();
      expect(h.text('latest-walk-track-title'), 'Track 1');
      await h.focus('latest-walk');
      await h.key(LogicalKeyboardKey.keyB);
      expect(h.text('latest-walk-track-title'), 'Track 1');
      await h.key(LogicalKeyboardKey.keyW);
      expect(h.text('latest-walk-track-title'), 'Track 2');
      await h.key(LogicalKeyboardKey.enter);
      expect(h.path, '/map');
      expect(h.map.openedTracks, [2]);
      expect(h.container.read(mapProvider).selectedTrackId, 2);
      // Retained Dashboard state and pointer map actions use the same boundary.
      h.router.go('/');
      await tester.pumpAndSettle();
      await h.focus('latest-walk');
      expect(h.text('latest-walk-track-title'), 'Track 2');
      await tester.tap(find.byKey(const Key('latest-walk-track-title-link')));
      await tester.pumpAndSettle();
      expect(h.path, '/map');
      expect(h.map.openedTracks, [2, 2]);
    },
  );

  testWidgets(
    'My Year to Date has independent year bounds, statistics and loading guard',
    (tester) async {
      final h = await _Harness.pump(tester, populated: true);
      await h.focus('year-to-date');
      expect(h.text('year-to-date-title'), 'My Walks in 2026');
      await h.key(LogicalKeyboardKey.keyW);
      expect(h.text('year-to-date-title'), 'My Walks in 2026');
      await h.key(LogicalKeyboardKey.keyB);
      expect(h.text('year-to-date-title'), 'My Walks in 2025');
      expect(h.text('year-to-date-total-walks-value'), '1');
      h.expectFocus('year-to-date');
      await tester.tap(find.byKey(const Key('year-to-date-prev-year')));
      await tester.pumpAndSettle();
      await h.focus('year-to-date');
      expect(h.text('year-to-date-title'), 'My Walks in 2024');
      await h.key(LogicalKeyboardKey.keyW);
      expect(h.text('year-to-date-title'), 'My Walks in 2025');
      h.map.setLoadingTracks(true);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.pump();
      h.map.setLoadingTracks(false);
      await tester.pumpAndSettle();
      expect(h.text('year-to-date-title'), 'My Walks in 2025');
      expect(h.path, '/');
    },
  );

  testWidgets(
    'empty cards have no selection or Enter outcome; new data enters first row',
    (tester) async {
      final h = await _Harness.pump(tester);
      for (final id in ['latest-walk', 'my-lists', 'my-ascents']) {
        await h.focus(id);
        for (final key in [
          LogicalKeyboardKey.keyB,
          LogicalKeyboardKey.keyW,
          LogicalKeyboardKey.keyJ,
          LogicalKeyboardKey.keyK,
          LogicalKeyboardKey.enter,
        ]) {
          await h.key(key);
        }
        expect(h.path, '/');
        h.expectFocus(id);
        if (id != 'latest-walk') expect(h.selection(id).selectedId, isNull);
      }
      expect(h.map.openedTracks, isEmpty);
      expect(h.map.preparedLists, isEmpty);
      h.container.updateOverrides(h.overrides(populated: true));
      await tester.pumpAndSettle();
      await h.focus('my-lists');
      expect(h.selection('my-lists').selectedId, 1);
      await h.focus('my-ascents');
      expect(h.selection('my-ascents').selectedId, 12);
    },
  );

  for (final theme in [MyTheme.dark]) {
    for (final id in ['my-lists', 'my-ascents']) {
      testWidgets(
        '$id first/non-wrapping selection, measured scroll and distinct focus/hover ${theme.brightness}',
        (tester) async {
          final h = await _Harness.pump(
            tester,
            populated: true,
            theme: theme,
            scale: 1.5,
            size: const Size(1300, 520),
          );
          final semantics = tester.ensureSemantics();
          await h.focus(id);
          final ids = h.selection(id).ids;
          expect(h.selection(id).selectedId, ids.first);
          final first = h.row(id, ids.first);
          final firstStyle = h.decoration(first);
          expect(firstStyle.color, theme.colorScheme.primaryContainer);
          expect(
            (firstStyle.border! as Border).left.color,
            theme.colorScheme.primary,
          );
          expect(MediaQuery.textScalerOf(tester.element(first)).scale(1), 1.5);
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: const Offset(1, 1));
          await mouse.moveTo(tester.getCenter(h.row(id, ids[1])));
          await tester.pumpAndSettle();
          expect(
            h.decoration(h.row(id, ids[1])).color,
            isNot(firstStyle.color),
          );
          expect(h.selection(id).selectedId, ids.first);
          await mouse.removePointer();
          await h.key(LogicalKeyboardKey.keyK);
          expect(h.selection(id).selectedId, ids.first);
          for (var i = 0; i < ids.length; i++) {
            await h.key(
              i.isEven ? LogicalKeyboardKey.keyJ : LogicalKeyboardKey.arrowDown,
            );
          }
          expect(h.selection(id).selectedId, ids.last);
          final last = h.row(id, ids.last);
          expect(last.hitTestable(), findsOneWidget);
          final rowRect = tester.getRect(last);
          final scroller = find.descendant(
            of: h.card(id),
            matching: find.byType(SingleChildScrollView),
          );
          final viewport = tester.getRect(scroller);
          expect(rowRect.top, greaterThanOrEqualTo(viewport.top));
          expect(rowRect.bottom, lessThanOrEqualTo(viewport.bottom + 0.01));
          expect(h.scroll(id).offset, greaterThan(0));
          h.expectFocus(id);
          // Selected styling remains, but the keyboard accent follows card focus.
          await h.key(LogicalKeyboardKey.f6);
          expect(h.decoration(last).color, firstStyle.color);
          expect(
            (h.decoration(last).border! as Border).left.color,
            Colors.transparent,
          );
          await h.key(LogicalKeyboardKey.escape);
          h.expectFocus(id);
          expect(h.selection(id).selectedId, ids.last);
          expect(
            (h.decoration(last).border! as Border).left.color,
            theme.colorScheme.primary,
          );
          for (var i = 0; i < ids.length; i++) {
            await h.key(
              i.isEven ? LogicalKeyboardKey.keyK : LogicalKeyboardKey.arrowUp,
            );
          }
          expect(h.selection(id).selectedId, ids.first);
          expect(first.hitTestable(), findsOneWidget);
          await h.key(LogicalKeyboardKey.tab);
          expect(
            FocusManager.instance.primaryFocus!.debugLabel,
            startsWith('Dashboard card:'),
          );
          semantics.dispose();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'My Ascents S and pointer sort retain selected identity and reveal it',
    (tester) async {
      final h = await _Harness.pump(
        tester,
        populated: true,
        size: const Size(1300, 520),
      );
      await h.focus('my-ascents');
      await h.key(LogicalKeyboardKey.keyJ);
      final id = h.selection('my-ascents').selectedId!;
      expect(id, 11);
      await h.key(LogicalKeyboardKey.keyS);
      expect(h.container.read(myAscentsAscendingProvider), isTrue);
      expect(h.selection('my-ascents').selectedId, id);
      expect(h.row('my-ascents', id).hitTestable(), findsOneWidget);
      h.expectFocus('my-ascents');
      await tester.tap(find.byKey(const Key('my-ascents-sort-toggle')));
      await tester.pumpAndSettle();
      expect(h.container.read(myAscentsAscendingProvider), isFalse);
      expect(h.selection('my-ascents').selectedId, id);
      expect(h.row('my-ascents', id).hitTestable(), findsOneWidget);
      await h.focus('my-ascents');
      await h.key(LogicalKeyboardKey.keyJ);
      final trackId = 100 + h.selection('my-ascents').selectedId!;
      await h.key(LogicalKeyboardKey.enter);
      expect(h.path, '/map');
      expect(h.map.openedTracks, [trackId]);
    },
  );

  testWidgets(
    'My Lists Enter preserves preparation failures and navigates only when allowed',
    (tester) async {
      final h = await _Harness.pump(tester, populated: true);
      await h.focus('my-lists');
      await h.key(LogicalKeyboardKey.keyJ);
      h.map.result = const PeakListMapNavigationResult.noMappablePeaks();
      await h.key(LogicalKeyboardKey.enter);
      expect(h.map.preparedLists, [2]);
      expect(h.path, '/');
      expect(find.text('This list has no mappable peaks.'), findsOneWidget);
      h.expectFocus('my-lists');
      h.map.result = const PeakListMapNavigationResult.unavailable();
      ScaffoldMessenger.of(
        tester.element(h.card('my-lists')),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await h.key(LogicalKeyboardKey.enter);
      expect(find.text('Peak list is no longer available.'), findsOneWidget);
      expect(h.path, '/');
      h.map.result = const PeakListMapNavigationResult.queued();
      await h.key(LogicalKeyboardKey.enter);
      expect(h.map.preparedLists, [2, 2, 2]);
      expect(h.path, '/map');
      h.router.go('/');
      await tester.pumpAndSettle();
      await h.focus('my-lists');
      await tester.tap(h.row('my-lists', 1));
      await tester.pumpAndSettle();
      expect(h.map.preparedLists.last, 1);
      expect(h.path, '/map');
    },
  );

  testWidgets(
    'F6 highlights selected destination without activation; Escape/F6/Tab return correctly',
    (tester) async {
      final h = await _Harness.pump(
        tester,
        populated: true,
        size: const Size(1300, 420),
      );
      await h.focus('my-ascents');
      final order = h.container.read(dashboardLayoutProvider);
      for (final closing in [
        LogicalKeyboardKey.escape,
        LogicalKeyboardKey.f6,
      ]) {
        await h.key(LogicalKeyboardKey.f6);
        h.expectShellFocus(0);
        await h.key(LogicalKeyboardKey.keyJ);
        h.expectShellFocus(1);
        await h.key(LogicalKeyboardKey.arrowDown);
        h.expectShellFocus(2);
        await h.key(LogicalKeyboardKey.keyK);
        h.expectShellFocus(1);
        await h.key(LogicalKeyboardKey.arrowUp);
        h.expectShellFocus(0);
        expect(h.path, '/');
        await h.key(LogicalKeyboardKey.keyS);
        expect(h.container.read(myAscentsAscendingProvider), isFalse);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await h.key(LogicalKeyboardKey.arrowLeft);
        await h.key(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        expect(h.container.read(dashboardLayoutProvider), order);
        h.expectShellFocus(0);
        await h.key(closing);
        h.expectFocus('my-ascents');
      }
      await h.key(LogicalKeyboardKey.f6);
      await h.key(LogicalKeyboardKey.tab);
      h.expectFocus(order.first); // last -> first, including previously unbuilt
      await h.key(LogicalKeyboardKey.f6);
      await h.tabBack();
      h.expectFocus(order.last);
      await h.key(LogicalKeyboardKey.f6);
      await h.key(LogicalKeyboardKey.enter); // same destination restores card
      h.expectFocus(order.last);
      expect(h.path, '/');
      await h.key(LogicalKeyboardKey.f6);
      for (var i = 0; i < 4; i++) {
        await h.key(LogicalKeyboardKey.keyJ);
      }
      await h.key(LogicalKeyboardKey.enter);
      expect(h.path, '/settings');
      await h.key(LogicalKeyboardKey.keyB);
      expect(h.path, '/settings');
      h.router.go('/');
      await tester.pumpAndSettle();
      await h.focus('distance');
      await h.key(LogicalKeyboardKey.f6);
      h.expectShellFocus(0);
    },
  );

  testWidgets(
    'production routed shell shares F6 activation and pointer destination action',
    (tester) async {
      final h = await _Harness.pump(tester, productionRouter: true);
      await h.focus('distance');
      await h.key(LogicalKeyboardKey.f6);
      h.expectShellFocus(0);
      for (var i = 0; i < 4; i++) {
        await h.key(LogicalKeyboardKey.arrowDown);
      }
      expect(h.path, '/');
      await h.key(LogicalKeyboardKey.enter);
      expect(h.path, '/settings');
      await tester.tap(find.byKey(const Key('nav-dashboard')));
      await tester.pumpAndSettle();
      expect(h.path, '/');
      await h.focus('distance');
      await h.key(LogicalKeyboardKey.f6);
      h.expectShellFocus(0);
      await h.key(LogicalKeyboardKey.escape);
      h.expectFocus('distance');
    },
  );

  for (final card in dashboardCards) {
    testWidgets(
      'R from ${card.title} retries displayed Time warning with Time off-screen, retaining focus/deduplicating',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          dashboardCardOrderStorageKey: [
            card.id,
            ...dashboardDefaultCardOrder.where(
              (id) => id != card.id && id != 'time',
            ),
            if (card.id != 'time') 'time',
          ],
        });
        final storage = TestTimeChartPreferenceStorage()
          ..readSteps.add(() => Future.error(StateError('read')));
        final retry = Completer<String?>();
        storage.readSteps.add(() => retry.future);
        final h = await _Harness.pump(
          tester,
          storage: storage,
          size: const Size(1300, 420),
        );
        await h.focus(card.id);
        // Time is last in the saved order; the target is the first stop.
        if (card.id != 'time') {
          expect(h.card('time').hitTestable(), findsNothing);
        }
        expect(
          find.text('Couldn’t load Time chart preference.'),
          findsOneWidget,
        );
        expect(
          h.container.read(timeChartTypeProvider).visibleWarningId,
          isNotNull,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
        await tester.pump();
        expect(storage.reads, 2);
        h.expectFocus(card.id);
        // An explicit selection made while retrying must win the late read.
        await h.container
            .read(timeChartTypeProvider.notifier)
            .select(TimeChartType.clusteredColumn);
        retry.complete('line');
        await tester.pumpAndSettle();
        expect(
          h.container.read(timeChartTypeProvider).selected,
          TimeChartType.clusteredColumn,
        );
        expect(find.byType(SnackBar), findsNothing);
        h.expectFocus(card.id);
        await h.key(LogicalKeyboardKey.keyR);
        expect(storage.reads, 2);
      },
    );
  }

  testWidgets(
    'R save retry uses latest type; menus/shell/modifiers do not retry',
    (tester) async {
      final storage = TestTimeChartPreferenceStorage();
      final h = await _Harness.pump(tester, storage: storage, populated: true);
      await h.focus('distance');
      storage.writeSteps.add(() => Future.value(false));
      await h.container
          .read(timeChartTypeProvider.notifier)
          .select(TimeChartType.line);
      await tester.pumpAndSettle();
      final writes = storage.writes.length;
      await h.key(LogicalKeyboardKey.keyP);
      await h.key(LogicalKeyboardKey.keyR);
      expect(storage.writes.length, writes);
      await h.key(LogicalKeyboardKey.escape);
      await h.key(LogicalKeyboardKey.f6);
      await h.key(LogicalKeyboardKey.keyR);
      expect(storage.writes.length, writes);
      await h.key(LogicalKeyboardKey.escape);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await h.key(LogicalKeyboardKey.keyR);
      await h.key(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      expect(storage.writes.length, writes);
      // The latest failure identity replaces the first one.
      storage.writeSteps.add(() => Future.value(false));
      await h.container
          .read(timeChartTypeProvider.notifier)
          .select(TimeChartType.clusteredColumn);
      await tester.pumpAndSettle();
      final pending = Completer<bool>();
      storage.writeSteps.add(() => pending.future);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.pump();
      expect(storage.writes, ['line', 'clustered-column', 'clustered-column']);
      h.expectFocus('distance');
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(storage.stored, 'clustered-column');
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets(
    'R ignores queued Time warning/card-order Retry and preserves warning lifetime',
    (tester) async {
      final read = Completer<String?>();
      final storage = TestTimeChartPreferenceStorage()
        ..readSteps.add(() => read.future);
      final h = await _Harness.pump(tester, storage: storage, settle: false);
      await tester.pump(const Duration(seconds: 1));
      await h.focus('elevation', settle: false);
      final messenger = ScaffoldMessenger.of(
        tester.element(h.card('elevation')),
      );
      var orderRetries = 0;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Couldn’t save Dashboard card order.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => orderRetries++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      read.completeError(StateError('read'));
      await tester.pumpAndSettle();
      expect(h.container.read(timeChartTypeProvider).visibleWarningId, isNull);
      expect(find.text('Couldn’t load Time chart preference.'), findsNothing);
      await h.key(LogicalKeyboardKey.keyR);
      expect(storage.reads, 1);
      expect(orderRetries, 0);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(orderRetries, 1);
      expect(find.text('Couldn’t load Time chart preference.'), findsOneWidget);
      // Normal timeout removes keyboard identity and R becomes a no-op.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(h.container.read(timeChartTypeProvider).visibleWarningId, isNull);
      await h.key(LogicalKeyboardKey.keyR);
      expect(storage.reads, 1);
    },
  );

  testWidgets(
    'typing/modified row actions and inactive Dashboard do not dispatch',
    (tester) async {
      final h = await _Harness.pump(tester, populated: true);
      await h.focus('my-ascents');
      final id = h.selection('my-ascents').selectedId;
      for (final modifier in [
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.shiftLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        for (final key in [
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.keyJ,
          LogicalKeyboardKey.keyS,
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.keyR,
          LogicalKeyboardKey.f6,
        ]) {
          await h.key(key);
        }
        await tester.sendKeyUpEvent(modifier);
      }
      expect(h.selection('my-ascents').selectedId, id);
      expect(h.container.read(myAscentsAscendingProvider), isFalse);
      expect(h.map.openedTracks, isEmpty);
      h.editFocus.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'jksrBW');
      await h.key(LogicalKeyboardKey.keyJ);
      await h.key(LogicalKeyboardKey.keyS);
      expect(h.selection('my-ascents').selectedId, id);
      expect(h.container.read(myAscentsAscendingProvider), isFalse);
      h.router.go('/settings');
      await tester.pumpAndSettle();
      await h.key(LogicalKeyboardKey.keyS);
      await h.key(LogicalKeyboardKey.enter);
      expect(h.path, '/settings');
      expect(h.container.read(myAscentsAscendingProvider), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Harness {
  _Harness(this.tester, this.storage);
  final WidgetTester tester;
  final TestTimeChartPreferenceStorage storage;
  final editFocus = FocusNode();
  late final container = ProviderContainer(overrides: overrides());
  late GoRouter router;
  late final map = _ActionMap();

  List<Override> overrides({bool populated = false}) => [
    ...mappingCatalogTestOverrides,
    mapProvider.overrideWith(() => map),
    peakListRepositoryProvider.overrideWithValue(
      PeakListRepository.test(InMemoryPeakListStorage()),
    ),
    peaksBaggedRepositoryProvider.overrideWithValue(
      PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
    ),
    peakRepositoryProvider.overrideWithValue(
      PeakRepository.test(InMemoryPeakStorage()),
    ),
    dashboardReferenceClockProvider.overrideWithValue(
      () => DateTime(2026, 10, 15),
    ),
    latestWalkTileProviderFactoryProvider.overrideWithValue(
      FixtureTileProvider.new,
    ),
    timeChartPreferenceStorageProvider.overrideWithValue(storage),
    myListsSummaryProvider.overrideWithValue(
      populated
          ? [
              for (var i = 1; i <= 12; i++)
                PeakListSummaryRow(
                  peakList: PeakList(peakListId: i, name: 'List $i'),
                  totalPeaks: 5,
                  climbed: 1,
                  unclimbed: 4,
                  percentageValue: .2,
                ),
            ]
          : [],
    ),
    myAscentsSummaryProvider.overrideWithValue(
      populated
          ? MyAscentsDataset(
              baggedRows: [
                for (var i = 1; i <= 12; i++)
                  PeaksBagged(
                    baggedId: i,
                    peakId: i,
                    gpxId: 100 + i,
                    date: DateTime.utc(2020 + i ~/ 4, 1, i),
                  ),
              ],
              peaksByOsmId: {
                for (var i = 1; i <= 12; i++)
                  i: Peak(
                    osmId: i,
                    name: 'Peak $i',
                    latitude: -42,
                    longitude: 146,
                  ),
              },
            )
          : const MyAscentsDataset.empty(),
    ),
  ];

  static Future<_Harness> pump(
    WidgetTester tester, {
    bool populated = false,
    bool productionRouter = false,
    bool settle = true,
    TestTimeChartPreferenceStorage? storage,
    ThemeData? theme,
    double scale = 1,
    Size size = const Size(1600, 1000),
  }) async {
    final h = _Harness(tester, storage ?? TestTimeChartPreferenceStorage());
    h.container.updateOverrides(h.overrides(populated: populated));
    if (populated) {
      h.container.read(mapProvider);
      h.map.setTracks(_tracks());
    }
    if (productionRouter) {
      h.router = app_router.createRouter();
    } else {
      h.router = GoRouter(
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, child) {
              final selected = child.currentIndex;
              return ShellDestinationKeyboard(
                labels: [for (final d in app_router.shellDestinations) d.label],
                selectedIndex: selected,
                onActivate: (i) => child.goBranch(i),
                child: Scaffold(
                  body: Column(
                    children: [
                      Material(child: TextField(focusNode: h.editFocus)),
                      Expanded(
                        child: Row(
                          children: [
                            SideMenu(
                              destinations: app_router.shellDestinations,
                              selectedBranchIndex: selected,
                              onDestinationSelected: (d) =>
                                  child.goBranch(d.branchIndex),
                            ),
                            Expanded(child: child),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const DashboardScreen(),
                  ),
                ],
              ),
              for (final d in app_router.shellDestinations.skip(1))
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: d.routePath,
                      builder: (_, _) => Text(d.label),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
    }
    app_router.router = h.router;
    await tester.binding.setSurfaceSize(size);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      h.router.dispose();
      h.container.dispose();
      h.editFocus.dispose();
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp.router(
          theme: (theme ?? MyTheme.dark).copyWith(
            platform: TargetPlatform.macOS,
          ),
          routerConfig: h.router,
          builder: (_, child) => MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return h;
  }

  String get path => router.routerDelegate.currentConfiguration.uri.path;
  Finder card(String id) => find.byKey(Key('dashboard-card-$id'));
  Finder row(String id, int rowId) => find.byKey(Key('$id-row-$rowId'));
  String? text(String key) => tester.widget<Text>(find.byKey(Key(key))).data;
  DashboardRowSelection selection(String id) =>
      container.read(dashboardRowSelectionProvider(id));
  ScrollController scroll(String id) => tester
      .widget<SingleChildScrollView>(
        find.descendant(
          of: card(id),
          matching: find.byType(SingleChildScrollView),
        ),
      )
      .controller!;
  BoxDecoration decoration(Finder row) =>
      tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: row,
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .decoration!
          as BoxDecoration;
  FocusNode node(String id) => tester
      .widget<Focus>(find.byKey(Key('dashboard-card-$id-focus')))
      .focusNode!;
  void expectFocus(String id) =>
      expect(FocusManager.instance.primaryFocus, same(node(id)));
  void expectShellFocus(int index) => expect(
    FocusManager.instance.primaryFocus,
    same(
      tester
          .widget<Focus>(find.byKey(Key('shell-destination-$index-focus')))
          .focusNode,
    ),
  );
  Future<void> key(LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Future<void> tabBack() async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await key(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }

  Future<void> focus(String id, {bool settle = true}) async {
    for (var i = 0; i <= dashboardCards.length; i++) {
      final f = find.byKey(Key('dashboard-card-$id-focus'));
      if (f.evaluate().isNotEmpty &&
          FocusManager.instance.primaryFocus == node(id)) {
        return;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      if (settle) {
        await tester.pumpAndSettle();
      } else {
        for (var n = 0; n < 4; n++) {
          await tester.pump();
        }
      }
    }
    fail('Cannot focus $id');
  }
}

class _ActionMap extends TestMapNotifier {
  _ActionMap()
    : super(
        const MapState(
          center: LatLng(-42, 146),
          zoom: 10,
          basemap: Basemap.tracestrack,
        ),
      );
  final openedTracks = <int>[];
  final preparedLists = <int>[];
  PeakListMapNavigationResult result =
      const PeakListMapNavigationResult.queued();
  @override
  void showTrack(int trackId, {LatLng? selectedLocation}) {
    openedTracks.add(trackId);
    state = state.copyWith(selectedTrackId: trackId);
  }

  @override
  Future<PeakListMapNavigationResult> preparePeakListMapNavigation(
    int peakListId,
  ) async {
    preparedLists.add(peakListId);
    return result;
  }
}

List<GpxTrack> _tracks() => [
  for (var i = 1; i <= 3; i++)
    GpxTrack(
      gpxTrackId: i,
      contentHash: 'actions-$i',
      trackName: 'Track $i',
      startDateTime: DateTime.utc(2023 + i, 1, 1),
      trackDate: DateTime.utc(2023 + i, 1, 1),
      totalTimeMillis: 18000000,
      movingTime: 14400000,
      gpxFile: '<gpx/>',
      displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
        [const LatLng(-42, 146), const LatLng(-42.1, 146.1)],
      ]),
    ),
];
