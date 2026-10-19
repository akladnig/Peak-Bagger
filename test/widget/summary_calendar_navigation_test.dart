import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/track_date_status.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/dashboard/distance_card.dart';
import 'package:peak_bagger/widgets/dashboard/elevation_card.dart';
import 'package:peak_bagger/widgets/dashboard/peaks_bagged_card.dart';
import 'package:peak_bagger/widgets/dashboard/summary_card.dart';
import 'package:peak_bagger/widgets/dashboard/summary_chart.dart';
import 'package:peak_bagger/widgets/dashboard/time_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/summary_chart_controls.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final kind in ['elevation', 'distance', 'peaks-bagged', 'time']) {
    for (final view in summaryTestViews(kind)) {
      testWidgets(
        '$kind ${view.name} weekly hover and pin share compact titles and metric rows',
        (tester) async {
          await _pump(
            tester,
            kind: kind,
            tracks: [_track(1, DateTime.utc(2026, 10, 1))..distance3d = 770],
          );
          await selectSummaryView(tester, kind, view);
          await tester.pumpAndSettle();
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: const Offset(790, 590));
          addTearDown(mouse.removePointer);
          for (final preset in [
            SummaryPeriodPreset.last3Months,
            SummaryPeriodPreset.last6Months,
          ]) {
            await _selectPeriod(tester, preset.label);
            final index = _chart(
              tester,
            ).buckets.indexWhere((b) => b.start == DateTime(2026, 9, 28));
            final bucket = find.byKey(Key('$kind-bucket-$index'));
            await mouse.moveTo(tester.getCenter(bucket));
            await tester.pumpAndSettle();
            expect(find.text('28 Sep – 4 Oct 2026'), findsOneWidget);
            final tooltip = find.byKey(Key('$kind-tooltip'));
            final textFinder = find.descendant(
              of: tooltip,
              matching: find.byType(Text),
            );
            final hoverRows = tester
                .widgetList<Text>(textFinder)
                .map((t) => (t.data, t.style?.color))
                .toList();
            expect(hoverRows.map((row) => row.$1), [
              '28 Sep – 4 Oct 2026',
              if (kind == 'elevation') '70 m',
              if (kind == 'distance') ...['2D: 700 m', '3D: 770 m'],
              if (kind == 'peaks-bagged') ...['Total Peaks: 1', 'New peaks: 1'],
              if (kind == 'time') ...[
                'Total Time: 0d 5h 0m',
                'Moving Time: 0d 4h 0m',
              ],
            ]);
            await tester.tap(bucket);
            await mouse.moveTo(const Offset(790, 590));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widgetList<Text>(textFinder)
                  .map((t) => (t.data, t.style?.color)),
              hoverRows,
            );
            expect(tester.takeException(), isNull);
          }
        },
      );

      testWidgets(
        '$kind ${view.name} anchored presets share pages, bounds and summaries',
        (tester) async {
          SummaryVisibleSummary? summary;
          await _pump(
            tester,
            kind: kind,
            tracks: [
              _track(1, DateTime.utc(1989, 2, 28)),
              _track(2, DateTime.utc(2005, 6, 15)),
              _track(3, DateTime.utc(2026, 6, 15)),
            ],
            onSummary: (value) => summary = value,
          );
          // Default current page includes November 2025 through October 2026.
          expect(_chart(tester).period, SummaryPeriodPreset.last12Months);
          expect(_chart(tester).buckets.first.start, DateTime(2025, 11));
          expect(_chart(tester).buckets.last.endExclusive, DateTime(2026, 11));
          await selectSummaryView(tester, kind, view);
          await tester.pumpAndSettle();
          final unitValue = _unit(kind);
          for (final fixture in [
            (
              SummaryPeriodPreset.last3Months,
              DateTime(2026, 8),
              DateTime(2026, 5),
              DateTime(1989, 2),
              '3 Months',
              3,
            ),
            (
              SummaryPeriodPreset.last6Months,
              DateTime(2026, 5),
              DateTime(2025, 11),
              DateTime(1988, 11),
              '6 Months',
              6,
            ),
            (
              SummaryPeriodPreset.last12Months,
              DateTime(2025, 11),
              DateTime(2024, 11),
              DateTime(1988, 11),
              '12 Months',
              12,
            ),
            (
              SummaryPeriodPreset.allTime,
              DateTime(2015),
              DateTime(2003),
              DateTime(1989),
              '12 Years',
              12,
            ),
            (
              SummaryPeriodPreset.yearToDate,
              DateTime(2026),
              DateTime(2025),
              DateTime(1989),
              'Year',
              10,
            ),
          ]) {
            await _selectPeriod(tester, fixture.$1.label);
            expect(_chart(tester).buckets.first.start, fixture.$2);
            expect(_button(tester, 'prev').tooltip, 'Previous ${fixture.$5}');
            expect(_button(tester, 'next').tooltip, isNull);
            expect(
              (_button(tester, 'next').icon as Icon).semanticLabel,
              'Next ${fixture.$5}',
            );
            expect(_button(tester, 'first').tooltip, 'First');
            expect(
              _button(tester, 'last').tooltip,
              fixture.$1 == SummaryPeriodPreset.last3Months ? 'Last' : null,
            );
            expect(_button(tester, 'next').onPressed, isNull);
            final currentTotal = fixture.$1 == SummaryPeriodPreset.last3Months
                ? 0
                : unitValue;
            expect(summary?.totalValue, currentTotal);
            expect(summary?.averageValue, currentTotal / fixture.$6);
            expect(find.byKey(Key('$kind-empty-state')), findsNothing);
            await tester.tap(_control('prev'));
            await tester.pumpAndSettle();
            expect(_chart(tester).buckets.first.start, fixture.$3);
            expect(
              summary?.totalValue,
              fixture.$1 == SummaryPeriodPreset.last3Months ||
                      fixture.$1 == SummaryPeriodPreset.allTime
                  ? unitValue
                  : 0,
            );
            if (fixture.$1 == SummaryPeriodPreset.last3Months) {
              // June belongs to May–July, even though October anchors the sequence.
              expect(_button(tester, 'last').onPressed, isNull);
              expect(_button(tester, 'next').onPressed, isNotNull);
            }
            await tester.tap(_control('first'));
            await tester.pumpAndSettle();
            expect(_chart(tester).buckets.first.start, fixture.$4);
            expect(_button(tester, 'prev').onPressed, isNull);
            expect(_button(tester, 'first').onPressed, isNull);
            expect(_button(tester, 'next').onPressed, isNotNull);
            expect(summary?.totalValue, unitValue);
            expect(
              summary?.averageValue,
              unitValue /
                  (fixture.$1 == SummaryPeriodPreset.allTime
                      ? 2
                      : fixture.$1 == SummaryPeriodPreset.yearToDate
                      ? 12
                      : fixture.$6),
            );
            if (kind != 'elevation') {
              final chart = _chart(tester);
              expect(
                chart.secondaryBuckets!.map((b) => (b.start, b.endExclusive)),
                chart.buckets.map((b) => (b.start, b.endExclusive)),
              );
            }
            final beforeMode = _chart(tester).buckets.first.start;
            await toggleSummaryMode(tester, kind);
            await tester.pumpAndSettle();
            expect(_chart(tester).buckets.first.start, beforeMode);
            await toggleSummaryMode(tester, kind);
            await tester.pumpAndSettle();
            await tester.tap(_control('last'));
            await tester.pumpAndSettle();
            expect(
              _chart(tester).buckets.first.start,
              fixture.$1 == SummaryPeriodPreset.last3Months
                  ? DateTime(2026, 5)
                  : fixture.$2,
            );
            expect(_button(tester, 'last').onPressed, isNull);
            expect(summary?.totalValue, unitValue);
            if (kind == 'peaks-bagged') {
              expect(
                _chart(tester).secondaryBuckets!.every((b) => b.value == 0),
                isTrue,
              );
            }
          }
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '$kind ${view.name} clipped edge-week inspection and future cutoff',
        (tester) async {
          SummaryVisibleSummary? summary;
          await _pump(
            tester,
            kind: kind,
            tracks: [
              _track(1, DateTime.utc(2026, 7, 31))..distance3d = 770,
              _track(2, DateTime.utc(2026, 8, 1))..distance3d = 770,
              _track(3, DateTime.utc(2026, 8, 2))..distance3d = 770,
              _track(4, DateTime.utc(2026, 10, 16))..distance3d = 770,
              _track(5, DateTime.utc(2030))..distance3d = 770,
            ],
            onSummary: (value) => summary = value,
          );
          await _selectPeriod(tester, 'Last 3 Months');
          await selectSummaryView(tester, kind, view);
          await tester.pumpAndSettle();
          expect(_chart(tester).buckets, hasLength(14));
          expect(_chart(tester).buckets.first.trackCount, 2);
          expect(summary?.totalValue, _unit(kind) * 2);
          expect(summary?.averageValue, summary!.totalValue / 3);
          expect(find.text('Sat, 1 Aug - Sat, 31 Oct 2026'), findsOneWidget);
          if (kind == 'distance') {
            expect(_chart(tester).secondaryBuckets!.first.value, 1540);
          }
          await tester.tap(find.byKey(Key('$kind-bucket-0')));
          await tester.pumpAndSettle();
          expect(find.text('1-2 Aug 2026'), findsOneWidget);
          await tester.tap(_control('prev'));
          await tester.pumpAndSettle();
          expect(find.byKey(Key('$kind-tooltip')), findsNothing);
          expect(_chart(tester).buckets.last.trackCount, 1);
          await tester.tap(
            find.byKey(
              Key('$kind-bucket-${_chart(tester).buckets.length - 1}'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('27-31 Jul 2026'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '$kind ${view.name} all remaining presets exclude both future series',
        (tester) async {
          await _pump(
            tester,
            kind: kind,
            tracks: [
              _track(1, DateTime.utc(2026, 10, 14))..distance3d = 770,
              _track(2, DateTime.utc(2026, 10, 16))..distance3d = 770,
              _track(3, DateTime.utc(2030))..distance3d = 770,
            ],
          );
          await selectSummaryView(tester, kind, view);
          await tester.pumpAndSettle();
          for (final preset in SummaryPeriodPreset.values.skip(2)) {
            await _selectPeriod(tester, preset.label);
            final chart = _chart(tester);
            expect(
              chart.buckets.fold<int>(0, (sum, b) => sum + b.trackCount),
              1,
            );
            expect(
              chart.buckets.fold<double>(0, (sum, b) => sum + b.value),
              _unit(kind),
            );
            if (kind == 'distance') {
              expect(
                chart.secondaryBuckets!.fold<double>(
                  0,
                  (sum, b) => sum + b.value,
                ),
                770,
              );
            }
            if (kind == 'peaks-bagged') {
              expect(
                chart.secondaryBuckets!.fold<double>(
                  0,
                  (sum, b) => sum + b.value,
                ),
                1,
              );
            }
            for (final action in ['first', 'prev', 'next', 'last']) {
              expect(_button(tester, action).onPressed, isNull);
            }
          }
        },
      );

      for (final period in ['Week', 'Month']) {
        testWidgets(
          '$kind ${view.name} $period visits full history and empty gaps',
          (tester) async {
            SummaryVisibleSummary? summary;
            final tracks = [
              // Distance's non-null zero default remains qualifying activity.
              // Elevation/Peaks require an actual primary metric instead.
              if (kind != 'distance')
                GpxTrack(
                  gpxTrackId: 3,
                  contentHash: '3',
                  trackName: 'No metric',
                  trackDate: DateTime.utc(2010),
                ),
              _track(1, DateTime.utc(2020, 2, 29)),
              _track(2, DateTime.utc(2026, 8, 15)),
            ];
            await _pump(
              tester,
              kind: kind,
              tracks: tracks,
              onSummary: (s) => summary = s,
            );
            await _selectPeriod(tester, period);
            await selectSummaryView(tester, kind, view);
            await tester.pumpAndSettle();
            final currentStart = period == 'Month'
                ? DateTime(2026, 10)
                : DateTime(2026, 10, 12);
            expect(_chart(tester).buckets.first.start, currentStart);
            expect(summary?.totalValue, 0);
            expect(summary?.averageValue, 0);
            expect(_button(tester, 'next').onPressed, isNull);
            expect(_button(tester, 'last').onPressed, isNotNull);
            final controls = ['first', 'prev', 'next', 'last'];
            expect(
              controls.map((c) => (_button(tester, c).icon as Icon).icon),
              [
                Icons.first_page,
                Icons.chevron_left,
                Icons.chevron_right,
                Icons.last_page,
              ],
            );
            expect(controls.map((c) => _button(tester, c).tooltip), [
              'First',
              'Previous $period',
              null,
              'Last',
            ]);
            for (var i = 1; i < controls.length; i++) {
              expect(
                tester.getCenter(_control(controls[i])).dx,
                greaterThan(tester.getCenter(_control(controls[i - 1])).dx),
              );
              expect(
                tester.getCenter(_control(controls[i])).dy,
                tester.getCenter(_control(controls[0])).dy,
              );
            }

            await tester.tap(_control('last'));
            await tester.pumpAndSettle();
            expect(
              _chart(tester).buckets.first.start,
              period == 'Month' ? DateTime(2026, 8) : DateTime(2026, 8, 10),
            );
            expect(summary?.totalValue, _unit(kind));
            expect(
              summary?.averageValue,
              _unit(kind) / (period == 'Week' ? 7 : 6),
            );
            expect(_button(tester, 'last').onPressed, isNull);
            expect(
              _button(tester, 'last').mouseCursor,
              SystemMouseCursors.basic,
            );
            expect(
              _button(tester, 'next').mouseCursor,
              SystemMouseCursors.click,
            );
            // Repeated peaks are primary activity even without any new peaks.
            if (kind == 'peaks-bagged') {
              expect(
                _chart(
                  tester,
                ).secondaryBuckets!.fold<double>(0, (s, b) => s + b.value),
                0,
              );
            }
            if (kind == 'distance') {
              expect(
                _chart(tester).secondaryBuckets!.map((b) => b.start),
                _chart(tester).buckets.map((b) => b.start),
              );
              expect(
                _chart(tester).secondaryBuckets!.every((b) => b.value == 0),
                isTrue,
              );
            }
            await tester.tap(_control('next'));
            await tester.pumpAndSettle();
            expect(
              _chart(tester).buckets.first.start,
              period == 'Month' ? DateTime(2026, 9) : DateTime(2026, 8, 17),
            );
            expect(summary?.totalValue, 0);
            expect(summary?.averageValue, 0);
            expect(find.textContaining('No '), findsNothing);
            if (period == 'Month') {
              await tester.tap(_control('next'));
              await tester.pumpAndSettle();
              expect(_chart(tester).buckets.first.start, currentStart);
              expect(_button(tester, 'next').onPressed, isNull);
            }
            await tester.tap(_control('first'));
            await tester.pumpAndSettle();
            expect(
              _chart(tester).buckets.first.start,
              period == 'Month' ? DateTime(2020, 2) : DateTime(2020, 2, 24),
            );
            expect(
              _chart(tester).buckets,
              hasLength(period == 'Month' ? 29 : 7),
            );
            expect(_button(tester, 'first').onPressed, isNull);
            expect(_button(tester, 'prev').onPressed, isNull);
            expect(_button(tester, 'next').onPressed, isNotNull);
            final before = _chart(tester).buckets.first.start;
            await toggleSummaryMode(tester, kind);
            await tester.pumpAndSettle();
            expect(_chart(tester).buckets.first.start, before);
            await _selectPeriod(tester, period == 'Month' ? 'Week' : 'Month');
            expect(
              _chart(tester).buckets.first.start,
              period == 'Month' ? DateTime(2026, 10, 12) : DateTime(2026, 10),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
      testWidgets('$kind ${view.name} Month hover and future-day cutoff', (
        tester,
      ) async {
        SummaryVisibleSummary? summary;
        await _pump(
          tester,
          kind: kind,
          tracks: [
            _track(1, DateTime.utc(2026, 10, 15))..distance3d = 770,
            _track(2, DateTime.utc(2026, 10, 16))..distance3d = 770,
          ],
          onSummary: (s) => summary = s,
        );
        await _selectPeriod(tester, 'Month');
        await selectSummaryView(tester, kind, view);
        await tester.pumpAndSettle();
        expect(_chart(tester).buckets[14].trackCount, 1);
        expect(_chart(tester).buckets[15].trackCount, 0);
        expect(_chart(tester).buckets[15].value, 0);
        if (kind == 'distance') {
          expect(_chart(tester).secondaryBuckets![14].value, 770);
          expect(_chart(tester).secondaryBuckets![15].value, 0);
        }
        expect(_chart(tester).buckets, hasLength(31));
        expect(summary?.totalValue, _unit(kind));
        await tester.tap(find.byKey(Key('$kind-bucket-14')));
        await tester.pumpAndSettle();
        expect(find.text('Thu 15 Oct'), findsOneWidget);
        await _selectPeriod(tester, 'Week');
        expect(find.byKey(Key('$kind-tooltip')), findsNothing);
        expect(_chart(tester).buckets[4].value, 0);
      });
    }
  }

  for (final kind in ['elevation', 'distance', 'peaks-bagged', 'time']) {
    testWidgets('$kind future-only data retains the no-data state', (
      tester,
    ) async {
      await _pump(
        tester,
        kind: kind,
        tracks: [_track(1, DateTime.utc(2026, 10, 16))],
      );
      expect(find.byKey(Key('$kind-empty-state')), findsOneWidget);
      expect(find.byType(SummaryChart), findsNothing);
      expect(find.byKey(const Key('summary-first-window')), findsNothing);
    });
  }

  for (final theme in [MyTheme.light, MyTheme.dark]) {
    testWidgets(
      'single-row toolbar supports focus, semantics and enlarged text in ${theme.brightness.name}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(
          tester,
          kind: 'elevation',
          theme: theme.copyWith(platform: TargetPlatform.macOS),
          textScale: 1.5,
          tracks: [
            _track(1, DateTime.utc(2020)),
            _track(2, DateTime.utc(2026, 8)),
          ],
        );
        await _selectPeriod(tester, 'Year to Date');
        final first = _control('first');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        final focus = Focus.of(
          tester.element(
            find.descendant(of: first, matching: find.byType(Icon)).first,
          ),
        );
        focus.requestFocus();
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        expect(
          tester.getSemantics(first),
          matchesSemantics(
            label: 'First',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            isFocused: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
        final style = _button(tester, 'first').style!;
        expect(style.foregroundColor!.resolve({}), theme.colorScheme.onSurface);
        expect(
          style.foregroundColor!.resolve({WidgetState.disabled}),
          theme.colorScheme.onSurface.withValues(alpha: 0.38),
        );
        expect(
          style.overlayColor!.resolve({WidgetState.focused}),
          isNot(style.overlayColor!.resolve({WidgetState.hovered})),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(_chart(tester).buckets.first.start, DateTime(2020));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        // Disabled first/previous are skipped; next is the following action.
        final nextFocus = Focus.of(
          tester.element(
            find
                .descendant(of: _control('next'), matching: find.byType(Icon))
                .first,
          ),
        );
        expect(nextFocus.hasFocus, isTrue);
        final y = tester.getCenter(_control('first')).dy;
        expect(tester.getCenter(_control('last')).dy, y);
        expect(MediaQuery.textScalerOf(tester.element(first)).scale(10), 15);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  for (final period in SummaryPeriodPreset.values) {
    testWidgets(
      '${period.label} disabled controls have names but no hover or stale tooltip',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(
          tester,
          kind: 'elevation',
          tracks: [
            _track(1, DateTime.utc(1980)),
            _track(2, DateTime.utc(2005)),
          ],
        );
        await _selectPeriod(tester, period.label);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(790, 590));
        addTearDown(mouse.removePointer);
        Future<void> hover(String action) async {
          await mouse.moveTo(const Offset(790, 590));
          await tester.pumpAndSettle();
          await mouse.moveTo(tester.getCenter(_control(action)));
          await tester.pump(const Duration(seconds: 1));
          await tester.pumpAndSettle();
        }

        final names = {
          'first': 'First',
          'prev': period.previousTooltip,
          'next': period.nextTooltip,
          'last': 'Last',
        };
        await hover('next');
        expect(find.text(names['next']!), findsNothing);
        expect(_button(tester, 'next').tooltip, isNull);
        await hover('first');
        expect(find.text('First'), findsOneWidget);
        // Click while hovered: the popup must disappear as the action disables.
        await tester.tap(_control('first'));
        await tester.pumpAndSettle();
        expect(find.text('First'), findsNothing);
        for (final action in ['first', 'prev']) {
          await hover(action);
          expect(find.text(names[action]!), findsNothing);
          expect(_button(tester, action).tooltip, isNull);
          expect(_button(tester, action).mouseCursor, SystemMouseCursors.basic);
          expect(
            tester.getSemantics(_control(action)),
            matchesSemantics(
              label: names[action],
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
            ),
          );
        }
        for (final action in ['next', 'last']) {
          await hover(action);
          expect(find.text(names[action]!), findsOneWidget);
          expect(_button(tester, action).tooltip, names[action]);
          expect(_button(tester, action).mouseCursor, SystemMouseCursors.click);
        }
        await tester.tap(_control('next'));
        await tester.pumpAndSettle();
        await hover('prev');
        expect(find.text(names['prev']!), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}

SummaryChart _chart(WidgetTester tester) =>
    tester.widget<SummaryChart>(find.byType(SummaryChart));
double _unit(String kind) => switch (kind) {
  'elevation' => 70,
  'distance' => 700,
  'time' => 18000000,
  _ => 1,
};
Finder _control(String action) => find.byKey(Key('summary-$action-window'));
IconButton _button(WidgetTester tester, String action) =>
    tester.widget<IconButton>(_control(action));

Future<void> _selectPeriod(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('summary-period-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required String kind,
  required List<GpxTrack> tracks,
  ValueChanged<SummaryVisibleSummary?>? onSummary,
  ThemeData? theme,
  double textScale = 1,
  double width = 520,
}) async {
  final now = DateTime(2026, 10, 15, 12);
  final card = switch (kind) {
    'elevation' => ElevationCard(
      tracks: tracks,
      isLoading: false,
      now: now,
      onVisibleSummaryChanged: onSummary,
    ),
    'distance' => DistanceCard(
      tracks: tracks,
      isLoading: false,
      now: now,
      onVisibleSummaryChanged: onSummary,
    ),
    'time' => TimeCard(
      tracks: tracks,
      isLoading: false,
      now: now,
      onVisibleSummaryChanged: onSummary,
    ),
    _ => PeaksBaggedCard(
      tracks: tracks,
      isLoading: false,
      now: now,
      onVisibleSummaryChanged: onSummary,
    ),
  };
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: SizedBox(width: width, height: 320, child: card),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

GpxTrack _track(int id, DateTime day) =>
    GpxTrack(
        gpxTrackId: id,
        contentHash: '$id',
        trackName: 'Track $id',
        trackDate: day,
        trackDateStatus: TrackDateStatus.resolved,
        ascent: 70,
        distance2d: 700,
        totalTimeMillis: 18000000,
        movingTime: 14400000,
      )
      ..peaks.add(
        Peak(
          osmId: 11,
          name: 'Peak',
          latitude: -42,
          longitude: 147,
          elevation: 100,
        ),
      );
