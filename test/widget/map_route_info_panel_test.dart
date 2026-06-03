import 'dart:ui' show PointerDeviceKind;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/screens/map_screen_panels.dart';
import 'package:peak_bagger/widgets/elevation_profile_chart.dart';

void main() {
  testWidgets('renders elevation profile chart for a saved route', (
    tester,
  ) async {
    final route = app_route.Route(
      name: 'Test Route',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.5, 146.51)],
      gpxRouteElevations: const [100, 120],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: MapTrackInfoPanel(
              route: route,
              onClose: () {},
              onExport: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('elevation-profile-chart')), findsOneWidget);
    expect(find.byType(ElevationProfileChart), findsOneWidget);
  });

  testWidgets('forwards route chart hover samples', (tester) async {
    final hoverEvents = <ElevationProfileChartHoverSample?>[];
    final route = app_route.Route(
      name: 'Test Route',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.5, 146.51)],
      gpxRouteElevations: const [100, 120],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: MapTrackInfoPanel(
              route: route,
              onClose: () {},
              onExport: () {},
              onElevationProfileHoverChanged: hoverEvents.add,
            ),
          ),
        ),
      ),
    );

    final chart = find.byType(LineChart);
    final chartRect = tester.getRect(chart);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);

    await mouse.addPointer(location: chartRect.topLeft - const Offset(20, 20));
    await tester.pump();
    await mouse.moveTo(
      Offset(chartRect.left + (chartRect.width * 0.15), chartRect.center.dy),
    );
    await tester.pump();

    expect(hoverEvents.last, isNotNull);
    expect(hoverEvents.last!.sampleIndex, 0);
    expect(hoverEvents.last!.sample.segmentIndex, isNull);
    expect(hoverEvents.last!.sample.pointIndex, isNull);
  });

  testWidgets('renders a visibility row for a saved route', (tester) async {
    var visible = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              final route = app_route.Route(
                name: 'Test Route',
                visible: visible,
                gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.5, 146.51)],
                gpxRouteElevations: const [100, 120],
              );

              return SizedBox(
                width: 600,
                child: MapTrackInfoPanel(
                  route: route,
                  onClose: () {},
                  onExport: () {},
                  onVisibilityChanged: (value) {
                    setState(() {
                      visible = value;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    final switchFinder = find.byKey(
      const Key('track-info-panel-visibility-switch'),
    );
    expect(find.text('Hide this route on the map'), findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    final label = find.text('Hide this route on the map');
    expect(
      tester.getRect(label).left,
      lessThan(tester.getRect(switchFinder).left),
    );
    expect(
      (tester.getRect(label).center.dy - tester.getRect(switchFinder).center.dy)
          .abs(),
      lessThan(1),
    );

    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Show this route on the map'), findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
  });
}
