import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';

import 'peak_info_robot.dart';

void main() {
  testWidgets('peak cluster journey expands into individual peaks', (tester) async {
    final robot = PeakInfoRobot(tester);
    addTearDown(robot.dispose);

    await robot.pumpMap(
      initialState: MapState(
        center: const LatLng(-43.0, 147.0),
        zoom: 8,
        basemap: Basemap.tracestrack,
        peaks: [
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
          Peak(
            osmId: 7000,
            name: 'Other Peak',
            latitude: -43.0,
            longitude: 147.01,
          ),
        ],
      ),
    );

    final container = robot.container();
    expect(robot.peakClusterLayer, findsOneWidget);

    await robot.tapMapCenter();

    expect(container.read(mapProvider).zoom, greaterThan(8));
    expect(robot.peakClusterLayer, findsNothing);
    expect(find.byKey(const Key('peak-marker-layer')), findsOneWidget);
  });
}
