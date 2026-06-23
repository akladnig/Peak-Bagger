import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/widgets/dashboard/summary_chart.dart';

void main() {
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

    final hostRect = tester.getRect(find.byKey(const Key('summary-chart-host')));
    final graphLeft = tester.getRect(
      find.byKey(const Key('summary-y-axis-separator')),
    ).right;

    await tester.tap(find.byKey(const Key('summary-bucket-0')));
    await tester.pumpAndSettle();

    final firstTooltipRect = tester.getRect(find.byKey(const Key('summary-tooltip')));
    expect(firstTooltipRect.left, closeTo(graphLeft, 1.0));
    expect(firstTooltipRect.right, lessThanOrEqualTo(hostRect.right));

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('summary-bucket-11')));
    await tester.pumpAndSettle();

    final lastTooltipRect = tester.getRect(find.byKey(const Key('summary-tooltip')));
    expect(lastTooltipRect.left, greaterThanOrEqualTo(graphLeft));
    expect(lastTooltipRect.right, closeTo(hostRect.right, 1.0));
  });
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
