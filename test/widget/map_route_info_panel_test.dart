import 'dart:ui' show PointerDeviceKind;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/screens/map_screen_panels.dart';
import 'package:peak_bagger/services/route_timing_service.dart';
import 'package:peak_bagger/widgets/elevation_profile_chart.dart';

void main() {
  testWidgets('renders combined distance metric for a saved route', (
    tester,
  ) async {
    final route = app_route.Route(
      name: 'Test Route',
      distance2d: 17450,
      distance3d: 17920,
      ascent: 912,
      descent: 456,
      estimatedTime: 5400000,
      routeTimingSource: RouteTimingSources.verifiedWalk,
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

    expect(find.text('Distance (2d/3d)'), findsOneWidget);
    expect(find.text('17.4 km / 17.9 km'), findsOneWidget);
  });

  testWidgets('renders dual route timing rows and removes inline explanation', (
    tester,
  ) async {
    final route = app_route.Route(
      name: 'Timed Route',
      distance2d: 17450,
      distance3d: 17920,
      ascent: 912,
      descent: 456,
      estimatedTime: 5400000,
      routeTimingSource: RouteTimingSources.verifiedWalk,
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

    expect(
      find.byKey(const Key('route-estimated-time-explanation')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('route-estimated-time-naismith-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('route-estimated-time-scarf-row')),
      findsOneWidget,
    );
    expect(find.text('Estimated Time (Naismith)'), findsOneWidget);
    expect(find.text('Estimated Time (Scarf)'), findsOneWidget);
    expect(find.text('1h 30m'), findsNWidgets(2));
  });

  testWidgets('updates manual-route walking speed through callback', (
    tester,
  ) async {
    final route = app_route.Route(
      name: 'Manual Route',
      distance2d: 17450,
      distance3d: 17920,
      ascent: 0,
      descent: 0,
      routeTimingSource: RouteTimingSources.naismith,
      walkingSpeedKmh: 4.0,
      gpxRoute: const [LatLng(0, 0), LatLng(0, 0.08983)],
      gpxRouteElevations: const [0, 0],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 600,
                child: MapTrackInfoPanel(
                  route: route,
                  onClose: () {},
                  onExport: () {},
                  onRouteWalkingSpeedChanged: (value) {
                    setState(() {
                      route.walkingSpeedKmh = value;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('4.0 km/h'), findsOneWidget);

    final incrementButton = find.byKey(
      const Key('route-walking-speed-increment'),
    );
    await tester.ensureVisible(incrementButton);
    await tester.pumpAndSettle();
    await tester.tap(incrementButton, warnIfMissed: false);
    await tester.pump();

    expect(find.text('4.1 km/h'), findsOneWidget);
  });

  testWidgets('increments walking speed with focused keyboard shortcut', (
    tester,
  ) async {
    final route = app_route.Route(
      name: 'Shortcut Route',
      routeTimingSource: RouteTimingSources.naismith,
      walkingSpeedKmh: 4.0,
      gpxRoute: const [LatLng(0, 0), LatLng(0, 0.08983)],
      gpxRouteElevations: const [0, 0],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: 600,
                child: MapTrackInfoPanel(
                  route: route,
                  onClose: () {},
                  onExport: () {},
                  onRouteWalkingSpeedChanged: (value) {
                    setState(() {
                      route.walkingSpeedKmh = value;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    final speedControl = find.byKey(const Key('route-walking-speed-control'));
    await tester.ensureVisible(speedControl);
    await tester.pumpAndSettle();
    await tester.tap(speedControl, warnIfMissed: false);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();

    expect(find.text('4.1 km/h'), findsOneWidget);
  });

  testWidgets('renders an edit action before close for a saved route', (
    tester,
  ) async {
    var editTapped = false;
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
              onEdit: () {
                editTapped = true;
              },
              onExport: () {},
            ),
          ),
        ),
      ),
    );

    final editButton = find.byKey(const Key('track-info-panel-edit-button'));
    final closeButton = find.byKey(const Key('track-info-panel-close'));
    expect(find.byTooltip('Edit Route'), findsOneWidget);
    expect(
      tester.getRect(editButton).right,
      lessThan(tester.getRect(closeButton).left),
    );

    await tester.tap(editButton);
    await tester.pump();

    expect(editTapped, isTrue);
  });

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

  testWidgets('renders manual-route timing rows for untimed route source', (
    tester,
  ) async {
    final route = app_route.Route(
      name: 'Timed Route',
      distance2d: 17450,
      distance3d: 17920,
      ascent: 912,
      descent: 456,
      estimatedTime: 5400000,
      routeTimingSource: RouteTimingSources.naismith,
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

    expect(
      find.byKey(const Key('route-estimated-time-naismith-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('route-estimated-time-scarf-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('route-estimated-time-explanation')),
      findsNothing,
    );
  });

  testWidgets('renders legacy mixed fallback for extended verified walk route', (
    tester,
  ) async {
    final route = app_route.Route(
      name: 'Extended Route',
      distance2d: 17450,
      distance3d: 17920,
      ascent: 912,
      descent: 456,
      estimatedTime: 5400000,
      routeTimingSource: RouteTimingSources.extendedRoute,
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

    expect(
      find.byKey(const Key('route-timing-limitation-message')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Adjusted timing unavailable for this legacy mixed route because segment provenance was never stored.',
      ),
      findsOneWidget,
    );
    expect(find.text('Estimated Time (Scarf)'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });
}
