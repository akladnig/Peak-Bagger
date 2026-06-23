import 'dart:ui' show PointerDeviceKind;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/summary_card_service.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/dashboard/dashboard_series_colors.dart';
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
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('distance-scroll-view')),
                matching: find.text('3'),
              ),
            )
            .data,
        '3',
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('distance-scroll-view')),
                matching: find.text('10'),
              ),
            )
            .data,
        '10',
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('distance-scroll-view')),
                matching: find.text('17'),
              ),
            )
            .data,
        '17',
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('distance-scroll-view')),
                matching: find.text('24'),
              ),
            )
            .data,
        '24',
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('distance-scroll-view')),
                matching: find.text('31'),
              ),
            )
            .data,
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
        theme: CatppuccinColors.light,
      );

      await _selectPeriod(tester, 'Month');

      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('distance-scroll-view')),
                matching: find.text('1'),
              ),
            )
            .data,
        '1',
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const Key('distance-scroll-view')),
                matching: find.text('15'),
              ),
            )
            .data,
        '15',
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(find.byKey(const Key('distance-y-axis-label-0')), findsOneWidget);
      expect(find.byKey(const Key('distance-y-axis-label-4')), findsOneWidget);
      expect(
        find.byKey(const Key('distance-y-axis-separator')),
        findsOneWidget,
      );
      expect(
        tester.getCenter(find.byKey(const Key('distance-y-axis-label-0'))).dy,
        closeTo(
          tester
              .getTopLeft(find.byKey(const Key('distance-y-axis-separator')))
              .dy,
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
      expect(
        barChart.data.gridData.checkToShowHorizontalLine(barChart.data.maxY),
        isFalse,
      );
      expect(barChart.data.extraLinesData.extraLinesOnTop, isTrue);
      expect(barChart.data.extraLinesData.horizontalLines, hasLength(2));
      expect(barChart.data.extraLinesData.horizontalLines[0].y, 0);
      expect(barChart.data.extraLinesData.horizontalLines[0].dashArray, isNull);
      expect(
        barChart.data.extraLinesData.horizontalLines[1].y,
        barChart.data.maxY,
      );
      expect(
        barChart.data.extraLinesData.horizontalLines[1].dashArray,
        equals([8, 4]),
      );
      expect(
        barChart.data.gridData
            .getDrawingHorizontalLine(
              barChart.data.gridData.horizontalInterval!,
            )
            .dashArray,
        equals([8, 4]),
      );
      expect(
        barChart.data.barGroups[30].barRods.single.width,
        closeTo(
          DashboardUI.rodWidthFor(
            DashboardUI.columnWidthFor(
              availableWidth: 560 - 24 - DashboardUI.yAxisLabelWidth,
              visibleColumnCount: visibleColumnCountForPeriod(
                SummaryPeriodPreset.month,
              ),
            ),
          ),
          1e-9,
        ),
      );
      expect(barChart.data.barGroups[30].barRods, hasLength(1));
      final stackedRod = barChart.data.barGroups[30].barRods.single;
      expect(stackedRod.rodStackItems, hasLength(2));
      expect(stackedRod.rodStackItems[0].color, isNot(_secondarySeriesColor));
      expect(stackedRod.rodStackItems[1].color, _secondarySeriesColor);

      await tester.tap(_cardControl('summary-mode-fab'));
      await tester.pumpAndSettle();

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(find.byKey(const Key('distance-y-axis-label-0')), findsOneWidget);
      expect(find.byKey(const Key('distance-y-axis-label-4')), findsOneWidget);
      expect(
        find.byKey(const Key('distance-y-axis-separator')),
        findsOneWidget,
      );
      expect(
        tester.getCenter(find.byKey(const Key('distance-y-axis-label-0'))).dy,
        closeTo(
          tester
              .getTopLeft(find.byKey(const Key('distance-y-axis-separator')))
              .dy,
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
      expect(
        lineChart.data.gridData.checkToShowHorizontalLine(lineChart.data.maxY),
        isFalse,
      );
      expect(lineChart.data.extraLinesData.extraLinesOnTop, isTrue);
      expect(lineChart.data.extraLinesData.horizontalLines, hasLength(2));
      expect(lineChart.data.extraLinesData.horizontalLines[0].y, 0);
      expect(
        lineChart.data.extraLinesData.horizontalLines[0].dashArray,
        isNull,
      );
      expect(
        lineChart.data.extraLinesData.horizontalLines[1].y,
        lineChart.data.maxY,
      );
      expect(
        lineChart.data.extraLinesData.horizontalLines[1].dashArray,
        equals([8, 4]),
      );
      expect(lineChart.data.lineBarsData, hasLength(2));
      expect(lineChart.data.lineBarsData[0].color, _secondarySeriesColor);
      expect(
        lineChart.data.lineBarsData[1].color,
        isNot(_secondarySeriesColor),
      );
      expect(
        lineChart.data.maxX,
        lineChart.data.lineBarsData[0].spots.length.toDouble(),
      );
      for (final lineBar in lineChart.data.lineBarsData) {
        expect(lineBar.spots.first.x, 0.5);
        expect(lineBar.spots.last.x, closeTo(lineChart.data.maxX - 0.5, 1e-9));
      }
      expect(
        lineChart.data.lineBarsData[0].spots.map((spot) => spot.x),
        equals(lineChart.data.lineBarsData[1].spots.map((spot) => spot.x)),
      );

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
        find
            .descendant(
              of: find.byKey(const Key('distance-scroll-view')),
              matching: find.byType(Scrollable),
            )
            .first,
        const Offset(-240, 0),
      );
      await tester.pumpAndSettle();

      final topLeftAfter = tester.getTopLeft(
        find.byKey(const Key('distance-y-axis-label-0')),
      );
      expect(topLeftAfter.dx, closeTo(topLeftBefore.dx, 0.5));
      expect(topLeftAfter.dx, lessThan(16));

      await tester.tap(find.byKey(const Key('distance-bucket-30')));
      await tester.pumpAndSettle();

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

      final tooltipTextWidgets = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('distance-tooltip')),
              matching: find.byType(Text),
            ),
          )
          .toList();
      expect(tooltipTextWidgets, hasLength(3));
      expect(
        tooltipTextWidgets[1].style?.color,
        lighterSeriesColor(CatppuccinColors.light.colorScheme.primary),
      );
      expect(
        tooltipTextWidgets[2].style?.color,
        lighterSeriesColor(dashboardSecondarySeriesColor),
      );
    });
  });
}

const _secondarySeriesColor = Color(0xFF2E7D32);

Future<void> _pumpDistanceCard(
  WidgetTester tester, {
  required List<GpxTrack> tracks,
  bool isLoading = false,
  DateTime? now,
  bool settle = true,
  double width = 420,
  ThemeData? theme,
  ValueChanged<SummaryVisibleSummary?>? onVisibleSummaryChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
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
  final period = SummaryPeriodPreset.values.firstWhere(
    (value) => value.label == label,
  );
  final dynamic dropdown = tester.widget<PopupMenuButton>(
    _cardControl('summary-period-dropdown'),
  );
  dropdown.onSelected?.call(period);
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
