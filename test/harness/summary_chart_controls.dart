import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/widgets/dashboard/summary_chart.dart';

enum SummaryTestView {
  columns,
  line,
  clustered;

  SummaryDisplayMode get mode =>
      this == line ? SummaryDisplayMode.line : SummaryDisplayMode.columns;
}

const sharedSummaryMenuKey = Key('shared-dropdown-menu');

/// Capture the actual row gesture for same-frame lock/disposal regressions.
VoidCallback summaryChoiceAction(WidgetTester tester, String key) => tester
    .widget<GestureDetector>(
      find
          .descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(GestureDetector),
          )
          .first,
    )
    .onTap!;

Iterable<SummaryTestView> summaryTestViews(String kind) =>
    kind == 'time' ? SummaryTestView.values : SummaryTestView.values.take(2);

Future<void> selectSummaryView(
  WidgetTester tester,
  String kind,
  SummaryTestView view,
) async {
  final chart = tester.widget<SummaryChart>(find.byType(SummaryChart));
  if (kind == 'time') {
    final style = view == SummaryTestView.clustered
        ? SummaryBarSeriesStyle.grouped
        : SummaryBarSeriesStyle.subsetStacked;
    if (chart.mode == view.mode && chart.barSeriesStyle == style) return;
    await tester.tap(find.byKey(const Key('time-chart-type-button')));
    await tester.pump();
    final name = switch (view) {
      SummaryTestView.columns => 'stackedColumn',
      SummaryTestView.line => 'line',
      SummaryTestView.clustered => 'clusteredColumn',
    };
    await tester.tap(find.byKey(Key('time-chart-type-$name')));
  } else if (chart.mode != view.mode) {
    await tester.tap(find.byKey(const Key('summary-mode-fab')));
  }
}

Future<void> toggleSummaryMode(WidgetTester tester, String kind) async {
  final chart = tester.widget<SummaryChart>(find.byType(SummaryChart));
  await selectSummaryView(
    tester,
    kind,
    chart.mode == SummaryDisplayMode.line
        ? SummaryTestView.columns
        : SummaryTestView.line,
  );
}
