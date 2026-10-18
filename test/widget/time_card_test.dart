import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/track_date_status.dart';
import 'package:peak_bagger/providers/time_chart_type_provider.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/dashboard/summary_card.dart';
import 'package:peak_bagger/widgets/dashboard/summary_chart.dart';
import 'package:peak_bagger/widgets/dashboard/time_card.dart';

void main() {
  for (final theme in [
    MyTheme.light,
    MyTheme.dark,
    ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange)),
  ]) {
    for (final type in [TimeChartType.line, TimeChartType.clusteredColumn]) {
      testWidgets(
        '${type.name} has independent values, themed selection and full tooltip rows ${theme.brightness} ${theme.colorScheme.primary}',
        (tester) async {
          await _pump(
            tester,
            tracks: [
              _track(1, 18000000, 14400000),
              _track(2, 3600000, 3600000, month: 9),
              _track(3, 3600000, 0, month: 8),
              _track(4, 0, 0, month: 7),
            ],
            theme: theme,
          );
          await _selectType(tester, type);
          final palette =
              theme.extension<ChartSeriesTheme>() ??
              ChartSeriesTheme.fromColorScheme(theme.colorScheme);
          if (type == TimeChartType.line) {
            final data = tester.widget<LineChart>(find.byType(LineChart)).data;
            expect(data.minY, 0);
            expect(data.maxY, greaterThanOrEqualTo(5 / 24));
            // Moving is painted last, keeping green visible at coincident spots.
            expect(data.lineBarsData.map((s) => s.color), [
              palette.primarySeriesColor,
              palette.secondarySeriesColor,
            ]);
            expect(data.lineBarsData[0].spots.last.y, closeTo(5 / 24, 1e-12));
            expect(data.lineBarsData[1].spots.last.y, closeTo(4 / 24, 1e-12));
            expect(
              data.lineBarsData[0].spots[10],
              data.lineBarsData[1].spots[10],
            );
            expect(data.lineBarsData[0].spots[8].y, 0);
            expect(data.lineBarsData[1].spots[8].y, 0);
          } else {
            final data = tester.widget<BarChart>(find.byType(BarChart)).data;
            expect(data.minY, 0);
            expect(data.maxY, greaterThanOrEqualTo(5 / 24));
            final rods = data.barGroups.last.barRods;
            expect(rods.map((r) => r.toY), [5 / 24, 4 / 24]);
            expect(rods.map((r) => r.color), [
              palette.primarySeriesColor,
              palette.secondarySeriesColor,
            ]);
            expect(
              rods.every((r) => r.fromY == 0 && r.rodStackItems.isEmpty),
              isTrue,
            );
            expect(data.barGroups[10].barRods.map((r) => r.toY), [
              1 / 24,
              1 / 24,
            ]);
            expect(data.barGroups[9].barRods.map((r) => r.toY), [1 / 24, 0]);
            expect(data.barGroups[8].barRods.map((r) => r.toY), [0, 0]);
          }
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: const Offset(790, 590));
          addTearDown(mouse.removePointer);
          for (final index in [11, 10, 9, 8]) {
            final bucket = find.byKey(Key('time-bucket-$index'));
            await mouse.moveTo(tester.getCenter(bucket));
            await tester.pumpAndSettle();
            final rows = _tooltipRows(tester);
            expect(rows.map((t) => t.data), [
              ['Jul', 'Aug', 'Sep', 'Oct'][index - 8],
              'Total Time: ${index == 11
                  ? '0d 5h 0m'
                  : index == 8
                  ? '0d 0h 0m'
                  : '0d 1h 0m'}',
              'Moving Time: ${index == 11
                  ? '0d 4h 0m'
                  : index == 10
                  ? '0d 1h 0m'
                  : '0d 0h 0m'}',
            ]);
            expect(rows.skip(1).map((t) => t.style?.color), [
              lighten(palette.primarySeriesColor),
              lighten(palette.secondarySeriesColor),
            ]);
            if (type == TimeChartType.line) {
              final lines = tester
                  .widget<LineChart>(find.byType(LineChart))
                  .data
                  .lineBarsData;
              final dots = lines.map(
                (line) =>
                    line.dotData.getDotPainter(
                          line.spots[index],
                          0,
                          line,
                          index,
                        )
                        as FlDotCirclePainter,
              );
              expect(dots.map((dot) => dot.strokeColor), [
                palette.selectedPrimarySeriesColor,
                palette.selectedSecondarySeriesColor,
              ]);
            } else {
              expect(
                tester
                    .widget<BarChart>(find.byType(BarChart))
                    .data
                    .barGroups[index]
                    .barRods
                    .map((r) => r.color),
                [
                  palette.selectedPrimarySeriesColor,
                  palette.selectedSecondarySeriesColor,
                ],
              );
            }
            await mouse.moveTo(const Offset(790, 590));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('time-tooltip')), findsNothing);
            await mouse.moveTo(tester.getCenter(bucket));
            await tester.pumpAndSettle();
            await tester.tap(bucket);
            await tester.pumpAndSettle();
            expect(
              _tooltipRows(tester).map((t) => t.data),
              rows.map((t) => t.data),
            );
            // Leaving a pinned bucket keeps its full two-series values visible.
            await mouse.moveTo(const Offset(790, 590));
            await tester.pumpAndSettle();
            expect(
              _tooltipRows(tester).map((t) => t.data),
              rows.map((t) => t.data),
            );
            // A different type clears that inspection before the next pass.
            await _selectType(tester, TimeChartType.stackedColumn);
            expect(find.byKey(const Key('time-tooltip')), findsNothing);
            await _selectType(tester, type);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      'subset stacks, selected colours and inspection use the theme ${theme.brightness} ${theme.colorScheme.primary}',
      (tester) async {
        final tracks = [
          _track(1, 18000000, 14400000),
          _track(2, 3600000, 3600000, month: 9),
          _track(3, 3600000, 0, month: 8),
          _track(4, 0, 0, month: 7),
        ];
        await _pump(tester, tracks: tracks, theme: theme);
        final palette =
            theme.extension<ChartSeriesTheme>() ??
            ChartSeriesTheme.fromColorScheme(theme.colorScheme);
        BarChart chart() => tester.widget<BarChart>(find.byType(BarChart));
        final rods = chart().data.barGroups
            .map((g) => g.barRods.single)
            .toList();
        final fiveHours = rods[11];
        expect(fiveHours.toY, closeTo(5 / 24, 1e-12));
        expect(fiveHours.rodStackItems, hasLength(2));
        expect(fiveHours.rodStackItems.map((s) => (s.fromY, s.toY)), [
          (0.0, 4 / 24),
          (4 / 24, 5 / 24),
        ]);
        expect(fiveHours.rodStackItems.map((s) => s.color), [
          palette.secondarySeriesColor,
          palette.primarySeriesColor,
        ]);
        expect(rods[10].rodStackItems, hasLength(1));
        expect(
          rods[10].rodStackItems.single.color,
          palette.secondarySeriesColor,
        );
        expect(rods[9].rodStackItems, hasLength(1));
        expect(rods[9].rodStackItems.single.color, palette.primarySeriesColor);
        expect(rods[8].rodStackItems, isEmpty);
        final bucket = find.byKey(const Key('time-bucket-11'));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(790, 590));
        addTearDown(mouse.removePointer);
        await mouse.moveTo(tester.getCenter(bucket));
        await tester.pumpAndSettle();
        Finder tooltip() => find.descendant(
          of: find.byKey(const Key('time-tooltip')),
          matching: find.byType(Text),
        );
        final rows = tester
            .widgetList<Text>(tooltip())
            .map((t) => (t.data, t.style?.color))
            .toList();
        expect(rows, [
          ('Oct', theme.textTheme.bodyMedium?.color),
          ('Total Time: 0d 5h 0m', lighten(palette.primarySeriesColor)),
          ('Moving Time: 0d 4h 0m', lighten(palette.secondarySeriesColor)),
        ]);
        expect(
          chart().data.barGroups[11].barRods.single.rodStackItems.map(
            (s) => s.color,
          ),
          [
            palette.selectedSecondarySeriesColor,
            palette.selectedPrimarySeriesColor,
          ],
        );
        await tester.tap(bucket);
        await mouse.moveTo(const Offset(790, 590));
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<Text>(tooltip())
              .map((t) => (t.data, t.style?.color)),
          rows,
        );
      },
    );
  }

  testWidgets(
    'pair-invalid history is wholly empty; zero/zero is rendered activity',
    (tester) async {
      SummaryVisibleSummary? summary;
      await _pump(
        tester,
        tracks: [_track(1, 1, null), _track(2, 1, 2)],
        onSummary: (s) => summary = s,
      );
      expect(find.text('No time data yet'), findsOneWidget);
      expect(summary, isNull);
      await _pump(
        tester,
        tracks: [_track(3, 0, 0)],
        onSummary: (s) => summary = s,
      );
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('No time data yet'), findsNothing);
      expect(summary?.totalValue, 0);
      expect(summary?.averageValue, 0);
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.maxY, greaterThan(0));
      final labels = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  (w.key?.toString().contains('time-y-axis-label') ?? false),
            ),
          )
          .map((t) => t.data)
          .toSet();
      expect(labels, hasLength(5));
      await _pump(
        tester,
        tracks: [],
        loading: true,
        onSummary: (s) => summary = s,
      );
      expect(find.byKey(const Key('time-loading-state')), findsOneWidget);
      expect(find.text('No time data yet'), findsNothing);
      expect(summary, isNull);
    },
  );

  testWidgets(
    'chart menu has exact order, icons, accessible selection and no-op dismissal',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var reports = 0;
      await _pump(
        tester,
        tracks: [_track(1, 18000000, 14400000)],
        onSummary: (_) => reports++,
      );
      final button = find.byKey(const Key('time-chart-type-button'));
      expect(tester.widget<FloatingActionButton>(button).tooltip, 'Chart type');
      expect(find.bySemanticsLabel('Chart type'), findsOneWidget);
      expect(find.byKey(const Key('summary-mode-fab')), findsNothing);
      await tester.tap(find.byKey(const Key('time-bucket-11')));
      await tester.pumpAndSettle();
      final identity = _chart(tester).inspectionIdentity;
      final beforeReports = reports;
      await tester.tap(button);
      await tester.pumpAndSettle();
      final items = tester
          .widgetList<MenuItemButton>(find.byType(MenuItemButton))
          .toList();
      expect(
        tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(MenuItemButton),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data),
        ['Stacked column view', 'Line view', 'Clustered column view'],
      );
      expect(items.map((i) => (i.leadingIcon as Icon).icon), [
        Icons.stacked_bar_chart,
        Icons.show_chart,
        Icons.bar_chart,
      ]);
      expect(items.map((i) => (i.trailingIcon as Icon?)?.icon), [
        Icons.check,
        null,
        null,
      ]);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Stacked column view'))
            .getSemanticsData()
            .flagsCollection
            .isSelected
            .toBoolOrNull(),
        isTrue,
      );
      await tester.tap(find.byKey(const Key('time-chart-type-stackedColumn')));
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
      expect(_chart(tester).inspectionIdentity, identity);
      expect(reports, beforeReports);
      expect(find.byKey(const Key('time-tooltip')), findsOneWidget);
      for (final escape in [true, false]) {
        await tester.tap(button);
        await tester.pumpAndSettle();
        if (escape) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.tapAt(const Offset(790, 590));
        }
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(_chart(tester).inspectionIdentity, identity);
        expect(find.byKey(const Key('time-tooltip')), findsOneWidget);
      }
      for (final entry in [
        (TimeChartType.line, Icons.show_chart),
        (TimeChartType.clusteredColumn, Icons.bar_chart),
        (TimeChartType.stackedColumn, Icons.stacked_bar_chart),
      ]) {
        await _selectType(tester, entry.$1);
        expect(find.byType(MenuItemButton), findsNothing);
        expect(
          find.descendant(of: button, matching: find.byIcon(entry.$2)),
          findsOneWidget,
        );
        expect(find.byKey(const Key('time-tooltip')), findsNothing);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(
                find.bySemanticsLabel(switch (entry.$1) {
                  TimeChartType.stackedColumn => 'Stacked column view',
                  TimeChartType.line => 'Line view',
                  TimeChartType.clusteredColumn => 'Clustered column view',
                }),
              )
              .getSemanticsData()
              .flagsCollection
              .isSelected
              .toBoolOrNull(),
          isTrue,
        );
        expect(
          tester
              .widgetList<MenuItemButton>(find.byType(MenuItemButton))
              .where((i) => i.trailingIcon != null),
          hasLength(1),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      }
      semantics.dispose();
    },
  );

  for (final theme in [MyTheme.light, MyTheme.dark]) {
    testWidgets(
      'menu supports pointer and available keyboard controls at enlarged text ${theme.brightness}',
      (tester) async {
        await _pump(
          tester,
          tracks: [_track(1, 18000000, 14400000)],
          theme: theme.copyWith(platform: TargetPlatform.macOS),
          textScale: 1.5,
        );
        for (final type in TimeChartType.values) {
          await _selectType(tester, type);
          final top = tester
              .getTopLeft(find.byKey(const Key('time-chart-type-button')))
              .dy;
          for (final key in [
            'summary-period-dropdown',
            'summary-first-window',
            'summary-prev-window',
            'summary-next-window',
            'summary-last-window',
          ]) {
            expect(tester.getTopLeft(find.byKey(Key(key))).dy, top);
          }
          expect(
            MediaQuery.textScalerOf(
              tester.element(find.byKey(const Key('time-chart-type-button'))),
            ).scale(10),
            15,
          );
        }
        await _selectType(tester, TimeChartType.stackedColumn);
        // Period, then mode: disabled arrows are skipped in this initial slice.
        final mode = find.byKey(const Key('time-chart-type-button'));
        // Menu closure restores the native invoking-control focus in this slice.
        // Work Item 04 replaces this with owning-card focus restoration.
        expect(
          Focus.of(
            tester.element(
              find.descendant(of: mode, matching: find.byType(Icon)).first,
            ),
          ).hasFocus,
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Stacked column view'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(MenuItemButton), findsNothing);
        expect(find.byType(BarChart), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.byType(LineChart), findsOneWidget);
        expect(find.byType(MenuItemButton), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'type selection supersedes pending scroll and safely ignores a disposed menu callback',
    (tester) async {
      await _pump(tester, tracks: [_track(1, 1, 0, month: 1), _track(2, 1, 0)]);
      await tester.tap(find.byKey(const Key('time-chart-type-button')));
      await tester.pumpAndSettle();
      // Deliberately retain the selection callback to overlap pending browsing.
      final select = tester
          .widget<MenuItemButton>(find.byKey(const Key('time-chart-type-line')))
          .onPressed!;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getCenter(
            find.byKey(const Key('time-page-browser')),
          ),
          scrollDelta: const Offset(-160, 0),
        ),
      );
      select();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_chart(tester).buckets.first.start, DateTime(2025, 11));
      expect(find.byType(LineChart), findsOneWidget);
      await tester.tap(find.byKey(const Key('time-chart-type-button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('time-chart-type-clusteredColumn')),
      );
      // MenuItemButton defers its action until the next post-frame callback.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      select();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inspection and pending browsing cannot update after disposal', (
    tester,
  ) async {
    await _pump(tester, tracks: [_track(1, 1, 0, month: 1), _track(2, 1, 0)]);
    await tester.tap(find.byKey(const Key('time-bucket-11')));
    await tester.pump();
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(find.byKey(const Key('time-page-browser'))),
        scrollDelta: const Offset(-160, 0),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  for (final type in TimeChartType.values) {
    testWidgets(
      '${type.name} retains type across empty/loading and zero data remains renderable',
      (tester) async {
        await _pump(tester, tracks: [_track(1, 0, 0)]);
        await _selectType(tester, type);
        final maxY = type == TimeChartType.line
            ? tester.widget<LineChart>(find.byType(LineChart)).data.maxY
            : tester.widget<BarChart>(find.byType(BarChart)).data.maxY;
        expect(maxY.isFinite && maxY > 0, isTrue);
        await tester.tap(find.byKey(const Key('time-bucket-11')));
        await tester.pumpAndSettle();
        expect(_tooltipRows(tester).map((t) => t.data), [
          'Oct',
          'Total Time: 0d 0h 0m',
          'Moving Time: 0d 0h 0m',
        ]);
        await _pump(tester, tracks: [], loading: true);
        expect(find.byKey(const Key('time-loading-state')), findsOneWidget);
        expect(find.text('No time data yet'), findsNothing);
        expect(find.byKey(const Key('time-tooltip')), findsNothing);
        await _pump(tester, tracks: []);
        expect(find.text('No time data yet'), findsOneWidget);
        await _pump(tester, tracks: [_track(2, 0, 0)]);
        expect(
          _chart(tester).mode,
          type == TimeChartType.line
              ? SummaryDisplayMode.line
              : SummaryDisplayMode.columns,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${type.name} preserves historical preset/page and rejects superseded inspection callbacks',
      (tester) async {
        final tracks = [
          _track(1, 18000000, 14400000, month: 1),
          _track(2, 3600000, 0),
        ];
        await _pump(tester, tracks: tracks);
        await tester.tap(find.byKey(const Key('summary-period-dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Month').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('summary-prev-window')));
        await tester.pumpAndSettle();
        final page = _chart(tester).buckets.first.start;
        await tester.tap(find.byKey(const Key('time-bucket-0')));
        await tester.pumpAndSettle();
        final oldEnter = tester
            .widget<MouseRegion>(find.byKey(const Key('time-bucket-0')))
            .onEnter!;
        await _selectType(tester, type);
        expect(_chart(tester).period, SummaryPeriodPreset.month);
        expect(_chart(tester).buckets.first.start, page);
        if (type != TimeChartType.stackedColumn) {
          oldEnter(const PointerEnterEvent());
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('time-tooltip')), findsNothing);
        }
        // Refresh supersedes even a callback retained at the same bucket index.
        final enter = tester
            .widget<MouseRegion>(find.byKey(const Key('time-bucket-0')))
            .onEnter!;
        await _pump(tester, tracks: [...tracks]);
        enter(const PointerEnterEvent());
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('time-tooltip')), findsNothing);
        expect(_chart(tester).buckets.first.start, page);
      },
    );
  }
}

SummaryChart _chart(WidgetTester tester) =>
    tester.widget<SummaryChart>(find.byType(SummaryChart));

List<Text> _tooltipRows(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(const Key('time-tooltip')),
        matching: find.byType(Text),
      ),
    )
    .toList();

Future<void> _selectType(WidgetTester tester, TimeChartType type) async {
  await tester.tap(find.byKey(const Key('time-chart-type-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('time-chart-type-${type.name}')));
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester, {
  required List<GpxTrack> tracks,
  bool loading = false,
  ThemeData? theme,
  double textScale = 1,
  ValueChanged<SummaryVisibleSummary?>? onSummary,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: SizedBox(
              width: 700,
              height: 400,
              child: TimeCard(
                tracks: tracks,
                isLoading: loading,
                now: DateTime(2026, 10, 15),
                onVisibleSummaryChanged: onSummary,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  if (!loading) await tester.pumpAndSettle();
}

GpxTrack _track(int id, int? total, int? moving, {int month = 10}) => GpxTrack(
  gpxTrackId: id,
  contentHash: '$id',
  trackName: 'Track $id',
  trackDate: DateTime.utc(2026, month, 15),
  trackDateStatus: TrackDateStatus.resolved,
  totalTimeMillis: total,
  movingTime: moving,
);
