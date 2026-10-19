import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/dashboard/summary_chart.dart';

void main() {
  for (final mode in SummaryDisplayMode.values) {
    for (final pinned in [false, true]) {
      testWidgets(
        'clears ${pinned ? 'pinned' : 'hover'} selection when ${mode.name} timeline shrinks',
        (tester) async {
          final controller = ScrollController();
          addTearDown(controller.dispose);
          final buckets = _dailyBuckets(201);

          await _pumpChart(
            tester,
            controller: controller,
            buckets: buckets,
            mode: mode,
          );
          controller.jumpTo(controller.position.maxScrollExtent);
          await tester.pumpAndSettle();
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer();
          addTearDown(mouse.removePointer);
          await mouse.moveTo(
            tester.getCenter(find.byKey(const Key('summary-bucket-200'))),
          );
          if (pinned) {
            await tester.tap(find.byKey(const Key('summary-bucket-200')));
          }
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('summary-tooltip')), findsOneWidget);

          await _pumpChart(
            tester,
            controller: controller,
            buckets: buckets.take(61).toList(),
            mode: mode,
          );
          expect(tester.takeException(), isNull);
          await mouse.moveTo(const Offset(700, 500));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('summary-tooltip')), findsNothing);

          await _pumpChart(
            tester,
            controller: controller,
            buckets: buckets,
            mode: mode,
          );
          expect(find.byKey(const Key('summary-tooltip')), findsNothing);
        },
      );
    }
  }

  testWidgets('clears a pinned selection when the timeline becomes empty', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final buckets = _dailyBuckets(7);

    await _pumpChart(tester, controller: controller, buckets: buckets);
    await tester.tap(find.byKey(const Key('summary-bucket-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('summary-tooltip')), findsOneWidget);

    await _pumpChart(tester, controller: controller, buckets: []);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('summary-tooltip')), findsNothing);
  });

  testWidgets('clears selection when the period changes at a valid index', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final buckets = _dailyBuckets(7);

    await _pumpChart(tester, controller: controller, buckets: buckets);
    await tester.tap(find.byKey(const Key('summary-bucket-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('summary-tooltip')), findsOneWidget);

    await _pumpChart(
      tester,
      controller: controller,
      buckets: buckets,
      period: SummaryPeriodPreset.week,
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('summary-tooltip')), findsNothing);
  });

  testWidgets('clears selection when the selected bucket date range changes', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpChart(tester, controller: controller, buckets: _dailyBuckets(7));
    await tester.tap(find.byKey(const Key('summary-bucket-3')));
    await tester.pumpAndSettle();
    expect(find.text('Day 4'), findsOneWidget);

    await _pumpChart(
      tester,
      controller: controller,
      buckets: _dailyBuckets(7, startDay: 8),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('summary-tooltip')), findsNothing);
  });

  testWidgets('keeps the selected bucket on value refresh and mode changes', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await _pumpChart(tester, controller: controller, buckets: _dailyBuckets(7));
    await tester.tap(find.byKey(const Key('summary-bucket-3')));
    await tester.pumpAndSettle();
    expect(find.text('Day 4'), findsOneWidget);
    expect(find.text('Value: 1'), findsOneWidget);

    await _pumpChart(
      tester,
      controller: controller,
      buckets: _dailyBuckets(7, value: 3),
      mode: SummaryDisplayMode.line,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byKey(const Key('summary-tooltip')), findsOneWidget);
    expect(find.text('Day 4'), findsOneWidget);
    expect(find.text('Value: 3'), findsOneWidget);
  });

  testWidgets('tooltip aligns flush with clipped chart edges', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    final buckets = List.generate(
      12,
      (index) => SummaryBucket(
        start: DateTime(2025, index + 1, 1),
        endExclusive: DateTime(2025, index + 2, 1),
        label: _monthLabel(index),
        value: (index + 1).toDouble(),
        trackCount: 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            key: const Key('summary-chart-host'),
            width: 360,
            height: 260,
            child: SummaryChart(
              keyPrefix: 'summary',
              controller: controller,
              buckets: buckets,
              mode: SummaryDisplayMode.columns,
              barSeriesStyle: SummaryBarSeriesStyle.stacked,
              bucketExtent: 40,
              period: SummaryPeriodPreset.last12Months,
              referenceDate: DateTime(2025, 12, 31),
              chartMaxYFor: (_) => 12,
              tooltipValueTexts: (bucket, _) => [
                'Value: ${bucket.value.toInt()}',
              ],
              tooltipTitleText: (bucket, _) => bucket.label,
              yAxisLabelText: (value) => value.toInt().toString(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final hostRect = tester.getRect(
      find.byKey(const Key('summary-chart-host')),
    );
    final graphLeft = tester
        .getRect(find.byKey(const Key('summary-y-axis-separator')))
        .right;

    await tester.tap(find.byKey(const Key('summary-bucket-0')));
    await tester.pumpAndSettle();

    final firstTooltipRect = tester.getRect(
      find.byKey(const Key('summary-tooltip')),
    );
    expect(firstTooltipRect.left, closeTo(graphLeft, 1.0));
    expect(firstTooltipRect.right, lessThanOrEqualTo(hostRect.right));

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('summary-bucket-11')));
    await tester.pumpAndSettle();

    final lastTooltipRect = tester.getRect(
      find.byKey(const Key('summary-tooltip')),
    );
    expect(lastTooltipRect.left, greaterThanOrEqualTo(graphLeft));
    expect(lastTooltipRect.right, closeTo(hostRect.right, 1.0));
  });

  testWidgets('uses chart series theme colors for the first series', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    const chartSeriesTheme = ChartSeriesTheme(
      primarySeriesColor: Color(0xFF123456),
      secondarySeriesColor: Color(0xFF789ABC),
      selectedPrimarySeriesColor: Color(0xFF654321),
      selectedSecondarySeriesColor: Color(0xFFABCDEF),
    );

    final buckets = [
      SummaryBucket(
        start: DateTime(2025, 1, 1),
        endExclusive: DateTime(2025, 2, 1),
        label: 'Jan',
        value: 5,
        trackCount: 1,
      ),
    ];
    final secondaryBuckets = [
      SummaryBucket(
        start: DateTime(2025, 1, 1),
        endExclusive: DateTime(2025, 2, 1),
        label: 'Jan',
        value: 3,
        trackCount: 1,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [chartSeriesTheme]),
        home: Scaffold(
          body: SizedBox(
            key: const Key('summary-chart-host'),
            width: 360,
            height: 260,
            child: SummaryChart(
              keyPrefix: 'summary',
              controller: controller,
              buckets: buckets,
              secondaryBuckets: secondaryBuckets,
              mode: SummaryDisplayMode.columns,
              barSeriesStyle: SummaryBarSeriesStyle.grouped,
              bucketExtent: 40,
              period: SummaryPeriodPreset.last12Months,
              referenceDate: DateTime(2025, 12, 31),
              chartMaxYFor: (_) => 12,
              tooltipValueTexts: (bucket, _) => [
                'Value: ${bucket.value.toInt()}',
              ],
              tooltipTitleText: (bucket, _) => bucket.label,
              yAxisLabelText: (value) => value.toInt().toString(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final initialBarChart = tester.widget<BarChart>(find.byType(BarChart));
    expect(
      initialBarChart.data.barGroups.single.barRods[0].color,
      chartSeriesTheme.primarySeriesColor,
    );
    expect(
      initialBarChart.data.barGroups.single.barRods[1].color,
      chartSeriesTheme.secondarySeriesColor,
    );

    await tester.tap(find.byKey(const Key('summary-bucket-0')));
    await tester.pumpAndSettle();

    final selectedBarChart = tester.widget<BarChart>(find.byType(BarChart));
    expect(
      selectedBarChart.data.barGroups.single.barRods[0].color,
      chartSeriesTheme.selectedPrimarySeriesColor,
    );
    expect(
      selectedBarChart.data.barGroups.single.barRods[1].color,
      chartSeriesTheme.selectedSecondarySeriesColor,
    );
  });
}

List<SummaryBucket> _dailyBuckets(
  int count, {
  int startDay = 1,
  double value = 1,
}) {
  return List.generate(
    count,
    (index) => SummaryBucket(
      start: DateTime(2025, 1, startDay + index),
      endExclusive: DateTime(2025, 1, startDay + index + 1),
      label: 'Day ${startDay + index}',
      value: value,
      trackCount: 1,
    ),
  );
}

Future<void> _pumpChart(
  WidgetTester tester, {
  required ScrollController controller,
  required List<SummaryBucket> buckets,
  SummaryDisplayMode mode = SummaryDisplayMode.columns,
  SummaryPeriodPreset period = SummaryPeriodPreset.month,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 260,
          child: SummaryChart(
            keyPrefix: 'summary',
            controller: controller,
            buckets: buckets,
            mode: mode,
            barSeriesStyle: SummaryBarSeriesStyle.stacked,
            bucketExtent: 40,
            period: period,
            referenceDate: DateTime(2025, 12, 31),
            chartMaxYFor: (_) => 4,
            tooltipValueTexts: (bucket, _) => [
              'Value: ${bucket.value.toInt()}',
            ],
            tooltipTitleText: (bucket, _) => bucket.label,
            yAxisLabelText: (value) => value.toInt().toString(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _monthLabel(int index) {
  const labels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return labels[index];
}
