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
      gpxRoute: const [
        LatLng(-41.5, 146.5),
        LatLng(-41.5, 146.51),
      ],
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
}
