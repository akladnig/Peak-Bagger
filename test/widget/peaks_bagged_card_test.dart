import 'dart:ui' show PointerDeviceKind;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/widgets/dashboard/peaks_bagged_card.dart';
import 'package:peak_bagger/widgets/dashboard/summary_card.dart';

void main() {
  group('PeaksBaggedCard', () {
    testWidgets('renders loading placeholder while tracks load', (
      tester,
    ) async {
      await _pumpPeaksBaggedCard(
        tester,
        tracks: const [],
        isLoading: true,
        settle: false,
      );

      expect(
        find.byKey(const Key('peaks-bagged-loading-state')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('peaks-bagged-empty-state')), findsNothing);
    });

    testWidgets('renders empty state when no usable tracks exist', (
      tester,
    ) async {
      await _pumpPeaksBaggedCard(tester, tracks: const []);

      expect(find.byKey(const Key('peaks-bagged-empty-state')), findsOneWidget);
      expect(find.text('No peaks bagged yet'), findsOneWidget);
    });

    testWidgets('renders summary controls and anchored latest window', (
      tester,
    ) async {
      await _pumpPeaksBaggedCard(
        tester,
        tracks: [
          _track(10, DateTime(2026, 3, 1, 10), peakIds: [11]),
          _track(20, DateTime(2026, 4, 15, 10), peakIds: [11, 22]),
          _track(30, DateTime(2026, 5, 15, 10), peakIds: [33, 44]),
        ],
        now: DateTime(2026, 5, 15, 12),
        width: 1000,
      );

      expect(find.byKey(const Key('peaks-bagged-card')), findsOneWidget);
      expect(_cardControl('summary-period-dropdown'), findsOneWidget);
      expect(_cardControl('summary-prev-window'), findsOneWidget);
      expect(_cardControl('summary-next-window'), findsOneWidget);
      expect(_cardControl('summary-mode-fab'), findsOneWidget);
      expect(find.byKey(const Key('peaks-bagged-bucket-0')), findsOneWidget);
    });

    testWidgets('reports visible summary when period changes', (tester) async {
      SummaryVisibleSummary? summary;

      await _pumpPeaksBaggedCard(
        tester,
        tracks: [
          _track(10, DateTime(2025, 12, 15, 10), peakIds: [11]),
          _track(20, DateTime(2026, 1, 15, 10), peakIds: [11, 22]),
          _track(30, DateTime(2026, 5, 15, 10), peakIds: [33]),
        ],
        now: DateTime(2026, 5, 15, 12),
        onVisibleSummaryChanged: (value) => summary = value,
      );

      final initialSummary = summary;
      expect(initialSummary, isNotNull);

      await _selectPeriod(tester, 'Month');

      expect(summary, isNotNull);
      expect(summary, isNot(initialSummary));
      expect(summary?.totalValue.round(), 1);
      expect(find.byKey(const Key('peaks-bagged-scroll-view')), findsOneWidget);
    });

    testWidgets('toggles display mode and shows peaks tooltip', (
      tester,
    ) async {
      await _pumpPeaksBaggedCard(
        tester,
        tracks: [
          _track(10, DateTime(2026, 5, 1, 10), peakIds: [11]),
          _track(20, DateTime(2026, 5, 15, 10), peakIds: [11, 22]),
          _track(30, DateTime(2026, 5, 31, 10), peakIds: [11, 33, 44]),
        ],
        now: DateTime(2026, 5, 15, 12),
        width: 560,
      );

      await _selectPeriod(tester, 'Month');

      expect(find.byType(LineChart), findsOneWidget);
      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        find.byKey(const Key('peaks-bagged-y-axis-label-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peaks-bagged-y-axis-label-4')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peaks-bagged-y-axis-separator')),
        findsOneWidget,
      );
      expect(lineChart.data.gridData.show, isTrue);
      expect(lineChart.data.gridData.drawVerticalLine, isFalse);
      expect(
        lineChart.data.gridData.horizontalInterval,
        closeTo(lineChart.data.maxY / 4, 1e-9),
      );
      expect(lineChart.data.gridData.checkToShowHorizontalLine(0), isFalse);
      expect(lineChart.data.gridData.checkToShowHorizontalLine(lineChart.data.maxY), isFalse);
      expect(lineChart.data.extraLinesData.extraLinesOnTop, isTrue);
      expect(lineChart.data.extraLinesData.horizontalLines, hasLength(2));
      expect(lineChart.data.extraLinesData.horizontalLines[0].y, 0);
      expect(lineChart.data.extraLinesData.horizontalLines[0].dashArray, isNull);
      expect(lineChart.data.extraLinesData.horizontalLines[1].y, lineChart.data.maxY);
      expect(lineChart.data.extraLinesData.horizontalLines[1].dashArray, equals([8, 4]));
      expect(
        lineChart.data.gridData
            .getDrawingHorizontalLine(lineChart.data.gridData.horizontalInterval!)
            .dashArray,
        equals([8, 4]),
      );

      final topLabel = tester.widget<Text>(
        find.byKey(const Key('peaks-bagged-y-axis-label-0')),
      );
      final bottomLabel = tester.widget<Text>(
        find.byKey(const Key('peaks-bagged-y-axis-label-4')),
      );
      expect(
        _numericValue(topLabel.data),
        greaterThan(_numericValue(bottomLabel.data)),
      );

      await tester.tap(_cardControl('summary-mode-fab'));
      await tester.pumpAndSettle();

      final switchedBarChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(
        find.byKey(const Key('peaks-bagged-y-axis-label-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peaks-bagged-y-axis-label-4')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peaks-bagged-y-axis-separator')),
        findsOneWidget,
      );
      expect(switchedBarChart.data.gridData.show, isTrue);
      expect(switchedBarChart.data.gridData.drawVerticalLine, isFalse);
      expect(
        switchedBarChart.data.gridData.horizontalInterval,
        closeTo(switchedBarChart.data.maxY / 4, 1e-9),
      );
      expect(
        switchedBarChart.data.gridData.checkToShowHorizontalLine(0),
        isFalse,
      );
      expect(
        switchedBarChart.data.gridData.checkToShowHorizontalLine(
          switchedBarChart.data.maxY,
        ),
        isFalse,
      );
      expect(switchedBarChart.data.extraLinesData.extraLinesOnTop, isTrue);
      expect(switchedBarChart.data.extraLinesData.horizontalLines, hasLength(2));
      expect(switchedBarChart.data.extraLinesData.horizontalLines[0].y, 0);
      expect(
        switchedBarChart.data.extraLinesData.horizontalLines[0].dashArray,
        isNull,
      );
      expect(switchedBarChart.data.extraLinesData.horizontalLines[1].y, switchedBarChart.data.maxY);
      expect(
        switchedBarChart.data.extraLinesData.horizontalLines[1].dashArray,
        equals([8, 4]),
      );
      expect(
        switchedBarChart.data.gridData
            .getDrawingHorizontalLine(
              switchedBarChart.data.gridData.horizontalInterval!,
            )
            .dashArray,
        equals([8, 4]),
      );
      expect(switchedBarChart.data.barGroups[30].barRods, hasLength(1));
      expect(switchedBarChart.data.barGroups[30].barRods.single.toY, 3);
      expect(
        switchedBarChart.data.barGroups[30].barRods.single.rodStackItems,
        hasLength(2),
      );
      expect(
        switchedBarChart.data.barGroups[30].barRods.single.rodStackItems[0].toY,
        2,
      );
      expect(
        switchedBarChart.data.barGroups[30].barRods.single.rodStackItems[1].toY,
        3,
      );

      await _hoverBucket(tester, 0);

      expect(find.byKey(const Key('peaks-bagged-tooltip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('peaks-bagged-tooltip')),
          matching: find.text('1 May'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('peaks-bagged-tooltip')),
          matching: find.text('Total climbs: 1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('peaks-bagged-tooltip')),
          matching: find.text('New peaks: 1'),
        ),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpPeaksBaggedCard(
  WidgetTester tester, {
  required List<GpxTrack> tracks,
  bool isLoading = false,
  DateTime? now,
  bool settle = true,
  double width = 420,
  ValueChanged<SummaryVisibleSummary?>? onVisibleSummaryChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: 320,
          child: PeaksBaggedCard(
            tracks: tracks,
            isLoading: isLoading,
            now: now,
            onVisibleSummaryChanged: onVisibleSummaryChanged,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _selectPeriod(WidgetTester tester, String label) async {
  await tester.tap(_cardControl('summary-period-dropdown'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _hoverBucket(WidgetTester tester, int index) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);

  final bucket = find.byKey(Key('peaks-bagged-bucket-$index'));
  await mouse.addPointer(location: tester.getCenter(bucket));
  await tester.pump();
  await mouse.moveTo(tester.getCenter(bucket));
  await tester.pump();
}

Finder _cardControl(String key) {
  return find.descendant(
    of: find.byKey(const Key('peaks-bagged-card')),
    matching: find.byKey(Key(key)),
  );
}

double _numericValue(String? text) {
  final cleaned = text?.replaceAll(',', '') ?? '';
  final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(cleaned);
  return double.parse(match!.group(0)!);
}

GpxTrack _track(
  int id,
  DateTime? trackDate, {
  required List<int> peakIds,
}) {
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
  );
  track.peaks.addAll(
    peakIds.map(
      (peakId) => Peak(
        osmId: peakId,
        name: 'Peak $peakId',
        latitude: -42,
        longitude: 146,
      ),
    ),
  );
  return track;
}
