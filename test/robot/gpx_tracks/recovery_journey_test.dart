import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';

import 'recovery_robot.dart';

void main() {
  testWidgets('recovery banner opens settings and reset clears recovery', (
    tester,
  ) async {
    final robot = RecoveryRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 10,
        basemap: Basemap.tracestrack,
        hasTrackRecoveryIssue: true,
        tracks: const [],
      ),
    );

    await robot.pumpApp();

    expect(robot.banner, findsWidgets);
    expect(robot.importFab, findsOneWidget);
    expect(robot.showTracksFab, findsOneWidget);

    await robot.openSettingsFromBanner();
    expect(find.text('Settings'), findsOneWidget);

    await robot.resetTrackData();
    expect(find.text('Track Data Reset'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Imported 1'),
      ),
      findsOneWidget,
    );
  });
}
