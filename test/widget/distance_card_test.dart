import 'dart:ui' show PointerDeviceKind;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/widgets/dashboard/distance_card.dart';
import 'package:peak_bagger/widgets/dashboard/summary_card.dart';

void main() {
  group('DistanceCard', () {
    testWidgets('renders loading placeholder while tracks load', (
      tester,
    ) async {
      await _pumpDistanceCard(
        tester,
        tracks: const [],
        isLoading: true,
        settle: false,
      );

      expect(find.byKey(const Key('distance-loading-state')), findsOneWidget);
      expect(find.byKey(const Key('distance-empty-state')), findsNothing);
    });

    testWidgets('renders empty state when no usable tracks exist', (
      tester,
    ) async {
      await _pumpDistanceCard(tester, tracks: const []);

      expect(find.byKey(const Key('distance-empty-state')), findsOneWidget);
      expect(find.text('No distance data yet'), findsOneWidget);
    });

    testWidgets('renders summary controls and anchored latest window', (
      tester,
    ) async {
      await _pumpDistanceCard(
        tester,
        tracks: [
          _track(
            10,
            DateTime(2026, 3, 1, 10),
            distance2d: 1000,
            distance3d: 1050,
          ),
          _track(
            20,
            DateTime(2026, 4, 15, 10),
            distance2d: 2000,
            distance3d: 2100,
          ),
          _track(
            30,
            DateTime(2026, 5, 15, 10),
            distance2d: 3000,
            distance3d: 3200,
          ),
        ],
        now: DateTime(2026, 5, 15, 12),
        width: 1000,
      );

      expect(find.byKey(const Key('distance-card')), findsOneWidget);
      expect(_cardControl('summary-period-dropdown'), findsOneWidget);
      expect(_cardControl('summary-prev-window'), findsOneWidget);
      expect(_cardControl('summary-next-window'), findsOneWidget);
      expect(_cardControl('summary-mode-fab'), findsOneWidget);
      expect(find.byKey(const Key('distance-bucket-0')), findsOneWidget);
    });

    testWidgets('reports visible summary when period changes', (tester) async {
      SummaryVisibleSummary? summary;

      await _pumpDistanceCard(
        tester,
        tracks: [
          _track(
            10,
            DateTime(2025, 12, 15, 10),
            distance2d: 1000,
            distance3d: 1100,
          ),
          _track(
            20,
            DateTime(2026, 1, 15, 10),
            distance2d: 2000,
            distance3d: 2200,
          ),
          _track(
            30,
            DateTime(2026, 5, 15, 10),
            distance2d: 3000,
            distance3d: 3300,
          ),
        ],
        now: DateTime(2026, 5, 15, 12),
        onVisibleSummaryChanged: (value) => summary = value,
      );

      final initialSummary = summary;
      expect(initialSummary, isNotNull);

      await _selectPeriod(tester, 'Month');

      expect(summary, isNotNull);
      expect(summary, isNot(initialSummary));
      expect(summary?.totalValue.round(), 3000);
      expect(find.byKey(const Key('distance-scroll-view')), findsOneWidget);
    });

    testWidgets('renders every weekly month label including 24', (
      tester,
    ) async {
      await _pumpDistanceCard(
        tester,
        tracks: [
          _track(
            10,
            DateTime(2026, 5, 3, 10),
            distance2d: 100,
            distance3d: 110,
          ),
          _track(
            20,
            DateTime(2026, 5, 10, 10),
            distance2d: 200,
            distance3d: 210,
          ),
          _track(
            30,
            DateTime(2026, 5, 17, 10),
            distance2d: 300,
            distance3d: 310,
          ),
          _track(
            40,
            DateTime(2026, 5, 24, 10),
            distance2d: 400,
            distance3d: 410,
          ),
          _track(
            50,
            DateTime(2026, 5, 31, 10),
            distance2d: 500,
            distance3d: 510,
          ),
        ],
        now: DateTime(2026, 5, 31, 12),
        width: 560,
      );

      await _selectPeriod(tester, 'Month');

      expect(
        tester.widget<Text>(
          find.byKey(const Key('distance-bottom-axis-label-2')),
        ).data,
        '3',
      );
      expect(
        tester.widget<Text>(
          find.byKey(const Key('distance-bottom-axis-label-9')),
        ).data,
        '10',
      );
      expect(
        tester.widget<Text>(
          find.byKey(const Key('distance-bottom-axis-label-16')),
        ).data,
        '17',
      );
      expect(
        tester.widget<Text>(
          find.byKey(const Key('distance-bottom-axis-label-23')),
        ).data,
        '24',
      );
      expect(
        tester.widget<Text>(
          find.byKey(const Key('distance-bottom-axis-label-30')),
        ).data,
        '31',
      );
    });

    testWidgets('toggles display mode and shows distance tooltip', (
      tester,
    ) async {
      await _pumpDistanceCard(
        tester,
        tracks: [
          _track(
            10,
            DateTime(2026, 5, 1, 10),
            distance2d: 100,
            distance3d: 110,
          ),
          _track(
            20,
            DateTime(2026, 5, 15, 10),
            distance2d: 300,
            distance3d: 320,
          ),
          _track(
            30,
            DateTime(2026, 5, 31, 10),
            distance2d: 12340,
            distance3d: 12780,
          ),
        ],
        now: DateTime(2026, 5, 15, 12),
        width: 560,
      );

      await _selectPeriod(tester, 'Month');

      expect(
        tester.widget<Text>(
          find.byKey(const Key('distance-bottom-axis-label-0')),
        ).data,
        '1',
      );
      expect(
        tester.widget<Text>(
          find.byKey(const Key('distance-bottom-axis-label-14')),
        ).data,
        '15',
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(find.byKey(const Key('distance-y-axis-label-0')), findsOneWidget);
      expect(find.byKey(const Key('distance-y-axis-label-4')), findsOneWidget);
      expect(find.byKey(const Key('distance-y-axis-separator')), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const Key('distance-y-axis-label-0'))).dy,
        closeTo(
          tester.getTopLeft(find.byKey(const Key('distance-y-axis-separator'))).dy,
          0.5,
        ),
      );
      expect(
        tester.getCenter(find.byKey(const Key('distance-y-axis-label-4'))).dy,
        closeTo(
          tester
              .getBottomLeft(find.byKey(const Key('distance-y-axis-separator')))
              .dy,
          0.5,
        ),
      );
      expect(barChart.data.gridData.show, isTrue);
      expect(barChart.data.gridData.drawVerticalLine, isFalse);
      expect(barChart.data.maxY, 16000);
      expect(
        barChart.data.gridData.horizontalInterval,
        closeTo(barChart.data.maxY / 4, 1e-9),
      );
      expect(barChart.data.gridData.checkToShowHorizontalLine(0), isFalse);
      expect(barChart.data.gridData.checkToShowHorizontalLine(barChart.data.maxY), isFalse);
      expect(barChart.data.extraLinesData.extraLinesOnTop, isTrue);
      expect(barChart.data.extraLinesData.horizontalLines, hasLength(2));
      expect(barChart.data.extraLinesData.horizontalLines[0].y, 0);
      expect(barChart.data.extraLinesData.horizontalLines[0].dashArray, isNull);
      expect(barChart.data.extraLinesData.horizontalLines[1].y, barChart.data.maxY);
      expect(barChart.data.extraLinesData.horizontalLines[1].dashArray, equals([8, 4]));
      expect(
        barChart.data.gridData
            .getDrawingHorizontalLine(barChart.data.gridData.horizontalInterval!)
            .dashArray,
        equals([8, 4]),
      );
      expect(
        barChart.data.barGroups[30].barRods.single.width,
        closeTo(
          DashboardUI.rodWidthFor(
            DashboardUI.columnWidthFor(
              availableWidth:
                  560 - 24 - DashboardUI.yAxisLabelWidth,
              visibleColumnCount: visibleColumnCountForPeriod(
                SummaryPeriodPreset.month,
              ),
            ),
          ),
          1e-9,
        ),
      );
      expect(barChart.data.barGroups[30].barRods, hasLength(1));
      expect(
        barChart.data.barGroups[30].barRods.single.rodStackItems,
        hasLength(2),
      );

      await tester.tap(_cardControl('summary-mode-fab'));
      await tester.pumpAndSettle();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(find.byKey(const Key('distance-y-axis-label-0')), findsOneWidget);
      expect(find.byKey(const Key('distance-y-axis-label-4')), findsOneWidget);
      expect(find.byKey(const Key('distance-y-axis-separator')), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const Key('distance-y-axis-label-0'))).dy,
        closeTo(
          tester.getTopLeft(find.byKey(const Key('distance-y-axis-separator'))).dy,
          0.5,
        ),
      );
      expect(
        tester.getCenter(find.byKey(const Key('distance-y-axis-label-4'))).dy,
        closeTo(
          tester
              .getBottomLeft(find.byKey(const Key('distance-y-axis-separator')))
              .dy,
          0.5,
        ),
      );
      expect(lineChart.data.gridData.show, isTrue);
      expect(lineChart.data.gridData.drawVerticalLine, isFalse);
      expect(lineChart.data.maxY, 16000);
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
      expect(lineChart.data.lineBarsData, hasLength(2));

      final topLabel = tester.widget<Text>(
        find.byKey(const Key('distance-y-axis-label-0')),
      );
      final bottomLabel = tester.widget<Text>(
        find.byKey(const Key('distance-y-axis-label-4')),
      );
      expect(
        _numericValue(topLabel.data),
        greaterThan(_numericValue(bottomLabel.data)),
      );
      expect(topLabel.data, '16 km');

      final topLeftBefore = tester.getTopLeft(
        find.byKey(const Key('distance-y-axis-label-0')),
      );

      await tester.drag(
        find.descendant(
          of: find.byKey(const Key('distance-scroll-view')),
          matching: find.byType(Scrollable),
        ).first,
        const Offset(-240, 0),
      );
      await tester.pumpAndSettle();

      final topLeftAfter = tester.getTopLeft(
        find.byKey(const Key('distance-y-axis-label-0')),
      );
      expect(topLeftAfter.dx, closeTo(topLeftBefore.dx, 0.5));
      expect(topLeftAfter.dx, lessThan(16));

      await _hoverBucket(tester, 0);

      expect(find.byKey(const Key('distance-tooltip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('distance-tooltip')),
          matching: find.text('1 May'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('distance-tooltip')),
          matching: find.text('2D: 100 m'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('distance-tooltip')),
          matching: find.text('3D: 110 m'),
        ),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpDistanceCard(
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
          child: DistanceCard(
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

  final bucket = find.byKey(Key('distance-bucket-$index'));
  await mouse.addPointer(location: tester.getCenter(bucket));
  await tester.pump();
  await mouse.moveTo(tester.getCenter(bucket));
  await tester.pump();
}

Finder _cardControl(String key) {
  return find.descendant(
    of: find.byKey(const Key('distance-card')),
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
  required double distance2d,
  required double distance3d,
}) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
    distance2d: distance2d,
    distance3d: distance3d,
  );
}
