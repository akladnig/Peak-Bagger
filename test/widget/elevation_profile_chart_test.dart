import 'dart:ui' show PointerDeviceKind;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/elevation_profile_series_builder.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/elevation_profile_chart.dart';

void main() {
  testWidgets('renders empty state when no samples exist', (tester) async {
    await _pumpChart(
      tester,
      const ElevationProfileSeries(samples: [], supportsTimeAxis: false),
    );

    expect(
      find.byKey(const Key('elevation-profile-empty-state')),
      findsOneWidget,
    );
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('renders loading state when loading without samples', (
    tester,
  ) async {
    await _pumpChart(
      tester,
      const ElevationProfileSeries(samples: [], supportsTimeAxis: false),
      isLoading: true,
    );

    expect(
      find.byKey(const Key('elevation-profile-loading-state')),
      findsOneWidget,
    );
  });

  testWidgets('toggles between distance and time modes', (tester) async {
    final series = ElevationProfileSeriesBuilder.fromTrackProfileJson('''
[
  {"distanceMeters":0,"elevationMeters":1012,"timeLocal":"2024-01-15T08:00:00.000"},
  {"distanceMeters":4000,"elevationMeters":1260,"timeLocal":"2024-01-15T08:40:00.000"},
  {"distanceMeters":8000,"elevationMeters":1437,"timeLocal":"2024-01-15T09:20:00.000"},
  {"distanceMeters":13000,"elevationMeters":1310,"timeLocal":"2024-01-15T10:10:00.000"},
  {"distanceMeters":17000,"elevationMeters":1028,"timeLocal":"2024-01-15T11:00:00.000"}
]
''');

    await _pumpChart(tester, series);

    expect(
      find.byKey(const Key('elevation-profile-distance-toggle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('elevation-profile-time-toggle')),
      findsOneWidget,
    );
    final searchButtonTheme = MyTheme.light.extension<SearchButtonThemeData>()!;
    _expectSearchButtonStyle(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('elevation-profile-distance-toggle')),
          )
          .style,
      searchButtonTheme.styleFor(true),
    );
    _expectSearchButtonStyle(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('elevation-profile-time-toggle')),
          )
          .style,
      searchButtonTheme.styleFor(false),
    );

    var lineChart = tester.widget<LineChart>(find.byType(LineChart));
    expect(lineChart.data.maxX, 17000);
    expect(lineChart.data.lineBarsData.single.spots.last.x, 17000);
    expect(lineChart.data.minY, 1000);
    expect(lineChart.data.maxY, 1500);
    expect(lineChart.data.extraLinesData.horizontalLines, hasLength(5));
    expect(lineChart.data.extraLinesData.horizontalLines[0].y, 1000);
    expect(lineChart.data.extraLinesData.horizontalLines[1].y, 1125);
    expect(lineChart.data.extraLinesData.horizontalLines[2].y, 1250);
    expect(lineChart.data.extraLinesData.horizontalLines[3].y, 1375);
    expect(lineChart.data.extraLinesData.horizontalLines[4].y, 1500);
    expect(lineChart.data.extraLinesData.verticalLines.first.dashArray, isNull);
    expect(lineChart.data.extraLinesData.verticalLines.first.strokeWidth, 1.5);
    expect(find.text('1000'), findsOneWidget);
    expect(find.text('1125'), findsOneWidget);
    expect(find.text('1250'), findsOneWidget);
    expect(find.text('1375'), findsOneWidget);
    expect(find.text('1500'), findsOneWidget);
    expect(find.text('1400'), findsNothing);
    expect(find.text('1600'), findsNothing);
    expect(find.text('2000'), findsNothing);
    expect(find.text('Elevation profile'), findsNothing);
    expect(lineChart.data.extraLinesData.verticalLines, hasLength(5));
    expect(lineChart.data.extraLinesData.verticalLines.first.x, 0);
    expect(lineChart.data.extraLinesData.verticalLines.last.x, 17000);
    expect(find.text('m'), findsNothing);
    expect(find.text('km'), findsOneWidget);
    expect(find.text('17.0'), findsOneWidget);
    expect(find.text('17.0 km'), findsNothing);

    final bar = lineChart.data.lineBarsData.single;
    expect(bar.dotData.show, isFalse);

    final lineChartRect = tester.getRect(find.byType(LineChart));
    final distanceToggleRect = tester.getRect(
      find.byKey(const Key('elevation-profile-distance-toggle')),
    );
    expect(distanceToggleRect.top, greaterThan(lineChartRect.bottom));

    await tester.tap(find.byKey(const Key('elevation-profile-time-toggle')));
    await tester.pumpAndSettle();

    lineChart = tester.widget<LineChart>(find.byType(LineChart));
    expect(lineChart.data.maxX, greaterThan(17000));
    expect(lineChart.data.lineBarsData.single.spots.first.x, greaterThan(0));
    expect(find.text('11:00'), findsOneWidget);
    expect(
      tester
          .widget<MouseRegion>(
            find.byKey(const Key('elevation-profile-chart-touch-area')),
          )
          .cursor,
      SystemMouseCursors.click,
    );
    expect(
      lineChart.data.lineTouchData.touchTooltipData.getTooltipColor(
        LineBarSpot(
          lineChart.data.lineBarsData.single,
          0,
          lineChart.data.lineBarsData.single.spots.first,
        ),
      ),
      MyTheme.light.colorScheme.primaryContainer,
    );
  });

  testWidgets('renders timestamp hover details only in time mode', (
    tester,
  ) async {
    final series = ElevationProfileSeriesBuilder.fromTrackProfileJson('''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00"},
  {"distanceMeters":10,"elevationMeters":120,"timeLocal":"2024-01-16T09:15:00"}
]
''');

    await _pumpChart(tester, series);

    var lineChart = tester.widget<LineChart>(find.byType(LineChart));
    var tooltip = _tooltipForLastSpot(lineChart);
    expect(tooltip.text, '120 m\n0.0 km');
    expect(
      tooltip.textStyle.color,
      MyTheme.light.colorScheme.onPrimaryContainer,
    );

    await tester.tap(find.byKey(const Key('elevation-profile-time-toggle')));
    await tester.pumpAndSettle();

    lineChart = tester.widget<LineChart>(find.byType(LineChart));
    tooltip = _tooltipForLastSpot(lineChart);
    expect(tooltip.text, '120 m\n25:15 elapsed\n09:15');
  });

  testWidgets('uses provided elevation bounds when supplied', (tester) async {
    final series = ElevationProfileSeriesBuilder.fromTrackProfileJson('''
[
  {"distanceMeters":0,"elevationMeters":1012},
  {"distanceMeters":50,"elevationMeters":1260},
  {"distanceMeters":100,"elevationMeters":1437}
]
''');

    await _pumpChart(tester, series, minElevation: 1022, maxElevation: 1377);

    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    expect(lineChart.data.minY, 1000);
    expect(lineChart.data.maxY, 1400);
  });

  testWidgets('floors the lower bound so all elevation samples are visible', (
    tester,
  ) async {
    final series = ElevationProfileSeriesBuilder.fromRoutePoints(
      points: const [LatLng(0, 0), LatLng(0, 0.01)],
      elevations: const [1151, 1390],
    );

    await _pumpChart(tester, series);

    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    expect(lineChart.data.minY, 1100);
    expect(lineChart.data.maxY, 1400);
    expect(find.text('1175'), findsOneWidget);
  });

  testWidgets('disables time mode when timestamps are missing', (tester) async {
    final series = ElevationProfileSeriesBuilder.fromRoutePoints(
      points: const [LatLng(0, 0), LatLng(0, 0.01)],
      elevations: const [100, 120],
    );

    await _pumpChart(tester, series);

    final timeButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('elevation-profile-time-toggle')),
    );
    expect(timeButton.onPressed, isNull);
    expect(
      tester
          .widget<MouseRegion>(
            _mouseRegionFor(
              find.byKey(const Key('elevation-profile-distance-toggle')),
            ),
          )
          .cursor,
      SystemMouseCursors.click,
    );
    expect(
      tester
          .widget<MouseRegion>(
            _mouseRegionFor(
              find.byKey(const Key('elevation-profile-time-toggle')),
            ),
          )
          .cursor,
      SystemMouseCursors.basic,
    );

    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final tooltip = _tooltipForLastSpot(lineChart);
    expect(tooltip.text, '120 m\n1.1 km');
  });

  testWidgets('disabled time toggle keeps the unselected search button style', (
    tester,
  ) async {
    final series = ElevationProfileSeriesBuilder.fromRoutePoints(
      points: const [LatLng(0, 0), LatLng(0, 0.01)],
      elevations: const [100, 120],
    );

    await _pumpChart(tester, series);

    final timeButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('elevation-profile-time-toggle')),
    );
    expect(timeButton.onPressed, isNull);
    _expectSearchButtonStyle(
      timeButton.style,
      MyTheme.light.extension<SearchButtonThemeData>()!.styleFor(false),
      states: const {WidgetState.disabled},
    );
  });

  testWidgets('reports hovered samples and clears on exit', (tester) async {
    final hoverEvents = <ElevationProfileChartHoverSample?>[];
    final series = ElevationProfileSeriesBuilder.fromTrackProfileJson('''
[
  {"segmentIndex":0,"pointIndex":0,"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"segmentIndex":0,"pointIndex":1,"distanceMeters":5,"elevationMeters":null,"timeLocal":null},
  {"segmentIndex":1,"pointIndex":0,"distanceMeters":10,"elevationMeters":120,"timeLocal":"2024-01-15T08:10:00.000"}
]
''');

    await _pumpChart(tester, series, onHoverChanged: hoverEvents.add);

    final chart = find.byType(LineChart);
    final chartRect = tester.getRect(chart);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() async {
      await gesture.removePointer();
    });

    await gesture.addPointer(
      location: chartRect.topLeft - const Offset(20, 20),
    );
    await tester.pump();

    await gesture.moveTo(
      Offset(chartRect.left + (chartRect.width * 0.12), chartRect.center.dy),
    );
    await tester.pump();

    expect(hoverEvents.last, isNotNull);
    expect(hoverEvents.last!.sampleIndex, 0);
    expect(hoverEvents.last!.sample.segmentIndex, 0);
    expect(hoverEvents.last!.sample.pointIndex, 0);

    await gesture.moveTo(Offset(chartRect.right - 1, chartRect.center.dy));
    await tester.pump();

    expect(hoverEvents.last, isNotNull);
    expect(hoverEvents.last!.sampleIndex, 2);
    expect(hoverEvents.last!.sample.segmentIndex, 1);
    expect(hoverEvents.last!.sample.pointIndex, 0);

    await gesture.moveTo(chartRect.bottomRight + const Offset(20, 20));
    await tester.pump();

    expect(hoverEvents.last, isNull);
  });

  testWidgets('uses map hover styling and keeps tap interactions intact', (
    tester,
  ) async {
    final interactions = <ElevationProfileChartInteraction?>[];
    final series = ElevationProfileSeriesBuilder.fromTrackProfileJson('''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00"},
  {"distanceMeters":10,"elevationMeters":120,"timeLocal":"2024-01-15T08:10:00"}
]
''');

    await _pumpChart(tester, series, onInteractionChanged: interactions.add);

    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final bar = lineChart.data.lineBarsData.single;
    final indicator = lineChart.data.lineTouchData.getTouchedSpotIndicator(
      bar,
      const [0],
    ).single!;
    final dotPainter =
        indicator.touchedSpotDotData.getDotPainter(bar.spots.first, 0, bar, 0)
            as FlDotCirclePainter;
    expect(indicator.indicatorBelowLine.color, MapChartHoverDotTheme.color);
    expect(indicator.indicatorBelowLine.strokeWidth, 2);
    expect(dotPainter.color, MapChartHoverDotTheme.color);
    expect(dotPainter.strokeColor, MapChartHoverDotTheme.color);

    lineChart.data.lineTouchData.touchCallback!(
      FlTapUpEvent(
        TapUpDetails(localPosition: Offset.zero, kind: PointerDeviceKind.touch),
      ),
      LineTouchResponse(
        touchLocation: Offset.zero,
        touchChartCoordinate: Offset(bar.spots.first.x, bar.spots.first.y),
        lineBarSpots: [TouchLineBarSpot(bar, 0, bar.spots.first, 0)],
      ),
    );
    await tester.pump();

    expect(interactions.last!.kind, ElevationProfileChartInteractionKind.tap);
    expect(interactions.last!.targetsExactPoint, isTrue);
    expect(interactions.last!.hoverSample.sampleIndex, 0);
  });
}

Finder _mouseRegionFor(Finder descendant) {
  return find.ancestor(of: descendant, matching: find.byType(MouseRegion));
}

void _expectSearchButtonStyle(
  ButtonStyle? actual,
  ButtonStyle expected, {
  Set<WidgetState> states = const {},
}) {
  expect(actual?.padding?.resolve(states), expected.padding?.resolve(states));
  expect(
    actual?.minimumSize?.resolve(states),
    expected.minimumSize?.resolve(states),
  );
  expect(
    actual?.backgroundColor?.resolve(states),
    expected.backgroundColor?.resolve(states),
  );
  expect(
    actual?.foregroundColor?.resolve(states),
    expected.foregroundColor?.resolve(states),
  );
  expect(actual?.side?.resolve(states), expected.side?.resolve(states));
  expect(actual?.visualDensity, expected.visualDensity);
  expect(actual?.tapTargetSize, expected.tapTargetSize);
}

LineTooltipItem _tooltipForLastSpot(LineChart lineChart) {
  final bar = lineChart.data.lineBarsData.single;
  return lineChart.data.lineTouchData.touchTooltipData.getTooltipItems([
    LineBarSpot(bar, 0, bar.spots.last),
  ]).single!;
}

Future<void> _pumpChart(
  WidgetTester tester,
  ElevationProfileSeries series, {
  bool isLoading = false,
  String? errorText,
  double? minElevation,
  double? maxElevation,
  ValueChanged<ElevationProfileChartHoverSample?>? onHoverChanged,
  ValueChanged<ElevationProfileChartInteraction?>? onInteractionChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: MyTheme.light,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 640,
            child: ElevationProfileChart(
              series: series,
              isLoading: isLoading,
              errorText: errorText,
              minElevation: minElevation,
              maxElevation: maxElevation,
              onHoverChanged: onHoverChanged,
              onInteractionChanged: onInteractionChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
