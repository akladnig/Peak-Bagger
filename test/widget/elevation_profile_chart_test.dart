import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/elevation_profile_series_builder.dart';
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
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"distanceMeters":50,"elevationMeters":125,"timeLocal":"2024-01-15T08:10:00.000"},
  {"distanceMeters":100,"elevationMeters":150,"timeLocal":"2024-01-15T08:20:00.000"}
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

    var lineChart = tester.widget<LineChart>(find.byType(LineChart));
    expect(lineChart.data.maxX, 100);
    expect(lineChart.data.lineBarsData.single.spots.last.x, 100);

    await tester.tap(find.byKey(const Key('elevation-profile-time-toggle')));
    await tester.pumpAndSettle();

    lineChart = tester.widget<LineChart>(find.byType(LineChart));
    expect(lineChart.data.maxX, greaterThan(100));
    expect(lineChart.data.lineBarsData.single.spots.first.x, greaterThan(0));
  });

  testWidgets('disables time mode when timestamps are missing', (tester) async {
    final series = ElevationProfileSeriesBuilder.fromRoutePoints(
      points: const [LatLng(0, 0), LatLng(0, 0.01)],
      elevations: const [100, 120],
    );

    await _pumpChart(tester, series);

    final timeChip = tester.widget<ChoiceChip>(
      find.byKey(const Key('elevation-profile-time-toggle')),
    );
    expect(timeChip.onSelected, isNull);
  });
}

Future<void> _pumpChart(
  WidgetTester tester,
  ElevationProfileSeries series, {
  bool isLoading = false,
  String? errorText,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 640,
            child: ElevationProfileChart(
              series: series,
              isLoading: isLoading,
              errorText: errorText,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
